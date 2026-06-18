#!/usr/bin/env python3
"""Check and optionally fix project text encoding policy."""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path
from typing import Any

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

PROJECT_ROOT = Path(__file__).resolve().parent.parent
UTF8_BOM = b"\xef\xbb\xbf"
BINARY_TRANSLATION_MAGIC = b"RSRC"
QUESTION_MARK_RUN_PATTERN = re.compile(r"(?<![A-Za-z0-9_])\?{2,}(?![A-Za-z0-9_])")
TEXT_SUFFIXES = {
    ".cfg",
    ".cmd",
    ".csv",
    ".gd",
    ".godot",
    ".json",
    ".md",
    ".ps1",
    ".py",
    ".sh",
    ".tres",
    ".tscn",
    ".txt",
}
SKIP_DIRS = {
    ".git",
    ".godot",
    ".runtime",
    "exports",
    "html5",
    "reports",
    "tools",
}


def _rel(path: Path) -> str:
    return path.relative_to(PROJECT_ROOT).as_posix()


def _is_skipped(path: Path) -> bool:
    return any(part in SKIP_DIRS for part in path.relative_to(PROJECT_ROOT).parts)


def _user_editable_csv_files() -> list[Path]:
    files: list[Path] = []
    for root in (PROJECT_ROOT / "assets" / "data", PROJECT_ROOT / "策划文档"):
        if root.exists():
            files.extend(path for path in root.rglob("*.csv") if path.is_file())
    return sorted(files)


def _project_text_files() -> list[Path]:
    files: list[Path] = []
    for path in PROJECT_ROOT.rglob("*"):
        if not path.is_file() or _is_skipped(path):
            continue
        if path.suffix.lower() in TEXT_SUFFIXES:
            files.append(path)
    return sorted(files)


def _decode_text(data: bytes) -> tuple[str | None, str]:
    try:
        return data.decode("utf-8-sig"), "utf-8-sig"
    except UnicodeDecodeError:
        return None, "decode-failed"


def _decode_fixable_csv(data: bytes) -> tuple[str | None, str]:
    for encoding in ("utf-8-sig", "utf-8", "gb18030"):
        try:
            return data.decode(encoding), encoding
        except UnicodeDecodeError:
            continue
    return None, "decode-failed"


def _write_utf8_bom(path: Path, text: str) -> None:
    with path.open("w", encoding="utf-8-sig", newline="") as handle:
        handle.write(text)


def _decode_legacy_text(data: bytes) -> tuple[str | None, str]:
    try:
        data.decode("utf-8-sig")
    except UnicodeDecodeError as exc:
        split_at = exc.start
        try:
            prefix = data[:split_at].decode("utf-8-sig")
            suffix = data[split_at:].decode("gb18030")
            return prefix + suffix, "utf-8+gb18030"
        except UnicodeDecodeError:
            pass
    for encoding in ("gb18030", "cp936"):
        try:
            return data.decode(encoding), encoding
        except UnicodeDecodeError:
            continue
    return None, "decode-failed"


def _write_utf8(path: Path, text: str) -> None:
    with path.open("w", encoding="utf-8", newline="") as handle:
        handle.write(text)


def _check_question_mark_replacement() -> list[dict[str, str]]:
    issues: list[dict[str, str]] = []
    for path in _project_text_files():
        data = path.read_bytes()
        if path.suffix.lower() == ".translation" and data.startswith(BINARY_TRANSLATION_MAGIC):
            continue
        text, encoding = _decode_text(data)
        if encoding == "decode-failed" or text is None:
            continue
        for line_no, line in enumerate(text.splitlines(), start=1):
            match = QUESTION_MARK_RUN_PATTERN.search(line)
            if not match:
                continue
            issues.append({
                "path": _rel(path),
                "line": str(line_no),
                "issue": "发现连续问号，疑似 PowerShell 管道或非 UTF-8 转码已把中文替换为 '?'；请从原始 UTF-8 输入重建。",
            })
            break
    return issues


def _check_text_decoding(fix: bool) -> tuple[list[dict[str, str]], list[str]]:
    issues: list[dict[str, str]] = []
    fixed: list[str] = []
    for path in _project_text_files():
        data = path.read_bytes()
        if path.suffix.lower() == ".translation" and data.startswith(BINARY_TRANSLATION_MAGIC):
            continue
        _, encoding = _decode_text(data)
        if encoding != "decode-failed":
            continue
        text, legacy_encoding = _decode_legacy_text(data)
        if fix and text is not None:
            _write_utf8(path, text)
            fixed.append(f"{_rel(path)} ({legacy_encoding} -> utf-8)")
            continue
        issues.append({
            "path": _rel(path),
            "issue": "文件不能按 UTF-8/UTF-8 BOM 解码。",
        })
    return issues, fixed


def _check_csv_bom(fix: bool) -> tuple[list[dict[str, str]], list[str]]:
    issues: list[dict[str, str]] = []
    fixed: list[str] = []
    for path in _user_editable_csv_files():
        data = path.read_bytes()
        if data.startswith(UTF8_BOM):
            continue
        text, source_encoding = _decode_fixable_csv(data)
        if text is None:
            issues.append({
                "path": _rel(path),
                "issue": "CSV 不能按 UTF-8 或 GB18030 解码，无法安全补 UTF-8 BOM。",
            })
            continue
        if fix:
            _write_utf8_bom(path, text)
            fixed.append(f"{_rel(path)} ({source_encoding} -> utf-8-sig)")
        else:
            issues.append({
                "path": _rel(path),
                "issue": "Excel 可编辑 CSV 必须保存为 UTF-8 with BOM。",
            })
    return issues, fixed


def run(fix: bool) -> dict[str, Any]:
    text_issues, text_fixed = _check_text_decoding(fix)
    csv_issues, fixed = _check_csv_bom(fix)
    fixed = text_fixed + fixed
    if fix and fixed:
        text_issues, _ = _check_text_decoding(False)
        csv_issues, _ = _check_csv_bom(False)
    question_mark_issues = _check_question_mark_replacement()
    issues = text_issues + csv_issues + question_mark_issues
    return {
        "status": "PASS" if not issues else "FAIL",
        "fixed": fixed,
        "issues": issues,
        "checked": {
            "text_files": len(_project_text_files()),
            "excel_csv_files": len(_user_editable_csv_files()),
        },
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="检查项目 UTF-8、PowerShell 问号替换和 Excel CSV BOM 规则。")
    parser.add_argument("--fix", action="store_true", help="为 Excel 可编辑 CSV 自动补 UTF-8 BOM。")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args()

    report = run(args.fix)
    if args.json:
        print(json.dumps(report, ensure_ascii=False, indent=2))
    else:
        print(f"编码检查：{report['status']}")
        for item in report["fixed"]:
            print(f"[FIXED] {item}")
        for issue in report["issues"]:
            location = f"{issue['path']}:{issue['line']}" if "line" in issue else issue["path"]
            print(f"[FAIL] {location}: {issue['issue']}")
    return 0 if report["status"] == "PASS" else 1


if __name__ == "__main__":
    raise SystemExit(main())
