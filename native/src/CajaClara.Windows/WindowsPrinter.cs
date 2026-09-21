using System.Drawing;
using System.Drawing.Printing;
using CajaClara.Core;

namespace CajaClara.Windows;

public sealed record PrinterPreferences(string PrinterName, int WidthMm)
{
    private static string PathName => Path.Combine(App.DataDirectory, "printer.json");
    public static PrinterPreferences Load()
    {
        if (File.Exists(PathName)) return Json.Read<PrinterPreferences>(File.ReadAllText(PathName));
        var defaults = new PrinterSettings(); return new(defaults.IsValid ? defaults.PrinterName : "", 80);
    }
    public void Save()
    {
        if (WidthMm is not (58 or 80 or 210) || !WindowsPrinter.Names().Contains(PrinterName)) throw new BusinessException("Impresora o tamaño inválido.");
        File.WriteAllText(PathName + ".new", Json.Write(this)); File.Move(PathName + ".new", PathName, true);
    }
}
public static class WindowsPrinter
{
    public static string[] Names() => PrinterSettings.InstalledPrinters.Cast<string>().ToArray();
    public static void Print(string[] lines, PrinterPreferences settings)
    {
        using var document = new PrintDocument(); document.PrinterSettings.PrinterName = settings.PrinterName;
        if (!document.PrinterSettings.IsValid || settings.WidthMm is not (58 or 80 or 210)) throw new BusinessException("Configurá una impresora válida.");
        document.DocumentName = "Caja Clara - comprobante interno";
        document.PrintController = new StandardPrintController();
        document.DefaultPageSettings.Margins = new Margins(8, 8, 10, 10);
        if (settings.WidthMm != 210) document.DefaultPageSettings.PaperSize = new PaperSize("Caja Clara " + settings.WidthMm, (int)Math.Round(settings.WidthMm * 100d / 25.4), 1100);
        using var font = new Font("Consolas", settings.WidthMm == 58 ? 7 : 8, FontStyle.Regular);
        var position = 0; string[]? wrapped = null;
        document.PrintPage += (_, e) =>
        {
            if (e.Graphics is null) throw new BusinessException("El controlador no entregó una superficie de impresión.");
            var characterWidth = e.Graphics.MeasureString("0000000000", font).Width / 10;
            var columns = Math.Max(12, (int)(e.MarginBounds.Width / characterWidth) - 1);
            wrapped ??= lines.SelectMany(x => Receipt.Wrap(x, columns)).ToArray();
            var leading = font.GetHeight(e.Graphics) + 3; var y = (float)e.MarginBounds.Top;
            while (position < wrapped.Length && y + leading <= e.MarginBounds.Bottom)
            {
                e.Graphics.DrawString(wrapped[position++], font, Brushes.Black, e.MarginBounds.Left, y); y += leading;
            }
            e.HasMorePages = position < wrapped.Length;
        };
        document.Print();
    }
}
