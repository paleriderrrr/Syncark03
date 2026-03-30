from __future__ import annotations

from colorsys import hls_to_rgb, rgb_to_hls
from pathlib import Path
from typing import Dict, Tuple

from PIL import Image


ROOT = Path(__file__).resolve().parents[2]
SOURCE_DIR = ROOT / "Art" / "Lunchbox"
OUTPUT_DIR = SOURCE_DIR / "Generated"
TILE_SIZE = 256

PIECE_LAYOUT: Dict[str, str] = {
    "IMG_0212.PNG": "top_left",
    "IMG_0213.PNG": "bottom_right",
    "IMG_0214.PNG": "top",
    "IMG_0215.PNG": "left",
    "IMG_0216.PNG": "bottom",
    "IMG_0217.PNG": "right",
    "IMG_0218.PNG": "top_right",
    "IMG_0219.PNG": "bottom_left",
    "IMG_0220.PNG": "center",
}

ROLE_TARGET_COLORS: Dict[str, Tuple[int, int, int] | None] = {
    "warrior": None,
    "hunter": (113, 92, 182),
    "mage": (70, 146, 88),
}

SIZE_VARIANTS: Dict[str, Tuple[int, int]] = {
    "1x1": (1, 1),
    "2x2": (2, 2),
    "1x4": (1, 4),
    "2x4": (2, 4),
    "3x3": (3, 3),
}


def _load_piece_tiles() -> Dict[str, Image.Image]:
    tiles: Dict[str, Image.Image] = {}
    for file_name, piece_name in PIECE_LAYOUT.items():
        source_path = SOURCE_DIR / file_name
        image = Image.open(source_path).convert("RGBA")
        bbox = image.getbbox()
        if bbox is None:
            raise RuntimeError(f"No visible pixels found in {source_path}")
        tile = image.crop(bbox).resize((TILE_SIZE, TILE_SIZE), Image.Resampling.LANCZOS)
        tiles[piece_name] = tile
    return tiles


def _measure_border_thickness(tile: Image.Image, edge: str) -> int:
    width, height = tile.size
    center_color = tile.getpixel((width // 2, height // 2))

    def distance(pixel: Tuple[int, int, int, int]) -> float:
        r, g, b, _a = pixel
        cr, cg, cb, _ca = center_color
        return ((r - cr) ** 2 + (g - cg) ** 2 + (b - cb) ** 2) ** 0.5

    samples = []
    if edge == "top":
        samples = [tile.getpixel((width // 2, y)) for y in range(height)]
    elif edge == "bottom":
        samples = [tile.getpixel((width // 2, y)) for y in range(height - 1, -1, -1)]
    elif edge == "left":
        samples = [tile.getpixel((x, height // 2)) for x in range(width)]
    elif edge == "right":
        samples = [tile.getpixel((x, height // 2)) for x in range(width - 1, -1, -1)]
    else:
        raise ValueError(f"Unsupported edge {edge}")

    thickness = 0
    for pixel in samples:
        if distance(pixel) > 15.0:
            thickness += 1
        else:
            break
    return max(thickness, 1)


def _recolor_tile(tile: Image.Image, target_rgb: Tuple[int, int, int] | None) -> Image.Image:
    if target_rgb is None:
        return tile.copy()
    target_h, _target_l, target_s = rgb_to_hls(*(channel / 255.0 for channel in target_rgb))
    recolored = Image.new("RGBA", tile.size)
    source = tile.load()
    dest = recolored.load()
    for y in range(tile.height):
        for x in range(tile.width):
            r, g, b, a = source[x, y]
            if a == 0:
                dest[x, y] = (0, 0, 0, 0)
                continue
            _src_h, src_l, _src_s = rgb_to_hls(r / 255.0, g / 255.0, b / 255.0)
            new_r, new_g, new_b = hls_to_rgb(target_h, src_l, target_s)
            dest[x, y] = (
                int(round(new_r * 255)),
                int(round(new_g * 255)),
                int(round(new_b * 255)),
                a,
            )
    return recolored


def _compose_texture(tiles: Dict[str, Image.Image], width_cells: int, height_cells: int) -> Image.Image:
    top = _measure_border_thickness(tiles["top"], "top")
    bottom = _measure_border_thickness(tiles["bottom"], "bottom")
    left = _measure_border_thickness(tiles["left"], "left")
    right = _measure_border_thickness(tiles["right"], "right")

    output_width = width_cells * TILE_SIZE
    output_height = height_cells * TILE_SIZE
    center_width = max(output_width - left - right, 1)
    center_height = max(output_height - top - bottom, 1)

    canvas = Image.new("RGBA", (output_width, output_height), (0, 0, 0, 0))

    top_left = tiles["top_left"].crop((0, 0, left, top))
    top_right = tiles["top_right"].crop((TILE_SIZE - right, 0, TILE_SIZE, top))
    bottom_left = tiles["bottom_left"].crop((0, TILE_SIZE - bottom, left, TILE_SIZE))
    bottom_right = tiles["bottom_right"].crop((TILE_SIZE - right, TILE_SIZE - bottom, TILE_SIZE, TILE_SIZE))
    top_edge = tiles["top"].crop((left, 0, TILE_SIZE - right, top)).resize((center_width, top), Image.Resampling.LANCZOS)
    bottom_edge = tiles["bottom"].crop((left, TILE_SIZE - bottom, TILE_SIZE - right, TILE_SIZE)).resize((center_width, bottom), Image.Resampling.LANCZOS)
    left_edge = tiles["left"].crop((0, top, left, TILE_SIZE - bottom)).resize((left, center_height), Image.Resampling.LANCZOS)
    right_edge = tiles["right"].crop((TILE_SIZE - right, top, TILE_SIZE, TILE_SIZE - bottom)).resize((right, center_height), Image.Resampling.LANCZOS)
    center_fill = tiles["center"].crop((left, top, TILE_SIZE - right, TILE_SIZE - bottom)).resize((center_width, center_height), Image.Resampling.LANCZOS)

    canvas.alpha_composite(top_left, dest=(0, 0))
    canvas.alpha_composite(top_edge, dest=(left, 0))
    canvas.alpha_composite(top_right, dest=(left + center_width, 0))
    canvas.alpha_composite(left_edge, dest=(0, top))
    canvas.alpha_composite(center_fill, dest=(left, top))
    canvas.alpha_composite(right_edge, dest=(left + center_width, top))
    canvas.alpha_composite(bottom_left, dest=(0, top + center_height))
    canvas.alpha_composite(bottom_edge, dest=(left, top + center_height))
    canvas.alpha_composite(bottom_right, dest=(left + center_width, top + center_height))
    return canvas


def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    source_tiles = _load_piece_tiles()
    for role_id, target_rgb in ROLE_TARGET_COLORS.items():
        recolored_tiles = {
            piece_name: _recolor_tile(tile, target_rgb)
            for piece_name, tile in source_tiles.items()
        }
        for size_label, (width_cells, height_cells) in SIZE_VARIANTS.items():
            output_image = _compose_texture(recolored_tiles, width_cells, height_cells)
            output_path = OUTPUT_DIR / f"{role_id}_{size_label}.png"
            output_image.save(output_path)
            print(f"generated {output_path.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
