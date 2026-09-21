using CajaClara.Core;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using global::Windows.Storage.Pickers;

namespace CajaClara.Windows;

public sealed partial class MainWindow
{
    private UIElement BuildProducts()
    {
        var panel = Column(18); var search = Input("Filtrar productos");
        var list = new ListView { ItemsSource = vm.Snapshot?.Products.OrderBy(x => x.Name).ToArray(), DisplayMemberPath = "Display", Height = 460 };
        search.TextChanged += (_, _) => list.ItemsSource = vm.Snapshot?.Products.Where(x => x.Name.Contains(search.Text, StringComparison.OrdinalIgnoreCase) || x.Code.Contains(search.Text, StringComparison.OrdinalIgnoreCase) || x.Barcode.Contains(search.Text, StringComparison.Ordinal)).OrderBy(x => x.Name).ToArray();
        panel.Children.Add(search); panel.Children.Add(list);
        if (!vm.CanManage) { panel.Children.Add(Body("Catálogo en modo consulta.")); return panel; }
        Product Selected() => list.SelectedItem as Product ?? throw new BusinessException("Seleccioná un producto.");
        panel.Children.Add(Row(Button("Nuevo producto", () => ProductFormAsync(null), true), Button("Editar", () => ProductFormAsync(Selected())), Button("Ajustar stock", async () =>
        {
            var p = Selected(); var quantity = Input("Variación: positiva para ingreso, negativa para salida"); var reason = Input("Motivo obligatorio");
            if (await FormAsync("Ajustar " + p.Name, Column(Body("Stock actual: " + p.StockText), quantity, reason), async () =>
            {
                if (!decimal.TryParse(quantity.Text, System.Globalization.NumberStyles.Number, Money.Culture, out var value) || value == 0) throw new BusinessException("Cantidad inválida.");
                var delta = Money.Quantity(Math.Abs(value)) * Math.Sign(value);
                await Task.Run(() => vm.Pos.AdjustStock(vm.User, new(p.Id, p.Version, delta, reason.Text)));
            })) await Navigate("products");
        })));
        panel.Children.Add(Row(Button("Exportar catálogo XLSX", async () =>
        {
            var path = await SavePathAsync("Productos-CajaClara", ".xlsx"); if (path is null) return;
            await Task.Run(() => vm.Reports.ExportProducts(vm.User, path)); Notify("Catálogo exportado."); Launch(path);
        }), Button("Plantilla de importación", async () =>
        {
            var path = await SavePathAsync("Plantilla-Productos-CajaClara", ".xlsx"); if (path is null) return;
            await Task.Run(() => vm.Reports.ExportProducts(vm.User, path, true)); Launch(path);
        }), Button("Importar XLSX", async () =>
        {
            var path = await OpenPathAsync(".xlsx"); if (path is null) return;
            var preview = await Task.Run(() => vm.Reports.PreviewProducts(vm.User, path));
            var detail = $"{preview.Valid} productos válidos. {preview.Errors} errores.\n" + string.Join("\n", preview.Rows.Where(x => x.Error.Length > 0).Take(20).Select(x => $"Fila {x.Row}: {x.Error}"));
            if (preview.Errors != 0 || preview.Valid == 0) { await FormAsync("No se importó ningún producto", Column(Body(detail)), () => Task.CompletedTask, "Entendido"); return; }
            if (await FormAsync("Revisar importación", Column(Body(detail + "\nSe incorporarán productos nuevos con movimiento de stock inicial.")), async () => { await Task.Run(() => vm.Reports.ImportProducts(vm.User, preview)); }, "Importar"))
            { await Navigate("products"); Notify("Importación completada."); }
        })));
        return panel;
    }
    private async Task ProductFormAsync(Product? old)
    {
        var code = Input("Código interno", old?.Code ?? ""); var barcode = Input("Código de barras", old?.Barcode ?? ""); var name = Input("Producto", old?.Name ?? ""); var category = Input("Categoría", old?.Category ?? "");
        var cost = Input("Costo en pesos", DecimalText(old?.CostCents ?? 0)); var price = Input("Precio final en pesos", old is null ? "" : DecimalText(old.PriceCents));
        var stock = Input("Stock inicial", ((old?.StockMilli ?? 0) / 1000m).ToString("0.###", Money.Culture)); stock.IsEnabled = old is null;
        var minimum = Input("Stock mínimo", ((old?.MinStockMilli ?? 0) / 1000m).ToString("0.###", Money.Culture));
        var unit = new ComboBox { Header = "Unidad", ItemsSource = new[] { "un", "kg", "l", "m" }, SelectedItem = old?.Unit ?? "un", MinWidth = 240 };
        var vat = new ComboBox { Header = "IVA incluido (porcentaje)", ItemsSource = new[] { "0", "2,5", "5", "10,5", "21", "27" }, SelectedItem = ((old?.VatBasisPoints ?? 2100) / 100m).ToString("0.##", Money.Culture), MinWidth = 240 };
        var active = new CheckBox { Content = "Producto disponible para vender", IsChecked = old?.Active ?? true };
        var id = old?.Id ?? Guid.NewGuid();
        if (await FormAsync(old is null ? "Nuevo producto" : "Editar producto", Column(code, barcode, name, category, cost, price, stock, minimum, unit, vat, active), async () =>
        {
            long QuantityOrZero(TextBox field) => decimal.TryParse(field.Text, System.Globalization.NumberStyles.Number, Money.Culture, out var n) ? n == 0 ? 0 : Money.Quantity(n) : throw new BusinessException("Cantidad inválida.");
            var value = new Product(id, (old?.Version ?? 0) + 1, code.Text, barcode.Text, name.Text, category.Text, Amount(cost), Amount(price, false),
                (int)Money.Cents(decimal.Parse(vat.SelectedItem?.ToString() ?? "21", Money.Culture)), old?.StockMilli ?? QuantityOrZero(stock), QuantityOrZero(minimum), unit.SelectedItem?.ToString() ?? "un", active.IsChecked == true, old?.SupplierId);
            await Task.Run(() => vm.Pos.SaveProduct(vm.User, value, old?.Version ?? 0));
        })) { await Navigate("products"); Notify("Producto guardado."); }
    }
    private UIElement BuildContacts()
    {
        var list = new ListView { ItemsSource = vm.Snapshot?.Contacts.OrderBy(x => x.Supplier).ThenBy(x => x.Name).ToArray(), DisplayMemberPath = "Display", Height = 480 };
        var panel = Column(18); panel.Children.Add(list);
        if (vm.CanSell) panel.Children.Add(Row(Button("Nuevo cliente / proveedor", () => ContactFormAsync(null), true), Button("Editar", () => ContactFormAsync(list.SelectedItem as Contact ?? throw new BusinessException("Seleccioná un contacto.")))));
        return panel;
    }
    private async Task ContactFormAsync(Contact? old)
    {
        var name = Input("Nombre / razón social", old?.Name ?? ""); var tax = Input("Documento / CUIT", old?.TaxId ?? "");
        var phone = Input("Teléfono", old?.Phone ?? ""); var email = Input("Correo", old?.Email ?? ""); var address = Input("Domicilio", old?.Address ?? "");
        var supplier = new CheckBox { Content = "Es proveedor", IsChecked = old?.Supplier ?? false };
        var condition = Input("Condición IVA receptor (código ARCA)", (old?.TaxCondition ?? 5).ToString()); var id = old?.Id ?? Guid.NewGuid();
        if (await FormAsync("Datos del contacto", Column(name, tax, phone, email, address, supplier, condition), async () =>
        {
            if (!int.TryParse(condition.Text, out var code)) throw new BusinessException("Condición IVA inválida.");
            await Task.Run(() => vm.Pos.SaveContact(vm.User, new Contact(id, (old?.Version ?? 0) + 1, name.Text, tax.Text, phone.Text, email.Text, address.Text, supplier.IsChecked == true, code), old?.Version ?? 0));
        })) await Navigate("contacts");
    }
    private UIElement BuildPurchases()
    {
        var panel = Column(18);
        if (!vm.CanManage) { panel.Children.Add(Body("Compras requiere permisos de administración.")); return panel; }
        var purchases = vm.Pos.History<Purchase>(vm.User).OrderByDescending(x => x.At).ToArray();
        panel.Children.Add(Body("La recepción incrementa stock y actualiza el costo. El pago en efectivo afecta la caja abierta."));
        panel.Children.Add(Button("Recibir mercadería", PurchaseFormAsync, true));
        panel.Children.Add(new ListView { Height = 440, ItemsSource = purchases.Select(x => $"{x.At.ToLocalTime():dd/MM/yyyy HH:mm} · {x.Reference} · Total {Money.Format(x.TotalCents)} · Pendiente proveedor {Money.Format(x.TotalCents - x.PaidCents)}").ToArray() });
        return panel;
    }
    private async Task PurchaseFormAsync()
    {
        var suppliers = vm.Snapshot?.Contacts.Where(x => x.Supplier).ToArray() ?? [];
        if (suppliers.Length == 0) throw new BusinessException("Primero cargá un proveedor en Clientes y proveedores.");
        var supplier = new ComboBox { Header = "Proveedor", ItemsSource = suppliers, DisplayMemberPath = "Display", SelectedIndex = 0, MinWidth = 320 };
        var product = new ComboBox { Header = "Producto", ItemsSource = vm.Snapshot?.Products, DisplayMemberPath = "Name", MinWidth = 320 };
        var quantity = Input("Cantidad recibida", "1"); var cost = Input("Costo unitario en pesos");
        var reference = Input("Referencia / factura del proveedor"); var paid = Input("Pago desde efectivo de caja", "0,00");
        var lines = new List<PurchaseLine>(); var list = new ListView { Height = 130 }; var error = Body("");
        var add = new Button { Content = "Agregar producto" }; var remove = new Button { Content = "Quitar seleccionado" };
        void Refresh() => list.ItemsSource = lines.Select(x => $"{vm.Snapshot?.Products.FirstOrDefault(p => p.Id == x.ProductId)?.Name} · {x.QuantityMilli / 1000m:0.###} × {Money.Format(x.UnitCostCents)}").ToArray();
        product.SelectionChanged += (_, _) => { if (product.SelectedItem is Product p) cost.Text = DecimalText(p.CostCents); };
        add.Click += (_, _) =>
        {
            try
            {
                if (product.SelectedItem is not Product selected || !decimal.TryParse(quantity.Text, System.Globalization.NumberStyles.Number, Money.Culture, out var qty)) throw new BusinessException("Seleccioná producto y cantidad válida.");
                if (lines.Any(x => x.ProductId == selected.Id)) throw new BusinessException("El producto ya fue agregado. Quitalo para corregir la cantidad.");
                lines.Add(new(selected.Id, Money.Quantity(qty), Amount(cost, false))); Refresh(); error.Text = "";
            }
            catch (BusinessException e) { error.Text = e.Message; }
        };
        remove.Click += (_, _) => { if (list.SelectedIndex >= 0) lines.RemoveAt(list.SelectedIndex); Refresh(); };
        var id = Guid.NewGuid();
        if (await FormAsync("Recepción de compra", Column(supplier, product, quantity, cost, Row(add, remove), list, reference, paid, error), async () =>
        {
            if (supplier.SelectedItem is not Contact selected) throw new BusinessException("Seleccioná un proveedor.");
            if (string.IsNullOrWhiteSpace(reference.Text)) throw new BusinessException("Indicá una referencia de la compra.");
            await Task.Run(() => vm.Pos.ReceivePurchase(vm.User, id, selected.Id, lines.ToArray(), Amount(paid), reference.Text));
        }, "Recibir y guardar")) { await Navigate("purchases"); Notify("Compra recibida y stock actualizado."); }
    }
    private UIElement BuildReports()
    {
        var panel = Column(18);
        if (vm.User.Role is not (Role.Owner or Role.Admin or Role.Viewer)) { panel.Children.Add(Body("Los reportes completos requieren permiso de administración o consulta.")); return panel; }
        var from = new CalendarDatePicker { Header = "Desde", Date = DateTimeOffset.Now.Date, MinWidth = 220 };
        var to = new CalendarDatePicker { Header = "Hasta (inclusive)", Date = DateTimeOffset.Now.Date, MinWidth = 220 };
        var output = Column();
        async Task<SalesReport> Report()
        {
            if (from.Date is null || to.Date is null) throw new BusinessException("Seleccioná las fechas.");
            var start = new DateTimeOffset(from.Date.Value.Date, DateTimeOffset.Now.Offset);
            var end = new DateTimeOffset(to.Date.Value.Date.AddDays(1), DateTimeOffset.Now.Offset);
            return await Task.Run(() => vm.Reports.Sales(vm.User, start, end));
        }
        panel.Children.Add(Row(from, to));
        panel.Children.Add(Row(Button("Consultar", async () =>
        {
            var report = await Report(); output.Children.Clear();
            output.Children.Add(Card(Column(Heading("Ventas netas: " + Money.Format(report.NetSalesCents)), Body($"{report.Transactions} ventas · Bruto {Money.Format(report.GrossCents)} · Devoluciones del período {Money.Format(report.RefundsCents)}"),
                Heading("Margen bruto estimado: " + Money.Format(report.EstimatedMarginCents), 20), Body("No es ganancia neta: no descuenta gastos, comisiones ni impuestos."))));
            foreach (var (method, value) in report.Payments) output.Children.Add(Body(method + ": " + Money.Format(value)));
        }, true), Button("Exportar XLSX", async () =>
        {
            var report = await Report(); var path = await SavePathAsync("Ventas-CajaClara", ".xlsx"); if (path is null) return;
            await Task.Run(() => vm.Reports.ExportSales(vm.User, report.From, report.To, path)); Launch(path);
        }), Button("Exportar PDF", async () =>
        {
            var report = await Report(); var path = await SavePathAsync("Reporte-CajaClara", ".pdf"); if (path is null) return;
            var lines = new List<string> { vm.Snapshot?.Business?.Name ?? "Caja Clara", "REPORTE COMERCIAL - NO FISCAL", $"Desde {report.From:dd/MM/yyyy} hasta {report.To.AddDays(-1):dd/MM/yyyy}", "Ventas netas: " + Money.Format(report.NetSalesCents), "Devoluciones: " + Money.Format(report.RefundsCents), "Margen bruto estimado: " + Money.Format(report.EstimatedMarginCents), "No descuenta gastos, comisiones ni impuestos." };
            lines.AddRange(report.Sales.Select(x => x.Display)); await Task.Run(() => Receipt.Pdf(path, lines.ToArray(), 210)); Launch(path);
        })));
        panel.Children.Add(output); return panel;
    }
    private async Task<string?> SavePathAsync(string name, string extension)
    {
        var picker = new FileSavePicker { SuggestedStartLocation = PickerLocationId.DocumentsLibrary, SuggestedFileName = name };
        picker.FileTypeChoices.Add(extension == ".xlsx" ? "Libro Excel" : "Documento PDF", new List<string> { extension });
        WinRT.Interop.InitializeWithWindow.Initialize(picker, WinRT.Interop.WindowNative.GetWindowHandle(this));
        var file = await picker.PickSaveFileAsync(); return file?.Path;
    }
    private async Task<string?> OpenPathAsync(string extension)
    {
        var picker = new FileOpenPicker { SuggestedStartLocation = PickerLocationId.DocumentsLibrary };
        picker.FileTypeFilter.Add(extension); WinRT.Interop.InitializeWithWindow.Initialize(picker, WinRT.Interop.WindowNative.GetWindowHandle(this));
        var file = await picker.PickSingleFileAsync(); return file?.Path;
    }
}
