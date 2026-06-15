#!/usr/bin/env python3
"""
接续执行包输出。

输出当前 Godot V1 Plus 脚手架的关键上下文、PM 状态和可复制给 AI 的接续提示。
"""
from __future__ import annotations

import subprocess
import sys
import shutil
import json
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
PM_CLI = PROJECT_ROOT / ".agents" / "skills" / "pm-agile" / "scripts" / "pm_cli.py"


def _find_git() -> str:
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
    return "git"


def _run(command: list[str]) -> str:
    try:
        result = subprocess.run(
            command,
            cwd=PROJECT_ROOT,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            text=True,
            encoding="utf-8",
            errors="replace",
        )
        return (result.stdout or "").strip()
    except Exception as exc:
        return str(exc).strip()


def _git(args: list[str]) -> str:
    return _run([_find_git(), *args])


def _read(path: Path, max_lines: int = 36) -> str:
    if not path.exists():
        return ""
    lines = path.read_text(encoding="utf-8", errors="ignore").splitlines()
    return "\n".join(lines[:max_lines])


def _pm_status() -> str:
    if not PM_CLI.exists():
        return "未找到 PM CLI。"
    raw = _run([sys.executable, str(PM_CLI), "status"])
    try:
        data = json.loads(raw)
    except Exception:
        return raw

    summary: dict[str, list[dict[str, object]]] = {}
    for section, items in data.items():
        if not isinstance(items, list):
            continue
        summary[section] = []
        for item in items:
            if not isinstance(item, dict):
                continue
            compact = {
                "demand_id": item.get("demand_id"),
                "title": item.get("title"),
            }
            for key in ("current_task", "next_task", "days_waiting"):
                if key in item:
                    compact[key] = item.get(key)
            summary[section].append(compact)
    return json.dumps(summary, ensure_ascii=False, indent=2)


def main() -> int:
    branch = _git(["rev-parse", "--abbrev-ref", "HEAD"])
    if "not a git repository" in branch.lower():
        branch = "未初始化 Git"
    last_commit = _git(["log", "--oneline", "-1"])
    if "not a git repository" in last_commit.lower():
        last_commit = "无"
    dirty_text = _git(["status", "--porcelain"])
    dirty = bool(dirty_text and "not a git repository" not in dirty_text.lower())

    must_read = [
        "AGENTS.md",
        "docs/project-map.md（AI 最小导航：目录职责、示例索引、接力读取规则）",
        "docs/game-concept.md",
        "docs/project/game-concept.md（当前游戏分层项目文档入口，若存在）",
    ]
    on_demand = [
        "docs/project/gameplay/README.md（当前游戏玩法总览）",
        "docs/project/gameplay/systems/（当前游戏系统规格）",
        "docs/project/gameplay/content-units.md（当前游戏首版内容单元）",
        "docs/design-inputs/（用户原始输入和 AI 提炼稿，需要核对设定来源时读）",
        "docs/AI_WORKFLOW.md（完整流程）",
        "docs/GAME_DESIGN_GUIDE.md（玩法拆解和中度/混合玩法蓝图）",
        "docs/ART_PIPELINE.md（美术和素材）",
        "docs/QUALITY_BAR.md（交付标准）",
        "docs/TOOLCHAIN.md（工具链、常见问题、本地存档点）",
        "docs/GODOT_MCP.md（可选 GodotMCP / MCP 编辑器桥接）",
        "scripts/generate_project_map.py（新增稳定入口或核心文件后更新项目地图）",
        "spec/spec.json（模板规格，需要时再读）",
        "spec/gameplay_blueprints.json（机器可读玩法蓝图，需要时再读）",
    ]

    output = f"""
## AI 接续执行包

### 项目状态
- 分支：{branch}
- 最新存档点：{last_commit}
- 未存档变更：{"是" if dirty else "否或未初始化 Git"}

### PM 状态
```json
{_pm_status()}
```

### 必读文件
{chr(10).join(f"- {item}" for item in must_read)}

### 按需文件
{chr(10).join(f"- {item}" for item in on_demand)}

### 游戏设定摘要
{_read(PROJECT_ROOT / "docs" / "project" / "game-concept.md") or _read(PROJECT_ROOT / "docs" / "game-concept.md") or "未找到游戏设定文档"}

### 验证命令
- 环境检查：python scripts/check_env.py --json
- GodotMCP 配置生成：python scripts/setup_godot_mcp.py --provider auto
- AI 客户端项目级 MCP 自动配置：python scripts/setup_ai_mcp.py --apply-project
- 质量工具准备：python scripts/setup_quality_tools.py
- 质量门禁（GDUnit4 可选）：python scripts/godot_quality_tools.py --json
- AI 自动审查：python scripts/ai_review.py --strict
- 玩法语义审查：python scripts/gameplay_logic_review.py
- 体验结构审查：python scripts/experience_design_review.py
- Godot headless 场景加载：python scripts/godot_headless_check.py
- Godot 正常运行日志：python scripts/godot_runtime_log_check.py
- Web 导出：python scripts/export_web.py --json
- 本地预览：python scripts/run_web_preview.py --open --json
- 美术管线审查：python scripts/art_pipeline_review.py
- 真实游戏首版不能因为没有 PSD/UI 源图跳过 UI；应生成 UI sheet、HUD 图标、按钮或面板，接入 assets/ui/，再由 art_pipeline_review.py 检查运行时证据。
- 体验检查：python scripts/experience_check.py --strict
- 视觉可读性审查：python scripts/visual_readability_review.py --strict
- 模板导出 dry-run：python scripts/export_template.py --dry-run

### 可复制给 AI 的接续提示
```text
请继续 Godot V1 Plus 脚手架工作。先查看 PM 状态；继续具体需求时运行
pm_cli.py info <ID> 获取 read_first，再读取 AGENTS.md、docs/project-map.md、
read_first、docs/game-concept.md 和 docs/project/game-concept.md，按当前 doing 任务推进。
做玩法、内容、美术或 UI 时优先读取 docs/project/；只有需要完整流程、
游戏设计指南或美术管线时再读对应脚手架 docs。
不要自动执行 git commit/push/reset。
```
""".strip()
    print(output)
    return 0


if __name__ == "__main__":
    sys.exit(main())
