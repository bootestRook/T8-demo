#!/usr/bin/env python3
"""
AI 自动审查入口。

目标：每轮改动后由 AI 自己完成代码、文档、模板和运行体验检查；
人工只参与需求输入、危险操作确认和最终成果验收。
"""
from __future__ import annotations

import argparse
import ast
import json
import os
import re
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
PM_CLI = PROJECT_ROOT / ".agents" / "skills" / "pm-agile" / "scripts" / "pm_cli.py"
PROCESS_DIR_PATTERNS = (
    ".pm/",
    ".runtime/",
    ".codex/",
    "html5/",
    "exports/",
    "reports/",
    ".git/",
    ".agents/.pm/",
    ".agents/skills/ui-studio/evals/",
    ".agents/skills/ui-studio/test-source/",
)
RUNTIME_SCAN_PATHS = [
    PROJECT_ROOT / "project.godot",
    PROJECT_ROOT / "export_presets.cfg",
    PROJECT_ROOT / "src",
    PROJECT_ROOT / "scenes",
]
RUNTIME_SOURCE_EXTENSIONS = {".gd", ".tscn", ".tres", ".cfg", ".godot"}
TEMPLATE_TEXT_PATTERNS = ("TODO", "Lorem ipsum", "placeholder", "Phaser Vibe Prototype")
EXTERNAL_DOC_COMMANDS = {"agent-browser.cmd"}

checks: list[dict[str, str]] = []
final_status = "PASS"
experience_screenshot_dir = ""
REVIEW_DIMENSIONS = {
    "Technical": [
        "Python 语法",
        "PowerShell 语法",
        "OpenCode 插件语法",
        "文档路由",
        "PM 状态源",
        "PM 一致性",
        "项目地图",
        "多 Agent 契约",
        "架构边界审查",
        "质量门禁",
        "Godot headless 场景加载",
        "Godot 正常运行日志",
        "模板导出 dry-run",
        "环境检查",
        "Web 导出与体验",
        "Web 导出",
        "Godot 原生截图检查",
        "运行时素材路径",
        "运行时模板文案",
    ],
    "Art": [
        "美术管线审查",
        "视觉可读性审查",
    ],
    "Gameplay": [
        "玩法语义审查",
        "体验结构审查",
    ],
    "UX": [
        "体验检查",
        "视觉可读性审查",
        "体验结构审查",
    ],
}


def _run(command: list[str], timeout: int = 180, env: dict[str, str] | None = None) -> tuple[bool, str]:
    try:
        run_env = os.environ.copy()
        if env:
            run_env.update(env)
        result = subprocess.run(
            command,
            cwd=PROJECT_ROOT,
            env=run_env,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=timeout,
        )
        return result.returncode == 0, (result.stdout or "").strip()
    except Exception as exc:
        return False, str(exc)


def _add(name: str, status: str, detail: str) -> None:
    global final_status
    checks.append({"name": name, "status": status, "detail": detail})
    if status == "FAIL":
        final_status = "FAIL"
    elif status == "CONCERNS" and final_status == "PASS":
        final_status = "CONCERNS"


def _status_rank(status: str) -> int:
    return {"PASS": 0, "CONCERNS": 1, "FAIL": 2}.get(status, 1)


def _worst_status(items: list[dict[str, str]]) -> str:
    if not items:
        return "CONCERNS"
    return max((item["status"] for item in items), key=_status_rank)


def _dimension_summary() -> list[dict[str, str]]:
    result: list[dict[str, str]] = []
    for dimension, names in REVIEW_DIMENSIONS.items():
        related = [check for check in checks if check["name"] in names]
        status = _worst_status(related)
        issues = [
            f"{check['name']}: {check['detail']}"
            for check in related
            if check["status"] in {"FAIL", "CONCERNS"}
        ]
        result.append({
            "name": dimension,
            "status": status,
            "detail": "；".join(issues[:6]) if issues else "分项检查通过。",
        })

    human_status = "CONCERNS" if final_status == "PASS" else final_status
    human_detail = (
        "自动检查通过后仍需人工试玩验收；用户明确反馈不满意时，本项应视为 FAIL 并把需求拉回 doing。"
        if final_status == "PASS"
        else "自动检查仍有 FAIL/CONCERNS，不能进入人工验收。"
    )
    result.append({"name": "Human Acceptance", "status": human_status, "detail": human_detail})
    return result


def _parse_json(text: str) -> dict[str, Any] | None:
    try:
        parsed = json.loads(text)
        return parsed if isinstance(parsed, dict) else None
    except Exception:
        return None


def _rel(path: Path) -> str:
    return path.relative_to(PROJECT_ROOT).as_posix()


def _python_files() -> list[Path]:
    files = list((PROJECT_ROOT / "scripts").glob("*.py"))
    files += list((PROJECT_ROOT / ".agents" / "skills").glob("*/scripts/*.py"))
    return sorted({file for file in files if file.is_file()})


def _check_python_compile() -> None:
    files = [str(file.relative_to(PROJECT_ROOT)) for file in _python_files()]
    if not files:
        _add("Python 语法", "CONCERNS", "未找到 Python 脚本。")
        return
    cache_dir = PROJECT_ROOT / ".runtime" / "pycache"
    cache_dir.mkdir(parents=True, exist_ok=True)
    ok, text = _run(
        [sys.executable, "-m", "py_compile", *files],
        timeout=120,
        env={"PYTHONPYCACHEPREFIX": str(cache_dir)},
    )
    _add("Python 语法", "PASS" if ok else "FAIL", f"{len(files)} 个脚本" if ok else text)


def _check_powershell_parse() -> None:
    files = sorted((PROJECT_ROOT / "scripts").glob("*.ps1"))
    if not files:
        return

    shell = shutil.which("pwsh") or shutil.which("powershell")
    if not shell:
        _add("PowerShell 语法", "CONCERNS", "未找到 pwsh/powershell，跳过 .ps1 解析检查。")
        return

    failures: list[str] = []
    for file in files:
        ps_path = str(file).replace("'", "''")
        command = (
            "$tokens = $null; "
            "$parseErrors = $null; "
            "[System.Management.Automation.Language.Parser]::ParseFile("
            f"(Resolve-Path -LiteralPath '{ps_path}'), [ref]$tokens, [ref]$parseErrors) | Out-Null; "
            "if ($parseErrors.Count -gt 0) { "
            "$parseErrors | ForEach-Object { "
            "\"line=$($_.Extent.StartLineNumber) col=$($_.Extent.StartColumnNumber) $($_.Message)\" "
            "}; exit 1 }"
        )
        ok, text = _run(
            [shell, "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", command],
            timeout=60,
        )
        if not ok:
            failures.append(f"{_rel(file)}: {text}")

    _add(
        "PowerShell 语法",
        "FAIL" if failures else "PASS",
        "；".join(failures) if failures else f"{len(files)} 个 .ps1 脚本解析通过。",
    )


def _check_opencode_plugin_syntax() -> None:
    plugin = PROJECT_ROOT / ".opencode" / "plugins" / "game-tools.js"
    if not plugin.exists():
        return

    node = shutil.which("node")
    if not node:
        _add("OpenCode 插件语法", "CONCERNS", "未找到 node，跳过 game-tools.js 语法检查。")
        return

    ok, text = _run([node, "--check", str(plugin)], timeout=60)
    _add("OpenCode 插件语法", "PASS" if ok else "FAIL", "game-tools.js 语法通过。" if ok else text)


def _check_pm() -> None:
    if not PM_CLI.exists():
        _add("PM 状态源", "FAIL", "未找到 pm_cli.py。")
        return
    if not (PROJECT_ROOT / ".pm" / "project" / "backlog.json").exists():
        _add("PM 状态源", "CONCERNS", "尚未初始化 .pm/。init 阶段应运行 pm_cli.py init-backlog。")
        return
    ok, text = _run([sys.executable, str(PM_CLI), "check"], timeout=60)
    _add("PM 一致性", "PASS" if ok else "FAIL", text or "pm check 通过。")


def _check_project_map() -> None:
    script = PROJECT_ROOT / "scripts" / "generate_project_map.py"
    output = PROJECT_ROOT / "docs" / "project-map.md"
    if not script.exists():
        _add("项目地图", "FAIL", "未找到 scripts/generate_project_map.py。")
        return
    if not output.exists():
        _add("项目地图", "FAIL", "未找到 docs/project-map.md，请运行 python scripts/generate_project_map.py。")
        return
    ok, text = _run([sys.executable, str(script), "--check"], timeout=60)
    _add("项目地图", "PASS" if ok else "FAIL", text or "project-map 检查完成。")


def _check_document_routes() -> None:
    scanned = [
        PROJECT_ROOT / "AGENTS.md",
        PROJECT_ROOT / "README.md",
        PROJECT_ROOT / "START_HERE.md",
        *sorted((PROJECT_ROOT / "docs").glob("*.md")),
        *sorted((PROJECT_ROOT / ".agents" / "skills").glob("*/SKILL.md")),
    ]
    missing: list[str] = []
    for file in scanned:
        if not file.exists():
            continue
        text = file.read_text(encoding="utf-8", errors="ignore")
        for match in re.findall(r"`(\.agents/skills/[^`]+/SKILL\.md)`", text):
            if not (PROJECT_ROOT / match).exists():
                missing.append(f"{_rel(file)} -> {match}")
        for match in re.findall(r"`python\s+(scripts/[A-Za-z0-9_\-]+\.py)", text):
            if not (PROJECT_ROOT / match).exists():
                missing.append(f"{_rel(file)} -> {match}")
        for match in re.findall(r"`(?:powershell\s+[^`]*\s+)?(scripts/[A-Za-z0-9_\-]+\.ps1|[A-Za-z0-9_\-]+\.cmd)`", text):
            if match in EXTERNAL_DOC_COMMANDS:
                continue
            if not (PROJECT_ROOT / match).exists():
                missing.append(f"{_rel(file)} -> {match}")

    _add(
        "文档路由",
        "FAIL" if missing else "PASS",
        "；".join(missing) if missing else "skill 路由和脚本命令均指向存在的文件。",
    )


def _roles_from_script(path: Path) -> set[str]:
    if not path.exists():
        return set()
    try:
        tree = ast.parse(path.read_text(encoding="utf-8", errors="ignore"), filename=str(path))
    except SyntaxError:
        return set()
    for node in tree.body:
        if not isinstance(node, ast.Assign):
            continue
        if not any(isinstance(target, ast.Name) and target.id == "VALID_ROLES" for target in node.targets):
            continue
        if not isinstance(node.value, (ast.Set, ast.List, ast.Tuple)):
            return set()
        roles: set[str] = set()
        for item in node.value.elts:
            if not isinstance(item, ast.Constant) or not isinstance(item.value, str):
                return set()
            roles.add(item.value)
        return roles
    return set()


def _roles_from_role_files(path: Path) -> set[str]:
    if not path.exists():
        return set()
    return {
        file.stem
        for file in path.glob("*.md")
        if file.is_file()
    }


def _check_multi_agent_contract() -> None:
    script_paths = ["scripts/agent_task.py", "scripts/agent_merge.py"]
    role_sets = {
        script_path: _roles_from_script(PROJECT_ROOT / script_path)
        for script_path in script_paths
    }
    script_roles = set().union(*role_sets.values()) if role_sets else set()
    role_file_roles = _roles_from_role_files(PROJECT_ROOT / ".agents" / "roles")
    agent_roles = script_roles | role_file_roles
    required = [
        "docs/MULTI_AGENT_WORKFLOW.md",
        "docs/templates/agent-task.md",
        *[f".agents/roles/{role}.md" for role in sorted(agent_roles)],
        "scripts/agent_task.py",
        "scripts/agent_merge.py",
    ]
    missing = [path for path in required if not (PROJECT_ROOT / path).exists()]
    role_issues: list[str] = []
    for script_path, roles in role_sets.items():
        if not roles:
            role_issues.append(f"{script_path} 未声明 VALID_ROLES")
    if role_sets:
        baseline_path = script_paths[0]
        baseline_roles = role_sets.get(baseline_path, set())
        for script_path in script_paths[1:]:
            roles = role_sets.get(script_path, set())
            missing_in_script = sorted(baseline_roles - roles)
            extra_in_script = sorted(roles - baseline_roles)
            if missing_in_script:
                role_issues.append(f"{script_path} 缺少角色：" + "，".join(missing_in_script))
            if extra_in_script:
                role_issues.append(f"{script_path} 多出角色：" + "，".join(extra_in_script))
    missing_role_files = sorted(script_roles - role_file_roles)
    extra_role_files = sorted(role_file_roles - script_roles)
    if missing_role_files:
        role_issues.append("缺少角色文件：" + "，".join(f".agents/roles/{role}.md" for role in missing_role_files))
    if extra_role_files:
        role_issues.append("脚本未声明角色文件：" + "，".join(f".agents/roles/{role}.md" for role in extra_role_files))
    docs_to_check = [
        "docs/MULTI_AGENT_WORKFLOW.md",
        ".agents/roles/coordinator.md",
    ]
    for doc_path in docs_to_check:
        text = (PROJECT_ROOT / doc_path).read_text(encoding="utf-8", errors="ignore").lower() if (PROJECT_ROOT / doc_path).exists() else ""
        for role in sorted(agent_roles):
            if role not in text and role.replace("-", " ") not in text:
                role_issues.append(f"{doc_path} 缺少角色 {role}")
    issues = missing + role_issues
    _add(
        "多 Agent 契约",
        "FAIL" if issues else "PASS",
        "；".join(issues) if issues else "主从协作工作流、角色模板、任务包模板、脚本白名单和文档角色索引一致。",
    )


def _runtime_source_files() -> list[Path]:
    files: list[Path] = []
    for path in RUNTIME_SCAN_PATHS:
        if not path.exists():
            continue
        if path.is_file() and path.suffix in RUNTIME_SOURCE_EXTENSIONS:
            files.append(path)
        elif path.is_dir():
            files += [
                file for file in path.rglob("*")
                if file.is_file() and file.suffix in RUNTIME_SOURCE_EXTENSIONS
            ]
    return files


def _check_runtime_hygiene() -> None:
    template_hits: list[str] = []
    reference_loads: list[str] = []
    for file in _runtime_source_files():
        text = file.read_text(encoding="utf-8", errors="ignore")
        lower = text.lower()
        for pattern in TEMPLATE_TEXT_PATTERNS:
            if pattern.lower() in lower:
                template_hits.append(f"{pattern} @ {_rel(file)}")
        for line_no, line in enumerate(text.splitlines(), start=1):
            line_lower = line.lower()
            if "references/" not in line_lower and "res://references" not in line_lower:
                continue
            if any(token in line_lower for token in ("load(", "preload(", "resourceloader", "ext_resource")):
                reference_loads.append(f"{_rel(file)}:{line_no}")

    _add(
        "运行时模板文案",
        "CONCERNS" if template_hits else "PASS",
        "；".join(template_hits) if template_hits else "未发现常见模板感文案。",
    )
    _add(
        "运行时素材路径",
        "FAIL" if reference_loads else "PASS",
        "；".join(reference_loads) if reference_loads else "未发现直接加载 references/。",
    )


def _check_gameplay_logic() -> None:
    script = PROJECT_ROOT / "scripts" / "gameplay_logic_review.py"
    if not script.exists():
        _add("玩法语义审查", "FAIL", "未找到 scripts/gameplay_logic_review.py。")
        return
    ok, text = _run([sys.executable, str(script), "--json"], timeout=60)
    data = _parse_json(text)
    if not data:
        _add("玩法语义审查", "FAIL" if not ok else "CONCERNS", text or "无法解析玩法语义审查输出。")
        return
    status = str(data.get("status") or ("PASS" if ok else "FAIL"))
    failed = [
        f"{item.get('name')}: {item.get('detail')}"
        for item in data.get("checks", [])
        if item.get("status") in {"FAIL", "CONCERNS"}
    ]
    detail = "；".join(failed) if failed else "胜负、输入、边界、数值、素材反馈和概念隔离检查通过。"
    _add("玩法语义审查", status, detail)


def _check_art_pipeline() -> None:
    script = PROJECT_ROOT / "scripts" / "art_pipeline_review.py"
    if not script.exists():
        _add("美术管线审查", "FAIL", "未找到 scripts/art_pipeline_review.py。")
        return
    ok, text = _run([sys.executable, str(script), "--json"], timeout=60)
    data = _parse_json(text)
    if not data:
        _add("美术管线审查", "FAIL" if not ok else "CONCERNS", text or "无法解析美术管线审查输出。")
        return
    status = str(data.get("status") or ("PASS" if ok else "FAIL"))
    failed = [
        f"{item.get('name')}: {item.get('detail')}"
        for item in data.get("checks", [])
        if item.get("status") in {"FAIL", "CONCERNS"}
    ]
    detail = "；".join(failed) if failed else "provider、media_api 命令和风格候选落地检查通过。"
    _add("美术管线审查", status, detail)


def _check_experience_design() -> None:
    script = PROJECT_ROOT / "scripts" / "experience_design_review.py"
    if not script.exists():
        _add("体验结构审查", "FAIL", "未找到 scripts/experience_design_review.py。")
        return
    ok, text = _run([sys.executable, str(script), "--json"], timeout=60)
    data = _parse_json(text)
    if not data:
        _add("体验结构审查", "FAIL" if not ok else "CONCERNS", text or "无法解析体验结构审查输出。")
        return
    status = str(data.get("status") or ("PASS" if ok else "FAIL"))
    issues = [
        f"{item.get('name')}: {item.get('detail')}"
        for item in data.get("checks", [])
        if item.get("status") in {"FAIL", "CONCERNS"}
    ]
    detail = "；".join(issues) if issues else "完整首版体验结构或空脚手架豁免检查通过。"
    _add("体验结构审查", status, detail)


def _check_architecture_boundaries() -> None:
    script = PROJECT_ROOT / "scripts" / "architecture_review.py"
    if not script.exists():
        _add("架构边界审查", "FAIL", "未找到 scripts/architecture_review.py。")
        return
    ok, text = _run([sys.executable, str(script), "--json"], timeout=60)
    data = _parse_json(text)
    if not data:
        _add("架构边界审查", "FAIL" if not ok else "CONCERNS", text or "无法解析架构边界审查输出。")
        return
    status = str(data.get("status") or ("PASS" if ok else "FAIL"))
    issues = [
        f"{item.get('name')}: {item.get('detail')}"
        for item in data.get("checks", [])
        if item.get("status") in {"FAIL", "CONCERNS"}
    ]
    detail = "；".join(issues) if issues else "模块、HUD、Game.gd 和运行时资源边界检查通过。"
    _add("架构边界审查", status, detail)


def _check_required_quality_tools() -> None:
    script = PROJECT_ROOT / "scripts" / "godot_quality_tools.py"
    if not script.exists():
        _add("质量门禁", "FAIL", "未找到 scripts/godot_quality_tools.py。")
        return
    ok, text = _run([sys.executable, str(script), "--json"], timeout=360)
    data = _parse_json(text)
    if not data:
        _add("质量门禁", "FAIL" if not ok else "CONCERNS", text or "无法解析质量门禁输出。")
        return
    status = str(data.get("status") or ("PASS" if ok else "FAIL"))
    issues = [
        f"{item.get('name')}: {item.get('detail')}"
        for item in data.get("checks", [])
        if item.get("status") in {"FAIL", "CONCERNS"}
    ]
    detail = "；".join(issues) if issues else "GDScript Toolkit 门禁通过；GDUnit4 为可选检查。"
    _add("质量门禁", status, detail)


def _check_godot_headless(skip_runtime: bool) -> None:
    if skip_runtime:
        _add("Godot headless 场景加载", "CONCERNS", "已按参数跳过 Godot headless 场景加载。")
        return
    script = PROJECT_ROOT / "scripts" / "godot_headless_check.py"
    if not script.exists():
        _add("Godot headless 场景加载", "FAIL", "未找到 scripts/godot_headless_check.py。")
        return
    ok, text = _run([sys.executable, str(script), "--json"], timeout=120)
    data = _parse_json(text)
    if not data:
        _add("Godot headless 场景加载", "FAIL" if not ok else "CONCERNS", text or "无法解析 headless 检查输出。")
        return
    status = str(data.get("status") or ("PASS" if ok else "FAIL"))
    blocking = data.get("blocking") or []
    detail = "；".join(str(item) for item in blocking[:8]) if blocking else f"{data.get('scene')} 加载通过。"
    _add("Godot headless 场景加载", status, detail)


def _check_godot_runtime_log(skip_runtime: bool) -> None:
    if skip_runtime:
        _add("Godot 正常运行日志", "CONCERNS", "已按参数跳过 Godot 正常运行日志检查。")
        return
    script = PROJECT_ROOT / "scripts" / "godot_runtime_log_check.py"
    if not script.exists():
        _add("Godot 正常运行日志", "FAIL", "未找到 scripts/godot_runtime_log_check.py。")
        return
    ok, text = _run([sys.executable, str(script), "--json"], timeout=90)
    data = _parse_json(text)
    if not data:
        _add("Godot 正常运行日志", "FAIL" if not ok else "CONCERNS", text or "无法解析正常运行日志检查输出。")
        return
    status = str(data.get("status") or ("PASS" if ok else "FAIL"))
    blocking = data.get("blocking") or []
    transient_failures = data.get("transient_failures") or []
    if blocking:
        detail = "；".join(str(item) for item in blocking[:8])
    elif transient_failures:
        status = "CONCERNS" if status == "PASS" else status
        diagnostics = data.get("crash_diagnostics") or {}
        diagnostic_detail = ""
        if isinstance(diagnostics, dict) and diagnostics.get("likely_external_injection"):
            modules = diagnostics.get("suspicious_modules") or []
            diagnostic_detail = "；WER 显示疑似系统注入模块：" + ",".join(str(item) for item in modules[:8])
        detail = (
            f"{data.get('scene')} 正常运行日志重试后通过；"
            "曾发生短暂失败："
            + "；".join(str(item) for item in transient_failures[:4])
            + diagnostic_detail
        )
    else:
        detail = f"{data.get('scene')} 正常运行日志通过。"
    _add("Godot 正常运行日志", status, detail)


def _check_godot_native_screenshot(skip_runtime: bool) -> None:
    global experience_screenshot_dir
    if skip_runtime:
        _add("Godot 原生截图检查", "CONCERNS", "已按参数跳过 Godot 原生运行截图检查。")
        return
    script = PROJECT_ROOT / "scripts" / "godot_native_screenshot_check.py"
    if not script.exists():
        _add("Godot 原生截图检查", "FAIL", "未找到 scripts/godot_native_screenshot_check.py。")
        return
    ok, text = _run([sys.executable, str(script), "--json"], timeout=90)
    data = _parse_json(text)
    if not data:
        _add("Godot 原生截图检查", "FAIL" if not ok else "CONCERNS", text or "无法解析原生截图检查输出。")
        return
    status = str(data.get("status") or ("PASS" if ok else "FAIL"))
    issues = [
        f"{item.get('name')}: {item.get('detail')}"
        for item in data.get("checks", [])
        if item.get("status") in {"FAIL", "CONCERNS"}
    ]
    screenshot_dir = str(data.get("screenshot_dir") or "")
    if not experience_screenshot_dir and screenshot_dir:
        experience_screenshot_dir = screenshot_dir
    transient_failures = data.get("transient_failures") or []
    if transient_failures and status == "PASS":
        status = "CONCERNS"
        issues.append("曾发生短暂失败：" + "；".join(str(item) for item in transient_failures[:4]))
    detail = "；".join(issues) if issues else f"原生运行截图通过：{screenshot_dir}"
    _add("Godot 原生截图检查", status, detail)


def _check_template_export() -> None:
    ok, text = _run([sys.executable, "scripts/export_template.py", "--dry-run"], timeout=120)
    if not ok:
        _add("模板导出 dry-run", "FAIL", text)
        return
    included = [
        line.strip() for line in text.splitlines()
        if line.strip() and not line.startswith("#") and not re.match(r"^(Files|Output|Format|Include Tools|Generated Empty Git Repo):", line)
    ]
    bad = [line for line in included if line.startswith(PROCESS_DIR_PATTERNS)]
    includes_tools = re.search(r"^Include Tools:\s+yes$", text, re.MULTILINE) is not None
    if not includes_tools:
        bad.append("missing default tools inclusion marker")
    has_empty_git = re.search(r"^Generated Empty Git Repo:\s+yes$", text, re.MULTILINE) is not None
    if not has_empty_git:
        bad.append("missing generated empty .git repo marker")
    required_out_of_box = {
        "scripts/godot_quality_tools.py": "missing quality gate script",
        "scripts/setup_quality_tools.py": "missing quality setup script",
        "scripts/run_python_entrypoint.py": "missing Python entrypoint runner",
        "scripts/godot_runtime_log_check.py": "missing runtime log check script",
        "scripts/godot_mcp_stdio.py": "missing GodotMCP stdio wrapper",
        "scripts/godot_mcp_stdio.cmd": "missing GodotMCP Windows stdio wrapper",
        "scripts/godot_mcp_stdio.sh": "missing GodotMCP POSIX stdio wrapper",
        "scripts/setup_ai_mcp.py": "missing AI MCP setup script",
        "spec/quality_tools.json": "missing quality tools manifest",
        "tools/godot-mcp-node/node_modules/@coding-solo/godot-mcp/build/index.js": (
            "missing bundled Coding-Solo GodotMCP package; run "
            "python scripts/setup_godot_mcp.py --provider coding-solo --install-coding-solo --yes "
            "after confirming network access"
        ),
    }
    included_set = set(included)
    for path, message in required_out_of_box.items():
        if path not in included_set:
            bad.append(message)
    if ".mcp.json" in included_set:
        bad.append(".mcp.json should be generated by init on the target machine, not exported from the current host")
    if not any(path.startswith("tools/gdtoolkit/python/gdtoolkit/") for path in included):
        bad.append("missing bundled GDScript Toolkit package")
    _add(
        "模板导出 dry-run",
        "FAIL" if bad else "PASS",
        "模板导出问题：" + "，".join(bad) if bad else f"导出清单 {len(included)} 个文件，未包含过程目录，并会生成空 Git 仓库。",
    )


def _check_environment() -> bool:
    ok, text = _run([sys.executable, "scripts/check_env.py", "--json"], timeout=60)
    data = _parse_json(text)
    if not data:
        _add("环境检查", "FAIL" if not ok else "CONCERNS", text)
        return False
    checks_by_name = {item.get("check"): item for item in data.get("checks", [])}
    python_ok = checks_by_name.get("python", {}).get("status") == "ok"
    godot_ok = checks_by_name.get("godot", {}).get("status") == "ok"
    templates_ok = checks_by_name.get("export_templates", {}).get("status") == "ok"
    if not python_ok:
        _add("环境检查", "FAIL", text)
        return False
    if not godot_ok:
        _add("环境检查", "FAIL", "未检测到 Godot 4；无法完成 Web 导出和运行体验审查。")
        return False
    if not templates_ok:
        _add("环境检查", "FAIL", "未检测到 Godot Export Templates；无法完成 Web 导出。")
        return False
    _add("环境检查", "PASS", "Python、Godot 4、Export Templates 可用。")
    return True


def _check_export_and_experience(skip_runtime: bool) -> None:
    global experience_screenshot_dir
    experience_screenshot_dir = ""
    if skip_runtime:
        _add("Web 导出与体验", "CONCERNS", "已按参数跳过运行时审查。")
        return
    if not _check_environment():
        _add("Web 导出", "FAIL", "环境未就绪，跳过导出命令。")
        _add("体验检查", "FAIL", "环境未就绪，跳过浏览器运行体验检查。")
        return

    export_ok, export_text = _run([sys.executable, "scripts/export_web.py", "--json"], timeout=240)
    export_data = _parse_json(export_text)
    if export_ok and export_data and export_data.get("status") == "ok":
        _add("Web 导出", "PASS", f"{export_data.get('output_dir')}，文件数 {export_data.get('file_count')}")
    else:
        _add("Web 导出", "FAIL", export_text or "导出失败。")
        _add("体验检查", "FAIL", "Web 导出失败，跳过体验检查。")
        return

    experience_ok, experience_text = _run([sys.executable, "scripts/experience_check.py", "--skip-export", "--json"], timeout=360)
    experience_data = _parse_json(experience_text)
    if experience_data:
        status = str(experience_data.get("status") or ("PASS" if experience_ok else "FAIL"))
        screenshots = experience_data.get("screenshots") or {}
        if isinstance(screenshots, dict):
            first_path = next((str(value) for value in screenshots.values() if value), "")
            if first_path:
                parent = Path(first_path).parent.as_posix()
                if parent and parent != ".":
                    experience_screenshot_dir = parent
        detail = json.dumps(experience_data, ensure_ascii=False, indent=2)[-1800:]
        _add("体验检查", status, detail)
        return

    status_match = re.search(r"结论：\s*(PASS|CONCERNS|FAIL)", experience_text)
    status = status_match.group(1) if status_match else ("PASS" if experience_ok else "FAIL")
    _add("体验检查", status, experience_text[-1800:] if experience_text else "无输出。")


def _check_visual_readability(skip_runtime: bool) -> None:
    if skip_runtime:
        _add("视觉可读性审查", "CONCERNS", "已按参数跳过运行时截图审查。")
        return
    if not experience_screenshot_dir:
        _add(
            "视觉可读性审查",
            "CONCERNS",
            "本轮 experience_check 未产出截图目录；不使用历史截图目录做视觉验收。",
        )
        return
    script = PROJECT_ROOT / "scripts" / "visual_readability_review.py"
    if not script.exists():
        _add("视觉可读性审查", "FAIL", "未找到 scripts/visual_readability_review.py。")
        return
    command = [sys.executable, str(script), "--json"]
    command.extend(["--screenshots-dir", experience_screenshot_dir])
    ok, text = _run(command, timeout=60)
    data = _parse_json(text)
    if not data:
        _add("视觉可读性审查", "FAIL" if not ok else "CONCERNS", text or "无法解析视觉可读性审查输出。")
        return
    status = str(data.get("status") or ("PASS" if ok else "FAIL"))
    issues = [
        f"{item.get('name')}: {item.get('detail')}"
        for item in data.get("checks", [])
        if item.get("status") in {"FAIL", "CONCERNS"}
    ]
    screenshot_dir = str(data.get("screenshot_dir") or "")
    detail = "；".join(issues) if issues else f"截图和基础玩家可读性证据通过：{screenshot_dir}"
    _add("视觉可读性审查", status, detail)


def _print_report(json_mode: bool) -> None:
    dimensions = _dimension_summary()
    if json_mode:
        print(json.dumps({"status": final_status, "dimensions": dimensions, "checks": checks}, ensure_ascii=False, indent=2))
        return

    print("## AI Review")
    print("")
    print("| 检查项 | 结果 | 说明 |")
    print("|---|---|---|")
    for check in checks:
        detail = check["detail"].replace("\n", "<br>")
        print(f"| {check['name']} | {check['status']} | {detail} |")
    print("")
    print("## Review Dimensions")
    print("")
    print("| 维度 | 结果 | 说明 |")
    print("|---|---|---|")
    for item in dimensions:
        detail = item["detail"].replace("\n", "<br>")
        print(f"| {item['name']} | {item['status']} | {detail} |")
    print("")
    print(f"结论：{final_status}")
    print("注意：本审查证明技术链路、基础体验和截图证据状态，不等于美术、UI、手感和玩家可读性已被人工接受。涉及视觉/体验反馈时，以浏览器截图和人工试玩反馈为准。")
    if final_status == "PASS":
        print("下一步：AI 可交付给人工做成果验收。")
    elif final_status == "CONCERNS":
        print("下一步：AI 先处理 CONCERNS，或在明确可接受时标注原因后交付验收。")
    else:
        print("下一步：AI 必须先修复 FAIL 项，不应进入人工成果验收。")


def main() -> int:
    parser = argparse.ArgumentParser(description="AI 自动审查")
    parser.add_argument("--json", action="store_true")
    parser.add_argument("--skip-runtime", action="store_true", help="只做静态和模板审查，不运行 Godot 导出/浏览器检查")
    parser.add_argument("--strict", action="store_true", help="CONCERNS 也返回非 0，用于交付门禁")
    args = parser.parse_args()

    _check_pm()
    _check_project_map()
    _check_python_compile()
    _check_powershell_parse()
    _check_opencode_plugin_syntax()
    _check_document_routes()
    _check_multi_agent_contract()
    _check_runtime_hygiene()
    _check_gameplay_logic()
    _check_art_pipeline()
    _check_experience_design()
    _check_architecture_boundaries()
    _check_required_quality_tools()
    _check_godot_headless(args.skip_runtime)
    _check_godot_runtime_log(args.skip_runtime)
    _check_template_export()
    _check_export_and_experience(args.skip_runtime)
    if not experience_screenshot_dir:
        _check_godot_native_screenshot(args.skip_runtime)
    _check_visual_readability(args.skip_runtime)
    _print_report(args.json)
    return 1 if final_status == "FAIL" or (args.strict and final_status == "CONCERNS") else 0


if __name__ == "__main__":
    sys.exit(main())
