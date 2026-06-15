#!/usr/bin/env python3
"""Post-process generated spritesheets into Godot-ready transparent frames.

This tool adapts MIT-licensed processing ideas from
0x0funky/agent-sprite-forge, but uses this scaffold's neutral CLI and asset
contracts. It does not generate art; it only cleans and validates images that
already came from the configured media pipeline.
"""
from __future__ import annotations

import argparse
import json
import math
import re
import sys
from collections import deque
from pathlib import Path

try:
    import numpy as np
    from PIL import Image
except Exception as exc:  # pragma: no cover - exercised by local env only
    print(f"[FAIL] 缺少 Pillow/numpy：{exc}")
    print("请先运行：python -m pip install Pillow numpy")
    raise SystemExit(1)

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

MAGENTA = (255, 0, 255)


def _color_distance(rgb: tuple[int, int, int], target: tuple[int, int, int] = MAGENTA) -> float:
    r, g, b = rgb
    tr, tg, tb = target
    return math.sqrt((r - tr) ** 2 + (g - tg) ** 2 + (b - tb) ** 2)


def remove_magenta_background(img: Image.Image, threshold: int, edge_threshold: int) -> Image.Image:
    img = img.convert("RGBA")
    pixels = img.load()
    width, height = img.size

    for x in range(width):
        for y in range(height):
            r, g, b, a = pixels[x, y]
            if a > 0 and _color_distance((r, g, b)) < threshold:
                pixels[x, y] = (0, 0, 0, 0)

    visited: set[tuple[int, int]] = set()
    queue: deque[tuple[int, int]] = deque()
    for x in range(width):
        queue.append((x, 0))
        queue.append((x, height - 1))
    for y in range(height):
        queue.append((0, y))
        queue.append((width - 1, y))

    while queue:
        x, y = queue.popleft()
        if (x, y) in visited or x < 0 or x >= width or y < 0 or y >= height:
            continue
        visited.add((x, y))
        r, g, b, a = pixels[x, y]
        should_expand = a == 0
        if a > 0 and _color_distance((r, g, b)) < edge_threshold:
            pixels[x, y] = (0, 0, 0, 0)
            should_expand = True
        if should_expand:
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    if dx == 0 and dy == 0:
                        continue
                    nxt = (x + dx, y + dy)
                    if nxt not in visited:
                        queue.append(nxt)
    return img


def trim_border(img: Image.Image, px: int) -> Image.Image:
    if px <= 0:
        return img
    width, height = img.size
    if width <= px * 2 or height <= px * 2:
        return img
    return img.crop((px, px, width - px, height - px))


def clean_edges(img: Image.Image, depth: int) -> Image.Image:
    if depth <= 0:
        return img
    pixels = img.load()
    width, height = img.size
    for d in range(depth):
        for x in range(width):
            for y in (d, height - 1 - d):
                if 0 <= y < height:
                    r, g, b, a = pixels[x, y]
                    if a > 0 and ((r < 40 and g < 40 and b < 40) or _color_distance((r, g, b)) < 150):
                        pixels[x, y] = (0, 0, 0, 0)
        for y in range(height):
            for x in (d, width - 1 - d):
                if 0 <= x < width:
                    r, g, b, a = pixels[x, y]
                    if a > 0 and ((r < 40 and g < 40 and b < 40) or _color_distance((r, g, b)) < 150):
                        pixels[x, y] = (0, 0, 0, 0)
    return img


def connected_components(img: Image.Image, min_area: int) -> list[dict[str, object]]:
    alpha = img.getchannel("A")
    pixels = alpha.load()
    width, height = img.size
    visited = [[False] * width for _ in range(height)]
    components: list[dict[str, object]] = []

    for y in range(height):
        for x in range(width):
            if pixels[x, y] == 0 or visited[y][x]:
                continue
            queue: deque[tuple[int, int]] = deque([(x, y)])
            visited[y][x] = True
            area = 0
            min_x = max_x = x
            min_y = max_y = y
            touches_edge = x == 0 or y == 0 or x == width - 1 or y == height - 1
            while queue:
                cx, cy = queue.popleft()
                area += 1
                min_x = min(min_x, cx)
                min_y = min(min_y, cy)
                max_x = max(max_x, cx)
                max_y = max(max_y, cy)
                if cx == 0 or cy == 0 or cx == width - 1 or cy == height - 1:
                    touches_edge = True
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = cx + dx, cy + dy
                    if 0 <= nx < width and 0 <= ny < height and pixels[nx, ny] > 0 and not visited[ny][nx]:
                        visited[ny][nx] = True
                        queue.append((nx, ny))
            if area >= min_area:
                components.append(
                    {
                        "area": area,
                        "bbox": (min_x, min_y, max_x + 1, max_y + 1),
                        "touches_edge": touches_edge,
                    }
                )
    components.sort(key=lambda item: int(item["area"]), reverse=True)
    return components


def pad_bbox(bbox: tuple[int, int, int, int], padding: int, width: int, height: int) -> tuple[int, int, int, int]:
    x0, y0, x1, y1 = bbox
    return (
        max(0, x0 - padding),
        max(0, y0 - padding),
        min(width, x1 + padding),
        min(height, y1 + padding),
    )


def bbox_touches_edge(bbox: tuple[int, int, int, int] | None, width: int, height: int, margin: int) -> bool:
    if not bbox:
        return False
    x0, y0, x1, y1 = bbox
    return x0 <= margin or y0 <= margin or x1 >= width - margin or y1 >= height - margin


def _labels(rows: int, cols: int, prefix: str, labels_file: Path | None) -> list[str]:
    if labels_file:
        labels = [
            line.strip()
            for line in labels_file.read_text(encoding="utf-8").splitlines()
            if line.strip() and not line.lstrip().startswith("#")
        ]
    else:
        labels = [f"{prefix}-{index + 1:02d}" for index in range(rows * cols)]
    if len(labels) != rows * cols:
        raise ValueError(f"标签数量必须等于 rows*cols：got {len(labels)}, expected {rows * cols}")
    return [re.sub(r"[^a-zA-Z0-9_-]+", "-", label).strip("-").lower() or f"{prefix}-{i + 1:02d}" for i, label in enumerate(labels)]


def split_grid(
    img: Image.Image,
    *,
    rows: int,
    cols: int,
    cell_width: int,
    cell_height: int,
    output_width: int,
    output_height: int,
    threshold: int,
    edge_threshold: int,
    trim_border_px: int,
    edge_clean_depth: int,
    align: str,
    fit_scale: float,
    shared_scale: bool,
    component_mode: str,
    component_padding: int,
    min_component_area: int,
    edge_touch_margin: int,
) -> tuple[list[Image.Image], list[dict[str, object]]]:
    cleaned = remove_magenta_background(img.convert("RGBA"), threshold, edge_threshold)
    cropped_frames: list[Image.Image] = []
    frame_info: list[dict[str, object]] = []

    for row in range(rows):
        for col in range(cols):
            source_box = (col * cell_width, row * cell_height, (col + 1) * cell_width, (row + 1) * cell_height)
            frame = cleaned.crop(source_box)
            frame = trim_border(frame, trim_border_px)
            frame = clean_edges(frame, edge_clean_depth)
            components = connected_components(frame, min_component_area)
            selected_component = None
            if component_mode == "largest" and components:
                selected_component = components[0]
                bbox = tuple(selected_component["bbox"])  # type: ignore[arg-type]
            else:
                bbox = frame.getbbox()
            edge_touch = bbox_touches_edge(bbox, frame.width, frame.height, edge_touch_margin)
            crop_bbox = pad_bbox(bbox, component_padding, frame.width, frame.height) if bbox else None
            cropped = frame.crop(crop_bbox) if crop_bbox else Image.new("RGBA", (1, 1), (0, 0, 0, 0))
            cropped_frames.append(cropped)
            frame_info.append(
                {
                    "grid": [row, col],
                    "source_box": list(source_box),
                    "component_mode": component_mode,
                    "component_count": len(components),
                    "selected_component_area": int(selected_component["area"]) if selected_component else None,
                    "crop_bbox": list(bbox) if bbox else None,
                    "padded_crop_bbox": list(crop_bbox) if crop_bbox else None,
                    "edge_touch": edge_touch,
                }
            )

    common_scale = None
    if shared_scale:
        max_width = max((frame.width for frame in cropped_frames), default=0)
        max_height = max((frame.height for frame in cropped_frames), default=0)
        if max_width > 0 and max_height > 0:
            common_scale = min(output_width / max_width, output_height / max_height) * fit_scale

    frames: list[Image.Image] = []
    for index, frame in enumerate(cropped_frames):
        canvas = Image.new("RGBA", (output_width, output_height), (0, 0, 0, 0))
        if frame.width > 0 and frame.height > 0:
            scale = common_scale or min(output_width / frame.width, output_height / frame.height) * fit_scale
            new_width = max(1, int(frame.width * scale))
            new_height = max(1, int(frame.height * scale))
            resized = frame.resize((new_width, new_height), Image.Resampling.LANCZOS)
            paste_x = (output_width - new_width) // 2
            if align in {"bottom", "feet"}:
                pad_y = max(0, int(output_height * (1 - fit_scale) * 0.5))
                paste_y = output_height - new_height - pad_y
            else:
                paste_y = (output_height - new_height) // 2
            canvas.paste(resized, (paste_x, paste_y), resized)
            frame_info[index]["output_size"] = [new_width, new_height]
            frame_info[index]["paste_position"] = [paste_x, paste_y]
        frames.append(canvas)
    return frames, frame_info


def compose_sheet(frames: list[Image.Image], rows: int, cols: int, width: int, height: int) -> Image.Image:
    canvas = Image.new("RGBA", (cols * width, rows * height), (0, 0, 0, 0))
    for index, frame in enumerate(frames):
        row, col = divmod(index, cols)
        canvas.paste(frame, (col * width, row * height), frame)
    return canvas


def save_transparent_gif(frames: list[Image.Image], out_path: Path, duration: int) -> None:
    if not frames:
        return
    key = (255, 0, 254)
    width, height = frames[0].size
    stacked = Image.new("RGB", (width, height * len(frames)), key)
    for index, frame in enumerate(frames):
        r, g, b, a = frame.split()
        hard_mask = a.point(lambda value: 255 if value >= 128 else 0)
        stacked.paste(Image.merge("RGB", (r, g, b)), (0, index * height), hard_mask)
    paletted = stacked.convert("P", palette=Image.Palette.ADAPTIVE, colors=256, dither=Image.Dither.NONE)
    palette = list(paletted.getpalette() or [])
    while len(palette) < 256 * 3:
        palette.append(0)
    key_index = 0
    best_distance = None
    for index in range(256):
        r, g, b = palette[index * 3], palette[index * 3 + 1], palette[index * 3 + 2]
        distance = (r - key[0]) ** 2 + (g - key[1]) ** 2 + (b - key[2]) ** 2
        if best_distance is None or distance < best_distance:
            best_distance = distance
            key_index = index
    if key_index != 0:
        lut = np.arange(256, dtype=np.uint8)
        lut[0], lut[key_index] = key_index, 0
        paletted = Image.fromarray(lut[np.array(paletted)], mode="P")
        for channel in range(3):
            zero_idx = channel
            key_idx = key_index * 3 + channel
            palette[zero_idx], palette[key_idx] = palette[key_idx], palette[zero_idx]
        paletted.putpalette(palette)
    out_frames = [paletted.crop((0, index * height, width, (index + 1) * height)) for index in range(len(frames))]
    out_frames[0].save(
        out_path,
        format="GIF",
        save_all=True,
        append_images=out_frames[1:],
        duration=duration,
        loop=0,
        disposal=2,
        transparency=0,
        background=0,
    )


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="清理、切分并验证 Godot 2D spritesheet")
    parser.add_argument("input", type=Path)
    parser.add_argument("--rows", type=int, required=True)
    parser.add_argument("--cols", type=int, required=True)
    parser.add_argument("--out-dir", required=True, type=Path)
    parser.add_argument("--frame-width", type=int, default=0, help="输入单元宽；默认按图片宽/cols")
    parser.add_argument("--frame-height", type=int, default=0, help="输入单元高；默认按图片高/rows")
    parser.add_argument("--output-width", type=int, default=128)
    parser.add_argument("--output-height", type=int, default=128)
    parser.add_argument("--prefix", default="frame")
    parser.add_argument("--labels-file", type=Path)
    parser.add_argument("--threshold", type=int, default=100)
    parser.add_argument("--edge-threshold", type=int, default=150)
    parser.add_argument("--trim-border", type=int, default=4)
    parser.add_argument("--edge-clean-depth", type=int, default=2)
    parser.add_argument("--align", choices=["center", "bottom", "feet"], default="feet")
    parser.add_argument("--fit-scale", type=float, default=0.86)
    parser.add_argument("--shared-scale", action="store_true")
    parser.add_argument("--component-mode", choices=["all", "largest"], default="all")
    parser.add_argument("--component-padding", type=int, default=0)
    parser.add_argument("--min-component-area", type=int, default=1)
    parser.add_argument("--edge-touch-margin", type=int, default=0)
    parser.add_argument("--reject-edge-touch", action="store_true")
    parser.add_argument("--duration", type=int, default=160)
    parser.add_argument("--prompt-file", type=Path)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    if args.rows <= 0 or args.cols <= 0:
        raise SystemExit("--rows 和 --cols 必须为正整数")
    if not args.input.exists():
        raise SystemExit(f"输入文件不存在：{args.input}")

    raw = Image.open(args.input).convert("RGBA")
    cell_width = args.frame_width or raw.width // args.cols
    cell_height = args.frame_height or raw.height // args.rows
    if cell_width <= 0 or cell_height <= 0:
        raise SystemExit("无法推导有效单元尺寸")

    args.out_dir.mkdir(parents=True, exist_ok=True)
    raw.save(args.out_dir / "raw-sheet.png")
    remove_magenta_background(raw.copy(), args.threshold, args.edge_threshold).save(args.out_dir / "raw-sheet-clean.png")
    labels = _labels(args.rows, args.cols, args.prefix, args.labels_file)
    frames, frame_info = split_grid(
        raw,
        rows=args.rows,
        cols=args.cols,
        cell_width=cell_width,
        cell_height=cell_height,
        output_width=args.output_width,
        output_height=args.output_height,
        threshold=args.threshold,
        edge_threshold=args.edge_threshold,
        trim_border_px=args.trim_border,
        edge_clean_depth=args.edge_clean_depth,
        align=args.align,
        fit_scale=args.fit_scale,
        shared_scale=args.shared_scale,
        component_mode=args.component_mode,
        component_padding=args.component_padding,
        min_component_area=args.min_component_area,
        edge_touch_margin=args.edge_touch_margin,
    )
    for label, frame in zip(labels, frames):
        frame.save(args.out_dir / f"{label}.png")
    compose_sheet(frames, args.rows, args.cols, args.output_width, args.output_height).save(args.out_dir / "sheet-transparent.png")
    save_transparent_gif(frames, args.out_dir / "animation.gif", args.duration)

    metadata = {
        "tool": "scripts/process_spritesheet.py",
        "input": str(args.input),
        "rows": args.rows,
        "cols": args.cols,
        "source_cell_size": [cell_width, cell_height],
        "output_cell_size": [args.output_width, args.output_height],
        "align": args.align,
        "fit_scale": args.fit_scale,
        "shared_scale": args.shared_scale,
        "component_mode": args.component_mode,
        "frame_labels": labels,
        "frames": frame_info,
        "edge_touch_frames": [info["grid"] for info in frame_info if bool(info.get("edge_touch"))],
    }
    if args.prompt_file and args.prompt_file.exists():
        (args.out_dir / "prompt-used.txt").write_text(args.prompt_file.read_text(encoding="utf-8"), encoding="utf-8")
        metadata["prompt_file"] = str(args.prompt_file)
    (args.out_dir / "pipeline-meta.json").write_text(json.dumps(metadata, ensure_ascii=False, indent=2), encoding="utf-8")
    if args.reject_edge_touch and metadata["edge_touch_frames"]:
        print(f"[FAIL] 帧触碰单元边缘：{metadata['edge_touch_frames']}")
        return 1
    print(f"[OK] 已处理 spritesheet -> {args.out_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
