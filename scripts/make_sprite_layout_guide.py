#!/usr/bin/env python3
"""Create a layout-only guide for generated sprite or prop sheets.

Inspired by the MIT-licensed Agent Sprite Forge layout guide utility.
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

try:
    from PIL import Image, ImageDraw
except Exception as exc:  # pragma: no cover
    print(f"[FAIL] 缺少 Pillow：{exc}")
    print("请先运行：python -m pip install Pillow")
    raise SystemExit(1)

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")


def dashed_line(draw: ImageDraw.ImageDraw, start: tuple[int, int], end: tuple[int, int], *, fill: str) -> None:
    x1, y1 = start
    x2, y2 = end
    dash = 14
    gap = 16
    if x1 == x2:
        for y in range(min(y1, y2), max(y1, y2), dash + gap):
            draw.line((x1, y, x2, min(y + dash, max(y1, y2))), fill=fill, width=2)
        return
    if y1 == y2:
        for x in range(min(x1, x2), max(x1, x2), dash + gap):
            draw.line((x, y1, min(x + dash, max(x1, x2)), y2), fill=fill, width=2)
        return
    raise ValueError("只支持水平或垂直虚线")


def main() -> int:
    parser = argparse.ArgumentParser(description="生成 spritesheet/prop pack 布局参考图")
    parser.add_argument("--rows", type=int, required=True)
    parser.add_argument("--cols", type=int, required=True)
    parser.add_argument("--cell-width", type=int, default=384)
    parser.add_argument("--cell-height", type=int, default=384)
    parser.add_argument("--safe-margin-x", type=int, default=52)
    parser.add_argument("--safe-margin-y", type=int, default=52)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--label-cells", action="store_true")
    args = parser.parse_args()

    if min(args.rows, args.cols, args.cell_width, args.cell_height) <= 0:
        raise SystemExit("rows、cols 和 cell 尺寸必须为正数")

    width = args.cols * args.cell_width
    height = args.rows * args.cell_height
    image = Image.new("RGB", (width, height), "#f8f8f8")
    draw = ImageDraw.Draw(image)
    for row in range(args.rows):
        for col in range(args.cols):
            left = col * args.cell_width
            top = row * args.cell_height
            right = left + args.cell_width - 1
            bottom = top + args.cell_height - 1
            safe_left = left + args.safe_margin_x
            safe_top = top + args.safe_margin_y
            safe_right = right - args.safe_margin_x
            safe_bottom = bottom - args.safe_margin_y
            draw.rectangle((left, top, right, bottom), outline="#111111", width=4)
            draw.rectangle((safe_left, safe_top, safe_right, safe_bottom), outline="#2f80ed", width=3)
            center_x = left + args.cell_width // 2
            center_y = top + args.cell_height // 2
            dashed_line(draw, (center_x, safe_top), (center_x, safe_bottom), fill="#b8b8b8")
            dashed_line(draw, (safe_left, center_y), (safe_right, center_y), fill="#b8b8b8")
            if args.label_cells:
                draw.text((left + 12, top + 10), f"{row + 1},{col + 1}", fill="#777777")

    args.output.parent.mkdir(parents=True, exist_ok=True)
    image.save(args.output)
    print(f"[OK] 已生成布局参考图 -> {args.output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
