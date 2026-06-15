#!/usr/bin/env python3
"""Extract transparent props from a solid-magenta prop pack sheet.

Adapted from MIT-licensed processing ideas in 0x0funky/agent-sprite-forge.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

from process_spritesheet import (
    Image,
    bbox_touches_edge,
    clean_edges,
    connected_components,
    pad_bbox,
    remove_magenta_background,
    trim_border,
)

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")


def slug(value: str) -> str:
    return re.sub(r"[^a-zA-Z0-9_-]+", "-", value.strip().lower()).strip("-") or "prop"


def parse_labels(raw: str | None, labels_file: Path | None, count: int) -> list[str]:
    if labels_file:
        labels = [
            line.strip()
            for line in labels_file.read_text(encoding="utf-8").splitlines()
            if line.strip() and not line.lstrip().startswith("#")
        ]
    elif raw:
        labels = [item.strip() for item in raw.split(",")]
    else:
        labels = [f"prop-{index + 1}" for index in range(count)]
    if len(labels) > count:
        raise ValueError(f"标签数量超过单元数量：{len(labels)} > {count}")
    labels.extend(f"prop-{index + 1}" for index in range(len(labels), count))
    return ["" if label.lower() in {"empty", "skip", "-"} else slug(label) for label in labels]


def alpha_bbox(img: Image.Image) -> tuple[int, int, int, int] | None:
    return img.getchannel("A").getbbox()


def mask_to_component(img: Image.Image, component: dict[str, object]) -> Image.Image:
    selected = Image.new("RGBA", img.size, (0, 0, 0, 0))
    src = img.load()
    dst = selected.load()
    for x, y in component.get("coords", []):  # type: ignore[assignment]
        dst[x, y] = src[x, y]
    return selected


def connected_components_with_coords(img: Image.Image, min_area: int) -> list[dict[str, object]]:
    components = connected_components(img, min_area)
    alpha = img.getchannel("A")
    pixels = alpha.load()
    for component in components:
        x0, y0, x1, y1 = component["bbox"]  # type: ignore[misc]
        coords = []
        for y in range(int(y0), int(y1)):
            for x in range(int(x0), int(x1)):
                if pixels[x, y] > 0:
                    coords.append((x, y))
        component["coords"] = coords
    return components


def main() -> int:
    parser = argparse.ArgumentParser(description="从 prop pack sheet 提取透明道具")
    parser.add_argument("input", type=Path)
    parser.add_argument("--rows", required=True, type=int)
    parser.add_argument("--cols", required=True, type=int)
    parser.add_argument("--out-dir", required=True, type=Path)
    parser.add_argument("--manifest", type=Path)
    parser.add_argument("--labels")
    parser.add_argument("--labels-file", type=Path)
    parser.add_argument("--threshold", type=int, default=100)
    parser.add_argument("--edge-threshold", type=int, default=150)
    parser.add_argument("--trim-border", type=int, default=4)
    parser.add_argument("--edge-clean-depth", type=int, default=2)
    parser.add_argument("--component-mode", choices=["all", "largest"], default="largest")
    parser.add_argument("--component-padding", type=int, default=8)
    parser.add_argument("--min-component-area", type=int, default=100)
    parser.add_argument("--edge-touch-margin", type=int, default=0)
    parser.add_argument("--reject-edge-touch", action="store_true")
    args = parser.parse_args()

    if not args.input.exists():
        raise SystemExit(f"输入文件不存在：{args.input}")
    if args.rows <= 0 or args.cols <= 0:
        raise SystemExit("--rows 和 --cols 必须为正整数")

    expected = args.rows * args.cols
    labels = parse_labels(args.labels, args.labels_file, expected)
    args.out_dir.mkdir(parents=True, exist_ok=True)
    raw = Image.open(args.input).convert("RGBA")
    cleaned = remove_magenta_background(raw, args.threshold, args.edge_threshold)
    cell_width = cleaned.width // args.cols
    cell_height = cleaned.height // args.rows
    accepted: list[dict[str, object]] = []
    rejected: list[dict[str, object]] = []

    for index, label in enumerate(labels):
        row, col = divmod(index, args.cols)
        source_box = (col * cell_width, row * cell_height, (col + 1) * cell_width, (row + 1) * cell_height)
        item: dict[str, object] = {"index": index, "label": label, "grid": [row, col], "source_box": list(source_box)}
        if not label:
            item["status"] = "skipped-label"
            rejected.append(item)
            continue
        cell = cleaned.crop(source_box)
        frame = clean_edges(trim_border(cell, args.trim_border), args.edge_clean_depth)
        components = connected_components_with_coords(frame, args.min_component_area)
        selected = components[0] if components and args.component_mode == "largest" else None
        if selected:
            frame = mask_to_component(frame, selected)
            bbox = tuple(selected["bbox"])  # type: ignore[arg-type]
        else:
            bbox = alpha_bbox(frame)
        item["component_count"] = len(components)
        item["selected_component_area"] = int(selected["area"]) if selected else None
        item["crop_bbox"] = list(bbox) if bbox else None
        item["edge_touch"] = bbox_touches_edge(bbox, frame.width, frame.height, args.edge_touch_margin)
        if not bbox:
            item["status"] = "empty"
            rejected.append(item)
            continue
        crop = pad_bbox(bbox, args.component_padding, frame.width, frame.height)
        prop = frame.crop(crop)
        prop_dir = args.out_dir / label
        prop_dir.mkdir(parents=True, exist_ok=True)
        prop_path = prop_dir / "prop.png"
        prop.save(prop_path)
        item["status"] = "accepted"
        item["padded_crop_bbox"] = list(crop)
        item["output_size"] = list(prop.size)
        item["image"] = str(prop_path)
        accepted.append(item)

    edge_touch_props = [str(item["label"]) for item in accepted if bool(item.get("edge_touch"))]
    manifest = {
        "tool": "scripts/extract_prop_pack.py",
        "input": str(args.input),
        "rows": args.rows,
        "cols": args.cols,
        "accepted": accepted,
        "rejected": rejected,
        "edge_touch_props": edge_touch_props,
    }
    manifest_path = args.manifest or (args.out_dir / "prop-pack.json")
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    manifest_path.write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")
    if args.reject_edge_touch and edge_touch_props:
        print(f"[FAIL] 道具触碰单元边缘：{edge_touch_props}")
        return 1
    print(f"[OK] 已提取 prop pack -> {manifest_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
