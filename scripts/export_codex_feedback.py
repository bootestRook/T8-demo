#!/usr/bin/env python3
"""
Codex CLI 协作反馈包导出脚本。

一条命令收集：Codex CLI 会话、项目关键快照、git 状态和脚手架验证输出。
默认输出到 exports/feedback/，该目录已被 .gitignore 排除。
"""
from __future__ import annotations

import argparse
import json
import os
import platform
import re
import shlex
import shutil
import subprocess
import sys
import time
import zipfile
from collections import deque
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path, PureWindowsPath

from asset_coverage import (
    asset_inventory,
    existing_runtime_asset_references,
    generated_runtime_refs,
    missing_runtime_assets,
    role_coverage,
    runtime_asset_references,
    safe_read,
)

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

PROJECT_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_EXPORT_ROOT = PROJECT_ROOT / "exports" / "feedback"

PROJECT_FILES = [
    "AGENTS.md",
    "README.md",
    "START_HERE.md",
    "project.godot",
    "export_presets.cfg",
    "opencode.json",
    ".gitignore",
]
PROJECT_DIRS = [
    ".agents/skills",
    ".opencode/plugins",
    ".pm",
    "addons",
    "assets",
    "docs",
    "scenes",
    "scripts",
    "spec",
    "src",
]
EXCLUDED_DIR_NAMES = {
    ".git",
    ".godot",
    ".import",
    ".runtime",
    ".venv",
    "__pycache__",
    "build",
    "dist",
    "exports",
    "html5",
    "installers",
    "node_modules",
    "tools",
    "venv",
}
SENSITIVE_FILE_NAMES = {
    ".env",
    ".env.local",
    ".env.production",
    ".npmrc",
    "auth.json",
    "credentials.json",
    "id_dsa",
    "id_ed25519",
    "id_rsa",
    "known_hosts",
}
SENSITIVE_SUFFIXES = {
    ".key",
    ".p12",
    ".pfx",
    ".pem",
}
TEXT_SECRET_SUFFIXES = {
    "",
    ".cfg",
    ".conf",
    ".ini",
    ".json",
    ".toml",
    ".txt",
    ".yaml",
    ".yml",
}
SESSION_SUFFIXES = {".json", ".jsonl"}


@dataclass
class CommandSpec:
    name: str
    command: list[str]
    timeout: int = 180


def _now_stamp() -> str:
    return datetime.now().strftime("%Y%m%d-%H%M%S")


def _rel(path: Path) -> str:
    try:
        return path.relative_to(PROJECT_ROOT).as_posix()
    except ValueError:
        try:
            return "~/" + path.relative_to(Path.home()).as_posix()
        except ValueError:
            return path.name


def _pack_rel(path: Path) -> str:
    try:
        return path.relative_to(PROJECT_ROOT).as_posix()
    except ValueError:
        return path.name


def _redact_text(text: str) -> str:
    replacements: list[tuple[str, str]] = []
    for source, target in [
        (PROJECT_ROOT, "<PROJECT_ROOT>"),
        (Path.home(), "~"),
    ]:
        raw = str(source)
        replacements.append((raw, target))
        replacements.append((raw.replace("\\", "\\\\"), target))
        replacements.append((source.as_posix(), target))
    redacted = text
    for raw, target in replacements:
        if raw:
            redacted = redacted.replace(raw, target)
    redacted = re.sub(
        r"(?<![A-Za-z0-9_])[A-Za-z]:[\\/][^\s\"'<>|]+",
        lambda match: f"<ABS_PATH>/{PureWindowsPath(match.group(0)).name}",
        redacted,
    )
    return redacted


def _is_absolute_path_text(text: str) -> bool:
    return (
        len(text) >= 3
        and text[1] == ":"
        and text[2] in ("\\", "/")
    ) or text.startswith("/")


def _redact_command(command: list[str]) -> list[str]:
    redacted: list[str] = []
    for part in command:
        text = _redact_text(part)
        if text == part and _is_absolute_path_text(part):
            redacted.append(f"<ABS_PATH>/{Path(part).name}")
        else:
            redacted.append(text)
    return redacted


def _command_text(command: list[str]) -> str:
    if sys.platform == "win32":
        return subprocess.list2cmdline(command)
    return shlex.join(command)


def _write_text(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8", errors="replace")


def _copy_file(src: Path, dst: Path, manifest: dict, max_bytes: int) -> bool:
    if src.is_symlink():
        manifest["skipped_files"].append({"path": _rel(src), "reason": "symlink"})
        return False
    if _is_sensitive_file(src):
        manifest["skipped_files"].append({"path": _rel(src), "reason": "sensitive_name"})
        return False
    try:
        size = src.stat().st_size
    except OSError as exc:
        manifest["skipped_files"].append({"path": _rel(src), "reason": str(exc)})
        return False
    if size > max_bytes:
        manifest["skipped_files"].append(
            {"path": _rel(src), "reason": f"larger_than_{max_bytes // 1024 // 1024}MB"}
        )
        return False
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst)
    manifest["copied_files"] += 1
    return True


def _copy_redacted_text_file(src: Path, dst: Path, manifest: dict, max_bytes: int) -> bool:
    if src.is_symlink():
        manifest["skipped_files"].append({"path": _rel(src), "reason": "symlink"})
        return False
    try:
        size = src.stat().st_size
    except OSError as exc:
        manifest["skipped_files"].append({"path": _rel(src), "reason": str(exc)})
        return False
    if size > max_bytes:
        manifest["skipped_files"].append(
            {"path": _rel(src), "reason": f"larger_than_{max_bytes // 1024 // 1024}MB"}
        )
        return False
    text = src.read_text(encoding="utf-8", errors="replace")
    _write_text(dst, _redact_text(text))
    manifest["copied_files"] += 1
    return True


def _is_sensitive_file(path: Path) -> bool:
    name = path.name.lower()
    suffix = path.suffix.lower()
    if name in SENSITIVE_FILE_NAMES or name.startswith(".env."):
        return True
    if suffix in SENSITIVE_SUFFIXES:
        return True
    secret_words = ("api_key", "apikey", "cookie", "credential", "password", "secret", "token")
    return suffix in TEXT_SECRET_SUFFIXES and any(word in name for word in secret_words)


def _is_excluded_project_path(path: Path) -> bool:
    try:
        rel = path.relative_to(PROJECT_ROOT)
    except ValueError:
        return True
    return any(part in EXCLUDED_DIR_NAMES for part in rel.parts)


def _copy_tree(src_root: Path, dst_root: Path, manifest: dict, max_bytes: int) -> None:
    if not src_root.exists():
        manifest["missing_paths"].append(_rel(src_root))
        return
    for path in sorted(src_root.rglob("*")):
        if not path.is_file() or _is_excluded_project_path(path):
            continue
        rel = path.relative_to(PROJECT_ROOT)
        _copy_file(path, dst_root / rel, manifest, max_bytes)


def _extract_markdown_value(text: str, heading: str) -> str:
    pattern = re.compile(rf"##\s+{re.escape(heading)}\s*\n+((?:- .+\n?)+)", re.MULTILINE)
    match = pattern.search(text)
    if not match:
        return ""
    first_line = match.group(1).strip().splitlines()[0]
    return first_line.removeprefix("-").strip().strip("`")


def _concept_summary() -> dict[str, str]:
    concept = safe_read(PROJECT_ROOT / "docs" / "game-concept.md")
    style_candidate = ""
    runtime_art_status = ""
    for line in concept.splitlines():
        if "选中风格候选图" in line:
            style_candidate = re.split(r"[:：]", line, maxsplit=1)[-1].strip(" `")
        if "素材落地状态" in line:
            runtime_art_status = re.split(r"[:：]", line, maxsplit=1)[-1].strip()
    return {
        "concept_id": _extract_markdown_value(concept, "概念ID"),
        "blueprint": _extract_markdown_value(concept, "玩法蓝图"),
        "goal": _extract_markdown_value(concept, "一句话目标"),
        "style_candidate": style_candidate,
        "runtime_art_status": runtime_art_status,
        "is_starter_template": str("starter-template" in concept).lower(),
        "declares_placeholder": str(any(marker in concept for marker in ("程序化占位", "未锁定最终美术"))).lower(),
    }


def _auto_findings(concept: dict[str, str], refs: dict[str, list[str]], roles: dict[str, list[str]]) -> list[str]:
    findings: list[str] = []
    style_candidate = concept.get("style_candidate", "")
    is_starter_template = concept.get("is_starter_template") == "true"
    declares_placeholder = concept.get("declares_placeholder") == "true"
    generated_refs = generated_runtime_refs(refs)

    if is_starter_template:
        if refs:
            findings.append("空脚手架仍发现运行时素材引用，应确认是否为新游戏残留。")
        return findings
    if style_candidate and not generated_refs and not refs and not declares_placeholder:
        findings.append("已锁定风格候选图，但未发现运行时素材引用。")
    if generated_refs and roles["background_map"] and not (
        roles["player_actor"] or roles["challenge_actor"] or roles["objective_pickup"]
    ):
        findings.append("运行时生成素材疑似集中在地图/背景，缺少主角或可交互对象覆盖。")
    if not declares_placeholder:
        missing = []
        if not roles["player_actor"]:
            missing.append("主角/玩家素材")
        if not (roles["challenge_actor"] or roles["objective_pickup"]):
            missing.append("敌人/障碍/目标/收集物素材")
        if not roles["ui_skin"]:
            missing.append("UI/HUD sprite（没有 PSD 时也应生成 UI sheet、图标或面板素材后接入 assets/ui/）")
        if missing:
            findings.append("运行时素材角色覆盖不足：" + "，".join(missing))
    return findings


def _write_feedback_summary(pack_dir: Path, manifest: dict) -> None:
    concept = _concept_summary()
    assets = asset_inventory()
    refs = runtime_asset_references(include_audio=True)
    missing_refs = missing_runtime_assets(refs)
    existing_refs = existing_runtime_asset_references(refs)
    roles = role_coverage(existing_refs)
    command_status = {
        item["name"]: {
            "status": item["status"],
            "returncode": item["returncode"],
            "elapsed_seconds": item["elapsed_seconds"],
        }
        for item in manifest["commands"]
    }
    findings = _auto_findings(concept, existing_refs, roles)
    if missing_refs:
        samples = [
            f"{path} @ {locations[0]}"
            for path, locations in missing_refs.items()
        ]
        findings.append("运行时代码引用了不存在的素材文件：" + "，".join(samples[:8]))
    ui_runtime_gap = (
        concept.get("is_starter_template") != "true"
        and concept.get("declares_placeholder") != "true"
        and not roles["ui_skin"]
    )
    summary = {
        "concept": concept,
        "assets": assets,
        "runtime_asset_references": {
            "count": len(refs),
            "items": {path: locations[:8] for path, locations in refs.items()},
        },
        "missing_runtime_asset_references": {
            "count": len(missing_refs),
            "items": {path: locations[:8] for path, locations in missing_refs.items()},
        },
        "role_coverage": {role: hits[:12] for role, hits in roles.items()},
        "command_status": command_status,
        "ui_runtime_gap": ui_runtime_gap,
        "auto_findings": findings,
    }

    analysis_dir = pack_dir / "analysis"
    _write_text(analysis_dir / "feedback-summary.json", json.dumps(summary, ensure_ascii=False, indent=2))
    lines = [
        "# 反馈包自动复盘摘要",
        "",
        "## 概念",
        f"- 概念ID：{concept.get('concept_id') or '未识别'}",
        f"- 玩法蓝图：{concept.get('blueprint') or '未识别'}",
        f"- 目标：{concept.get('goal') or '未识别'}",
        "",
        "## 自动发现",
    ]
    if findings:
        lines.extend(f"- {item}" for item in findings)
    else:
        lines.append("- 未发现脚本可判定的素材覆盖阻塞；仍需人工试玩判断成品感。")
    lines.extend([
        "",
        "## 素材计数",
    ])
    for name, count in assets["counts"].items():
        lines.append(f"- {name}: {count}")
    lines.extend([
        "",
        "## 角色覆盖",
    ])
    for role, hits in roles.items():
        lines.append(f"- {role}: {len(hits)}")
    lines.extend([
        "",
        "## UI 闭环",
        f"- 运行时 UI 素材缺口：{'是' if ui_runtime_gap else '否'}",
        "- 判定：非空脚手架且未声明程序化占位时，应能在运行时代码中看到 `res://assets/ui/...` 或 HUD/UI sprite 素材引用；没有 PSD/UI 源图时，应先生成 UI sheet、图标或面板素材再接入。",
    ])
    manifest["analysis"] = {
        "summary_json": "analysis/feedback-summary.json",
        "summary_md": "analysis/feedback-summary.md",
        "auto_findings_count": len(findings),
    }
    _write_text(analysis_dir / "feedback-summary.md", "\n".join(lines) + "\n")


def _find_git() -> str | None:
    candidates = [
        PROJECT_ROOT / "tools" / "git" / "cmd" / "git.exe",
        PROJECT_ROOT / "tools" / "git" / "bin" / "git.exe",
        PROJECT_ROOT / "tools" / "PortableGit" / "cmd" / "git.exe",
        "git",
    ]
    for candidate in candidates:
        text = str(candidate)
        resolved = shutil.which(text) or (Path(text).is_file() and text)
        if resolved:
            return str(resolved)
    return None


def _find_codex_home() -> Path:
    env_home = os.environ.get("CODEX_HOME")
    if env_home:
        return Path(env_home).expanduser()
    return Path.home() / ".codex"


def _session_files(codex_home: Path) -> list[Path]:
    sessions_dir = codex_home / "sessions"
    if not sessions_dir.exists():
        return []
    files = [
        path
        for path in sessions_dir.rglob("*")
        if path.is_file() and path.suffix.lower() in SESSION_SUFFIXES
    ]
    return sorted(files, key=lambda path: path.stat().st_mtime, reverse=True)


def _file_contains(path: Path, needle: str, max_bytes: int = 8 * 1024 * 1024) -> bool:
    if not needle:
        return False
    target = needle.encode("utf-8", errors="ignore")
    try:
        total = 0
        with path.open("rb") as handle:
            while total < max_bytes:
                chunk = handle.read(1024 * 1024)
                if not chunk:
                    return False
                total += len(chunk)
                if target in chunk:
                    return True
    except OSError:
        return False
    return False


def _file_contains_any(path: Path, needles: list[str]) -> bool:
    return any(_file_contains(path, needle) for needle in needles if needle)


def _select_sessions(codex_home: Path, session_id: str, count: int) -> list[Path]:
    files = _session_files(codex_home)
    if session_id:
        return [
            path
            for path in files
            if session_id in path.name or _file_contains(path, session_id)
        ]
    limit = max(count, 0)
    if limit == 0:
        return []
    project_markers = [
        str(PROJECT_ROOT),
        PROJECT_ROOT.as_posix(),
        PROJECT_ROOT.name,
    ]
    project_sessions = [path for path in files if _file_contains_any(path, project_markers)]
    if project_sessions:
        return project_sessions[:limit]
    return files[:limit]


def _safe_session_name(path: Path, sessions_dir: Path) -> str:
    try:
        rel_parts = path.relative_to(sessions_dir).parts
    except ValueError:
        rel_parts = path.parts[-3:]
    return "__".join(rel_parts)


def _tail_file(src: Path, dst: Path, line_count: int) -> None:
    if not src.exists() or line_count <= 0:
        return
    lines: deque[str] = deque(maxlen=line_count)
    with src.open("r", encoding="utf-8", errors="replace") as handle:
        for line in handle:
            lines.append(line)
    _write_text(dst, _redact_text("".join(lines)))


def _collect_codex(pack_dir: Path, args: argparse.Namespace, manifest: dict) -> None:
    codex_home = _find_codex_home()
    manifest["codex_home"] = "CODEX_HOME" if os.environ.get("CODEX_HOME") else "~/.codex"
    codex_dir = pack_dir / "codex"
    sessions_dir = codex_home / "sessions"
    _write_text(
        codex_dir / "codex-home.txt",
        "Codex home 已定位；为避免泄露本机用户名和目录结构，反馈包不写入绝对路径。\n",
    )

    sessions = _select_sessions(codex_home, args.session_id, args.session_count)
    selected_lines = ["mtime\tsize\tcopied_name"]
    selected_names: set[str] = set()
    for session in sessions:
        dst_name = _safe_session_name(session, sessions_dir)
        dst = codex_dir / "sessions" / dst_name
        if _copy_redacted_text_file(session, dst, manifest, args.max_file_mb * 1024 * 1024):
            selected_names.add(dst_name)
            selected_lines.append(f"{session.stat().st_mtime:.0f}\t{session.stat().st_size}\t{dst_name}")
    if len(selected_lines) == 1:
        selected_lines.append("未找到匹配的 Codex CLI session 文件。")
    _write_text(codex_dir / "selected-sessions.tsv", "\n".join(selected_lines) + "\n")

    index_lines = ["mtime\tsize\tname\tselected"]
    for session in _session_files(codex_home)[:30]:
        name = _safe_session_name(session, sessions_dir)
        index_lines.append(
            f"{session.stat().st_mtime:.0f}\t{session.stat().st_size}\t{name}\t{str(name in selected_names).lower()}"
        )
    _write_text(codex_dir / "sessions-index.tsv", "\n".join(index_lines) + "\n")

    history = codex_home / "history.jsonl"
    if args.include_history and history.exists() and args.history_lines > 0:
        _tail_file(history, codex_dir / "history-recent.jsonl", args.history_lines)
    elif args.include_history and not history.exists():
        _write_text(codex_dir / "history-recent.jsonl", "未找到 history.jsonl。\n")
    else:
        _write_text(
            codex_dir / "history-recent.jsonl",
            "默认未导出全局 history.jsonl；如确实需要，请重新运行并加 --include-history。\n",
        )


def _collect_project(pack_dir: Path, args: argparse.Namespace, manifest: dict) -> None:
    if args.no_project:
        return
    project_dir = pack_dir / "project"
    max_bytes = args.max_file_mb * 1024 * 1024
    for rel in PROJECT_FILES:
        src = PROJECT_ROOT / rel
        if src.exists() and src.is_file():
            _copy_file(src, project_dir / rel, manifest, max_bytes)
        else:
            manifest["missing_paths"].append(rel)
    dirs = list(PROJECT_DIRS)
    if args.include_references:
        dirs.append("references")
    for rel in dirs:
        _copy_tree(PROJECT_ROOT / rel, project_dir, manifest, max_bytes)


def _run_command(spec: CommandSpec, out_dir: Path) -> dict:
    started = time.monotonic()
    redacted_command = _redact_command(spec.command)
    header = f"$ {_command_text(redacted_command)}\n\n"
    try:
        result = subprocess.run(
            spec.command,
            cwd=PROJECT_ROOT,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=spec.timeout,
        )
        output = result.stdout or ""
        status = "ok" if result.returncode == 0 else "failed"
        code = result.returncode
    except subprocess.TimeoutExpired as exc:
        output = (exc.stdout or "") + (exc.stderr or "")
        output += f"\n\n[TIMEOUT] 命令超过 {spec.timeout} 秒，已停止等待。"
        status = "timeout"
        code = None
    except Exception as exc:
        output = str(exc)
        status = "error"
        code = None
    elapsed = round(time.monotonic() - started, 2)
    _write_text(out_dir / f"{spec.name}.txt", _redact_text(header + output.strip()) + "\n")
    return {
        "name": spec.name,
        "status": status,
        "returncode": code,
        "elapsed_seconds": elapsed,
        "command": redacted_command,
    }


def _command_specs(args: argparse.Namespace) -> list[CommandSpec]:
    specs: list[CommandSpec] = []
    codex = shutil.which("codex")
    if codex:
        specs.append(CommandSpec("codex-version", [codex, "--version"], timeout=30))
    else:
        specs.append(CommandSpec("codex-version", [sys.executable, "-c", "print('未找到 codex 命令')"], timeout=30))

    git = _find_git()
    if git:
        specs.extend(
            [
                CommandSpec("git-status", [git, "status", "--short"], timeout=60),
                CommandSpec("git-diff", [git, "diff", "--", "."], timeout=120),
                CommandSpec("git-log", [git, "log", "--oneline", "-20"], timeout=60),
            ]
        )
    else:
        specs.append(CommandSpec("git-status", [sys.executable, "-c", "print('未找到 git 命令')"], timeout=30))

    pm_cli = PROJECT_ROOT / ".agents" / "skills" / "pm-agile" / "scripts" / "pm_cli.py"
    if pm_cli.exists():
        specs.extend(
            [
                CommandSpec("pm-status", [sys.executable, str(pm_cli), "status"], timeout=60),
                CommandSpec("pm-check", [sys.executable, str(pm_cli), "check"], timeout=60),
            ]
        )

    if args.skip_checks:
        return specs

    specs.extend(
            [
                CommandSpec("check-env-fast", [sys.executable, "scripts/check_env.py", "--json", "--fast"], timeout=90),
                CommandSpec("gameplay-logic-review", [sys.executable, "scripts/gameplay_logic_review.py"], timeout=180),
                CommandSpec("art-pipeline-review", [sys.executable, "scripts/art_pipeline_review.py"], timeout=180),
                CommandSpec("experience-design-review", [sys.executable, "scripts/experience_design_review.py"], timeout=180),
                CommandSpec("godot-headless-check", [sys.executable, "scripts/godot_headless_check.py"], timeout=240),
                CommandSpec("godot-runtime-log-check", [sys.executable, "scripts/godot_runtime_log_check.py"], timeout=120),
            ]
        )
    if not args.quick:
        specs.extend(
            [
                CommandSpec("export-web", [sys.executable, "scripts/export_web.py", "--json"], timeout=420),
                CommandSpec("experience-check", [sys.executable, "scripts/experience_check.py", "--strict"], timeout=600),
                CommandSpec("visual-readability-review", [sys.executable, "scripts/visual_readability_review.py", "--strict"], timeout=180),
                CommandSpec("ai-review", [sys.executable, "scripts/ai_review.py", "--strict"], timeout=600),
            ]
        )
    return specs


def _collect_commands(pack_dir: Path, args: argparse.Namespace, manifest: dict) -> None:
    out_dir = pack_dir / "commands"
    for spec in _command_specs(args):
        result = _run_command(spec, out_dir)
        manifest["commands"].append(result)
        if not args.json:
            print(f"[{result['status']}] {spec.name} ({result['elapsed_seconds']}s)")


def _write_readme(pack_dir: Path, args: argparse.Namespace, manifest: dict) -> None:
    readme = f"""
# Codex CLI 反馈包

生成时间：{manifest["created_at"]}

## 内容

- `codex/`：Codex CLI session、可选 history 摘要和 session 索引。
- `project/`：Godot 脚手架关键文件快照。
- `commands/`：Codex、git、PM 和 Godot 验证命令输出。
- `analysis/feedback-summary.*`：自动复盘摘要，包含素材清单、运行时素材引用、主角/威胁/目标/UI 覆盖和脚本发现的问题。
- `manifest.json`：收集范围、跳过文件和命令结果。

## 分享前检查

请在发送 zip 前检查这些内容：

- `codex/sessions/` 可能包含完整用户指令、AI 回复、路径和报错。
- `codex/history-recent.jsonl` 默认不包含全局 history；如果使用了 `--include-history`，它会包含最近 {args.history_lines} 行历史，仍可能有隐私信息。
- `codex/sessions-index.tsv` 只记录 session 文件名，不记录本机绝对路径。
- 脚本默认跳过 `auth.json`、`.env`、密钥文件、`.git/`、`tools/`、`html5/` 和 `exports/`。
- 如果项目里有私人素材或商业资源，请先自行删除再分享。

## 复盘重点

- AI 是否正确理解玩法目标。
- skill 路由是否失效或遗漏。
- 验证链路在哪一步失败。
- 是否只生成了地图/背景，却没有把主角、敌人/目标、UI 素材落到运行时。
- 用户自然语言需求到可试玩版本之间哪里断裂。
""".strip()
    _write_text(pack_dir / "README_REVIEW_BEFORE_SHARING.md", readme + "\n")


def _write_manifest(pack_dir: Path, manifest: dict) -> None:
    _write_text(pack_dir / "manifest.json", json.dumps(manifest, ensure_ascii=False, indent=2))
    skipped = ["path\treason"]
    for item in manifest["skipped_files"]:
        skipped.append(f"{item['path']}\t{item['reason']}")
    _write_text(pack_dir / "skipped-files.tsv", "\n".join(skipped) + "\n")


def _zip_dir(pack_dir: Path, zip_path: Path) -> None:
    zip_path.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(zip_path, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for path in sorted(pack_dir.rglob("*")):
            if not path.is_file():
                continue
            archive.write(path, path.relative_to(pack_dir).as_posix())


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="导出 Codex CLI + Godot 脚手架反馈包")
    parser.add_argument("--out", default="", help="输出 zip 路径，默认 exports/feedback/codex-feedback-时间.zip")
    parser.add_argument("--session-id", default="", help="指定 Codex session ID；推荐用 /status 获取")
    parser.add_argument("--session-count", type=int, default=1, help="未指定 session ID 时，优先复制匹配当前项目的最近 N 个 session")
    parser.add_argument("--include-history", action="store_true", help="额外导出全局 history.jsonl 最近记录，默认关闭")
    parser.add_argument("--history-lines", type=int, default=200, help="配合 --include-history 使用，复制 history.jsonl 最近 N 行")
    parser.add_argument("--max-file-mb", type=int, default=20, help="项目快照单文件体积上限")
    parser.add_argument("--quick", action="store_true", help="跳过 Web 导出、浏览器体验检查和 ai_review")
    parser.add_argument("--skip-checks", action="store_true", help="只收集 Codex/git/PM，不运行 Godot 检查")
    parser.add_argument("--no-project", action="store_true", help="不复制项目快照")
    parser.add_argument("--include-references", action="store_true", help="额外包含 references/ 参考资料")
    parser.add_argument("--json", action="store_true", help="只输出 JSON 摘要")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    stamp = _now_stamp()
    export_root = DEFAULT_EXPORT_ROOT
    pack_dir = export_root / f"codex-feedback-{stamp}"
    zip_path = Path(args.out).expanduser() if args.out else export_root / f"codex-feedback-{stamp}.zip"

    manifest = {
        "created_at": datetime.now().isoformat(timespec="seconds"),
        "platform": platform.platform(),
        "python": sys.version.split()[0],
        "project_root": ".",
        "pack_dir": _pack_rel(pack_dir),
        "zip_path": _pack_rel(zip_path),
        "copied_files": 0,
        "missing_paths": [],
        "skipped_files": [],
        "commands": [],
        "options": {
            "session_id": args.session_id,
            "session_count": args.session_count,
            "history_lines": args.history_lines,
            "include_history": args.include_history,
            "quick": args.quick,
            "skip_checks": args.skip_checks,
            "no_project": args.no_project,
            "include_references": args.include_references,
        },
    }

    pack_dir.mkdir(parents=True, exist_ok=True)
    if not args.json:
        print(f"[INFO] 输出目录：{pack_dir}")

    _collect_codex(pack_dir, args, manifest)
    _collect_project(pack_dir, args, manifest)
    _collect_commands(pack_dir, args, manifest)
    _write_feedback_summary(pack_dir, manifest)
    _write_readme(pack_dir, args, manifest)
    _write_manifest(pack_dir, manifest)
    _zip_dir(pack_dir, zip_path)

    size_kb = zip_path.stat().st_size // 1024
    summary = {
        "status": "ok",
        "zip": _pack_rel(zip_path),
        "pack_dir": _pack_rel(pack_dir),
        "size_kb": size_kb,
        "copied_files": manifest["copied_files"],
        "commands": manifest["commands"],
    }
    if args.json:
        print(json.dumps(summary, ensure_ascii=False))
    else:
        print(f"[OK] 反馈包已生成：{zip_path}（{size_kb} KB）")
        print("[NEXT] 分享前先查看 README_REVIEW_BEFORE_SHARING.md，确认没有隐私信息。")
    return 0


if __name__ == "__main__":
    sys.exit(main())
