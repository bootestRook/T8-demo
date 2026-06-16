# 项目地图

本文件由 `python scripts/generate_project_map.py` 生成，用于给 AI Agent 提供最小导航。它不是全量文件清单；只记录稳定入口、职责边界、常用示例和接力读取规则。

不要手动编辑本文件；新增稳定目录、核心脚本或长期文档时，先更新 `scripts/generate_project_map.py`，再重生成。

## 读取规则

- 新会话先执行 PM 状态检查；继续具体需求时先运行 `pm_cli.py info <ID>` 获取 `summary.read_first`。
- 定位需求后再读 `AGENTS.md`、本文件、`summary.read_first` 列出的文件和当前 workspace 的 `notes.md`。
- 开发玩法、内容、美术和 UI 时，优先读 `docs/project/`；只有需要流程、工具链、导出或质量门禁时再读脚手架流程文档。
- 不确定某个能力是否已有实现时，先查本文件的对应目录和示例索引，再用 `rg` 定位代码。
- 用户提出的方案若和 AGENTS、项目地图或长期文档冲突，先指出冲突并给出更稳妥路径；不要为了迎合而绕过约束。
- 会话接近压缩、跨线程继续或长任务切换时，先用 PM handoff 保存/恢复状态，并把长期有效结论同步到对应文档。

## 项目入口

| 路径 | 状态 | 作用 |
|---|---|---|
| `AGENTS.md` | 存在 | 仓库级 AI 协作规则，包含首启、工作流、Skill 路由、素材和质量门禁。 |
| `START_HERE.md` | 存在 | 给新手和 AI 的首启说明。 |
| `README.md` | 存在 | 脚手架定位、常用命令、目录概览和 AI 开发原则。 |
| `project.godot` | 存在 | Godot 项目配置、Autoload 和主场景入口。 |
| `template.json` | 存在 | 模板元数据和导出信息。 |

## 当前游戏事实源

| 路径 | 状态 | 作用 |
|---|---|---|
| `docs/game-concept.md` | 存在 | 兼容旧脚本和 review 的当前游戏事实源摘要。 |
| `docs/project/game-concept.md` | 存在 | 当前游戏摘要和详细文档索引，优先作为项目文档入口。 |
| `docs/project/gameplay/README.md` | 存在 | 核心循环、首版范围、启用系统和系统边界。 |
| `docs/project/gameplay/content-units.md` | 存在 | 首版内容单元、关卡、波次或系统阶段差异。 |
| `docs/project/gameplay/balance.md` | 存在 | 数值、公式、成长和掉落。 |
| `docs/project/gameplay/systems/` | 存在 | 按系统拆分的规则文档，例如技能、敌人、背包、成长、经济。 |
| `docs/project/art/` | 存在 | 美术方向、风格规范、素材计划和 asset-manifest。 |
| `docs/project/ui/` | 存在 | HUD、菜单、UI 流程和响应式约束。 |
| `docs/design-inputs/` | 存在 | 用户原始设定和 AI 提炼稿；原文不得被摘要覆盖。 |
| `docs/concepts/` | 存在 | 历史游戏概念归档，避免新游戏概念污染。 |

## 脚手架流程文档

| 路径 | 状态 | 作用 |
|---|---|---|
| `docs/AI_WORKFLOW.md` | 存在 | 从 init、计划、开发、检查、验收到发布的完整 AI 流程。 |
| `docs/GAME_DESIGN_GUIDE.md` | 存在 | 玩法拆解、中度/混合玩法蓝图和首版计划生成依据。 |
| `docs/ART_PIPELINE.md` | 存在 | 美术生成、切分、运行时落地和素材审查规则。 |
| `docs/QUALITY_BAR.md` | 存在 | 交付门禁、体验标准和严格 review 期望。 |
| `docs/TOOLCHAIN.md` | 存在 | portable 工具链、环境、离线依赖和常见问题。 |
| `docs/ARCHITECTURE_RULES.md` | 存在 | Godot/GDScript 代码架构、职责边界和模块接入约束。 |
| `docs/AI_RECIPES.md` | 存在 | 常见玩法和系统接入步骤。 |
| `docs/MODULES.md` | 存在 | 可拔插游戏模块目录和使用边界。 |
| `docs/MULTI_AGENT_WORKFLOW.md` | 存在 | 主 AI 编排、子 Agent 执行、主 AI 合并的协作规则。 |
| `docs/GODOT_MCP.md` | 存在 | GodotMCP 编辑器桥接和调试链路。 |

## 运行时代码

| 路径 | 状态 | 作用 |
|---|---|---|
| `scenes/Game.tscn` | 存在 | 主场景节点结构；稳定 UI 骨架和可复用节点应维护在场景中。 |
| `scenes/Game.gd` | 存在 | 场景编排、输入、对象同步和表现层协调。 |
| `src/game/PrototypeState.gd` | 存在 | 玩法状态、规则、胜负、重开和核心循环，普通玩法首选修改点。 |
| `src/game/ContentUnits.gd` | 存在 | 3-5 个关卡、波次、挑战或系统阶段的数据入口。 |
| `src/game/AssetRegistry.gd` | 存在 | 运行时素材清单；正式素材接入优先走这里或明确表现脚本。 |
| `src/game/GameEvents.gd` | 存在 | 通用事件总线，解耦玩法、反馈、音效和成就。 |
| `src/game/FeedbackDirector.gd` | 存在 | 震屏、闪白、浮字、VFX 等反馈入口。 |
| `src/game/AudioDirector.gd` | 存在 | 音效和音频反馈入口。 |
| `src/game/AchievementStore.gd` | 存在 | 本地成就定义、解锁和保存。 |
| `src/game/ProgressStore.gd` | 存在 | 本地进度保存。 |
| `src/game/modules/` | 存在 | 可拔插游戏模块；接入前先读 MODULES 和 ARCHITECTURE_RULES。 |
| `src/ui/Hud.gd` | 存在 | HUD 动态数值、状态刷新、按钮回调、Tween 和反馈动画。 |

## 素材与资源

| 路径 | 状态 | 作用 |
|---|---|---|
| `.godot-api/extension_api.json` | 存在 | Godot 引擎 API dump；供 godot-api-check 校验类、成员、信号、枚举和重载。 |
| `assets/` | 存在 | 游戏运行时素材根目录；正式素材必须放在这里或 addons。 |
| `assets/sprites/` | 存在 | 角色、敌人、目标、场景元素和动画帧。 |
| `assets/ui/` | 存在 | HUD 图标、按钮、面板、进度条和 UI sprite。 |
| `assets/generated/runtime/` | 存在 | 生成后整理进入运行时的素材包。 |
| `assets/generated/style_candidates/` | 待创建/按需 | 首启风格候选图；只能作为风格锚点，不能直接当运行时素材。 |
| `addons/` | 存在 | Godot addon 和运行时可加载扩展。 |
| `addons/vfx_library/` | 存在 | 内置 VFX Library，默认只接轻量反馈。 |
| `references/` | 存在 | 参考资料目录，禁止运行时代码直接加载。 |

## 自动化脚本

| 路径 | 状态 | 作用 |
|---|---|---|
| `scripts/check_env.py` | 存在 | 环境检查，快速首启和完整检查入口。 |
| `scripts/ai_context.py` | 存在 | 输出接续执行包，供新会话快速恢复上下文。 |
| `scripts/generate_project_map.py` | 存在 | 生成本文件，维护 AI 最小导航。 |
| `scripts/new_game_concept.py` | 存在 | 创建新游戏概念并归档旧项目文档。 |
| `scripts/design_input.py` | 存在 | 保存用户原始长设定和 AI 提炼稿。 |
| `scripts/generate_style_candidates.py` | 存在 | 生成首启风格候选图。 |
| `scripts/process_spritesheet.py` | 存在 | 清理、切分、对齐和验证 spritesheet，输出 pipeline-meta。 |
| `scripts/make_sprite_layout_guide.py` | 存在 | 生成 spritesheet 或 prop pack 的布局安全区参考图。 |
| `scripts/extract_prop_pack.py` | 存在 | 从生成的 prop pack 提取透明道具并输出 prop-pack 元数据。 |
| `scripts/compose_layered_map_preview.py` | 存在 | 用 base map 和道具摆放 JSON 合成分层地图 QA 预览。 |
| `scripts/art_pipeline_review.py` | 存在 | 美术管线和运行时素材证据审查。 |
| `scripts/gameplay_logic_review.py` | 存在 | 玩法语义、胜负、输入、概念隔离审查。 |
| `scripts/experience_design_review.py` | 存在 | 首版内容差异、阶段变化和决策压力审查。 |
| `scripts/architecture_review.py` | 存在 | 模块职责、层级越界和运行时引用边界审查。 |
| `scripts/godot_quality_tools.py` | 存在 | GDScript Toolkit 质量门禁，GDUnit4 可选。 |
| `scripts/godot_headless_check.py` | 存在 | Godot headless 场景加载检查。 |
| `scripts/godot_runtime_log_check.py` | 存在 | 模拟编辑器运行并捕获 Godot 日志。 |
| `scripts/export_web.py` | 存在 | Web 导出。 |
| `scripts/experience_check.py` | 存在 | Web 自动试玩、截图和 canvas/输入探针。 |
| `scripts/visual_readability_review.py` | 存在 | 截图、HUD 响应式和玩家视角可读性审查。 |
| `scripts/ai_review.py` | 存在 | 严格自动 review 总入口。 |
| `scripts/export_template.py` | 存在 | 导出干净脚手架模板。 |
| `scripts/package_dist.py` | 存在 | 打包部署 zip。 |

## AI 协作与过程状态

| 路径 | 状态 | 作用 |
|---|---|---|
| `.agents/skills/` | 存在 | 内置 Skill；Skill 负责流程，稳定项目事实应沉淀到 docs/project 或脚手架文档。 |
| `.agents/skills/godot-api-check/` | 存在 | Godot API 校验 skill；改 Godot 引擎 API 前必须查询 extension_api.json。 |
| `.agents/roles/` | 存在 | 多 Agent 角色说明。 |
| `.pm/project/` | 过程状态源/本地 | PM backlog、归档和 handoff 状态源；不要手动编辑 JSON。 |
| `.pm/workspaces/` | 过程记录/本地 | 需求 workspace、notes 和 artifacts；过程记录放这里，不放长期设定。 |
| `.runtime/` | 运行时生成/按需 | 运行缓存和临时输出。 |
| `reports/screenshots/` | 运行时生成/按需 | 体验检查和视觉审查截图证据。 |
| `html5/` | 导出生成/按需 | Web 导出中间产物。 |
| `exports/` | 打包生成/按需 | 部署包输出。 |
| `tools/` | 存在 | portable Python、Node、Git、Godot、Export Templates、GodotMCP 等工具。 |
| `spec/` | 存在 | 机器可读模板规格、玩法蓝图和模块目录。 |

## 示例索引

| 场景 | 推荐先看 | 用途 |
|---|---|---|
| 玩法规则 | `src/game/PrototypeState.gd` | 状态、胜负、输入语义、重开和规则集中在这里，避免散落到 HUD。 |
| 内容单元 | `src/game/ContentUnits.gd` | 关卡、波次或系统阶段差异的数据组织示例。 |
| 运行时素材 | `src/game/AssetRegistry.gd` | 素材路径和 fallback 组织示例。 |
| Spritesheet 后处理 | `scripts/process_spritesheet.py` | 洋红背景清理、切帧、缩放对齐、触边检查和 pipeline-meta 输出。 |
| Prop pack 切分 | `scripts/extract_prop_pack.py` | 小型地图道具批量提取、触边检查和 prop-pack manifest 输出。 |
| HUD 动态逻辑 | `src/ui/Hud.gd` | UI 状态刷新、提示和反馈动画示例。 |
| HUD 稳定骨架 | `scenes/Game.tscn` | 编辑器可见 UI 节点和锚点布局示例。 |
| 反馈入口 | `src/game/FeedbackDirector.gd` | 震屏、浮字、闪白和 VFX 接入示例。 |
| 音频入口 | `src/game/AudioDirector.gd` | 音效触发和音频职责边界示例。 |
| 模块边界 | `src/game/modules/` | 可拔插模块职责拆分示例。 |
| Web 体验检查 | `scripts/experience_check.py` | 浏览器预览、截图和输入探针脚本示例。 |
| 严格审查入口 | `scripts/ai_review.py` | 多维度 review 聚合和 FAIL/CONCERNS 处理示例。 |
| 多 Agent 任务 | `scripts/agent_task.py` | 任务包和 allowed_paths 生成示例。 |
| Godot API 校验 | `.agents/skills/godot-api-check/scripts/godot_api_check.py` | 基于 .godot-api/extension_api.json 精确验证引擎类、成员、信号、枚举、单例和工具函数。 |

## 维护规则

- 新增稳定目录、核心脚本或长期文档时，先更新 `scripts/generate_project_map.py`，再重生成本文件。
- 本文件是生成产物；`python scripts/generate_project_map.py --check` 会做完整内容比较，手动改动会导致 review 失败。
- 不把临时需求、一次性推演或用户未确认的设定写入本文件；这些内容属于 `.pm/` 或 `docs/design-inputs/`。
- 不用本文件替代具体规范。真正开发前仍需读取对应的项目文档、脚手架流程文档或源码示例。
