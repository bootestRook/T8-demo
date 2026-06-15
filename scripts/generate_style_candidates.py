#!/usr/bin/env python3
"""Generate first-run art style candidates with the scaffold media API."""
from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

PROJECT_ROOT = Path(__file__).resolve().parent.parent
MEDIA_API = PROJECT_ROOT / ".agents" / "skills" / "aistudio-media-generation" / "scripts" / "media_api.py"
DEFAULT_OUTPUT_DIR = PROJECT_ROOT / "assets" / "generated" / "style_candidates"


def _rel(path: Path) -> str:
    try:
        return path.resolve().relative_to(PROJECT_ROOT).as_posix()
    except ValueError:
        return path.as_posix()


def _load_prompt(path: Path) -> str:
    if not path.exists():
        raise SystemExit(f"prompt file not found: {path}")
    text = path.read_text(encoding="utf-8-sig", errors="replace").strip()
    if not text:
        raise SystemExit(f"prompt file is empty: {path}")
    return text


def _build_command(
    args: argparse.Namespace,
    prompt_file: Path,
    options_file: Path,
    output_dir: Path,
    output_file: Path,
) -> list[str]:
    command = [sys.executable, str(MEDIA_API)]
    if args.api_key:
        command += ["--api-key", args.api_key]
    command += [
        "generate",
        "--provider",
        args.provider,
        "--prompt-file",
        str(prompt_file),
        "--options-file",
        str(options_file),
        "--wait",
        "--output",
        "downloads",
        "--download-dir",
        str(output_dir),
        "--output-file",
        str(output_file),
    ]
    return command


def _downloaded_files(data: dict[str, Any]) -> list[str]:
    files = data.get("files")
    if not isinstance(files, list):
        return []
    result: list[str] = []
    for item in files:
        if not isinstance(item, dict):
            continue
        path = item.get("path")
        if isinstance(path, str) and path:
            result.append(_rel(Path(path)))
    return result


def _build_options(args: argparse.Namespace, include_count: bool) -> dict[str, Any]:
    options: dict[str, Any] = {
        "size": args.size,
        "background": args.background,
        "format": args.format,
    }
    if include_count:
        options["n"] = args.count
    return options


def _run_media_command(command: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        command,
        cwd=PROJECT_ROOT,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=720,
    )


def _print_process_output(result: subprocess.CompletedProcess[str]) -> None:
    if result.stdout:
        print(result.stdout.strip())
    if result.stderr:
        print(result.stderr.strip(), file=sys.stderr)


def _should_fallback_to_single_image(args: argparse.Namespace, result: subprocess.CompletedProcess[str]) -> bool:
    if args.provider != "gpt-image-2" or args.count <= 1:
        return False
    text = f"{result.stdout}\n{result.stderr}".lower()
    request_error = result.returncode != 0 and (
        "http 400" in text
        or "bad request" in text
        or "unsupported" in text
        or "invalid" in text
    ) and (
        '"n"' in text
        or "'n'" in text
        or " n " in text
        or "count" in text
        or "number" in text
    )
    generic_gpt_image_400 = result.returncode != 0 and (
        "http 400" in text
        or "bad request" in text
    )
    return request_error or generic_gpt_image_400


def _load_result_data(result_file: Path, result: subprocess.CompletedProcess[str]) -> dict[str, Any] | None:
    try:
        return json.loads(result_file.read_text(encoding="utf-8-sig"))
    except json.JSONDecodeError:
        _print_process_output(result)
        print(f"Invalid media API JSON output: {_rel(result_file)}", file=sys.stderr)
    except OSError as exc:
        _print_process_output(result)
        print(f"Cannot read media API JSON output: {exc}", file=sys.stderr)
    return None


def _run_single_image_fallback(
    args: argparse.Namespace,
    prompt_for_command: Path,
    options_for_command: Path,
    output_dir: Path,
    result_file: Path,
) -> int:
    files: list[str] = []
    raw_results: list[dict[str, Any]] = []
    single_options = _build_options(args, include_count=False)

    for index in range(1, args.count + 1):
        single_result_file = output_dir / f"style_candidate_{index:02d}_result.json"
        options_for_command.write_text(json.dumps(single_options, ensure_ascii=False, indent=2), encoding="utf-8")
        command = _build_command(args, prompt_for_command, options_for_command, output_dir, single_result_file)
        result = _run_media_command(command)
        if result.returncode != 0:
            _print_process_output(result)
            return result.returncode
        data = _load_result_data(single_result_file, result)
        if data is None:
            return 1
        raw_results.append(data)
        files.extend(_downloaded_files(data))

    combined = {
        "status": "ok",
        "provider": args.provider,
        "mode": "single-image-fallback",
        "output_dir": _rel(output_dir),
        "files": files,
        "raw": raw_results,
    }
    result_file.write_text(json.dumps(combined, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps(combined, ensure_ascii=False, indent=2))
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description="生成 init 阶段的 3 张美术风格候选图")
    parser.add_argument("--prompt-file", required=True, help="由 asset-prompt-spec 生成的提示词文件")
    parser.add_argument("--output-dir", default=str(DEFAULT_OUTPUT_DIR), help="候选图下载目录")
    parser.add_argument("--provider", default="gpt-image-2")
    parser.add_argument("--size", default="1536x1024", choices=["1024x1024", "1536x1024", "1024x1536"])
    parser.add_argument("--count", type=int, default=3)
    parser.add_argument("--background", default="opaque", choices=["auto", "transparent", "opaque"])
    parser.add_argument("--format", default="png", choices=["png", "jpeg"])
    parser.add_argument("--api-key", default="", help="可选；默认读取 MEDIA_API_KEY")
    parser.add_argument("--dry-run", action="store_true", help="只输出将执行的命令和 options，不调用媒体 API")
    args = parser.parse_args()

    if args.count < 1 or args.count > 4:
        raise SystemExit("count must be between 1 and 4 for gpt-image-2")
    if not MEDIA_API.exists():
        raise SystemExit(f"media_api.py not found: {_rel(MEDIA_API)}")

    source_prompt = Path(args.prompt_file)
    _load_prompt(source_prompt)
    output_dir = Path(args.output_dir)
    result_file = output_dir / "style_candidates_result.json"
    options = _build_options(args, include_count=True)

    prompt_for_command = source_prompt
    options_for_command = output_dir / "style_candidates_options.json"
    if args.dry_run:
        command = _build_command(args, prompt_for_command, options_for_command, output_dir, result_file)
        print(json.dumps({
            "status": "dry-run",
            "provider": args.provider,
            "output_dir": _rel(output_dir),
            "options": options,
            "command": command,
        }, ensure_ascii=False, indent=2))
        return 0

    if not args.api_key and not os.environ.get("MEDIA_API_KEY"):
        raise SystemExit("Missing MEDIA_API_KEY. Set it or pass --api-key before generating images.")

    output_dir.mkdir(parents=True, exist_ok=True)
    prompt_snapshot = output_dir / "style_candidates_prompt.txt"
    if source_prompt.resolve() != prompt_snapshot.resolve():
        shutil.copyfile(source_prompt, prompt_snapshot)
    prompt_for_command = prompt_snapshot
    options_for_command.write_text(json.dumps(options, ensure_ascii=False, indent=2), encoding="utf-8")

    command = _build_command(args, prompt_for_command, options_for_command, output_dir, result_file)
    result = _run_media_command(command)
    if result.returncode != 0:
        if _should_fallback_to_single_image(args, result):
            print("批量数量参数不兼容，自动改为逐张生成。", file=sys.stderr)
            return _run_single_image_fallback(
                args,
                prompt_for_command,
                options_for_command,
                output_dir,
                result_file,
            )
        _print_process_output(result)
        return result.returncode

    data = _load_result_data(result_file, result)
    if data is None:
        return 1

    files = _downloaded_files(data)
    print(json.dumps({
        "status": "ok",
        "provider": args.provider,
        "output_dir": _rel(output_dir),
        "files": files,
        "raw": data,
    }, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
