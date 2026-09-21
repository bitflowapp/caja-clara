from pathlib import Path
root = Path(__file__).resolve().parents[1]
p = root / 'src/CajaClara.Core/Domain/Models.cs'
s = p.read_text(encoding='utf-8')
s = s.replace('· {State} · {Money.Format(ExpectedCents)}', '· {Labels.Cash(State)} · {Money.Format(ExpectedCents)}')
anchor = 'public string Verification => Method == PaymentMethod.Cash ? "CASH_RECEIVED" : "MANUAL_UNVERIFIED";'
if 'public override string ToString() => Labels.Payment(Method)' not in s:
    s = s.replace(anchor, anchor + '\n    public override string ToString() => Labels.Payment(Method) + " · " + Money.Format(AppliedCents) + (ChangeCents > 0 ? " · Vuelto " + Money.Format(ChangeCents) : "");')
p.write_text(s, encoding='utf-8')
p = root / 'src/CajaClara.Core/Application/Reports.cs'
s = p.read_text(encoding='utf-8')
s = s.replace('sheet.Cell(row, 7).Value = sale.FiscalState.ToString();', 'sheet.Cell(row, 7).Value = Labels.Fiscal(sale.FiscalState);')
s = s.replace('Add($"{p.Method}: {Money.Format(p.AppliedCents)}");', 'Add($"{Labels.Payment(p.Method)}: {Money.Format(p.AppliedCents)}");')
s = s.replace('Add("Estado fiscal: " + sale.FiscalState);', 'Add("Estado fiscal: " + Labels.Fiscal(sale.FiscalState));')
s = s.replace('var wrapped = lines.SelectMany(x => Wrap(x, cols)).ToArray();\n        var pageSize', 'var wrapped = lines.SelectMany(x => Wrap(x, cols)).ToArray();\n        if (widthMm != 210) height = Math.Clamp(wrapped.Length * leading + margin * 2 + 12, 100d, 1440d);\n        var pageSize')
s = s.replace('try { book.SaveAs(temporary); File.Move(temporary, path, true); }', '''try
        {
            book.SaveAs(temporary, new SaveOptions { EvaluateFormulasBeforeSaving = true });
            using (var archive = System.IO.Compression.ZipFile.Open(temporary, System.IO.Compression.ZipArchiveMode.Update))
            {
                var entry = archive.GetEntry("xl/styles.xml") ?? throw new BusinessException("Faltan estilos del libro.");
                System.Xml.Linq.XDocument styles;
                using (var stream = entry.Open()) styles = System.Xml.Linq.XDocument.Load(stream);
                System.Xml.Linq.XNamespace ns = "http://schemas.openxmlformats.org/spreadsheetml/2006/main";
                foreach (var format in styles.Descendants(ns + "xf"))
                {
                    if ((string?)format.Attribute("fillId") is string fill && fill != "0") format.SetAttributeValue("applyFill", "1");
                    if ((string?)format.Attribute("fontId") is string font && font != "0") format.SetAttributeValue("applyFont", "1");
                }
                entry.Delete();
                using var target = archive.CreateEntry("xl/styles.xml").Open(); styles.Save(target);
            }
            File.Move(temporary, path, true);
        }''')
p.write_text(s, encoding='utf-8')
p = root / 'src/CajaClara.Windows/PosPages.cs'
s = p.read_text(encoding='utf-8')
s = s.replace('ItemsSource = Enum.GetValues<PaymentMethod>(), SelectedIndex = 0', 'ItemsSource = PaymentChoice.All, DisplayMemberPath = "Label", SelectedIndex = 0')
s = s.replace('if (method.SelectedItem is not PaymentMethod selected) throw new BusinessException("Elegí un medio.");', 'if (method.SelectedItem is not PaymentChoice choice) throw new BusinessException("Elegí un medio.");\n                var selected = choice.Value;')
p.write_text(s, encoding='utf-8')
p = root / 'src/CajaClara.Windows/MainWindow.cs'
s = p.read_text(encoding='utf-8').replace('{vm.User.Name} ({vm.User.Role})', '{vm.User.Name} ({Labels.UserRole(vm.User.Role)})')
p.write_text(s, encoding='utf-8')
print('Applied Spanish payment labels, compact receipts and explicit spreadsheet header styles.')
