# Godot V1 Plus AI 协作指南

## 目标

这个仓库是纯 AI 驱动的 Godot 4 中小型 2D 游戏脚手架。用户只需要用自然语言和 OpenCode、Codex、Claude Code 等工具协作，AI 负责从立项、玩法、美术、素材、开发、测试、反馈、迭代到 Web 部署的完整闭环。

## 总原则

- 始终使用简体中文回复。
- 默认目标是可试玩完整游戏首版：围绕用户创意落实核心循环、必要系统、主题化运行时素材、反馈、结算和本地进度。只做技术验证必须由用户明确要求，不能作为真实游戏交付目标。
- 遵循 KISS、DRY、SOLID；可以按游戏目标扩展背包、经济、联网、关卡编辑器等系统，但必须有清晰职责、玩家价值、验收标准和运行时证据。
- 如果用户没有主动要求，不要计划或执行 `git commit`、`git push`、分支操作。
- 先读后写，先理解当前 Godot 项目结构，再修改文件。
- 运行时素材必须放在 `assets/` 或 `addons/`；`references/` 只放参考资料，不可被游戏运行时代码直接加载。
- AI 默认完成过程 review；人工只参与需求输入、危险操作确认和最终成果验收。
- 依赖优先级：`tools/` portable 工具或压缩包 > 系统 PATH；不再使用 `installers/` 作为首启链路。
- `init.cmd` 是用户首启入口；AI 可运行只写入项目 `tools/` 的解包检查，下载、全局安装或系统配置修改前仍必须先确认。
- Node.js 只作为 AI 工具链依赖内聚到 `tools/node/`；不得把 Node/npm/npx 作为 Godot 游戏运行时依赖。
- GDScript Toolkit 是必选质量门禁；GDUnit4 调整为可选检查。缺失 GDScript Toolkit 时 `check_env.py`、`godot_quality_tools.py` 和 `ai_review.py` 必须失败。联网安装或复制外部 addon 前仍必须先确认。
- GodotMCP 是内置的可选编辑器桥接能力；不作为游戏运行时依赖，默认使用 `tools/godot-mcp-node/` 本地包和当前项目动态路径生成 MCP 配置。下载、`npx` 首次拉包、全局安装或复制外部 addon 前必须先确认。
- 新会话先执行 PM 状态检查；跨线程接力或长任务恢复时，先用 `pm_cli.py info <ID>` 获取 `read_first`，再读 `AGENTS.md`、`docs/project-map.md` 和 `read_first` 文件；不要依赖聊天上下文记住长期约定。
- 如果用户或 AI 的方案和本文件、项目地图、长期项目文档冲突，必须先指出冲突并给出更稳妥路径；不要为了迎合指令绕过仓库约束。

## 首次入口

用户输入 `init`、`初始化`、`第一次使用`、`开始做游戏` 时：

1. 使用 `.agents/skills/project-init/SKILL.md`。
2. 只读检查项目、环境和文档，不直接改玩法代码。
3. 如果 Windows `tools/` 内有 portable 工具包但尚未解包，先运行 `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/bootstrap-cn.ps1 -InitPm -AutoInstallMissing`；该流程会同时执行 `python scripts/setup_ai_mcp.py --apply-project` 生成项目级 AI MCP 配置；再运行 `python scripts/check_env.py --json --fast`。
4. 确认游戏方向、目标层级和平台。
5. 让用户选择 2-3 个美术方向之一；再用 `asset-prompt-spec` 和 `aistudio-media-generation` 生成 3 张风格候选图。
6. 如果用户提供详细设定、系统描述、技能列表、角色设定、世界观、参考游戏或长文本，必须先原样保存到 `docs/design-inputs/<concept-id>/source.md`，再生成 `docs/design-inputs/<concept-id>/extracted.md` 作为 AI 提炼稿。用户可以反复讨论修改；未经用户确认，不得把摘要覆盖为当前事实源，也不得开始开发。
7. 用户确认首版设定并选定风格后，固化玩法、目标层级、平台、风格候选图、首版内容单元目标、首版交付范围和系统边界到 `docs/game-concept.md` 和 `docs/project/`。
   - 全新游戏必须使用新的概念ID；上一版设定归档到 `docs/concepts/`，避免概念污染。
   - 中度或混合玩法必须写入 `玩法蓝图`，蓝图来源见 `docs/GAME_DESIGN_GUIDE.md` 和 `spec/gameplay_blueprints.json`。
8. 使用 `docs/GAME_DESIGN_GUIDE.md` 生成完整首版计划，并同步列出本轮美术素材落地计划。
9. 初始化或接续 `.pm/` 工作流。

## 工作流

AI 每轮按这个顺序推进：

1. `init`：确认玩法、目标层级、平台，生成并锁定美术风格候选。
2. `plan`：用 `.pm/` 创建或接续需求，同时列出本轮玩法内容和美术内容。
3. `art-spec`：明确本轮 1-3 类素材规格：用途、尺寸、透明背景、帧数、落地路径。
4. `asset`：生成、提取或切分素材，放入 `assets/`，必要时登记 `AssetRegistry.gd`。
5. `sprite-process`：对 spritesheet、UI sheet 或外部 PNG 做切图、去背景、裁边、统一命名和尺寸，输出到 `assets/sprites/` 或 `assets/ui/`。
6. `runtime-bind`：接入玩法、系统、UI、动画帧和 VFX，正式素材必须由 `AssetRegistry.gd`、`Hud.gd`、表现脚本或场景资源真实加载。
7. `visual-proof`：运行预览保留截图，确认素材在玩家视角可见，并更新 `docs/project/art/asset-manifest.json`。
8. `do`：优先改最小文件集，直接推进有差异内容单元的完整首版；基础闭环是首版的一部分，不单独交付。
9. `check`：运行玩法、美术管线、Godot、Web 导出和体验检查。
10. `review`：运行 `python scripts/ai_review.py --strict`，AI 自行处理 FAIL/CONCERNS。
11. `accept`：只把试玩地址或部署包交给人工做成果验收。
12. `feedback`：把试玩反馈分类，下一轮只修 1-3 个最高优先级问题。
13. `ship`：打包 Web zip，交付浏览器部署版本。

详细流程见 `docs/AI_WORKFLOW.md`。

## 多 Agent 协作

- 支持“主 AI 编排，子 Agent 执行，主 AI 合并”的协作模式，详见 `docs/MULTI_AGENT_WORKFLOW.md`。
- 主 AI 是唯一 PM 状态写入者、冲突裁决者和最终合并者；子 Agent 只处理任务包限定范围。
- 子 Agent 角色说明放在 `.agents/roles/`，任务包模板见 `docs/templates/agent-task.md`。
- 多 Agent 第一版不自动启动外部 AI CLI，不让多个 Agent 同时直接抢主工作区；结果由主 AI 串行合并并运行 `python scripts/ai_review.py --strict`。

## 首版内容规则

- 基础闭环用于证明目标、操作、反馈、胜负/重开和 Web 运行链路成立；真实游戏默认必须继续推进到完整首版。
- 完整首版默认包含至少 3 个精细关卡、章节、波次、挑战或系统阶段；内容单元必须有明确差异，例如空间布局、敌人/目标组合、节奏、数值、奖励、阶段压力、系统组合或失败压力不同。
- 已锁定美术风格时，每个首版内容单元都要有运行时素材落地证据：玩家、主要威胁/目标、场地或背景、核心 UI/VFX 至少覆盖本轮实际玩法。
- 动作、射击、生存、平台、跑酷、搜打撤等动态品类必须有关键角色动画证据；最低要求是首轮 1-2 个动作、每个动作 4-6 帧，或等效的 `AnimatedSprite2D` / `SpriteFrames` 运行时接入。
- 首版必须有 30 秒内可感知变化、结算反馈和玩家决策压力；缺失时 `experience_design_review.py` 在严格门禁中应返回 FAIL。
- 如果媒体服务不可用，可以先做程序化占位，但必须在 `docs/game-concept.md` 写明 `素材落地状态：程序化占位`，并把补美术列为下一轮优先项。

## 统一视觉资产闭环

- 概念图只作为风格锚点，不得直接作为 HUD、角色、怪物、场景或 VFX 的运行时素材。
- 风格候选确认后，必须沉淀 `docs/project/art/style-guide.md` 或等效美术规则，记录色板、线条、材质、角色比例、UI 形状语言、镜头和反馈气质。
- 正式首版必须维护 `docs/project/art/asset-manifest.json`，记录每个运行时素材的 source、prompt/provider、源图、运行时路径、透明背景、接入状态和截图可见性；`procedural`、`placeholder`、`debug` 不能计入正式素材完成。
- spritesheet、动画帧和 prop pack 必须保留后处理元数据：`pipeline-meta.json` 通过 `postprocess_meta` 登记，`prop-pack.json` 通过 `prop_pack_meta` 登记；触边、帧数不一致或坏元数据会阻断美术管线审查。
- 首版开发前必须生成或整理同源运行时视觉包：玩家、主要威胁/目标、场地或背景、HUD/UI、核心 VFX 至少覆盖当前玩法；产物进入 `assets/sprites/`、`assets/ui/`、`assets/generated/runtime/` 或 `addons/`。
- HUD、按钮、面板、图标、进度条、结算界面必须走 `godot-ui` 与 UI 素材流程；没有 UI 设计稿时，AI 先生成 UI sheet 或独立 UI sprite，再接入 `assets/ui/`。
- 只有需要从概念图提取主体、前后景或 UI sprite 时，才允许用 `ui-layer-split` 或 `ui-studio` 处理；输出必须是整理后的 PNG/WebP/atlas 并进入运行时素材目录。
- 禁止把 JPG 概念图裁剪块、`style_candidates/` 候选图、`references/` 参考图或临时 workspace 文件直接接入游戏运行时。
- 美术管线和视觉可读性审查必须检查 HUD、角色、怪物/目标、场景和 VFX 是否来自同一风格规范；风格突兀时按视觉返工处理，不得宣称首版视觉完成。

## 游戏体验反馈优先级

- 当用户反馈“不好玩、看不见、看不懂、没感觉、UI 差、像占位、和概念图差太多、基本玩不了”时，AI 必须停止普通代码小修，先进入体验/视觉返工流程。
- 用户试玩反馈优先级高于 `ai_review.py`、`experience_check.py`、导出成功和像素健康检查；自动检查 PASS 只代表技术链路可用，不代表游戏可交付。
- 涉及画面、UI、角色、敌人、场景、可见性或风格偏差的问题时，必须先运行 Web 预览并获取截图证据，再判断修复方向。
- 没有截图证据，不得宣称视觉、UI、角色/敌人可见性或玩家可读性问题已解决。

## 视觉证据与占位命名

- 视觉/体验类交付前至少保留首屏和运行中截图；若本轮涉及决策弹窗、升级、结算或失败/胜利界面，也必须保留对应截图。
- 截图默认由 `python scripts/experience_check.py --strict` 写入 `reports/screenshots/`，并由 `scripts/visual_readability_review.py` 做基础可读性审查。
- 不得把几何 SVG、代码绘制图形、纯色块 UI、圆形敌人或简单线条图形称为正式美术素材。这类内容必须标注为“程序化占位”或“临时美术”。
- 正式首版素材必须符合已选美术方向，并在玩家视角下具备明确角色、威胁/目标和 UI 辨识度。

## 主要文件

- `project.godot`：Godot 项目配置和 Autoload。
- `scenes/Game.tscn`：主场景。
- `scenes/Game.gd`：场景编排、输入、对象同步。
- `src/game/PrototypeState.gd`：玩法状态和规则，AI 首选修改点。
- `src/ui/Hud.gd`：HUD 显示。
- `src/game/GameEvents.gd`：通用游戏事件总线，解耦玩法、反馈、音效和成就。
- `src/game/AchievementStore.gd`：本地成就定义、解锁和保存。
- `src/game/AssetRegistry.gd`：运行时素材清单。
- `src/game/FeedbackDirector.gd`：震屏、闪白、浮字、VFX 入口。
- `src/game/AudioDirector.gd`：基础音效和音频入口。
- `src/game/ContentUnits.gd`：3-5 个关卡、波次或挑战单元。
- `src/game/ProgressStore.gd`：本地进度保存。
- `docs/project-map.md`：AI 最小导航、目录职责、示例索引和接力读取规则，由 `python scripts/generate_project_map.py` 生成。
- `.agents/skills/`：所有内置 AI skill。
- `.agents/roles/`：多 Agent 主从协作角色说明。
- `addons/vfx_library/`：内置 Godot VFX Library。

## 项目文档分层

- `docs/game-concept.md`：兼容旧脚本和 review 的当前游戏事实源摘要；必须保留核心玩法、蓝图、内容单元、美术计划和验收标准。
- `docs/project/`：当前游戏项目的长期文档。AI 开发玩法、内容、美术和 UI 时优先读取这里。
  - `docs/project/game-concept.md`：当前游戏摘要和详细文档索引。
  - `docs/project/gameplay/README.md`：核心循环、首版范围、启用系统和系统边界。
  - `docs/project/gameplay/systems/`：每个系统单独成文档，例如技能、敌人、背包、成长、经济。
  - `docs/project/gameplay/content-units.md`：首版 3 个内容单元及差异。
  - `docs/project/gameplay/balance.md`：数值、公式、成长和掉落。
  - `docs/project/art/`：美术方向和素材计划。
  - `docs/project/ui/`：HUD、菜单和 UI 流程。
- `docs/design-inputs/<concept-id>/source.md`：用户原始长设定，原样保存，不得被摘要覆盖。
- `docs/design-inputs/<concept-id>/source-002.md` 等：同一概念多轮补充的原始输入，继续原样保存，不覆盖旧原文。
- `docs/design-inputs/<concept-id>/extracted.md`：AI 提炼稿和确认后的首版范围。
- `.pm/`：开发需求、任务和过程记录。不要把 `.pm/` 当作长期游戏设定源。
- `docs/concepts/`：历史游戏概念归档。

信息边界：

- 概念设定回答“这是一个什么游戏”，放在 `docs/design-inputs/` 和 `docs/project/game-concept.md`。
- 游戏系统设定回答“规则是什么”，放在 `docs/project/gameplay/`。
- 开发需求回答“这一轮做什么”，放在 `.pm/`。
- 不要把用户原始长设定、系统细节和开发任务全部塞进 `docs/game-concept.md`。
- 新增稳定目录、核心脚本或长期文档时，先更新 `scripts/generate_project_map.py`，再运行 `python scripts/generate_project_map.py` 重生成 `docs/project-map.md`。

## 上下文接力

- 新会话先执行 PM 状态检查；继续具体需求时使用 `pm_cli.py info <ID>` 获取 `read_first`，并读取 `AGENTS.md`、`docs/project-map.md` 和 `read_first` 列出的文件。
- 会话内容过大、即将压缩、需要换线程或暂停长流程时，使用 `pm handoff save` 保存当前任务、下一步、阻塞、关键产物和必须先读文件；恢复时使用 `pm handoff resume`，不要凭记忆继续。
- 过程记录写入 `.pm/workspaces/<demand>/artifacts/`；变成长期有效的玩法、美术、UI、工具链或架构约定时，及时同步到 `docs/project/` 或脚手架文档。
- Skill 只承载可复用流程、脚本和检查步骤；稳定项目事实、风格、规则和示例索引必须落在项目文档或 `docs/project-map.md`，不要把 Skill 当作第二套知识库。

## Skill 路由

- 首次初始化：`.agents/skills/project-init/SKILL.md`
- 需求管理：`.agents/skills/pm-agile/SKILL.md`
- 创意、功能或行为变更前置方案澄清：`.agents/skills/brainstorming/SKILL.md`（来自 `obra/superpowers`；本仓库规则优先，未经用户主动要求不得 `git commit`，缺少 `writing-plans` 时用 `pm-agile` 接续计划）
- Godot 首版开发与迭代：`.agents/skills/vibe-iteration/SKILL.md`
- 中小型游戏能力：`.agents/skills/godot-medium-game-scaffold/SKILL.md`
- Web 导出：`.agents/skills/godot-export-web/SKILL.md`
- 运行体验检查：`.agents/skills/godot-runtime-preview-check/SKILL.md`
- 浏览器自动化诊断：`.agents/skills/agent-browser/SKILL.md`
- 试玩反馈：`.agents/skills/godot-playtest-report/SKILL.md`
- 手感调优：`.agents/skills/godot-game-feel-tuning/SKILL.md`
- 素材路径检查：`.agents/skills/godot-asset-audit/SKILL.md`
- 图片、角色、背景、图标、精灵生成：先用 `.agents/skills/asset-prompt-spec/SKILL.md`，再用 `.agents/skills/aistudio-media-generation/SKILL.md`
- Godot 原生 UI/HUD/菜单/Theme/响应式布局：`.agents/skills/godot-ui/SKILL.md`
- UI 拆层、抠图：`.agents/skills/ui-layer-split/SKILL.md`
- UI sprite 提取、PSD/PNG UI 处理：`.agents/skills/ui-studio/SKILL.md`
- 精灵切图和动画条：`.agents/skills/godot-sprite-pipeline/SKILL.md`
- Godot API 查询：`.agents/skills/godot-api-lookup/SKILL.md`
- Godot API 精确校验：`.agents/skills/godot-api-check/SKILL.md`
- GodotMCP / MCP 编辑器桥接：`.agents/skills/godot-mcp/SKILL.md`
- 玩法与中度/混合系统拆解：`docs/GAME_DESIGN_GUIDE.md`

## Godot API 铁律

- 凡是 Godot 引擎 API，一律不得凭记忆使用。
- 必须先通过 `godot-api-check` skill 查询 `extension_api.json`。
- 查询不到的 API 一律视为不存在，禁止调用、禁止建议、禁止写入代码。
- 涉及类、内置类型、方法、属性、信号、枚举、枚举值、常量、单例、utility function、operator、constructor 时，都必须查询到确切符号、参数、返回值和约束后再使用。
- 同一轮任务中只有已经查询并留在上下文里的精确符号可以复用；新增符号或新增 overload 必须再次查询。
- 项目自定义类、节点、Autoload、输入动作、资源路径、场景路径、分组和项目设置必须在仓库文件中验证，不得臆造。
- 如果无法完成查询或验证，必须停止并说明阻塞原因，不得用记忆补全。

## 图片生成规则

- 默认使用平台提供的 provider id：`gpt-image-2`。
- 首启风格候选优先使用 `python scripts/generate_style_candidates.py --prompt-file prompt.txt`，由脚本稳定调用媒体 API。
- 直接调用媒体 API 时使用 `.agents/skills/aistudio-media-generation/scripts/media_api.py`；下载文件必须用 `--output downloads --download-dir <目录>`。
- 生成前先明确用途、尺寸、数量、透明背景要求、风格约束和是否需要参考图。
- 静态素材按当前首版系统和内容单元成套规划，优先覆盖玩家、主要威胁/目标、场地、HUD/UI 和核心反馈；动作帧可以小批量生成，每个关键角色首轮 1-2 个动作、每个动作 4-6 帧，避免素材割裂但不能牺牲基本动感。
- 生成结果下载到 `assets/generated/` 或对应运行时目录，再由 `AssetRegistry.gd` 登记并在画面中真实加载。
- 角色、敌人、NPC 和动画道具优先生成矩阵 spritesheet，并用 `python scripts/process_spritesheet.py` 输出透明帧、`sheet-transparent.png`、`animation.gif` 和 `pipeline-meta.json`；小型地图道具 pack 用 `python scripts/extract_prop_pack.py` 提取。
- `assets/generated/style_candidates/` 只放风格候选图；候选图不等于运行时素材。首版开发前必须生成/切分出当前主题运行时素材，或在 `docs/game-concept.md` 明确写入 `素材落地状态：程序化占位`。
- 锁定风格后，HUD、角色、怪物/目标、场景和 VFX 必须来自同一视觉规范；不得由 AI 分别临时绘制导致风格割裂。
- 不把 token、API key 或登录凭证写进仓库。

## UI 规则

- 设计或实现 Godot 原生 UI/HUD/菜单、Control 节点层级、Theme、响应式布局、焦点导航时用 `godot-ui`。
- UI 来源为 PNG/JPG/PSD 设计图、sprite sheet 或需要提取 layout/sprite 时，优先用 `ui-studio`。
- 如果用户没有 UI 设计稿，AI 必须先生成 UI sheet、HUD 图标、按钮或面板素材，再落到 `assets/ui/` 并接入运行时；不得以“没有 PSD/UI 源图”为由跳过 UI 工作流。
- 需要抠图、主体透明 cutout、背景/前景/主体分层时用 `ui-layer-split`。
- 风格候选图不必默认走 `ui-studio` 或 `ui-layer-split`；只有要从候选图拆出 UI sprite、角色主体、前后景层时才使用对应 skill。
- Godot 运行时只使用整理后的 sprite、atlas 或纹理，不直接依赖 UI Studio 的临时工作目录。
- UI 文案服务玩法，不解释工程结构。
- 真实游戏首版未声明程序化占位时，必须有 `assets/ui/` 或 HUD/UI sprite 运行时引用证据；否则美术管线审查应阻断交付。
- 稳定、可视化、编辑器友好的 UI 骨架应维护在 `.tscn` 或独立 UI 场景中，例如 `CanvasLayer`、full rect `Control`、容器布局、关键 `Label` / `ProgressBar` / `Button` / `TextureRect`、默认占位文案和锚点；动态数值、状态刷新、按钮回调、Tween 和反馈动画留在 `Hud.gd` 或对应 UI 脚本。
- 空脚手架默认 HUD 必须让用户在 Godot 编辑器打开主场景时看见清晰的 UI 层级和占位信息；运行时再由脚本替换成当前游戏目标、状态、提示和结算反馈。

## VFX 规则

- 内置 `haowg/GODOT-VFX-LIBRARY` 到 `addons/vfx_library/`，保留 MIT LICENSE。
- 默认只接入轻量反馈：屏幕震动、受击闪白、浮字、命中爆裂、拖尾。
- 环境特效、shader 和演示场景按游戏目标启用；启用时必须服务玩法、可读性或风格一致性。
- 如果需要重新获取上游，网络失败时可使用代理：`socks5://127.0.0.1:10808`。

## 代码约束

- 正常开发优先修改 `PrototypeState.gd`、`Game.gd`、`Hud.gd`。
- 新增模块必须有单一职责。
- 账号、联网、排行榜、背包、经济、关卡编辑器等系统可按用户创意进入首版；新增前写清职责边界、数据归属、UI/素材需求和验收方式。
- 不为临时数值、玩法规则、动态对象或一次性调试内容修改 `.tscn`；但新增稳定 UI 骨架、可复用实体场景、HUD 面板、菜单、结算界面、必要碰撞/相机/容器节点时，应维护 `.tscn`，保持节点职责清晰、命名稳定，并在改后验证场景加载和导出。
- 不使用 `@tool` 脚本写业务逻辑。
- 每轮影响玩法、UI、素材或导出的改动后，至少运行：
  - `python scripts/gameplay_logic_review.py`
  - `python scripts/art_pipeline_review.py`
  - `python scripts/experience_design_review.py`
  - `python scripts/godot_quality_tools.py --json`
  - `python scripts/godot_headless_check.py`
  - `python scripts/godot_runtime_log_check.py`
  - `python scripts/export_web.py --json`
  - `python scripts/experience_check.py --strict`
  - `python scripts/visual_readability_review.py --strict`
  - `python scripts/ai_review.py --strict`

## 命令

- Windows 首启：双击 `init.cmd`，或运行 `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/bootstrap-cn.ps1 -InitPm -AutoInstallMissing`
- 快速首启检查：`python scripts/check_env.py --json --fast`
- 完整环境检查：`python scripts/check_env.py --json`
- GodotMCP 配置生成：`python scripts/setup_godot_mcp.py --provider auto`
- 导出 Godot API dump：`New-Item -ItemType Directory -Force .godot-api; Push-Location .godot-api; godot --headless --dump-extension-api; Pop-Location`
- 查询 Godot API 符号：`python .agents/skills/godot-api-check/scripts/godot_api_check.py class Node`
- AI 客户端项目级 MCP 自动配置：`python scripts/setup_ai_mcp.py --apply-project`
- AI 客户端用户级 MCP 注册（显式确认后）：`python scripts/setup_ai_mcp.py --client codex --apply-user` 或 `python scripts/setup_ai_mcp.py --client claude --apply-user`
- 创建子 Agent 任务包：`python scripts/agent_task.py create --demand-id <ID> --task-id T-01 --role gameplay --goal "..." --allowed-path src/game/PrototypeState.gd`
- 检查子 Agent 任务包：`python scripts/agent_task.py check --manifest <manifest.json>`
- 检查子 Agent patch：`python scripts/agent_merge.py check --manifest <manifest.json> --patch <changes.patch>`
- 质量工具准备：`python scripts/setup_quality_tools.py`
- 质量工具安装（联网下载前需确认）：`python scripts/setup_quality_tools.py --install --yes`
- 可选安装 GDUnit4：`python scripts/setup_quality_tools.py --install-gdunit --yes`
- 质量门禁（GDUnit4 可选）：`python scripts/godot_quality_tools.py --json`
- AI 自动审查：`python scripts/ai_review.py --strict`
- 玩法语义审查：`python scripts/gameplay_logic_review.py`
- 美术管线审查：`python scripts/art_pipeline_review.py`
- 体验结构审查：`python scripts/experience_design_review.py`
- Godot headless 场景加载：`python scripts/godot_headless_check.py`
- Godot 正常运行日志：`python scripts/godot_runtime_log_check.py`
- 新游戏概念隔离：`python scripts/new_game_concept.py --help`
- 保存 init 设定输入：`python scripts/design_input.py --help`
- 生成 spritesheet 布局参考：`python scripts/make_sprite_layout_guide.py --rows 2 --cols 2 --output assets/generated/runtime/player-guide.png`
- 处理 spritesheet：`python scripts/process_spritesheet.py <sheet.png> --rows 2 --cols 2 --out-dir assets/sprites/player/walk --align feet --shared-scale --reject-edge-touch`
- 提取 prop pack：`python scripts/extract_prop_pack.py <sheet.png> --rows 3 --cols 3 --labels rock,shrub,crate --out-dir assets/sprites/props --reject-edge-touch`
- 合成分层地图预览：`python scripts/compose_layered_map_preview.py --base <base.png> --placements <placements.json> --output <preview.png>`
- Web 导出：`python scripts/export_web.py --json`
- 打开预览：`python scripts/run_web_preview.py --open --json`
- 停止预览：`python scripts/stop_web_preview.py`
- 体验检查：`python scripts/experience_check.py --strict`
- 视觉可读性审查：`python scripts/visual_readability_review.py --strict`
- 打包部署：`python scripts/package_dist.py --json`
- 导出模板：`python scripts/export_template.py --dry-run`
- 导出开箱即用模板：`python scripts/export_template.py`
- 导出瘦身模板：`python scripts/export_template.py --no-tools`

如果没有系统 Python，先运行 `init.cmd`，再用 `tools/python/python.exe` 替代上面命令中的 `python`。
