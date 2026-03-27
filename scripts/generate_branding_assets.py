from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageFilter


ROOT = Path(__file__).resolve().parent.parent
BRANDING_DIR = ROOT / "assets" / "branding"
WINDOWS_ICON_PATH = ROOT / "windows" / "runner" / "resources" / "app_icon.ico"

ICON_SOURCE_PATH = BRANDING_DIR / "caja_clara_icon_source.png"
SYMBOL_PATH = BRANDING_DIR / "caja_clara_symbol.png"
FAVICON_32_PATH = BRANDING_DIR / "favicon-32.png"
ICON_48_PATH = BRANDING_DIR / "icon-48.png"

SYMBOL_SIZE = 1024
ICO_SIZES = [(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)]


def main() -> None:
    source = Image.open(ICON_SOURCE_PATH).convert("RGBA")
    trimmed_symbol = _crop_main_symbol(source)
    square_symbol = _center_on_square(
        trimmed_symbol,
        padding=max(40, trimmed_symbol.width // 18),
    )
    symbol = square_symbol.resize(
        (SYMBOL_SIZE, SYMBOL_SIZE),
        Image.Resampling.LANCZOS,
    )
    symbol = symbol.filter(ImageFilter.UnsharpMask(radius=1.4, percent=135, threshold=2))
    symbol.save(SYMBOL_PATH, optimize=True)

    symbol.resize((32, 32), Image.Resampling.LANCZOS).save(
        FAVICON_32_PATH,
        optimize=True,
    )
    symbol.resize((48, 48), Image.Resampling.LANCZOS).save(
        ICON_48_PATH,
        optimize=True,
    )
    symbol.save(WINDOWS_ICON_PATH, sizes=ICO_SIZES)

    print(f"Updated {SYMBOL_PATH.relative_to(ROOT)} -> {symbol.size}")
    print(f"Updated {FAVICON_32_PATH.relative_to(ROOT)} -> 32x32")
    print(f"Updated {ICON_48_PATH.relative_to(ROOT)} -> 48x48")
    print(
        f"Updated {WINDOWS_ICON_PATH.relative_to(ROOT)} -> "
        + ", ".join(f"{width}x{height}" for width, height in ICO_SIZES)
    )


def _crop_main_symbol(source: Image.Image) -> Image.Image:
    alpha = source.getchannel("A")
    width, height = alpha.size
    threshold = max(24, width // 48)

    rows = [0] * height
    columns = [0] * width
    pixels = alpha.load()
    for y in range(height):
        row_count = 0
        for x in range(width):
            if pixels[x, y] >= 36:
                row_count += 1
                columns[x] += 1
        rows[y] = row_count

    top = _first_index(rows, threshold)
    bottom = _last_index(rows, threshold)
    left = _first_index(columns, threshold)
    right = _last_index(columns, threshold)
    if None in (top, bottom, left, right):
        raise RuntimeError(f"No visible symbol found in {ICON_SOURCE_PATH}")

    return source.crop((left, top, right + 1, bottom + 1))


def _center_on_square(symbol: Image.Image, *, padding: int) -> Image.Image:
    side = max(symbol.width, symbol.height) + padding * 2
    square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    offset = ((side - symbol.width) // 2, (side - symbol.height) // 2)
    square.paste(symbol, offset, mask=symbol)
    return square


def _first_index(values: list[int], threshold: int) -> int | None:
    for index, count in enumerate(values):
        if count >= threshold:
            return index
    return None


def _last_index(values: list[int], threshold: int) -> int | None:
    for reverse_index, count in enumerate(reversed(values)):
        if count >= threshold:
            return len(values) - reverse_index - 1
    return None


if __name__ == "__main__":
    main()
