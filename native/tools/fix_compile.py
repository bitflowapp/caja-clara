from pathlib import Path
root = Path(__file__).resolve().parents[1]
p = root / 'src/CajaClara.Core/Application/Reports.cs'
s = p.read_text(encoding='utf-8')
s = s.replace('return new(from, to, sales.Length, gross, returned, gross - returned, margin,', 'return new SalesReport(from, to, sales.Length, gross, returned, gross - returned, margin,')
s = s.replace('sheet.ColumnsUsed().AdjustToContents(10, 42);', 'sheet.ColumnsUsed().AdjustToContents(10d, 42d);')
p.write_text(s, encoding='utf-8')
print('Applied explicit report result type and bounded column autofit.')
