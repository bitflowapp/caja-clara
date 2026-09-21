from pathlib import Path
root = Path(__file__).resolve().parents[1]
p = root / 'src/CajaClara.Windows/MainWindow.cs'
s = p.read_text(encoding='utf-8').replace('global::Windows.UI.Text.FontWeights.SemiBold', 'Microsoft.UI.Text.FontWeights.SemiBold')
p.write_text(s, encoding='utf-8')
print('Corrected WinUI font weights namespace.')
