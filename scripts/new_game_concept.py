#!/usr/bin/env python3
"""创建新的游戏设定卡，并归档上一版概念。

AI 在 init 阶段锁定玩法和美术后使用此脚本，避免第二次建游戏污染第一次的设定。
"""
from __future__ import annotations

import argparse
import shutil
import re
from datetime import datetime
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
CONCEPT_FILE = PROJECT_ROOT / "docs" / "game-concept.md"
ARCHIVE_DIR = PROJECT_ROOT / "docs" / "concepts"
PROJECT_DOC_DIR = PROJECT_ROOT / "docs" / "project"
DESIGN_INPUTS_DIR = PROJECT_ROOT / "docs" / "design-inputs"


def _slug(text: str) -> str:
    value = re.sub(r"[^a-zA-Z0-9\u4e00-\u9fff]+", "-", text).strip("-")
    return value[:36] or "new-game"


def _archive_current(timestamp: str) -> Path | None:
    if not CONCEPT_FILE.exists():
        return None
    ARCHIVE_DIR.mkdir(parents=True, exist_ok=True)
    target = ARCHIVE_DIR / f"{timestamp}-game-concept.md"
    if target.exists():
        suffix = 2
        while (ARCHIVE_DIR / f"{timestamp}-game-concept-{suffix}.md").exists():
            suffix += 1
        target = ARCHIVE_DIR / f"{timestamp}-game-concept-{suffix}.md"
    target.write_text(CONCEPT_FILE.read_text(encoding="utf-8", errors="ignore"), encoding="utf-8")
    return target


def _archive_project_docs(timestamp: str) -> Path | None:
    if not PROJECT_DOC_DIR.exists():
        return None
    ARCHIVE_DIR.mkdir(parents=True, exist_ok=True)
    target = ARCHIVE_DIR / f"{timestamp}-project"
    if target.exists():
        suffix = 2
        while (ARCHIVE_DIR / f"{timestamp}-project-{suffix}").exists():
            suffix += 1
        target = ARCHIVE_DIR / f"{timestamp}-project-{suffix}"
    shutil.copytree(PROJECT_DOC_DIR, target)
    shutil.rmtree(PROJECT_DOC_DIR)
    return target


def _read_optional(path_value: str) -> str:
    if not path_value:
        return ""
    path = Path(path_value)
    if not path.is_absolute():
        path = PROJECT_ROOT / path
    if not path.exists():
        raise SystemExit(f"输入文件不存在：{path}")
    return path.read_text(encoding="utf-8", errors="ignore").strip()


def _write(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def _split_items(value: str) -> list[str]:
    return [item.strip(" -\t\r") for item in re.split(r"[\n；;]+", value) if item.strip(" -\t\r")]


def _bullet_lines(value: str, fallback: str) -> str:
    items = _split_items(value)
    if not items:
        items = [fallback]
    return "\n".join(f"- {item}" for item in items)


def _numbered_sections(items: list[str], fallback: str) -> str:
    if not items:
        items = [fallback]
    sections: list[str] = []
    for index, item in enumerate(items, start=1):
        sections.append(
            f"""## 内容单元 {index}

- 目标：{item}
- 差异：待在开发需求中进一步细化。
- 压力：待在开发需求中进一步细化。
- 素材：围绕本单元目标从本轮美术素材计划中选择。"""
        )
    return "\n\n".join(sections)


def _system_filename(name: str) -> str:
    slug = re.sub(r"[^a-zA-Z0-9\u4e00-\u9fff]+", "-", name).strip("-").lower()
    return f"{slug[:48] or 'system'}.md"


def _rel_project_path(path: Path) -> str:
    return path.relative_to(PROJECT_ROOT).as_posix()


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


def _source_sort_key(path: Path) -> tuple[int, str]:
    if path.name == "source.md":
        return (1, path.name)
    match = re.match(r"source-(\d+)\.md$", path.name)
    if match:
        return (int(match.group(1)), path.name)
    return (9999, path.name)


def _update_input_index(target_dir: Path, concept_id: str) -> None:
    sources = sorted(target_dir.glob("source*.md"), key=_source_sort_key)
    extracted = target_dir / "extracted.md"
    lines = [
        "# 设定输入索引",
        "",
        f"- 概念ID：`{concept_id}`",
        "",
        "## 原始输入",
        "",
    ]
    lines.extend(f"- `{path.name}`" for path in sources) if sources else lines.append("- 暂无。")
    lines.extend(["", "## AI 提炼稿", ""])
    lines.append(f"- `{extracted.name}`" if extracted.exists() else "- 暂无。")
    _write(target_dir / "README.md", "\n".join(lines) + "\n")


def _same_path(left: Path, right: Path) -> bool:
    try:
        return left.resolve() == right.resolve()
    except OSError:
        return left == right


def _resolve_project_path(path_value: str) -> Path:
    path = Path(path_value)
    if not path.is_absolute():
        path = PROJECT_ROOT / path
    return path


def _validate_existing_doc(path_value: str, label: str) -> str:
    if not path_value:
        return ""
    path = _resolve_project_path(path_value)
    if not path.exists():
        raise SystemExit(f"{label} 不存在：{path}")
    try:
        return path.relative_to(PROJECT_ROOT).as_posix()
    except ValueError as exc:
        raise SystemExit(f"{label} 必须位于项目目录内：{path}") from exc


def _save_design_inputs(args: argparse.Namespace, concept_id: str) -> tuple[str, str]:
    if args.source_doc and args.extracted_doc:
        return (
            _validate_existing_doc(args.source_doc, "原始设定文档"),
            _validate_existing_doc(args.extracted_doc, "AI 提炼稿文档"),
        )

    source_text = _read_optional(args.source_file) or args.source_text.strip()
    extracted_text = _read_optional(args.extracted_file) or args.extracted_text.strip()
    input_dir = DESIGN_INPUTS_DIR / concept_id
    source_rel = _validate_existing_doc(args.source_doc, "原始设定文档")
    extracted_rel = _validate_existing_doc(args.extracted_doc, "AI 提炼稿文档")

    if source_text:
        provided_path = _resolve_project_path(args.source_file) if args.source_file else None
        if provided_path and provided_path.parent == input_dir and provided_path.name.startswith("source"):
            source_path = provided_path
        else:
            source_path = _next_source_path(input_dir)
        if provided_path and _same_path(provided_path, source_path):
            source_rel = _rel_project_path(source_path)
        else:
            _write(
                source_path,
                f"""# 用户原始设定

概念ID：`{concept_id}`

以下内容为用户原始输入或参考设定，必须原样保留。AI 可以提炼，但不得用摘要覆盖本文件。

---

{source_text}
""",
            )
            source_rel = _rel_project_path(source_path)

    if extracted_text:
        extracted_path = input_dir / "extracted.md"
        if args.extracted_file and _same_path(_resolve_project_path(args.extracted_file), extracted_path):
            extracted_rel = _rel_project_path(extracted_path)
        else:
            _write(
                extracted_path,
                f"""# AI 提炼稿

概念ID：`{concept_id}`

本文件保存 AI 从原始输入中提炼出的结构化设定、首版范围和暂缓项。用户确认后，稳定结论再写入 `docs/project/` 和 `docs/game-concept.md`。

---

{extracted_text}
""",
            )
            extracted_rel = _rel_project_path(extracted_path)

    if source_text or extracted_text:
        _update_input_index(input_dir, concept_id)

    return source_rel, extracted_rel


def _build(args: argparse.Namespace, concept_id: str) -> str:
    blueprints = [item.strip() for item in args.blueprints.split(",") if item.strip()]
    if not blueprints:
        blueprints = ["custom"]
    blueprint_lines = "\n".join(f"- `{item}`" for item in blueprints)
    content_units_value = args.content_units
    content_unit_lines = _bullet_lines(
        content_units_value,
        "至少 3 个精细内容单元或系统阶段：第 1 个教学核心操作，第 2 个改变布局/目标组合/节奏，第 3 个加入阶段压力、奖励诱惑、系统组合或失败压力。",
    )
    runtime_art_plan_lines = _bullet_lines(
        args.runtime_art_plan,
        "优先生成或接入玩家、主要威胁/目标、场地、核心 UI/VFX 中最高收益的 1-3 类素材。",
    )
    source_line = f"- 原始设定：`{args.source_doc}`" if args.source_doc else "- 原始设定：未提供长设定。"
    extracted_line = (
        f"- AI 提炼稿：`{args.extracted_doc}`" if args.extracted_doc else "- AI 提炼稿：未单独保存。"
    )
    return f"""# 游戏设定卡

这个文件是当前游戏概念的单一事实源。每次新建游戏都必须生成新的概念ID，并把上一版设定归档到 `docs/concepts/`，避免第二次项目污染第一次的玩法目标。

## 概念ID

- `{concept_id}`

## 玩法蓝图

{blueprint_lines}

## 一句话目标

- {args.goal}

## 设定来源

{source_line}
{extracted_line}
- 分层项目文档：`docs/project/`

## 平台与目标层级

- 平台：{args.platform}
- 目标层级：{args.level}

## 核心玩法

- 核心操作：{args.core_action}
- 立即反馈：{args.feedback}
- 一轮结束：{args.end_condition}
- 重开方式：胜负后按 R、空格或点击重开。

## 玩法不变量

- {args.invariant}
- 至少存在一个成功条件和一个失败条件。
- 胜负后必须能一键重开，不要求刷新页面。
- 运行时代码不得直接加载 `references/`。

## 禁止污染项

- 新游戏 init 时不得沿用上一版的角色、胜负条件、美术关键词或数值目标，除非用户明确选择继续魔改上一版。
- 新游戏必须写入新的概念ID、一句话目标、玩法不变量、美术风格、首版内容单元或系统阶段、本轮美术素材计划、首版交付范围和系统边界。
- 参考资料只能进入 `references/`，运行时素材必须进入 `assets/` 或 `addons/`。

## 美术方向

- 当前锁定风格：{args.art_style}
- 选中风格候选图：{args.style_candidate}
- 素材落地状态：{args.runtime_art_status}
- 默认素材路径：`assets/generated/`、`assets/sprites/`、`assets/ui/`。
- 风格候选图只作为参考或种子；首版开发必须生成、切分或接入当前主题的同源运行时素材包，不能只登记候选图路径。
- 风格指南：`docs/project/art/style-guide.md` 必须记录色板、线条、材质、角色比例、怪物轮廓、UI 形状语言和 VFX 气质。
- 概念图裁剪块、`style_candidates/` 候选图、`references/` 参考图和临时 workspace 文件不得直接作为运行时素材。

## 首版范围

## 首版内容单元

{content_unit_lines}

## 首版基础闭环

- [ ] 一个可交互场景。
- [ ] 一个核心操作。
- [ ] 一个清晰反馈。
- [ ] 一个成功条件、失败条件和重开流程。

## 本轮美术素材计划

{runtime_art_plan_lines}

## 完整首版必做

- [ ] 默认至少 3 个精细内容单元、挑战或系统阶段，写清每个单元的目标和差异。
- [ ] 30 秒内有阶段变化、奖励诱惑、威胁升级或目标转折。
- [ ] 有结算反馈：胜利、失败、本轮表现、下一步。
- [ ] 有简单进度：当前内容单元、完成状态、最佳成绩或下一关。
- [ ] 本轮 1-3 类最高收益素材完成规格、落地路径和运行时接入。
- [ ] HUD、角色、威胁/目标、场景和 VFX 来自同一视觉规范和运行时素材包。
- [ ] 动态品类有关键角色动画证据。
- [ ] AI 自动试玩、玩法语义审查和体验结构审查通过。

## 后续增强

- [ ] 扩展到 4-5 个内容单元。
- [ ] 更完整的角色、背景、UI 和音效。

## 系统边界

- [ ] 启用系统：{args.systems or "待从用户确认稿中提炼。"}
- [ ] 分阶段实现：{args.deferred_systems or "按玩法目标和验收风险拆分，不默认排除背包、经济、联网、账号、排行榜或关卡编辑器。"}
- [ ] 新增系统必须写清玩家价值、职责边界、数据归属、UI/素材需求和验证方式。

## 验收标准

- `python scripts/gameplay_logic_review.py` 通过。
- `python scripts/art_pipeline_review.py` 通过。
- `python scripts/experience_design_review.py` 通过。
- `python scripts/export_web.py --json` 通过。
- `python scripts/experience_check.py --strict` 通过。
- `python scripts/ai_review.py --strict` 通过。
- 浏览器中能完成一轮开始、操作、反馈、结束和重开。
"""


def _build_project_concept(args: argparse.Namespace, concept_id: str) -> str:
    source = getattr(args, "source_doc", "") or "未提供长设定"
    extracted = getattr(args, "extracted_doc", "") or "未单独保存"
    return f"""# 当前游戏事实源

## 概念ID

- `{concept_id}`

## 一句话目标

- {args.goal}

## 设定来源

- 用户原始输入：`{source}`
- AI 提炼稿：`{extracted}`
- 兼容事实源：`docs/game-concept.md`

## 平台与目标层级

- 平台：{args.platform}
- 目标层级：{args.level}

## 核心玩法

- 核心操作：{args.core_action}
- 立即反馈：{args.feedback}
- 一轮结束：{args.end_condition}
- 玩法不变量：{args.invariant}

## 玩法蓝图

{_bullet_lines(args.blueprints.replace(",", "；"), "custom")}

## 详细文档索引

- 玩法总览：`docs/project/gameplay/README.md`
- 内容单元：`docs/project/gameplay/content-units.md`
- 数值与平衡：`docs/project/gameplay/balance.md`
- 系统文档：`docs/project/gameplay/systems/`
- 美术方向：`docs/project/art/art-direction.md`
- 风格指南：`docs/project/art/style-guide.md`
- UI/HUD：`docs/project/ui/hud-spec.md`

## 首版边界

- 默认先完成至少 3 个有差异内容单元、挑战或系统阶段。
- 基础闭环只作为首版的一部分，不作为真实游戏交付目标。
- 复杂系统必须拆到独立系统文档；开发需求写入 `.pm/`。
"""


def _build_project_readme(concept_id: str) -> str:
    return f"""# 当前游戏项目文档

这里保存当前游戏本身的长期设定。AI 开发玩法、内容、美术和 UI 时优先读取本目录，而不是直接读取脚手架流程文档。

## 当前概念

- 概念ID：`{concept_id}`
- 事实源：`game-concept.md`

## 推荐读取顺序

1. `game-concept.md`：当前游戏事实源摘要和详细文档索引。
2. `gameplay/README.md`：核心循环、首版范围和启用系统。
3. `gameplay/systems/`：按系统拆分的规则。
4. `gameplay/content-units.md`：首版 3 个内容单元和差异。
5. `art/art-direction.md`、`art/style-guide.md`、`ui/hud-spec.md`：美术和 UI 约束。

## 写入规则

- 稳定游戏设定写入本目录。
- 用户原始长设定保存在 `docs/design-inputs/<concept-id>/source.md`，多轮补充保存为 `source-002.md`、`source-003.md`。
- AI 提炼稿保存在 `docs/design-inputs/<concept-id>/extracted.md`。
- 开发过程、任务状态和临时推演写入 `.pm/`，不要污染本目录。
- 系统变多时，每个系统单独成文档；不要把技能、背包、敌人、经济和成长全部塞到一个文件。
- 创建全新游戏概念时，旧的 `docs/project/` 会归档到 `docs/concepts/<timestamp>-project/`，再生成干净的新项目文档，避免旧系统污染新游戏。
"""


def _build_gameplay_overview(args: argparse.Namespace) -> str:
    systems = _bullet_lines(args.systems, "待从用户确认稿中提炼。")
    deferred = _bullet_lines(args.deferred_systems, "按玩法目标和验收风险分阶段实现；不默认排除背包、经济、联网、账号、排行榜或关卡编辑器。")
    return f"""# 玩法总览

## 核心循环

- 玩家通过“{args.core_action}”推进目标。
- 操作后立刻获得反馈：{args.feedback}
- 一轮结束：{args.end_condition}

## 首版范围

- 目标层级：{args.level}
- 首版默认至少 3 个有差异内容单元、挑战或系统阶段。
- 先保证第 1 个内容单元完整可玩，再扩展后续内容单元、系统阶段或挑战差异。

## 启用系统

{systems}

## 系统边界

{deferred}

## 详细文档

- 内容单元：`content-units.md`
- 数值：`balance.md`
- 系统：`systems/`
"""


def _build_content_units(args: argparse.Namespace) -> str:
    content_units_value = args.content_units
    items = _split_items(content_units_value)
    fallback = "教学核心操作、改变布局/目标组合/节奏、加入阶段压力或失败压力。"
    return f"""# 内容单元

新游戏首版默认包含至少 3 个有差异的关卡、章节、波次、挑战或系统阶段。每个内容单元必须写清目标、差异、压力来源和素材需求。

{_numbered_sections(items, fallback)}
"""


def _build_art_direction(args: argparse.Namespace) -> str:
    return f"""# 美术方向

## 当前锁定风格

- {args.art_style}

## 风格候选

- 选中风格候选图：{args.style_candidate}
- 素材落地状态：{args.runtime_art_status}

## 素材计划

{_bullet_lines(args.runtime_art_plan, "优先生成或接入玩家、主要威胁/目标、场地、核心 UI/VFX 中最高收益的 1-3 类素材。")}

## 运行时素材要求

- 风格候选图不等于运行时素材。
- HUD、角色、威胁/目标、场景和 VFX 必须服从同一视觉规范。
- 运行时素材必须放入 `assets/` 或 `addons/`。
- `references/` 只能放参考资料，不允许被运行时代码直接加载。
"""


def _build_style_guide(args: argparse.Namespace, concept_id: str) -> str:
    blueprints = args.blueprints.replace(",", "、") if args.blueprints else "custom"
    systems = "、".join(_split_items(args.systems)) if _split_items(args.systems) else "核心玩法系统"
    return f"""# 风格指南

## 概念ID

- `{concept_id}`

## 风格锚点

- 当前锁定风格：{args.art_style}
- 选中风格候选图：{args.style_candidate}
- 素材落地状态：{args.runtime_art_status}

## 色板

- 主色：围绕“{args.art_style}”选择 2-3 个高识别主色，优先保证玩家、目标和危险区域可读。
- 辅色：用于场景层次、次要按钮、低优先级状态，不抢主角和目标。
- 警示色/奖励色：警示色只用于威胁、受击、失败压力；奖励色只用于收益、升级、稀有掉落或正反馈。

## 线条与材质

- 线条：同一角色、敌人、UI 图标使用一致描边粗细；小屏下轮廓优先于细节。
- 材质：所有运行时素材服从“{args.art_style}”的主材质语言，不混用写实、像素、厚涂、扁平等冲突材质。
- 阴影：角色、威胁/目标、场景交互物使用同一阴影方向和接触阴影强度。

## 角色比例

- 玩家：围绕核心操作“{args.core_action}”设计最清晰的动作轮廓，尺寸和对比度高于普通场景物。
- 威胁/目标：围绕反馈“{args.feedback}”设计危险或目标标记，与玩家保持可区分体型、轮廓或色彩。
- 道具/奖励：尺寸不小于玩家可读阈值，拾取/获得反馈与奖励色一致。

## 场景规则

- 场地/背景：背景低对比，交互物高对比；装饰元素不得抢玩家、威胁/目标和 UI 的视觉优先级。
- 内容单元差异：围绕首版内容单元或系统阶段，用色彩、布局、地标、UI 状态或反馈强度体现变化。

## UI 形状语言

- HUD：服务“{args.end_condition}”，优先显示目标、资源/状态、风险和下一步；图标描边与角色素材一致。
- 按钮/面板：按钮、面板、状态徽章使用同一边框、圆角、材质和按下/禁用状态。
- 结算：胜利、失败、本轮表现和下一步入口有明确层级，不使用工程说明文案。

## VFX 气质

- 命中/拾取：粒子形状、颜色和持续时间与 UI 奖励/警示色一致。
- 受击/失败：闪白、震屏、碎裂、消散或警示反馈只服务玩家可读性，不遮挡核心操作。
- 奖励/升级：光效、浮字和音画节奏与奖励色一致，强度高于普通拾取。

## 运行时素材包

- 玩家素材：按“{args.art_style}”生成或接入到 `assets/sprites/`，动态品类提供关键动作帧。
- 威胁/目标素材：覆盖当前蓝图 `{blueprints}` 的主要压力或目标，接入到 `assets/sprites/` 或 `assets/generated/runtime/`。
- 场景素材：覆盖首版内容单元或系统阶段差异，接入到 `assets/generated/runtime/` 或 `assets/sprites/`。
- UI 素材：覆盖系统 `{systems}` 的 HUD 图标、面板、按钮、状态或结算，接入到 `assets/ui/`。
- VFX 素材：命中、拾取、受击、奖励或升级反馈可程序化实现或接入 `addons/`，但视觉语言必须统一。

## 禁止事项

- 不得把概念图裁剪块、`style_candidates/` 候选图、`references/` 参考图或临时 workspace 文件直接作为运行时素材。
- HUD、角色、威胁/目标、场景和 VFX 不得各自使用冲突的材质、描边、色彩或比例。
"""


def _build_hud_spec(args: argparse.Namespace) -> str:
    return f"""# UI 与 HUD

## HUD 信息

- 目标：显示当前内容单元目标和玩家下一步。
- 反馈：显示得分、状态、倒计时、生命、资源或当前系统关键状态。
- 结算：显示胜利、失败、本轮表现和重开/下一关入口。

## UI 素材

- 真实首版至少接入 HUD 图标、按钮、面板、进度条或状态徽章之一。
- 没有 UI 源图时，AI 生成 UI sheet 或独立 UI sprite 后放入 `assets/ui/`。
- UI 必须遵循当前风格指南，不能和角色、怪物、场景使用割裂的材质、描边、色彩或比例。

## 验收

- 浏览器内能清楚看到目标、反馈、结算和下一步。
- UI 文案服务玩法，不解释工程结构。
"""


def _build_systems_readme(args: argparse.Namespace) -> str:
    current_systems = _bullet_lines(args.systems, "待创建新游戏后写入。")
    return f"""# 系统文档

每个系统单独成文档，避免 AI 在内容丰富后顾此失彼。

## 当前系统

{current_systems}

## 系统文档模板

```markdown
# 系统名称

## 目标
这个系统为玩家提供什么决策或体验。

## 首版范围
本版只做什么。

## 规则
具体规则。

## 数据
字段、数值范围、冷却、消耗、掉落或成长。

## 交互
和其他系统、HUD、美术、音效、存档的关系。

## 暂缓
以后可能做但本版不做。

## 验收
怎样证明它实现了。
```
"""


def _write_system_docs(args: argparse.Namespace) -> list[str]:
    written: list[str] = []
    for name in _split_items(args.systems):
        path = PROJECT_DOC_DIR / "gameplay" / "systems" / _system_filename(name)
        _write(
            path,
            f"""# {name}

## 目标

- 待在首版确认稿或开发需求中细化。

## 首版范围

- 首版只实现支撑核心循环的最小规则。

## 规则

- 待写入。

## 数据

- 待写入。

## 交互

- 与核心玩法、HUD、美术、音效和存档的关系待写入。

## 系统边界

- 说明本系统与核心循环、其他系统、HUD、素材和存档的关系。

## 验收

- 系统规则能在浏览器内通过一轮试玩验证。
""",
        )
        written.append(path.relative_to(PROJECT_ROOT).as_posix())
    return written


def _write_project_docs(args: argparse.Namespace, concept_id: str) -> list[str]:
    paths = [
        (PROJECT_DOC_DIR / "README.md", _build_project_readme(concept_id)),
        (PROJECT_DOC_DIR / "game-concept.md", _build_project_concept(args, concept_id)),
        (PROJECT_DOC_DIR / "gameplay" / "README.md", _build_gameplay_overview(args)),
        (PROJECT_DOC_DIR / "gameplay" / "content-units.md", _build_content_units(args)),
        (PROJECT_DOC_DIR / "gameplay" / "balance.md", "# 数值与平衡\n\n- 待首版实现或调参后沉淀。\n"),
        (PROJECT_DOC_DIR / "gameplay" / "systems" / "README.md", _build_systems_readme(args)),
        (PROJECT_DOC_DIR / "art" / "art-direction.md", _build_art_direction(args)),
        (PROJECT_DOC_DIR / "art" / "style-guide.md", _build_style_guide(args, concept_id)),
        (PROJECT_DOC_DIR / "ui" / "hud-spec.md", _build_hud_spec(args)),
    ]
    written: list[str] = []
    for path, text in paths:
        _write(path, text)
        written.append(path.relative_to(PROJECT_ROOT).as_posix())
    written.extend(_write_system_docs(args))
    return written


def _write_required_style_guide(args: argparse.Namespace, concept_id: str) -> list[str]:
    path = PROJECT_DOC_DIR / "art" / "style-guide.md"
    _write(path, _build_style_guide(args, concept_id))
    return [path.relative_to(PROJECT_ROOT).as_posix()]


def main() -> int:
    parser = argparse.ArgumentParser(description="创建新的游戏设定卡")
    parser.add_argument("--goal", required=True)
    parser.add_argument("--platform", default="浏览器 Web")
    parser.add_argument("--level", default="完整游戏首版")
    parser.add_argument("--art-style", required=True)
    parser.add_argument("--style-candidate", default="未选择")
    parser.add_argument("--runtime-art-status", default="待生成运行时素材")
    parser.add_argument(
        "--content-units",
        default="",
        help="首版内容单元目标；多条可用分号或换行分隔，默认至少 3 个",
    )
    parser.add_argument(
        "--runtime-art-plan",
        default="优先生成或接入玩家、主要威胁/目标、场地、核心 UI/VFX 中最高收益的 1-3 类素材。",
        help="本轮美术素材计划；多条可用分号或换行分隔",
    )
    parser.add_argument("--blueprints", default="", help="逗号分隔的玩法蓝图 ID，例如 roguelite,inventory_backpack")
    parser.add_argument("--core-action", required=True)
    parser.add_argument("--feedback", required=True)
    parser.add_argument("--end-condition", required=True)
    parser.add_argument("--invariant", required=True)
    parser.add_argument("--source-file", default="", help="用户原始长设定文件；会原样保存到 docs/design-inputs/<concept-id>/source.md")
    parser.add_argument("--source-text", default="", help="用户原始长设定文本；适合短输入")
    parser.add_argument("--extracted-file", default="", help="AI 提炼稿文件；会保存到 docs/design-inputs/<concept-id>/extracted.md")
    parser.add_argument("--extracted-text", default="", help="AI 提炼稿文本；适合短输入")
    parser.add_argument("--source-doc", default="", help="已保存的用户原始设定路径；只链接，不重写")
    parser.add_argument("--extracted-doc", default="", help="已保存的 AI 提炼稿路径；只链接，不重写")
    parser.add_argument("--systems", default="", help="首版启用系统；多条可用分号或换行分隔")
    parser.add_argument("--deferred-systems", default="", help="分阶段系统边界；多条可用分号或换行分隔")
    parser.add_argument(
        "--skip-project-docs",
        action="store_true",
        help="跳过大部分 docs/project 文档；仍会写入必需的 art/style-guide.md，兼容特殊旧流程",
    )
    parser.add_argument("--concept-id", default="")
    args = parser.parse_args()

    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    concept_id = args.concept_id or f"{timestamp}-{_slug(args.goal)}"
    source_doc, extracted_doc = _save_design_inputs(args, concept_id)
    args.source_doc = source_doc
    args.extracted_doc = extracted_doc
    archived = _archive_current(timestamp)
    archived_project = None if args.skip_project_docs else _archive_project_docs(timestamp)
    CONCEPT_FILE.write_text(_build(args, concept_id), encoding="utf-8")
    project_docs = (
        _write_required_style_guide(args, concept_id)
        if args.skip_project_docs else _write_project_docs(args, concept_id)
    )
    if archived:
        print(f"[OK] 已归档上一版概念：{archived.relative_to(PROJECT_ROOT).as_posix()}")
    if archived_project:
        print(f"[OK] 已归档上一版项目文档：{archived_project.relative_to(PROJECT_ROOT).as_posix()}")
    print(f"[OK] 已创建新概念：{concept_id}")
    if source_doc:
        print(f"[OK] 已保存原始设定：{source_doc}")
    if extracted_doc:
        print(f"[OK] 已保存 AI 提炼稿：{extracted_doc}")
    if project_docs:
        print("[OK] 已更新项目文档：")
        for path in project_docs:
            print(f"  - {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
