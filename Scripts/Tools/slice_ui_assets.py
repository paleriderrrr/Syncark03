from collections import deque
from pathlib import Path

from PIL import Image


ROOT = Path(r"E:\LargeScaleTestArea\Syncark03\syncark-03")
UI_DIR = ROOT / "Art" / "UI"
OUT_DIR = UI_DIR / "Slices"
OUT_DIR.mkdir(exist_ok=True)


SPECS = {
    "UI1.png": {
        "ui1_settings_icon": (1, 1, 125, 122),
        "ui1_help_icon": (256, 0, 372, 115),
        "ui1_coin_marker": (512, 0, 601, 75),
        "ui1_depart_sign": (768, 0, 1153, 208),
        "ui1_role_tag_top": (0, 256, 403, 503),
        "ui1_role_tag_mid": (0, 516, 427, 753),
        "ui1_role_tag_bottom": (0, 784, 410, 1014),
        "ui1_board_wood": (541, 266, 1610, 946),
        "ui1_right_board": (1791, 8, 2240, 452),
        "ui1_wanted_poster": (1953, 512, 2240, 859),
    },
    "UI2.png": {
        "ui2_market_banner": (0, 0, 1386, 343),
        "ui2_inventory_banner": (5, 418, 1647, 765),
        "ui2_refresh_button": (511, 893, 722, 1022),
        "ui2_buy_button": (767, 966, 886, 1023),
        "ui2_sell_button": (1023, 966, 1142, 1023),
        "ui2_left_chip": (0, 884, 138, 1023),
        "ui2_mid_chip": (255, 884, 394, 1023),
        "ui2_left_arrow": (1279, 963, 1314, 1023),
        "ui2_right_arrow": (1534, 952, 1578, 1023),
    },
}


def is_background(pixel: tuple[int, int, int, int]) -> bool:
    r, g, b, a = pixel
    return a == 0 or (r <= 18 and g <= 18 and b <= 18)


def trim_background(source: Image.Image, bbox: tuple[int, int, int, int]) -> Image.Image:
    crop = source.crop((bbox[0], bbox[1], bbox[2] + 1, bbox[3] + 1)).convert("RGBA")
    w, h = crop.size
    pixels = crop.load()
    transparent = set()
    queue = deque()

    for x in range(w):
        queue.append((x, 0))
        queue.append((x, h - 1))
    for y in range(h):
        queue.append((0, y))
        queue.append((w - 1, y))

    while queue:
        x, y = queue.popleft()
        if (x, y) in transparent or not (0 <= x < w and 0 <= y < h):
            continue
        if not is_background(pixels[x, y]):
            continue
        transparent.add((x, y))
        queue.extend(((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))

    for x, y in transparent:
        pixels[x, y] = (0, 0, 0, 0)

    return crop


def main() -> None:
    for atlas_name, atlas_specs in SPECS.items():
        atlas = Image.open(UI_DIR / atlas_name).convert("RGBA")
        for output_name, bbox in atlas_specs.items():
            trim_background(atlas, bbox).save(OUT_DIR / f"{output_name}.png")
            print(output_name)


if __name__ == "__main__":
    main()
