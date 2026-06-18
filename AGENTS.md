# Godot V1 Plus AI 协作指南

## 目标

这个仓库是纯 AI 驱动的 Godot 4 中小型 2D 游戏脚手架。用户只需要用自然语言和 OpenCode、Codex、Claude Code 等工具协作，AI 负责从立项、玩法、美术、素材、开发、测试、反馈、迭代到 Web 部署的完整闭环。

## 总原则

- 始终使用简体中文回复。
- 默认目标是可试玩完整游戏首版：围绕用户创意落实核心循环、必要系统、主题化运行时素材、反馈、结算和本地进度。只做技术验证必须由用户明确要求，不能作为真实游戏交付目标。
- 遵循 KISS、DRY、SOLID；可以按游戏目标扩展背包、经济、联网、关卡编辑器等系统，但必须有清晰职责、玩家价值、验收标准和运行时证据。
- 不得自作主张加入用户没有要求或长期文档未确认的玩法指标、结算字段、统计项、货币、积分、排行榜、奖励、惩罚、入口或解释文案；如认为必要，必须先说明玩家价值和验收方式并得到用户确认。结算界面只显示用户明确要求或长期文档已确认的字段。
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
- `scenes/Game.tscn`：主场景，只保留战斗根节点、运行时动画节点和独立 UI 场景实例。
- `scenes/ui/Hud.tscn`：独立 HUD 稳定骨架场景，保留 CanvasLayer、full rect Root、容器布局、关键 Label/ProgressBar/Button/Panel/Card 节点、默认占位文案和锚点。
- `scenes/ui/MainMenuScreen.tscn`：独立主界面场景，负责关卡选择、通关状态和开始入口的稳定 UI 骨架。
- `scenes/Game.gd`：场景编排、输入、对象同步和表现层绘制顺序。
- `src/game/GameBattlefieldDrawer.gd`：战场背景与区域表现层绘制 helper，负责战场底图、墙体 fallback、占位底座和 active_areas 区域提示，不持有玩法状态。
- `src/game/GameCombatEffectDrawer.gd`：战斗效果表现层绘制 helper，负责 combat_effects 圆环、爆炸区域和电磁穿刺线光效，不持有玩法状态。
- `src/game/GameDamageFloatDrawer.gd`：伤害飘字表现层绘制 helper，负责 combat_effects 玩家伤害数字、暴击强调和元素颜色，不持有玩法状态。
- `src/game/GameProjectileDrawer.gd`：投射物表现层绘制 helper，负责 active_projectiles 的线段/弹体绘制和方向计算，不持有玩法状态。
- `src/game/PrototypeState.gd`：玩法状态 facade、public API、跨系统编排和统一信号入口；不是独立系统逻辑堆放点。
- `src/game/CardConfigLoader.gd`：完整卡牌配置 JSON 读取入口，负责把 `assets/data/cards/card_configs.json` 转成运行时卡牌配置数组。
- `src/game/CardTextLoader.gd`：卡牌文本、费用和显示字段 CSV/JSON 覆盖入口，不承载完整卡牌规则表。
- `src/game/CardDeckState.gd`：手牌、牌堆、弃牌堆、补牌节奏和卡牌奖励落点。
- `src/game/CardPlayRuntime.gd`：出牌锁、同名冷却、复制牌记忆、pending bonus 和命中后奖励。
- `src/game/CoreSkillPayloadBuilder.gd`：核心技能 cast event、preview payload 和卡牌链加成 payload 构造。
- `src/game/StarterCardEffectResolver.gd`：starter 卡效果解析，处理枪械 buff、治疗、护盾、标记、眩晕和成长牌。
- `src/game/GunRuntimeState.gd`：枪械弹药、换弹、开火计时、临时 buff、核心技能 runtime 和 shot log。
- `src/game/modules/combat/gun/GunEvents.gd`：枪械事件常量、注册入口和 route public API facade。
- `src/game/modules/combat/gun/GunRouteTable.gd`：枪械 cast/hit/resolved route 阶段组合。
- `src/game/modules/combat/gun/GunCastRoutes.gd`：枪械开火投射物生成 route。
- `src/game/modules/combat/gun/GunHitRoutes.gd`：枪械子弹命中、爆炸触发和分裂触发 hit route。
- `src/game/modules/combat/gun/GunResolvedRoutes.gd`：枪械爆炸查询/伤害和分裂子弹生成 resolved route。
- `src/game/CombatRuntime.gd`：战斗实体运行时 facade，负责 tick 编排、事件路由执行和实体数组状态维护。
- `src/game/CombatSnapshotBuilder.gd`：战斗运行时 snapshot 组装和深拷贝输出。
- `src/game/CombatMonsterCatalog.gd`：默认怪物规格和 `ContentUnits` 自定义怪物规格读取。
- `src/game/CombatTargetSelector.gd`：战斗目标选择、距离过滤、线段命中查询和目标排序。
- `src/game/CombatEffectLog.gd`：战斗效果显示队列、命令日志和上限裁剪。
- `src/game/CombatSpawnRuntime.gd`：刷怪组队列推进、批量生成、出生位置和波次数值系数。
- `src/game/CombatAreaRuntime.gd`：区域效果创建、生命周期 tick 和区域 tick 事件路由。
- `src/game/CombatProjectileRuntime.gd`：投射物延迟生成、飞行推进、命中事件路由和即时投射物表现。
- `src/game/CombatProjectileFactory.gd`：投射物 spawn delay、origin、target context 和 projectile 字典构造。
- `src/game/CombatDamageRuntime.gd`：伤害结算、状态应用、持续伤害 tick、元素判定和暴击判定。
- `src/game/CombatMonsterRuntime.gd`：怪物移动推进、到墙攻击、死亡经验、Boss 死亡标记和实体查找/索引。
- `src/game/CombatCommandPayload.gd`：战斗命令 target 数组标准化、爆炸中心和爆炸半径 payload 解析。
- `src/game/CombatCommandRuntime.gd`：战斗 query targets 服务和击退命令执行。
- `src/game/CombatUnitScale.gd`：战斗半径和投射物速度等单位换算公式。
- `src/game/modules/combat/skills/thermobaric/ThermobaricEvents.gd`：温压弹事件常量和 route public API facade。
- `src/game/modules/combat/skills/thermobaric/ThermobaricRouteTable.gd`：温压弹 cast/hit/resolved route 阶段组合。
- `src/game/modules/combat/skills/thermobaric/ThermobaricCastRoutes.gd`：温压弹 cast 阶段投射物生成 route。
- `src/game/modules/combat/skills/thermobaric/ThermobaricHitRoutes.gd`：温压弹冲击、爆炸、击退、燃烧、火花命中 hit route。
- `src/game/modules/combat/skills/thermobaric/ThermobaricResolvedRoutes.gd`：温压弹爆炸结束后火花投射物生成 resolved route。
- `src/game/modules/combat/skills/electro_pierce/ElectroPierceEvents.gd`：电磁穿刺事件常量和 route public API facade。
- `src/game/modules/combat/skills/electro_pierce/ElectroPierceRouteTable.gd`：电磁穿刺 cast/hit/resolved/tick route 阶段组合。
- `src/game/modules/combat/skills/electro_pierce/ElectroPierceCastRoutes.gd`：电磁穿刺 cast 阶段投射物生成 route。
- `src/game/modules/combat/skills/electro_pierce/ElectroPierceHitRoutes.gd`：电磁穿刺命中、麻痹、爆炸触发和裂变粒子 hit route。
- `src/game/modules/combat/skills/electro_pierce/ElectroPierceResolvedRoutes.gd`：电磁穿刺爆炸和矩阵区域生成 resolved route。
- `src/game/modules/combat/skills/electro_pierce/ElectroPierceTickRoutes.gd`：电磁矩阵 tick 查询、伤害和减速 route。
- `src/game/modules/combat/skills/dry_ice/DryIceEvents.gd`：干冰弹事件常量和 route public API facade。
- `src/game/modules/combat/skills/dry_ice/DryIceRouteTable.gd`：干冰弹 cast/hit/resolved route 阶段组合。
- `src/game/modules/combat/skills/dry_ice/DryIceCastRoutes.gd`：干冰弹 cast 阶段穿透投射物生成 route。
- `src/game/modules/combat/skills/dry_ice/DryIceHitRoutes.gd`：干冰弹命中伤害、击退、冻结、冻伤和小冰晶 hit route。
- `src/game/modules/combat/skills/dry_ice/DryIceResolvedRoutes.gd`：干冰弹首次命中分裂小冰晶 resolved route。
- `src/game/LevelRewardRuntime.gd`：升级三选一运行时、已选次数、升级应用和新卡获得事件。
- `src/game/WaveRuntimeState.gd`：波次配置、推进、spawn log、Boss 标记和战斗清场判断。
- `src/ui/Hud.gd`：HUD 显示。
- `src/ui/HudSetupCoordinator.gd`：HUD 初始化 wiring，负责控制器 setup、层级/鼠标过滤、信号连接、FX/overlay/presenter setup，不持有节点、不处理运行时刷新。
- `src/ui/HudBattleUiFlow.gd`：HUD 战斗 UI 生命周期编排，负责开始/停止战斗 UI、暂停/继续/退出、阻塞 overlay 判断和统一 FX reset，不处理 snapshot 呈现和玩法规则。
- `src/ui/HudDiscardHandFlow.gd`：HUD 弃牌 UI flow，负责弃牌按钮响应、弃牌动画完成回调和阻塞文案拼装，不修改牌堆真实状态。
- `src/ui/HudHandQueries.gd`：HUD 手牌几何和只读查询 helper，负责当前手牌数量、点位命中卡牌、panel 到索引、拖拽重排目标索引和索引到卡名。
- `src/ui/HudSnapshotPresenter.gd`：HUD snapshot 基础状态字段呈现，负责时间、关卡、波次、经验、血量、护盾、弹药、能量和英雄名刷新。
- `src/ui/HudCardSnapshotPresenter.gd`：HUD 手牌 snapshot 呈现，负责把手牌卡牌数据写入已有 card widget，不负责节点复制、布局或动效。
- `src/ui/HudPileOverlay.gd`：牌堆/弃牌堆弹窗 facade，负责显示状态、布局、卡牌重建和关闭输入。
- `src/ui/HudPileOverlayView.gd`：牌堆/弃牌堆弹窗稳定节点树 facade，负责遮罩、居中容器、面板和内容列编排。
- `src/ui/HudPileOverlayHeaderView.gd`：牌堆/弃牌堆弹窗标题栏、标题 label 和关闭按钮创建。
- `src/ui/HudPileOverlayContentView.gd`：牌堆/弃牌堆弹窗滚动区、卡牌网格容器和空状态 label 创建。
- `src/ui/HudCardInteraction.gd`：HUD 手牌输入状态机，负责键盘/鼠标/拖拽/重排/取消的状态推进。
- `src/ui/HudCardInteractionPort.gd`：HUD 手牌交互对 `Hud.gd` 的纯接口适配，集中几何查询、冷却查询、出牌/重排请求和提示反馈调用。
- `src/ui/HudCardVisuals.gd`：HUD 手牌视觉生命周期 facade，只编排手牌可见性、feel state、目标变换、反馈叠加、按压 FX 和插值应用。
- `src/ui/HudCardVisualTarget.gd`：HUD 手牌目标变换 facade，只编排槽位、运动和按压 helper。
- `src/ui/HudCardVisualTargetSlots.gd`：HUD 手牌基础槽位、重排预览、悬浮扩散和边界夹取计算。
- `src/ui/HudCardVisualTargetMotion.gd`：HUD 手牌拖拽、可出牌拖拽、悬浮和选中目标运动计算。
- `src/ui/HudCardVisualTargetPress.gd`：HUD 手牌按压倾斜、位移和缩放目标变换。
- `src/ui/HudCardPressFeedback.gd`：HUD 手牌悬浮按压命中区域、卡面点、抬升点和按压法线计算。
- `src/ui/HudCardVisualFeedback.gd`：HUD 手牌无效、抽牌、获卡、弃牌和连锁费用提示反馈叠加。
- `src/ui/HudCardVisualInterpolator.gd`：HUD 手牌目标位置、缩放、旋转和 z-index 的最终插值应用。
- `src/ui/HudCardWidgets.gd`：HUD 卡牌控件创建、文本填充、费用状态和手牌排布入口。
- `src/ui/HudCardArtBinder.gd`：HUD 卡牌卡框/卡图 TextureRect 创建、流派图标路径和纹理加载。
- `src/ui/HudCardLabelStyler.gd`：HUD 卡牌标签样式 facade 和兼容缩放 API。
- `src/ui/HudCardLabelStyleGroups.gd`：HUD 卡牌费用、插图、名称、类型、描述和流派标签字体、颜色、描边和 stylebox 分组应用。
- `src/ui/HudCardNodeFinder.gd`：HUD 卡牌相关递归节点查找和 unique name 清理 helper。
- `src/ui/HudCardChainHintWidget.gd`：HUD 连锁费用提示 facade，保留 widget 字典同步、费用徽章闪光和珍珠闪烁更新。
- `src/ui/HudCardChainHintNodes.gd`：HUD 连锁费用提示 glow panel、sparkle label 查找/创建和基础样式。
- `src/ui/HudCardReadabilityRegions.gd`：HUD 卡牌可读区布局 facade，只编排矩形数据、装饰层和文字区应用。
- `src/ui/HudCardReadabilityRegionFrames.gd`：HUD 卡牌费用、名称、插图、描述、流派和连锁费用闪光挂点的纯矩形数据。
- `src/ui/HudCardReadabilityLayerApplier.gd`：HUD 卡牌框、禁用遮罩、连锁费用闪光和按压反馈层布局应用。
- `src/ui/HudCardReadabilityTextApplier.gd`：HUD 卡牌费用、名称、类型、插图、描述和流派文本区布局应用。
- `src/ui/HudCardDescriptionText.gd`：HUD 卡牌描述 RichTextLabel 创建、旧 DescLabel 兼容隐藏和 BBCode 文本应用。
- `src/ui/HudCardHandLayout.gd`：HUD 手牌排布、重叠间距、基础位置/旋转/z-index 和 snap 状态。
- `src/ui/HudLayoutStyler.gd`：HUD 响应式布局、稳定区域尺寸、手牌布局触发和终极条锁图标。
- `src/ui/HudLayoutStyleApplier.gd`：HUD 静态主题应用 facade，只编排面板、标签和控件样式 helper。
- `src/ui/HudLayoutPanelStyleApplier.gd`：HUD 面板样式 facade，只保留兼容入口并委托分组 helper。
- `src/ui/HudLayoutPanelStyleGroups.gd`：HUD 面板、徽章、手牌区域和菜单/暂停面板 stylebox 分组应用。
- `src/ui/HudLayoutLabelStyleApplier.gd`：HUD 非卡牌标签样式 facade，只保留兼容入口并委托分组 helper。
- `src/ui/HudLayoutLabelStyleGroups.gd`：HUD 非卡牌标签基础样式、主菜单、暂停、战斗状态、资源/护盾和目标标签分组样式应用。
- `src/ui/HudLayoutControlStyleApplier.gd`：HUD 按钮、进度条和结算 overlay 样式应用。
- `src/ui/HudRewardOverlay.gd`：升级三选一奖励弹窗 facade，负责弹窗生命周期、按钮容器、输入和选择反馈。
- `src/ui/HudRewardOverlayView.gd`：升级三选一奖励弹窗稳定节点树 facade，只保留兼容入口并委托节点 helper。
- `src/ui/HudRewardOverlayViewNodes.gd`：升级三选一奖励弹窗遮罩、居中容器、面板、标题和选项容器节点创建。
- `src/ui/HudRewardChoiceButtons.gd`：升级三选一奖励选项按钮清空、创建、样式和 pressed 信号绑定。
- `src/ui/HudRewardChoiceContent.gd`：升级三选一奖励选项内容 facade，保留兼容入口并委托节点和文本 helper。
- `src/ui/HudRewardChoiceContentNodes.gd`：升级三选一奖励选项卡标题、描述、流派行和角标节点树构建。
- `src/ui/HudRewardChoiceText.gd`：升级三选一奖励选项标题、描述、费用/流派数量文本、类型标签和签名规则。
- `src/ui/HudRewardChoiceBadges.gd`：升级三选一奖励选项徽章 facade，保留费用、类型、同费用/同流派数量徽章兼容入口。
- `src/ui/HudRewardChoiceCostBadge.gd`：升级三选一奖励选项费用徽章和同费用数量 label 节点树与样式构建。
- `src/ui/HudRewardChoiceEntryTypeBadge.gd`：升级三选一奖励选项类型徽章的 holder、panel、margin 和 label 节点树与样式构建。
- `src/ui/HudRewardChoiceSchoolBadge.gd`：升级三选一奖励选项流派徽章、同流派数量 label 和流派行节点树与样式构建。
- `src/ui/HudPlayCardFx.gd`：出牌飞行动效生命周期、卡牌复制、飞入/停留/溶解阶段编排。
- `src/ui/HudPlayCardFxFragments.gd`：出牌溶解碎片节点创建、颜色、散开轨迹、碎片淡出和释放。
- `src/ui/HudAcquireCardFx.gd`：获得新卡进入手牌/牌堆的事件同步、FX 队列状态、飞行动画更新和到达反馈。
- `src/ui/HudAcquireCardFxSpawn.gd`：获得新卡飞行动效的事件解析、节点初始化、起终点/缩放/旋转和 fx 数据构造。
- `src/ui/HudAcquireCardFxCardBuilder.gd`：获得新卡飞行动效的卡牌节点复制、纹理、文本和样式填充。
- `src/ui/HudDrawCardFx.gd`：牌堆抽牌飞入手牌的计数同步、FX 队列状态、飞行动画更新、牌堆脉冲和到达反馈。
- `src/ui/HudDrawCardFxSpawn.gd`：牌堆抽牌飞行动效的目标校验、卡牌节点复制初始化、起点和 fx 数据构造。
- `src/ui/HudDiscardHandFx.gd`：整手弃牌飞入弃牌堆的生命周期、FX 队列状态、飞行动画更新、弃牌堆脉冲和完成回调。
- `src/ui/HudDiscardHandFxSpawn.gd`：整手弃牌飞行动效的目标校验、卡牌节点复制初始化和 fx 数据构造。
- `src/game/GameEvents.gd`：通用游戏事件总线，解耦玩法、反馈、音效和成就。
- `src/game/AchievementStore.gd`：本地成就定义、解锁和保存。
- `src/game/AssetRegistry.gd`：运行时素材清单。
- `src/game/FeedbackDirector.gd`：震屏、闪白、浮字、VFX 入口。
- `src/game/AudioDirector.gd`：基础音效和音频入口。
- `src/game/ContentUnits.gd`：关卡、波次、怪物规格和默认波次兜底的数据入口。
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
- `scenes/Game.tscn` 不再承载 HUD 具体节点树；HUD 的稳定节点骨架必须写入 `scenes/ui/Hud.tscn`，主场景只实例化 `Hud`。后续新增 HUD 面板、按钮、提示层、结算层、牌堆层、卡牌槽位等稳定节点时，优先改 `scenes/ui/Hud.tscn` 或更小的 `scenes/ui/*.tscn` 子场景，不得把整棵 UI 子树塞回 `Game.tscn`。
- 空脚手架默认 HUD 必须让用户在 Godot 编辑器打开主场景时看见清晰的 UI 层级和占位信息；运行时再由脚本替换成当前游戏目标、状态、提示和结算反馈。

### HUD 脚本边界

`src/ui/Hud.gd` 是 HUD 对外 facade 和运行时编排入口，不再作为所有 HUD 逻辑的堆放文件。后续修改必须先判断职责归属：

- 可以写在 `Hud.gd`：`class_name Hud`、对外信号和公开接口，例如 `set_battle_snapshot()`、`set_gameplay_mode()`、`start_battle_ui()`、`stop_battle_ui()`、`is_gameplay_active()`；主场景稳定节点的 `@onready` 引用；子控制器 `setup()`；与 `PrototypeState`、按钮信号、overlay 控制器之间的薄 wrapper；少量跨多个子控制器的胶水函数。
- 可以写在 `Hud.gd`：只读查询类薄 wrapper，例如 `_current_hand_count()`、`_card_index_at_point()`、`_card_index_for_panel()`、`_card_reorder_index_at_point()` 和 `_card_name_for_index()`，用于兼容 `HudCardInteractionPort` 等既有调用点；实际计算体必须放在专责脚本。
- 必须写到外部脚本：`_ready()` 中成片的 setup wiring 写入 `HudSetupCoordinator.gd`；它只能做初始化阶段的控制器 setup、层级/鼠标过滤、信号连接和子 presenter/overlay/FX 注入，不持有节点所有权、不缓存运行时状态、不处理 snapshot 刷新。
- 必须写到外部脚本：战斗 UI 生命周期、暂停/继续/退出、开始/停止战斗 UI、阻塞 overlay 判断和统一 FX reset 写入 `HudBattleUiFlow.gd`；`Hud.gd` 只保留同名 facade/wrapper。`HudBattleUiFlow.gd` 可以请求 `PrototypeState.reset()` 等既有公开入口，但不得写 `PrototypeState` 内部字段、不得处理 snapshot 呈现、不得持有节点所有权。
- 必须写到外部脚本：弃牌按钮响应、弃牌动画完成回调和弃牌阻塞文案拼装写入 `HudDiscardHandFlow.gd`；`Hud.gd` 只保留 `_on_discard_hand_pressed()`、`_finish_discard_hand_animation()` 和 `_discard_hand_block_message()` 薄 wrapper。真实手牌/牌堆/弃牌堆变更仍只能通过 `PrototypeState.discard_hand()` 和规则层完成。
- 必须写到外部脚本：手牌几何和只读查询计算体写入 `HudHandQueries.gd`，包括当前手牌数量、点位命中卡牌、panel 到索引、拖拽重排目标索引和索引到卡名；`Hud.gd` 只保留同名私有 wrapper 以兼容 `HudCardInteractionPort`，不得在 wrapper 中重新堆循环和几何公式。
- 必须写到外部脚本：基础 snapshot 状态字段刷新写入 `HudSnapshotPresenter.gd`；手牌卡牌 snapshot 到已有 card widget 的呈现写入 `HudCardSnapshotPresenter.gd`。`Hud.gd` 只保留 `set_battle_snapshot()` 分发、widget 数量补齐、手牌布局和 FX 同步。
- 必须写到外部脚本：卡牌输入和交互状态机写入 `HudCardInteraction.gd`；`HudCardInteraction.gd` 不直接散落 `Hud.gd` 私有方法调用，几何查询、冷却查询、出牌/重排请求和提示反馈调用集中写入 `HudCardInteractionPort.gd`；手牌视觉生命周期编排写入 `HudCardVisuals.gd`，只保留循环、可见性、feel state 和 helper 调用；手牌目标变换 facade 写入 `HudCardVisualTarget.gd`，只编排槽位、运动和按压 helper；基础槽位、重排预览、悬浮扩散和边界夹取写入 `HudCardVisualTargetSlots.gd`；拖拽、可出牌拖拽、悬浮和选中目标运动写入 `HudCardVisualTargetMotion.gd`；按压倾斜、位移和缩放目标变换写入 `HudCardVisualTargetPress.gd`；悬浮按压命中区域、卡面点、抬升点和按压法线计算写入 `HudCardPressFeedback.gd`；无效、抽牌、获卡、弃牌和连锁费用提示反馈叠加写入 `HudCardVisualFeedback.gd`；目标位置、缩放、旋转和 z-index 的最终插值应用写入 `HudCardVisualInterpolator.gd`；HUD 静态主题 facade 写入 `HudLayoutStyleApplier.gd`，只允许编排调用，不继续堆具体样式；面板样式 facade 写入 `HudLayoutPanelStyleApplier.gd`，只委托分组 helper，面板/徽章/手牌区域/菜单/暂停面板 stylebox 分组写入 `HudLayoutPanelStyleGroups.gd`；非卡牌标签样式 facade 写入 `HudLayoutLabelStyleApplier.gd`，基础标签、主菜单、暂停、战斗状态、资源/护盾和目标标签分组样式写入 `HudLayoutLabelStyleGroups.gd`；按钮、进度条和结算 overlay 样式写入 `HudLayoutControlStyleApplier.gd`；HUD 响应式布局、稳定区域尺寸、手牌布局触发和终极条锁图标写入 `HudLayoutStyler.gd`；卡牌控件创建、文本填充、费用颜色、充能/冷却遮罩和手牌排布入口写入 `HudCardWidgets.gd`；手牌排布、重叠间距、基础位置/旋转/z-index 和 snap 状态写入 `HudCardHandLayout.gd`，`HudCardWidgets.gd` 只保留 `layout_hand_cards()` / `snap_card_widget_to_base()` 兼容薄代理；卡框/卡图 `TextureRect` 创建、流派图标路径和纹理加载写入 `HudCardArtBinder.gd`，`HudCardWidgets.gd` 只保留兼容薄代理；卡牌描述 RichTextLabel 创建、旧 DescLabel 兼容隐藏、BBCode 文本应用和 `{chain_font_size}` 替换写入 `HudCardDescriptionText.gd`，`HudCardWidgets.gd` 只保留兼容薄代理；卡牌标签样式 facade 和兼容缩放 API 写入 `HudCardLabelStyler.gd`，费用、插图、名称、类型、描述和流派标签字体/颜色/描边/stylebox 分组写入 `HudCardLabelStyleGroups.gd`，`HudCardWidgets.gd` 只调用 styler；卡牌相关递归节点查找和 unique name 清理写入 `HudCardNodeFinder.gd`，其他 HUD 卡牌脚本只调用 finder；连锁费用提示 facade、widget 字典同步、费用徽章闪光和珍珠闪烁更新写入 `HudCardChainHintWidget.gd`，glow panel、sparkle label 查找/创建和基础样式写入 `HudCardChainHintNodes.gd`；卡牌可读区布局 facade 写入 `HudCardReadabilityRegions.gd`，只编排调用；可读区基准矩形和缩放公式写入 `HudCardReadabilityRegionFrames.gd`；卡框、禁用遮罩、连锁费用闪光和按压反馈层布局应用写入 `HudCardReadabilityLayerApplier.gd`；费用、名称、类型、插图、描述和流派文本区布局应用写入 `HudCardReadabilityTextApplier.gd`；`HudCardWidgets.gd` 只保留薄代理。
- 必须写到外部脚本：牌堆、弃牌堆、奖励、结算、暂停菜单等具有独立显示状态或独立输入路径的 UI，写入对应 `Hud*Overlay.gd`、`Hud*OverlayController.gd` 或独立 UI 场景脚本；牌堆/弃牌堆弹窗遮罩、居中容器、面板和内容列编排写入 `HudPileOverlayView.gd`，标题栏、标题 label 和关闭按钮写入 `HudPileOverlayHeaderView.gd`，滚动区、卡牌网格容器和空状态 label 写入 `HudPileOverlayContentView.gd`；`HudPileOverlay.gd` 只保留显示状态、layout、卡牌重建、卡牌内容填充和关闭输入；奖励弹窗稳定节点树 facade 写入 `HudRewardOverlayView.gd`，遮罩、居中容器、面板、标题和选项容器节点创建写入 `HudRewardOverlayViewNodes.gd`；奖励选项按钮清空、创建、样式和 pressed 信号绑定写入 `HudRewardChoiceButtons.gd`；奖励选项内容 facade 写入 `HudRewardChoiceContent.gd`，标题/描述/流派行/角标节点树构建写入 `HudRewardChoiceContentNodes.gd`，标题、描述、费用/流派数量文本、类型标签和签名规则写入 `HudRewardChoiceText.gd`；奖励选项费用、类型、同费用/同流派数量徽章 facade 写入 `HudRewardChoiceBadges.gd`，费用徽章和同费用数量 label 节点树与样式写入 `HudRewardChoiceCostBadge.gd`，类型徽章 holder、panel、margin 和 label 节点树与样式写入 `HudRewardChoiceEntryTypeBadge.gd`，流派徽章、同流派数量 label 和流派行节点树与样式写入 `HudRewardChoiceSchoolBadge.gd`；`HudRewardOverlay.gd` 只保留弹窗生命周期、layout、输入命中、选择反馈和薄委托；抽牌、获得新卡、出牌、弃牌、连锁闪烁、释放范围等表现效果写入对应 `Hud*Fx.gd` 或表现脚本；抽牌飞行动效的计数同步、FX 队列状态、飞行更新、牌堆脉冲和到达反馈写入 `HudDrawCardFx.gd`，目标校验、卡牌节点复制初始化、起点和 fx 数据构造写入 `HudDrawCardFxSpawn.gd`；弃牌飞行动效的生命周期、FX 队列状态、飞行更新、弃牌堆脉冲和完成回调写入 `HudDiscardHandFx.gd`，目标校验、卡牌节点复制初始化和 fx 数据构造写入 `HudDiscardHandFxSpawn.gd`；出牌飞行动效生命周期、卡牌复制、飞入/停留/溶解阶段编排写入 `HudPlayCardFx.gd`，溶解碎片节点创建、颜色、散开轨迹、碎片淡出和释放写入 `HudPlayCardFxFragments.gd`；获得新卡飞行动效的事件同步、FX 队列状态、飞行/落地动画和到达反馈写入 `HudAcquireCardFx.gd`，事件解析、节点初始化、起终点/缩放/旋转和 fx 数据构造写入 `HudAcquireCardFxSpawn.gd`，卡牌节点复制、纹理、文本和样式填充写入 `HudAcquireCardFxCardBuilder.gd`。
- 必须写到外部脚本：默认数据、文案映射、格式化、纯 UI helper 写入 `HudDefaults.gd`、`HudTheme.gd`、`HudUiHelpers.gd` 或新的单一职责 `RefCounted`；不要把可复用常量、颜色表、文案表、布局公式继续塞回 `Hud.gd`。
- 禁止写在 `Hud.gd`：玩法规则、能量扣减、牌堆/弃牌堆真实变更、升级池规则、敌人/战斗结算等状态修改。HUD 只能通过 `PrototypeState` 的明确接口请求玩法动作，并根据 snapshot 刷新显示。
- 如果 `set_battle_snapshot()`、`_update_cards()` 或其他刷新函数继续膨胀，应优先拆出 `HudSnapshotPresenter.gd`、`HudStatusPresenter.gd` 或等价专责脚本，保持 `Hud.gd` 只负责把 snapshot 分发给表现组件。
- 新增 HUD 拆分脚本必须放在 `src/ui/`，使用单一职责命名，例如 `HudXxxController.gd`、`HudXxxVisuals.gd`、`HudXxxFx.gd`、`HudXxxPresenter.gd`；通过 `setup()` 注入需要的节点、数据和回调，不新增无必要的 Autoload。
- 拆分 HUD 后必须同步检查自动审查脚本是否仍只扫描 `Hud.gd`。如果规则本意是检查 HUD 整体能力，应改为扫描 `src/ui/*.gd` 或明确检查 facade 接口，不能为了通过检查把实现塞回 `Hud.gd`。

## VFX 规则

- 内置 `haowg/GODOT-VFX-LIBRARY` 到 `addons/vfx_library/`，保留 MIT LICENSE。
- 默认只接入轻量反馈：屏幕震动、受击闪白、浮字、命中爆裂、拖尾。
- 环境特效、shader 和演示场景按游戏目标启用；启用时必须服务玩法、可读性或风格一致性。
- 如果需要重新获取上游，网络失败时可使用代理：`socks5://127.0.0.1:10808`。

## 编码与表格规则

- 项目自有文本源文件统一使用 UTF-8；Python 脚本读用户可编辑文本时优先兼容 `utf-8-sig`，输出到终端前设置 `sys.stdout/stderr` 为 UTF-8。
- 给策划或用户用 Excel 直接打开编辑的 CSV 必须保存为 `UTF-8 with BOM`，当前范围包括 `assets/data/*.csv` 和 `策划文档/*.csv`。修改这些 CSV 后先运行 `python scripts/encoding_review.py --fix`，再运行 `python scripts/encoding_review.py --json`。
- Godot 运行时读取 CSV 时必须清理表头和单元格里的 `\uFEFF`，避免 BOM 进入第一列字段名，例如 `id`、`card_id`。
- `.translation` 文件是 Godot 生成的二进制资源，常见文件头为 `RSRC`；不得把 `.translation` 当文本或 CSV 转码，不得给它添加 UTF-8 BOM。
- 如果 PowerShell 控制台显示中文乱码，先区分“终端显示乱码”和“文件内容已损坏”：用 Python `Path.read_text(encoding="utf-8-sig")` 或 `python scripts/encoding_review.py --json` 判断，不要凭 `Get-Content` 的屏幕显示直接重写文件。
- 禁止通过 PowerShell 管道、`echo`、未指定编码的重定向或命令行长参数传递中文正文、提示词、JSON、Markdown 或 CSV 内容；这些路径可能把中文不可逆替换成 `?`。中文内容必须先写入 UTF-8/UTF-8 BOM 文件，再通过 `--prompt-file`、`--options-file`、`--extra-body-file`、脚本文件参数或 Python `Path.write_text(..., encoding="utf-8")` 读取；需要命令行内嵌少量中文时，使用 `\uXXXX` 转义或脚本参数文件。
- 在 Windows PowerShell 中生成提示词或 JSON 文件时，使用 `Set-Content -Encoding UTF8` / `Out-File -Encoding utf8`，或直接用项目 Python 脚本写 UTF-8 文件；不要使用 `"中文" | python ...`、`"中文" > file`、`echo 中文 | ...` 作为正式工作流。
- `python scripts/encoding_review.py --json` 会检查 UTF-8 解码、CSV BOM 和疑似 PowerShell 管道导致的连续问号替换；发现编码检查 FAIL 时，必须回到原始输入或 UTF-8 文件重建内容，不得在已变成 `?` 的文本上继续修补。
- `python scripts/ai_review.py --strict` 已包含 UTF-8 编码策略检查；编码检查 FAIL 时不得交付。

## 代码约束

- 正常开发优先修改 `PrototypeState.gd`、`Game.gd`、`Hud.gd`；但“首选修改点”只代表入口明确，不代表可以继续把独立系统逻辑堆进同一个文件。
- 新增模块必须有单一职责。
- 账号、联网、排行榜、背包、经济、关卡编辑器等系统可按用户创意进入首版；新增前写清职责边界、数据归属、UI/素材需求和验收方式。
- 不为临时数值、玩法规则、动态对象或一次性调试内容修改 `.tscn`；但新增稳定 UI 骨架、可复用实体场景、HUD 面板、菜单、结算界面、必要碰撞/相机/容器节点时，应维护 `.tscn`，保持节点职责清晰、命名稳定，并在改后验证场景加载和导出。
- `scenes/Game.tscn` 的边界是主场景编排根：允许保留 `Game`、`Background`、`RuntimeAnimationPlayer`、`MainMenuScreen` 实例和 `Hud` 实例；禁止在主场景内继续展开 HUD 子节点。HUD 节点结构归属 `scenes/ui/Hud.tscn`，主界面结构归属 `scenes/ui/MainMenuScreen.tscn`。
- 不使用 `@tool` 脚本写业务逻辑。

### PrototypeState 脚本边界

`src/game/PrototypeState.gd` 是玩法状态 Autoload facade 和规则编排入口，不再作为所有战斗、卡牌、升级、数据加载和快照逻辑的堆放文件。后续修改必须先判断职责归属，不能用删除空行、压缩写法或把函数顶到行数门禁以下来替代真实拆分。

- 可以写在 `PrototypeState.gd`：`Phase`、对外 signals、核心 public API，例如 `reset()`、`tick()`、`try_play_hand_card()`、`reorder_hand_card()`、`discard_hand()`、`choose_level_reward()`、`apply_wall_damage()`、`mark_boss_defeated()`、`get_snapshot()`；跨系统必须共享的少量运行时状态字段；子模块 `setup()`；对 `state_changed`、`feedback_requested` 和结算事件的统一 emit。
- 可以写在 `PrototypeState.gd`：薄编排代码，例如调用抽牌、升级、战斗、进度模块后提交少量状态并 `_emit_all()`；用于兼容旧测试或 snapshot 的薄属性代理也可以保留。单个函数如果超过约 30-40 行，或开始包含独立状态机、复杂循环、表加载、公式表、payload 大量拼装，就必须优先拆到专责脚本。
- 必须写到外部脚本：抽牌、洗牌、手牌/弃牌/牌堆移动、补牌节奏、抽牌结果记录和新卡落点，写入 `CardDrawResolver.gd`、`CardDeckState.gd` 或等价 `Card*` 模块；`PrototypeState.gd` 只调用接口、提交状态和 emit。
- 必须写到外部脚本：卡牌连锁、万能牌链位费用、同名冷却、出牌锁、卡牌效果解析、starter 卡效果、技能 payload 构造、后续技能 bonus、复制牌记忆、命中后奖励等，写入 `CardChainState.gd`、`CardChainRules.gd`、`CardPlayRuntime.gd`、`StarterCardEffectResolver.gd`、`CoreSkillPayloadBuilder.gd` 或等价专责脚本。
- 必须写到外部脚本：升级池读取、三选一生成、升级效果应用、新卡获得事件、已选次数、等级/经验公式和进度结算，写入 `UpgradePoolLoader.gd`、`UpgradeResolver.gd`、`LevelRewardRuntime.gd`、`ProgressRules.gd` 或新的 `ProgressionState.gd`；`PrototypeState.gd` 只保留 `grant_exp()`、`choose_level_reward()` 等入口。
- 必须写到外部脚本：怪物、波次推进、投射物、范围、状态、伤害、目标选择、枪械开火、换弹、shot log、战斗事件路由，写入 `CombatRuntime.gd`、`CombatDamageRuntime.gd`、`WaveRuntimeState.gd`、`GunRuntimeState.gd` 或 `TriggerRouter`/`EffectExecutor` 相关模块；不要把战斗实体数组、波次排序、开火 payload 和命中解析新增回 `PrototypeState.gd`。
- 必须写到外部脚本或外部数据：完整卡牌配置写入 `assets/data/cards/card_configs.json` 并由 `CardConfigLoader.gd` 读取；卡牌文案/费用覆盖写入 `assets/data/cards/card_texts.*` 并由 `CardTextLoader.gd` 读取；升级池写入 `assets/data/upgrades/upgrade_texts.*`，短期兜底写入 `assets/data/upgrades/default_upgrade_pool.json`，统一由 `UpgradePoolLoader.gd` 读取；波次、默认波次、怪物和关卡写入 `ContentUnits.gd` 与 `assets/data/combat/`。不得新增 `PrototypeContentCatalog.gd` 或把大段卡牌、升级、波次配置写回脚本；`PrototypeState.gd` 不再新增数据解析细节。
- 必须写到外部脚本：snapshot 组装、HUD 友好字段、卡牌显示结构和只读摘要，写入 `CardSnapshotBuilder.gd`、`GameSnapshotBuilder.gd` 和 `GameSnapshotSections.gd`；`get_snapshot()` 在 `PrototypeState.gd` 中只调用 builder 并合并少量顶层状态。`GameSnapshotBuilder.gd` 只作为玩法 snapshot facade 和 section 合并顺序入口，核心/成长/资源/牌堆/出牌/连锁/运行时日志字段必须写到 `GameSnapshotSections.gd`，不要把大段字段字典新增回 `PrototypeState.gd` 或 `GameSnapshotBuilder.gd`。
- 禁止写在 `PrototypeState.gd`：UI 节点访问、场景节点引用、VFX/音效实例化、资源路径加载、按钮/输入处理、截图、导出、浏览器或工具链逻辑。表现层通过 signals、snapshot 和 `feedback_requested` 消费状态。
- 新增玩法系统时先创建单一职责 `RefCounted` 或模块目录脚本，通过 `setup(self)`、显式数据输入或结构化结果接入；不得为了省事把系统规则直接追加到 `PrototypeState.gd`。
- 如果外部模块需要修改多个 `PrototypeState` 字段，优先让模块返回结构化结果、命令或 diff，由 `PrototypeState.gd` 统一提交状态和发信号，避免外部模块随意写 Autoload 内部字段。
- 拆分 `PrototypeState.gd` 后必须同步审查脚本：架构、玩法或体验审查如果只扫描 `PrototypeState.gd`，应改为扫描 `src/game/*.gd` 或明确 facade 接口，不能为了通过检查把实现塞回 `PrototypeState.gd`。

### CombatRuntime 脚本边界

`src/game/CombatRuntime.gd` 是战斗实体运行时 facade，目前仍偏大，后续必须继续一个职责一个职责地安全拆分，不能把所有战斗逻辑继续堆进同一个文件。

- 可以写在 `CombatRuntime.gd`：战斗 tick 总编排、事件路由服务入口、对 `active_monsters` / `active_projectiles` / `active_areas` 等运行时数组的集中提交、与 `PrototypeState` 的少量回调桥接。
- 必须写到外部脚本：战斗 snapshot 组装和深拷贝输出，写入 `CombatSnapshotBuilder.gd`；`CombatRuntime.get_snapshot()` 只保留 facade 调用。
- 必须写到外部脚本：默认怪物规格、怪物数据 fallback 和 `ContentUnits` 自定义怪物规格读取，写入 `CombatMonsterCatalog.gd` 或后续数据 catalog；不要把怪物表继续追加回 `CombatRuntime.gd`。
- 必须写到外部脚本：目标选择、距离过滤、线段命中查询和排序规则，写入 `CombatTargetSelector.gd`；`CombatRuntime` 只保留 `_select_target()` 等薄代理。
- 必须写到外部脚本：战斗效果显示队列、命令日志、生命周期 tick 和上限裁剪，写入 `CombatEffectLog.gd`；`CombatRuntime` 只保留 `combat_effects` / `combat_command_log` 数组和 `_add_combat_effect()`、`_update_combat_effects()`、`_log_combat_command()` 薄代理，保证 snapshot、表现层和测试兼容。
- 必须写到外部脚本：刷怪组队列推进、批量生成、出生位置、出生分布和波次数值系数，写入 `CombatSpawnRuntime.gd`；`CombatRuntime` 只保留 `active_spawn_groups` / `active_monsters` 的状态字段、`spawn_wave()` 对外入口和 `_spawn_*()` 兼容薄代理。
- 必须写到外部脚本：区域效果创建、生命周期 tick、tick payload 和区域 tick 事件路由，写入 `CombatAreaRuntime.gd`；`CombatRuntime` 只保留 `active_areas` 数组和 `_update_areas()`、`_service_spawn_area()`、`_route_area_tick()` 薄代理。
- 必须写到外部脚本：投射物飞行推进、穿透命中、命中事件 payload、即时投射物表现和投射物命中回调桥接，写入 `CombatProjectileRuntime.gd`；`CombatRuntime` 只保留 `active_projectiles` / `pending_projectile_spawns` 数组和 `_update_projectiles()`、`_service_spawn_projectile()`、`_resolve_projectile_hit()` 等兼容薄代理。
- 必须写到外部脚本：投射物 spawn delay、origin、target context 和 projectile 字典构造，写入 `CombatProjectileFactory.gd`；`CombatProjectileRuntime` 只保留 `projectile_spawn_delay()`、`projectile_target_context()`、`new_projectile()`、`command_origin()` 兼容薄代理。
- 必须写到外部脚本：伤害结算、状态应用、状态 tick、持续伤害、伤害易伤倍率、元素判定和暴击判定，写入 `CombatDamageRuntime.gd`；`CombatRuntime` 只保留 `apply_status_to_nearest_wall()`、`apply_status_to_all_living()`、`_service_deal_damage()`、`_service_apply_status()`、`_damage_monster()` 等兼容薄代理。
- 必须写到外部脚本：怪物移动推进、到墙攻击、死亡经验、Boss 死亡标记和实体查找/索引，写入 `CombatMonsterRuntime.gd`；`CombatRuntime` 只保留 `active_monsters` 数组和 `_update_monsters()`、`_update_monster_attack()`、`_on_monster_defeated()`、`_gain_exp_from_kill()`、`_monster_by_id()`、`_monster_index_by_id()` 兼容薄代理。
- 必须写到外部脚本：战斗命令 target 数组标准化、爆炸中心和爆炸半径 payload 解析，写入 `CombatCommandPayload.gd`；`CombatRuntime` 只保留 `_command_targets()`、`_explosion_effect_center()`、`_explosion_effect_radius()` 兼容薄代理。
- 必须写到外部脚本：query targets 服务、击退命令执行和后续同类 EffectExecutor 小服务，写入 `CombatCommandRuntime.gd`；`CombatRuntime` 只保留 `_service_query_targets()`、`_service_knockback()` 兼容薄代理。
- 必须写到外部脚本：战斗半径、投射物速度等单位换算公式，写入 `CombatUnitScale.gd`；`CombatRuntime` 只保留 `_combat_radius()`、`_combat_projectile_speed()` 兼容薄代理。
- 后续继续拆分时优先按低风险顺序推进：剩余 projectile facade 代理、目标选择代理收束，或转向更高风险的 HUD/PrototypeState presenter 级拆分。每拆一块都必须保留 `CombatRuntime` 的原 public 接口或提供兼容薄代理，并先跑专项检查再进入下一刀。

### 战斗事件路由表边界

- `*Events.gd` 只保留事件 `StringName` 常量、`get_routes()` public API 和必要的兼容 facade；不要把整棵 cast/hit/resolved/tick route 表继续写成一个超长函数。
- 单个技能 route 如果超过约 60 行，必须按触发阶段拆到同目录专责脚本，例如 `ElectroPierceCastRoutes.gd`、`ElectroPierceHitRoutes.gd`、`ElectroPierceResolvedRoutes.gd`、`ElectroPierceTickRoutes.gd`，再由 `ElectroPierceRouteTable.gd` 组合。
- 阶段 helper 只返回 EffectExecutor 可消费的纯 Dictionary/Array route 数据，不读取或修改 `PrototypeState`、`CombatRuntime`、HUD、场景节点或素材。
- `*Skill.gd` 继续负责默认 payload、`build_cast_event()` 和 `register(router)`；拆 route 表时不得改变技能 public event id、payload key、注册入口或 EffectExecutor command 字段。
- 后续处理 `GunEvents.gd`、`DryIceEvents.gd`、`ThermobaricEvents.gd` 时沿用同样边界：先拆 route 数据表，保留 `get_routes()` 兼容入口，再跑技能专项脚本和完整 AI review。

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
- 编码检查：`python scripts/encoding_review.py --json`
- 修复 Excel 可编辑 CSV UTF-8 BOM：`python scripts/encoding_review.py --fix`
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
