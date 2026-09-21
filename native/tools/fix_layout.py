from pathlib import Path
root = Path(__file__).resolve().parents[1]
p = root / 'src/CajaClara.Windows/MainWindow.cs'
s = p.read_text(encoding='utf-8')
s = s.replace('AppWindow.Resize(new global::Windows.Graphics.SizeInt32(1360, 900));', '''var display = Microsoft.UI.Windowing.DisplayArea.GetFromWindowId(AppWindow.Id, Microsoft.UI.Windowing.DisplayAreaFallback.Primary);
        var work = display.WorkArea;
        var width = Math.Min(1360, Math.Max(640, work.Width - 32));
        var height = Math.Min(900, Math.Max(480, work.Height - 32));
        AppWindow.MoveAndResize(new global::Windows.Graphics.RectInt32(work.X + (work.Width - width) / 2, work.Y + (work.Height - height) / 2, width, height));''')
p.write_text(s, encoding='utf-8')
p = root / 'src/CajaClara.Windows/PosPages.cs'
s = p.read_text(encoding='utf-8')
s = s.replace('Height = 410, SelectionMode', 'Height = Math.Clamp(root.ActualHeight - 480, 160, 360), SelectionMode')
s = s.replace('var right = Column(); right.Children.Add', 'var right = Column(7); right.Children.Add')
s = s.replace('Height = 290, SelectionMode', 'Height = Math.Clamp(root.ActualHeight - 590, 100, 260), SelectionMode')
s = s.replace('Heading(vm.TotalText, 36)', 'Heading(vm.TotalText, 32)')
s = s.replace('Button("Cantidad / descuento · F6", EditCartAsync)', 'Button("Editar · F6 / F7", EditCartAsync)')
s = s.replace('right.Children.Add(saleNotes); right.Children.Add(fiscalPending); right.Children.Add(caption); right.Children.Add(total);', '''right.Children.Add(new Expander { Header = "Datos adicionales de la venta", HorizontalAlignment = HorizontalAlignment.Stretch, Content = Column(saleNotes, fiscalPending) });
        right.Children.Add(caption); right.Children.Add(total);''')
s = s.replace('var leftCard = Card(left); var rightCard = Card(right);', 'var leftCard = Card(left); var rightCard = Card(right); leftCard.Padding = new Thickness(14); rightCard.Padding = new Thickness(14);')
s = s.replace('var narrow = e.NewSize.Width < 930;', 'var narrow = e.NewSize.Width < 660;')
p.write_text(s, encoding='utf-8')
p = root / 'tests/ui_smoke.py'
s = p.read_text(encoding='utf-8')
s = s.replace("exe = output / 'package/app/CajaClara.exe'", "exe = Path(os.environ.get('CAJACLARA_UI_EXE', str(output / 'package/app/CajaClara.exe')))")
s = s.replace("    ImageGrab.grab(all_screens=True).save(output / name)", "    if window is not None and window.exists():\n        window.wrapper_object().capture_as_image().save(output / name)\n    else:\n        ImageGrab.grab(all_screens=True).save(output / name)")
s = s.replace("    time.sleep(3)\n    capture('windows-01-onboarding.png')", "    window.wrapper_object().maximize()\n    time.sleep(3)\n    capture('windows-01-onboarding.png')")
p.write_text(s, encoding='utf-8')
print('Adapted initial window and POS density to smaller work areas; capture only the real application window.')
