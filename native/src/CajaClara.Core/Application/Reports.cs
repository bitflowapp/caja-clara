using System.Globalization;
using System.Text;
using ClosedXML.Excel;

namespace CajaClara.Core;

public sealed record SalesReport(DateTimeOffset From, DateTimeOffset To, int Transactions,
    long GrossCents, long RefundsCents, long NetSalesCents, long EstimatedMarginCents,
    long AuthorizedCents, IReadOnlyDictionary<string, long> Payments, Sale[] Sales);
public sealed record ImportRow(int Row, Product? Product, string Error);
public sealed record ImportPreview(ImportRow[] Rows)
{
    public int Valid => Rows.Count(x => x.Product is not null && x.Error.Length == 0);
    public int Errors => Rows.Count(x => x.Error.Length != 0);
}
public sealed class Reports(Store store)
{
    public SalesReport Sales(Actor actor, DateTimeOffset from, DateTimeOffset to) => store.Read(tx =>
    {
        AuthService.Require(tx, actor, Role.Owner, Role.Admin, Role.Viewer);
        if (from >= to || to - from > TimeSpan.FromDays(3660)) throw new BusinessException("Período inválido.");
        var sales = tx.All<Sale>().Where(x => x.At >= from && x.At < to).OrderBy(x => x.At).ToArray();
        var refunds = tx.All<Refund>().Where(x => x.At >= from && x.At < to).ToArray();
        var allSales = tx.All<Sale>().ToDictionary(x => x.Id);
        var margin = sales.Sum(x => x.Lines.Sum(l => l.TotalCents - Money.Extend(l.CostCents, l.QuantityMilli)));
        margin -= refunds.Sum(r => allSales.TryGetValue(r.SaleId, out var sale) ? sale.Lines.Sum(l => l.TotalCents - Money.Extend(l.CostCents, l.QuantityMilli)) : 0);
        var payments = Enum.GetValues<PaymentMethod>().ToDictionary(x => x.ToString(), x =>
            sales.Sum(s => s.Payments.Where(p => p.Method == x).Sum(p => p.AppliedCents)) -
            refunds.Sum(r => r.Payments.Where(p => p.Method == x).Sum(p => p.AppliedCents)));
        var gross = sales.Sum(x => x.TotalCents); var returned = refunds.Sum(x => x.TotalCents);
        return new(from, to, sales.Length, gross, returned, gross - returned, margin,
            sales.Where(x => x.FiscalState == FiscalState.Authorized).Sum(x => x.TotalCents), payments, sales);
    });
    public void ExportSales(Actor actor, DateTimeOffset from, DateTimeOffset to, string path)
    {
        var report = Sales(actor, from, to); using var book = new XLWorkbook();
        var summary = book.AddWorksheet("Resumen");
        string[] titles = ["Desde (inclusive)", "Hasta (exclusivo)", "Ventas", "Bruto", "Devoluciones", "Ventas netas", "Margen bruto estimado", "Autorizado fiscal"];
        for (var i = 0; i < titles.Length; i++) summary.Cell(i + 1, 1).Value = titles[i];
        summary.Cell(1, 2).Value = from.LocalDateTime; summary.Cell(2, 2).Value = to.LocalDateTime;
        summary.Range("B1:B2").Style.DateFormat.Format = "dd/mm/yyyy hh:mm";
        summary.Cell(3, 2).Value = report.Transactions;
        summary.Cell(4, 2).Value = report.GrossCents / 100m;
        summary.Cell(5, 2).Value = report.RefundsCents / 100m;
        summary.Cell(6, 2).FormulaA1 = "B4-B5";
        summary.Cell(7, 2).Value = report.EstimatedMarginCents / 100m;
        summary.Cell(8, 2).Value = report.AuthorizedCents / 100m;
        summary.Range("B4:B8").Style.NumberFormat.Format = "$ #,##0.00";
        summary.Cell(10, 1).Value = "El margen no descuenta impuestos, comisiones ni gastos operativos.";
        summary.Range("A10:D10").Merge().Style.Alignment.WrapText = true;
        var sheet = book.AddWorksheet("Ventas");
        string[] headers = ["Número", "Fecha", "Vendedor", "Cliente", "Total", "Devuelto acumulado", "Estado fiscal", "Identificador"];
        Header(sheet, headers); var row = 2;
        foreach (var sale in report.Sales)
        {
            sheet.Cell(row, 1).Value = sale.Number; sheet.Cell(row, 2).Value = sale.At.LocalDateTime;
            sheet.Cell(row, 3).Value = sale.UserName; sheet.Cell(row, 4).Value = sale.Customer?.Name ?? "Consumidor final";
            sheet.Cell(row, 5).Value = sale.TotalCents / 100m; sheet.Cell(row, 6).Value = sale.RefundedCents / 100m;
            sheet.Cell(row, 7).Value = sale.FiscalState.ToString(); sheet.Cell(row, 8).Value = sale.Id.ToString(); row++;
        }
        sheet.Column(2).Style.DateFormat.Format = "dd/mm/yyyy hh:mm";
        sheet.Columns(5, 6).Style.NumberFormat.Format = "$ #,##0.00";
        var methods = book.AddWorksheet("Medios de pago"); Header(methods, ["Medio", "Neto del período"]); row = 2;
        foreach (var (method, value) in report.Payments) { methods.Cell(row, 1).Value = method; methods.Cell(row++, 2).Value = value / 100m; }
        methods.Column(2).Style.NumberFormat.Format = "$ #,##0.00";
        foreach (var ws in book.Worksheets) Finish(ws);
        Save(book, path);
    }
    public void ExportProducts(Actor actor, string path, bool empty = false)
    {
        var products = store.Read(tx => { AuthService.Require(tx, actor, Role.Owner, Role.Admin); return tx.All<Product>(); });
        using var book = new XLWorkbook(); var sheet = book.AddWorksheet("Productos");
        Header(sheet, ImportHeaders); var row = 2;
        if (!empty) foreach (var p in products.OrderBy(x => x.Name))
        {
            sheet.Cell(row, 1).Value = p.Code; sheet.Cell(row, 2).Value = p.Barcode;
            sheet.Cell(row, 3).Value = p.Name; sheet.Cell(row, 4).Value = p.Category;
            sheet.Cell(row, 5).Value = p.CostCents / 100m; sheet.Cell(row, 6).Value = p.PriceCents / 100m;
            sheet.Cell(row, 7).Value = p.StockMilli / 1000m; sheet.Cell(row, 8).Value = p.MinStockMilli / 1000m;
            sheet.Cell(row, 9).Value = p.Unit; sheet.Cell(row, 10).Value = p.VatBasisPoints / 100m; row++;
        }
        sheet.Columns(1, 2).Style.NumberFormat.Format = "@";
        sheet.Columns(5, 6).Style.NumberFormat.Format = "0.00";
        sheet.Columns(7, 8).Style.NumberFormat.Format = "0.###";
        var help = book.AddWorksheet("Instrucciones");
        help.Cell(1, 1).Value = "Importa productos nuevos. No sobrescribe productos ni stock existentes.";
        help.Cell(2, 1).Value = "Código y código de barras: texto. Conservar ceros iniciales.";
        help.Cell(3, 1).Value = "Unidad: un, kg, l o m. IVA: 0; 2,5; 5; 10,5; 21; 27.";
        help.Cell(4, 1).Value = "Precios finales en pesos argentinos. Hasta dos decimales; cantidades hasta tres.";
        help.Column(1).Width = 90; help.Column(1).Style.Alignment.WrapText = true;
        Finish(sheet); Save(book, path);
    }
    public static readonly string[] ImportHeaders = ["Código", "Código de barras", "Producto", "Categoría", "Costo", "Precio", "Stock", "Stock mínimo", "Unidad", "IVA %"];
    public ImportPreview PreviewProducts(Actor actor, string path)
    {
        var existing = store.Read(tx => { AuthService.Require(tx, actor, Role.Owner, Role.Admin); return tx.All<Product>(); });
        if (new FileInfo(path).Length > 20_000_000) throw new BusinessException("El archivo excede 20 MB.");
        using var book = new XLWorkbook(path);
        if (!book.TryGetWorksheet("Productos", out var sheet)) throw new BusinessException("Falta la hoja Productos. Utilizá la plantilla de Caja Clara.");
        for (var i = 0; i < ImportHeaders.Length; i++) if (sheet.Cell(1, i + 1).GetString().Trim() != ImportHeaders[i])
            throw new BusinessException($"Encabezado inválido: columna {i + 1}. Usá la plantilla.");
        var count = sheet.LastRowUsed()?.RowNumber() ?? 1;
        if (count > 10001) throw new BusinessException("Máximo 10.000 productos por importación.");
        var codes = existing.Select(x => x.Code).ToHashSet(StringComparer.OrdinalIgnoreCase);
        var bars = existing.Where(x => x.Barcode.Length > 0).Select(x => x.Barcode).ToHashSet(StringComparer.Ordinal);
        var rows = new List<ImportRow>();
        for (var row = 2; row <= count; row++)
        {
            if (sheet.Row(row).Cells(1, 10).All(x => x.IsEmpty())) continue;
            try
            {
                if (sheet.Row(row).Cells(1, 10).Any(x => x.HasFormula)) throw new BusinessException("No se admiten fórmulas en productos importados.");
                string Text(int col) => sheet.Cell(row, col).GetString().Trim();
                decimal Number(int col) => sheet.Cell(row, col).TryGetValue<decimal>(out var n) ? n :
                    decimal.TryParse(Text(col), NumberStyles.Number, Money.Culture, out n) ? n : throw new BusinessException($"Número inválido en columna {col}.");
                var code = Text(1).ToUpperInvariant(); var barcode = Text(2); var name = Text(3); var unit = Text(9);
                if (code.Length is < 1 or > 40 || barcode.Length > 64 || name.Length is < 1 or > 160 || Text(4).Length > 80)
                    throw new BusinessException("Nombre, código o categoría inválidos.");
                if (codes.Contains(code) || (barcode.Length > 0 && bars.Contains(barcode))) throw new BusinessException("Código o código de barras duplicado/existente.");
                if (unit is not ("un" or "kg" or "l" or "m")) throw new BusinessException("Unidad inválida.");
                long Qty(int col) => Number(col) == 0 ? 0 : Money.Quantity(Number(col));
                var vat = Money.Cents(Number(10));
                if (vat is not (0 or 250 or 500 or 1050 or 2100 or 2700)) throw new BusinessException("IVA no admitido.");
                var p = new Product(Guid.NewGuid(), 1, code, barcode, name, Text(4), Money.Cents(Number(5)), Money.Cents(Number(6)), (int)vat, Qty(7), Qty(8), unit, true);
                Money.Valid(p.PriceCents, false);
                if (unit == "un" && (p.StockMilli % 1000 != 0 || p.MinStockMilli % 1000 != 0)) throw new BusinessException("Stock por unidad debe ser entero.");
                codes.Add(code); if (barcode.Length > 0) bars.Add(barcode); rows.Add(new(row, p, ""));
            }
            catch (Exception e) when (e is BusinessException or FormatException or OverflowException)
            { rows.Add(new(row, null, e.Message)); }
        }
        return new(rows.ToArray());
    }
    public int ImportProducts(Actor actor, ImportPreview preview) => store.Write(tx =>
    {
        var user = AuthService.Require(tx, actor, Role.Owner, Role.Admin);
        if (preview.Errors != 0 || preview.Valid == 0) throw new BusinessException("Corregí los errores antes de importar.");
        var business = tx.All<Business>().Single();
        foreach (var row in preview.Rows)
        {
            var p = row.Product ?? throw new BusinessException("Fila inválida.");
            tx.Put(p, 0);
            if (p.StockMilli != 0) tx.Put(new StockMovement(Guid.NewGuid(), 1, p.Id, user.Id, 0, p.StockMilli, p.StockMilli, "IMPORT", "Carga inicial XLSX", null, tx.Now), 0);
            tx.Audit(user, business.DeviceId, "PRODUCT_IMPORTED", p.Id, null, p);
        }
        return preview.Valid;
    });
    private static void Header(IXLWorksheet sheet, string[] headers)
    {
        for (var i = 0; i < headers.Length; i++) sheet.Cell(1, i + 1).Value = headers[i];
        var range = sheet.Range(1, 1, 1, headers.Length);
        range.Style.Font.Bold = true; range.Style.Font.FontColor = XLColor.White;
        range.Style.Fill.BackgroundColor = XLColor.FromHtml("26384A");
        sheet.SheetView.FreezeRows(1); sheet.Row(1).Height = 26;
    }
    private static void Finish(IXLWorksheet sheet)
    {
        sheet.Style.Font.FontName = "Calibri"; sheet.Style.Font.FontSize = 11;
        sheet.ColumnsUsed().AdjustToContents(10, 42);
        var range = sheet.RangeUsed(); if (range is not null && range.RowCount() > 1 && sheet.Name != "Resumen") range.SetAutoFilter();
    }
    private static void Save(XLWorkbook book, string path)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(Path.GetFullPath(path))!);
        var temporary = path + ".writing.xlsx";
        try { book.SaveAs(temporary); File.Move(temporary, path, true); }
        finally { if (File.Exists(temporary)) File.Delete(temporary); }
    }
}

public static class Receipt
{
    public static string[] Lines(Business business, Sale sale, int columns = 42)
    {
        var result = new List<string>();
        void Add(string text) { foreach (var line in Wrap(text, columns)) result.Add(line); }
        Add(business.Name); Add("CAJA CLARA - Tu negocio, claro.");
        Add("COMPROBANTE INTERNO NO FISCAL");
        if (business.Demo) Add("MODO DEMOSTRACION - SIN VALIDEZ");
        if (business.TaxId.Length > 0) Add("CUIT: " + business.TaxId);
        if (business.Address.Length > 0) Add(business.Address);
        Add($"Venta {sale.Number:000000} - {sale.At.ToLocalTime():dd/MM/yyyy HH:mm}");
        Add("Vendedor: " + sale.UserName); Add("Cliente: " + (sale.Customer?.Name ?? "Consumidor final"));
        Add(new string('-', columns));
        foreach (var line in sale.Lines)
        {
            Add(line.Name);
            Add($"{line.QuantityMilli / 1000m:0.###} x {Money.Format(line.UnitPriceCents)} = {Money.Format(line.TotalCents)}");
            if (line.DiscountCents > 0) Add("Descuento: " + Money.Format(line.DiscountCents));
        }
        Add(new string('-', columns)); Add("TOTAL: " + Money.Format(sale.TotalCents));
        foreach (var p in sale.Payments) Add($"{p.Method}: {Money.Format(p.AppliedCents)}");
        if (sale.ChangeCents > 0) Add("Vuelto: " + Money.Format(sale.ChangeCents));
        if (sale.RefundedCents > 0) Add("DEVUELTO: " + Money.Format(sale.RefundedCents));
        Add("Este ticket no reemplaza una factura.");
        Add("Estado fiscal: " + sale.FiscalState);
        if (sale.Payments.Any(x => x.Method != PaymentMethod.Cash)) Add("Cobros electronicos registrados manualmente; verificar conciliacion.");
        if (sale.Notes.Length > 0) Add(sale.Notes);
        Add("ID: " + sale.Id); return result.ToArray();
    }
    public static IEnumerable<string> Wrap(string text, int columns)
    {
        foreach (var original in text.Replace("\r", "").Split('\n'))
        {
            var remaining = original;
            while (remaining.Length > columns)
            {
                var cut = remaining.LastIndexOf(' ', columns - 1, columns);
                if (cut < columns / 3) cut = columns;
                yield return remaining[..cut]; remaining = remaining[cut..].TrimStart();
            }
            yield return remaining;
        }
    }
    public static void Pdf(string path, string[] lines, int widthMm = 80)
    {
        if (widthMm is not (58 or 80 or 210)) throw new BusinessException("Ancho de comprobante inválido.");
        var width = widthMm * 72d / 25.4; var height = widthMm == 210 ? 842d : 720d;
        const double margin = 12; var font = widthMm == 58 ? 7d : 8d; var leading = font + 3;
        var cols = (int)((width - margin * 2) / (font * .6));
        var wrapped = lines.SelectMany(x => Wrap(x, cols)).ToArray();
        var pageSize = (int)((height - margin * 2 - 12) / leading);
        var pages = wrapped.Chunk(pageSize).ToArray(); if (pages.Length == 0) pages = [Array.Empty<string>()];
        var objects = new List<byte[]>();
        byte[] Bytes(string s) => Encoding.Latin1.GetBytes(s);
        objects.Add(Bytes("<< /Type /Catalog /Pages 2 0 R >>"));
        objects.Add(Bytes("<< /Type /Pages /Count " + pages.Length + " /Kids [" + string.Join(' ', Enumerable.Range(0, pages.Length).Select(i => $"{4 + i * 2} 0 R")) + "] >>"));
        objects.Add(Bytes("<< /Type /Font /Subtype /Type1 /BaseFont /Courier /Encoding /WinAnsiEncoding >>"));
        string N(double n) => n.ToString("0.###", CultureInfo.InvariantCulture);
        for (var page = 0; page < pages.Length; page++)
        {
            objects.Add(Bytes($"<< /Type /Page /Parent 2 0 R /MediaBox [0 0 {N(width)} {N(height)}] /Resources << /Font << /F1 3 0 R >> >> /Contents {5 + page * 2} 0 R >>"));
            var content = new StringBuilder($"BT /F1 {N(font)} Tf {N(leading)} TL {N(margin)} {N(height - margin - font)} Td\n");
            foreach (var line in pages[page])
            {
                var safe = new string(line.Select(c => c is >= ' ' and <= '\u00FF' ? c : ' ').ToArray());
                content.Append('(').Append(safe.Replace("\\", "\\\\").Replace("(", "\\(").Replace(")", "\\)")).Append(") Tj T*\n");
            }
            content.Append("ET\n"); var stream = Bytes(content.ToString());
            objects.Add(Bytes($"<< /Length {stream.Length} >>\nstream\n").Concat(stream).Concat(Bytes("endstream")).ToArray());
        }
        using var output = new MemoryStream(); void Write(string text) => output.Write(Bytes(text));
        Write("%PDF-1.4\n%âãÏÓ\n"); var offsets = new List<long> { 0 };
        for (var i = 0; i < objects.Count; i++) { offsets.Add(output.Position); Write($"{i + 1} 0 obj\n"); output.Write(objects[i]); Write("\nendobj\n"); }
        var xref = output.Position; Write($"xref\n0 {objects.Count + 1}\n0000000000 65535 f \n");
        foreach (var offset in offsets.Skip(1)) Write(offset.ToString("0000000000", CultureInfo.InvariantCulture) + " 00000 n \n");
        Write($"trailer\n<< /Size {objects.Count + 1} /Root 1 0 R >>\nstartxref\n{xref}\n%%EOF\n");
        Directory.CreateDirectory(Path.GetDirectoryName(Path.GetFullPath(path))!);
        File.WriteAllBytes(path, output.ToArray());
    }
}
