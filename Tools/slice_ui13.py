from __future__ import annotations

import json
from pathlib import Path
from typing import Dict, List, Tuple

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
SOURCE_PATH = ROOT / "Art" / "UI" / "NewUI" / "UI1-3.png"
OUTPUT_DIR = ROOT / "Art" / "UI" / "NewUI" / "UI1-3_slices"
MANIFEST_PATH = OUTPUT_DIR / "ui13_slice_manifest.json"


SliceDef = Dict[str, object]


SLICE_DEFS: List[SliceDef] = [
    {"name": "ui13_formal_settings_icon.png", "bbox": [3, 3, 120, 125], "pad": 16},
    {"name": "ui13_formal_help_icon.png", "bbox": [257, 3, 369, 117], "pad": 16},
    {"name": "ui13_formal_coin_marker.png", "bbox": [513, 2, 596, 79], "pad": 14},
    {"name": "ui13_formal_header_plate_blank.png", "bbox": [771, 1, 1156, 201], "pad": 28},
    {"name": "ui13_formal_board_wood.png", "bbox": [526, 266, 1631, 980], "pad": 36},
    {"name": "ui13_formal_right_board.png", "bbox": [1790, 10, 2365, 454], "pad": 28},
    {"name": "ui13_formal_role_tab_top_green.png", "bbox": [0, 316, 407, 482], "pad": 26},
    {"name": "ui13_formal_role_tab_mid_red.png", "bbox": [0, 514, 432, 741], "pad": 26},
    {"name": "ui13_formal_role_tab_bottom_purple.png", "bbox": [0, 740, 419, 1018], "pad": 26},
    {"name": "ui13_formal_wanted_poster.png", "bbox": [1794, 512, 2029, 820], "pad": 24},
    {"name": "ui13_formal_depart_text.png", "bbox": [0, 1025, 304, 1140], "pad": 20},
    {"name": "ui13_formal_continue_text.png", "bbox": [512, 1025, 801, 1155], "pad": 20},
    {"name": "ui13_formal_exit_sign_button.png", "bbox": [1024, 1025, 1273, 1141], "pad": 20},
    {"name": "ui13_formal_restart_text.png", "bbox": [0, 1281, 340, 1393], "pad": 20},
    {"name": "ui13_formal_battle_text.png", "bbox": [512, 1282, 778, 1404], "pad": 20},
    {"name": "ui13_formal_end_text.png", "bbox": [0, 1549, 123, 1654], "pad": 20},
    {"name": "ui13_formal_leave_text.png", "bbox": [512, 1537, 734, 1661], "pad": 20},
    {"name": "ui13_formal_food_icon_veg.png", "bbox": [2304, 512, 2364, 576], "pad": 16},
    {"name": "ui13_formal_food_icon_dessert.png", "bbox": [2561, 513, 2632, 574], "pad": 16},
    {"name": "ui13_formal_food_icon_meat.png", "bbox": [2816, 513, 2889, 582], "pad": 16},
    {"name": "ui13_formal_food_icon_drink.png", "bbox": [2304, 768, 2372, 834], "pad": 16},
    {"name": "ui13_formal_food_icon_staple.png", "bbox": [2560, 768, 2625, 821], "pad": 16},
    {"name": "ui13_formal_food_icon_spice.png", "bbox": [2816, 768, 2889, 850], "pad": 16},
]


def expand_bbox(bbox: List[int], pad: int, width: int, height: int) -> Tuple[int, int, int, int]:
    left, top, right, bottom = bbox
    return (
        max(0, left - pad),
        max(0, top - pad),
        min(width, right + pad + 1),
        min(height, bottom + pad + 1),
    )


def main() -> None:
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    image = Image.open(SOURCE_PATH).convert("RGBA")
    width, height = image.size
    manifest: Dict[str, object] = {
        "source": SOURCE_PATH.name,
        "output_dir": OUTPUT_DIR.name,
        "policy": "expanded transparent safety padding; never hard-crop to the painted edge",
        "slices": [],
    }

    for item in SLICE_DEFS:
        name = str(item["name"])
        bbox = list(item["bbox"])  # type: ignore[arg-type]
        pad = int(item["pad"])
        crop_box = expand_bbox(bbox, pad, width, height)
        cropped = image.crop(crop_box)
        cropped.save(OUTPUT_DIR / name)
        manifest["slices"].append(
            {
                "name": name,
                "source_bbox": bbox,
                "padding": pad,
                "crop_box": list(crop_box),
                "size": list(cropped.size),
            }
        )

    MANIFEST_PATH.write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")


if __name__ == "__main__":
    main()
