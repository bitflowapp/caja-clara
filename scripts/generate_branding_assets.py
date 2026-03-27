from __future__ import annotations

from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parent.parent
BRANDING_DIR = ROOT / "assets" / "branding"
WINDOWS_ICON_PATH = ROOT / "windows" / "runner" / "resources" / "app_icon.ico"

ICON_SOURCE_PATH = BRANDING_DIR / "caja_clara_icon_source.png"
SYMBOL_PATH = BRANDING_DIR / "caja_clara_symbol.png"
FAVICON_32_PATH = BRANDING_DIR / "favicon-32.png"
ICON_48_PATH = BRANDING_DIR / "icon-48.png"

SYMBOL_HEIGHT = 1024
ICO_SIZES = [(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]


def main() -> None:
    source = Image.open(ICON_SOURCE_PATH).convert("RGBA")
    alpha_bbox = source.getchannel("A").getbbox()
    if alpha_bbox is None:
        raise RuntimeError(f"No opaque pixels found in {ICON_SOURCE_PATH}")

    tight_symbol = source.crop(alpha_bbox)
    symbol_width = round(tight_symbol.width * (SYMBOL_HEIGHT / tight_symbol.height))
    symbol = tight_symbol.resize(
        (symbol_width, SYMBOL_HEIGHT),
        Image.Resampling.LANCZOS,
    )
    symbol.save(SYMBOL_PATH, optimize=True)

    square_icon = source.copy()
    square_icon.resize((32, 32), Image.Resampling.LANCZOS).save(
        FAVICON_32_PATH,
        optimize=True,
    )
    square_icon.resize((48, 48), Image.Resampling.LANCZOS).save(
        ICON_48_PATH,
        optimize=True,
    )
    square_icon.save(WINDOWS_ICON_PATH, sizes=ICO_SIZES)

    print(f"Updated {SYMBOL_PATH.relative_to(ROOT)} -> {symbol.size}")
    print(f"Updated {FAVICON_32_PATH.relative_to(ROOT)} -> 32x32")
    print(f"Updated {ICON_48_PATH.relative_to(ROOT)} -> 48x48")
    print(
        f"Updated {WINDOWS_ICON_PATH.relative_to(ROOT)} -> "
        + ", ".join(f"{width}x{height}" for width, height in ICO_SIZES)
    )


if __name__ == "__main__":
    main()
