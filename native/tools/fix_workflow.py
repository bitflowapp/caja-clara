from pathlib import Path
root = Path(__file__).resolve().parents[1]
# This script intentionally touches only source/test files. CI configuration is versioned separately.
# Keep scripts reproducible while the isolated development branch is being validated.
for name in ('README.md','docs/DEPLOYMENT.md','docs/FISCAL.md','docs/MERCADOPAGO.md'):
    if not (root / name).is_file():
        raise RuntimeError('Required release documentation missing: ' + name)
print('Required deployment and integration limitations are present.')
