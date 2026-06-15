#!/usr/bin/env python3
"""保存 init 阶段的用户原始设定和 AI 提炼稿。

这个脚本用于确认前的草案阶段。用户提供长设定时，AI 先把原文保存到
docs/design-inputs/<concept-id>/source.md，再把提炼稿保存到 extracted.md。
确认后再调用 scripts/new_game_concept.py --concept-id <concept-id> 固化项目文档。
"""
from __future__ import annotations

import argparse
import re
from datetime import datetime
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
DESIGN_INPUTS_DIR = PROJECT_ROOT / "docs" / "design-inputs"


def _slug(text: str) -> str:
    value = re.sub(r"[^a-zA-Z0-9\u4e00-\u9fff]+", "-", text).strip("-")
    return value[:36] or "new-game"


def _read_text(file_value: str, text_value: str) -> str:
    if text_value.strip():
        return text_value.strip()
    if not file_value:
        return ""
    path = Path(file_value)
    if not path.is_absolute():
        path = PROJECT_ROOT / path
    if not path.exists():
        raise SystemExit(f"输入文件不存在：{path}")
    return path.read_text(encoding="utf-8", errors="ignore").strip()


def _write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def _next_source_path(target_dir: Path) -> Path:
    first = target_dir / "source.md"
    if not first.exists():
        return first
    index = 2
    while True:
        candidate = target_dir / f"source-{index:03d}.md"
        if not candidate.exists():
            return candidate
        index += 1


def _update_index(target_dir: Path, concept_id: str) -> None:
    def source_sort_key(path: Path) -> tuple[int, str]:
        if path.name == "source.md":
            return (1, path.name)
        match = re.match(r"source-(\d+)\.md$", path.name)
        if match:
            return (int(match.group(1)), path.name)
        return (9999, path.name)

    sources = sorted(target_dir.glob("source*.md"), key=source_sort_key)
    extracted = target_dir / "extracted.md"
    lines = [
        "# 设定输入索引",
        "",
        f"- 概念ID：`{concept_id}`",
        "",
        "## 原始输入",
        "",
    ]
    if sources:
        lines.extend(f"- `{path.name}`" for path in sources)
    else:
        lines.append("- 暂无。")
    lines.extend(["", "## AI 提炼稿", ""])
    lines.append(f"- `{extracted.name}`" if extracted.exists() else "- 暂无。")
    _write(target_dir / "README.md", "\n".join(lines) + "\n")


def main() -> int:
    parser = argparse.ArgumentParser(description="保存 init 阶段设定输入")
    parser.add_argument("--goal", default="new-game", help="用于生成概念ID的目标摘要")
    parser.add_argument("--concept-id", default="", help="指定已有概念ID；不填则自动生成")
    parser.add_argument("--source-file", default="", help="用户原始设定文件")
    parser.add_argument("--source-text", default="", help="用户原始设定文本")
    parser.add_argument("--extracted-file", default="", help="AI 提炼稿文件")
    parser.add_argument("--extracted-text", default="", help="AI 提炼稿文本")
    args = parser.parse_args()

    concept_id = args.concept_id or f"{datetime.now().strftime('%Y%m%d-%H%M%S')}-{_slug(args.goal)}"
    target_dir = DESIGN_INPUTS_DIR / concept_id
    source = _read_text(args.source_file, args.source_text)
    extracted = _read_text(args.extracted_file, args.extracted_text)

    written: list[str] = []
    if source:
        source_path = _next_source_path(target_dir)
        _write(
            source_path,
            f"""# 用户原始设定

概念ID：`{concept_id}`

以下内容为用户原始输入或参考设定，必须原样保留。AI 可以提炼，但不得用摘要覆盖本文件。

---

{source}
""",
        )
        written.append(source_path.relative_to(PROJECT_ROOT).as_posix())

    if extracted:
        extracted_path = target_dir / "extracted.md"
        _write(
            extracted_path,
            f"""# AI 提炼稿

概念ID：`{concept_id}`

本文件保存 AI 从原始输入中提炼出的结构化设定、首版范围和暂缓项。用户确认后，稳定结论再写入 `docs/project/` 和 `docs/game-concept.md`。

---

{extracted}
""",
        )
        written.append(extracted_path.relative_to(PROJECT_ROOT).as_posix())

    if source or extracted:
        _update_index(target_dir, concept_id)
        written.append((target_dir / "README.md").relative_to(PROJECT_ROOT).as_posix())

    print(f"[OK] 概念ID：{concept_id}")
    if written:
        print("[OK] 已保存：")
        for item in written:
            print(f"  - {item}")
    else:
        print("[WARN] 未提供 source 或 extracted 内容。")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
