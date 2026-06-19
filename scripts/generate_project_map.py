#!/usr/bin/env python3
"""
生成 AI 读取用的项目地图。

项目地图不是全量文件索引，而是给 Agent 的最小导航：先读什么、常改哪里、
哪些目录不能误用、哪些文件可以当作实现范例。
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

PROJECT_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_OUTPUT = PROJECT_ROOT / "docs" / "project-map.md"
FIXED_STATUS = {
    ".pm/project/": "过程状态源/本地",
    ".pm/workspaces/": "过程记录/本地",
    ".runtime/": "运行时生成/按需",
    "reports/screenshots/": "运行时生成/按需",
    "html5/": "导出生成/按需",
    "exports/": "打包生成/按需",
}


SECTIONS = [
    (
        "项目入口",
        [
            ("AGENTS.md", "仓库级 AI 协作规则，包含首启、工作流、Skill 路由、素材和质量门禁。"),
            ("START_HERE.md", "给新手和 AI 的首启说明。"),
            ("README.md", "脚手架定位、常用命令、目录概览和 AI 开发原则。"),
            ("project.godot", "Godot 项目配置、Autoload 和主场景入口。"),
            ("template.json", "模板元数据和导出信息。"),
        ],
    ),
    (
        "当前游戏事实源",
        [
            ("docs/game-concept.md", "兼容旧脚本和 review 的当前游戏事实源摘要。"),
            ("docs/project/game-concept.md", "当前游戏摘要和详细文档索引，优先作为项目文档入口。"),
            ("docs/project/gameplay/README.md", "核心循环、首版范围、启用系统和系统边界。"),
            ("docs/project/gameplay/content-units.md", "首版内容单元、关卡、波次或系统阶段差异。"),
            ("docs/project/gameplay/balance.md", "数值、公式、成长和掉落。"),
            ("docs/project/gameplay/systems/", "按系统拆分的规则文档，例如技能、敌人、背包、成长、经济。"),
            ("docs/project/art/", "美术方向、风格规范、素材计划和 asset-manifest。"),
            ("docs/project/ui/", "HUD、菜单、UI 流程和响应式约束。"),
            ("docs/design-inputs/", "用户原始设定和 AI 提炼稿；原文不得被摘要覆盖。"),
            ("docs/concepts/", "历史游戏概念归档，避免新游戏概念污染。"),
        ],
    ),
    (
        "脚手架流程文档",
        [
            ("docs/AI_WORKFLOW.md", "从 init、计划、开发、检查、验收到发布的完整 AI 流程。"),
            ("docs/GAME_DESIGN_GUIDE.md", "玩法拆解、中度/混合玩法蓝图和首版计划生成依据。"),
            ("docs/ART_PIPELINE.md", "美术生成、切分、运行时落地和素材审查规则。"),
            ("docs/QUALITY_BAR.md", "交付门禁、体验标准和严格 review 期望。"),
            ("docs/TOOLCHAIN.md", "portable 工具链、环境、离线依赖和常见问题。"),
            ("docs/ARCHITECTURE_RULES.md", "Godot/GDScript 代码架构、职责边界和模块接入约束。"),
            ("docs/AI_RECIPES.md", "常见玩法和系统接入步骤。"),
            ("docs/MODULES.md", "可拔插游戏模块目录和使用边界。"),
            ("docs/MULTI_AGENT_WORKFLOW.md", "主 AI 编排、子 Agent 执行、主 AI 合并的协作规则。"),
            ("docs/GODOT_MCP.md", "GodotMCP 编辑器桥接和调试链路。"),
        ],
    ),
    (
        "运行时代码",
        [
            ("scenes/Game.tscn", "主场景节点结构，只保留战斗根节点、运行时动画节点和独立 UI 场景实例。"),
            ("scenes/ui/Hud.tscn", "独立 HUD 稳定骨架场景，保留 CanvasLayer、Root、容器、关键标签/按钮/进度条和卡牌槽位。"),
            ("scenes/ui/MainMenuScreen.tscn", "独立主界面场景，负责通关状态、关卡切换和开始入口。"),
            ("scenes/Game.gd", "场景编排、输入、对象同步和表现层绘制顺序。"),
            ("src/game/GameBattlefieldDrawer.gd", "战场背景与区域表现层绘制 helper，负责战场底图、墙体 fallback、占位底座和 active_areas 区域提示，不持有玩法状态。"),
            ("src/game/GameCombatEffectDrawer.gd", "战斗效果表现层绘制 helper，负责 combat_effects 圆环、爆炸区域和电磁穿刺线光效，不持有玩法状态。"),
            ("src/game/GameDamageFloatDrawer.gd", "伤害飘字表现层绘制 helper，负责 combat_effects 玩家伤害数字、暴击强调和元素颜色，不持有玩法状态。"),
            ("src/game/GameProjectileDrawer.gd", "投射物表现层绘制 helper，负责 active_projectiles 的线段/弹体绘制和方向计算，不持有玩法状态。"),
            ("src/game/PrototypeState.gd", "玩法状态 facade、public API、规则编排和统一信号入口；独立系统逻辑按 AGENTS 边界拆到专责模块。"),
            ("src/game/CardConfigLoader.gd", "完整卡牌配置 JSON 读取入口，把 assets/data/cards/card_configs.json 转成运行时卡牌配置数组。"),
            ("src/game/CardTextLoader.gd", "卡牌文本、费用和显示字段 CSV/JSON 覆盖入口，不承载完整卡牌规则表。"),
            ("src/game/CardDeckState.gd", "手牌、牌堆、弃牌堆、补牌节奏和卡牌奖励落点运行时。"),
            ("src/game/CardPlayRuntime.gd", "出牌运行时：出牌锁、同名冷却、复制牌记忆、pending bonus 和命中后奖励。"),
            ("src/game/CardChainState.gd", "卡牌连锁状态、连续费用链推进和同流派前置效果继承。"),
            ("src/game/CardChainRules.gd", "卡牌连锁效果表、基础倍率和正面数值缩放规则。"),
            ("src/game/CardChainParamRules.gd", "卡牌连锁参数规范加载、实时文本数值格式化和 starter 运行时缩放 helper。"),
            ("src/game/CoreSkillPayloadBuilder.gd", "核心技能 cast event、preview payload 和卡牌链加成 payload 构造。"),
            ("src/game/StarterCardEffectResolver.gd", "starter 卡效果解析，处理枪械 buff、治疗、护盾、标记、眩晕和成长牌。"),
            ("src/game/GunRuntimeState.gd", "枪械弹药、换弹、开火计时、临时 buff、核心技能 runtime 和 shot log。"),
            ("src/game/modules/combat/gun/GunEvents.gd", "枪械事件常量、注册入口和 route public API facade。"),
            ("src/game/modules/combat/gun/GunRouteTable.gd", "枪械 cast/hit/resolved route 阶段组合。"),
            ("src/game/modules/combat/gun/GunCastRoutes.gd", "枪械开火投射物生成 route。"),
            ("src/game/modules/combat/gun/GunHitRoutes.gd", "枪械子弹命中、爆炸触发和分裂触发 hit route。"),
            ("src/game/modules/combat/gun/GunResolvedRoutes.gd", "枪械爆炸查询/伤害和分裂子弹生成 resolved route。"),
            ("src/game/CombatRuntime.gd", "战斗实体运行时 facade，负责 tick 编排、事件路由执行和实体数组状态维护。"),
            ("src/game/CombatSnapshotBuilder.gd", "战斗运行时 snapshot 组装和深拷贝输出。"),
            ("src/game/CombatMonsterCatalog.gd", "默认怪物规格和 ContentUnits 自定义怪物规格读取。"),
            ("src/game/CombatTargetSelector.gd", "战斗目标选择、距离过滤、线段命中查询和目标排序。"),
            ("src/game/CombatEffectLog.gd", "战斗效果显示队列、命令日志和上限裁剪。"),
            ("src/game/CombatSpawnRuntime.gd", "刷怪组队列推进、批量生成、出生位置和波次数值系数。"),
            ("src/game/CombatAreaRuntime.gd", "区域效果创建、生命周期 tick 和区域 tick 事件路由。"),
            ("src/game/CombatProjectileRuntime.gd", "投射物延迟生成、飞行推进、命中事件路由和即时投射物表现。"),
            ("src/game/CombatProjectileFactory.gd", "投射物 spawn delay、origin、target context 和 projectile 字典构造。"),
            ("src/game/CombatDamageRuntime.gd", "伤害结算、状态应用、持续伤害 tick、元素判定和暴击判定。"),
            ("src/game/CombatMonsterRuntime.gd", "怪物移动推进、到墙攻击、死亡经验、Boss 死亡标记和实体查找/索引。"),
            ("src/game/CombatCommandPayload.gd", "战斗命令 target 数组标准化、爆炸中心和爆炸半径 payload 解析。"),
            ("src/game/CombatCommandRuntime.gd", "战斗 query targets 服务和击退命令执行。"),
            ("src/game/CombatUnitScale.gd", "战斗半径和投射物速度等单位换算公式。"),
            ("src/game/modules/combat/skills/thermobaric/ThermobaricEvents.gd", "温压弹事件常量和 route public API facade。"),
            ("src/game/modules/combat/skills/thermobaric/ThermobaricRouteTable.gd", "温压弹 cast/hit/resolved route 阶段组合。"),
            ("src/game/modules/combat/skills/thermobaric/ThermobaricCastRoutes.gd", "温压弹 cast 阶段投射物生成 route。"),
            ("src/game/modules/combat/skills/thermobaric/ThermobaricHitRoutes.gd", "温压弹冲击、爆炸、击退、燃烧、火花命中 hit route。"),
            ("src/game/modules/combat/skills/thermobaric/ThermobaricResolvedRoutes.gd", "温压弹爆炸结束后火花投射物生成 resolved route。"),
            ("src/game/modules/combat/skills/electro_pierce/ElectroPierceEvents.gd", "电磁穿刺事件常量和 route public API facade。"),
            ("src/game/modules/combat/skills/electro_pierce/ElectroPierceRouteTable.gd", "电磁穿刺 cast/hit/resolved/tick route 阶段组合。"),
            ("src/game/modules/combat/skills/electro_pierce/ElectroPierceCastRoutes.gd", "电磁穿刺 cast 阶段投射物生成 route。"),
            ("src/game/modules/combat/skills/electro_pierce/ElectroPierceHitRoutes.gd", "电磁穿刺命中、麻痹、爆炸触发和裂变粒子 hit route。"),
            ("src/game/modules/combat/skills/electro_pierce/ElectroPierceResolvedRoutes.gd", "电磁穿刺爆炸和矩阵区域生成 resolved route。"),
            ("src/game/modules/combat/skills/electro_pierce/ElectroPierceTickRoutes.gd", "电磁矩阵 tick 查询、伤害和减速 route。"),
            ("src/game/modules/combat/skills/dry_ice/DryIceEvents.gd", "干冰弹事件常量和 route public API facade。"),
            ("src/game/modules/combat/skills/dry_ice/DryIceRouteTable.gd", "干冰弹 cast/hit/resolved route 阶段组合。"),
            ("src/game/modules/combat/skills/dry_ice/DryIceCastRoutes.gd", "干冰弹 cast 阶段穿透投射物生成 route。"),
            ("src/game/modules/combat/skills/dry_ice/DryIceHitRoutes.gd", "干冰弹命中伤害、击退、冻结、冻伤和小冰晶 hit route。"),
            ("src/game/modules/combat/skills/dry_ice/DryIceResolvedRoutes.gd", "干冰弹首次命中分裂小冰晶 resolved route。"),
            ("src/game/LevelRewardRuntime.gd", "升级三选一运行时、已选次数、升级应用和新卡获得事件。"),
            ("src/game/WaveRuntimeState.gd", "波次配置、推进、spawn log、Boss 标记和战斗清场判断。"),
            ("src/game/GameSnapshotBuilder.gd", "玩法运行时 snapshot facade，负责分段字段合并顺序和战斗 snapshot 合并入口。"),
            ("src/game/GameSnapshotSections.gd", "玩法运行时 snapshot 分段字段组装 helper，负责核心、成长资源、卡牌、连锁和运行时日志字段。"),
            ("src/game/UpgradePoolLoader.gd", "升级三选一奖励池 JSON/CSV 读取、短期默认池 fallback、权重、前置和互斥字段解析。"),
            ("src/game/ContentUnits.gd", "关卡、波次、怪物规格和默认波次兜底的数据入口。"),
            ("src/game/AssetRegistry.gd", "运行时素材清单；正式素材接入优先走这里或明确表现脚本。"),
            ("src/game/GameEvents.gd", "通用事件总线，解耦玩法、反馈、音效和成就。"),
            ("src/game/FeedbackDirector.gd", "震屏、闪白、浮字、VFX 等反馈入口。"),
            ("src/game/AudioDirector.gd", "音效和音频反馈入口。"),
            ("src/game/AchievementStore.gd", "本地成就定义、解锁和保存。"),
            ("src/game/ProgressStore.gd", "本地进度保存。"),
            ("src/game/modules/", "可拔插游戏模块；接入前先读 MODULES 和 ARCHITECTURE_RULES。"),
            ("src/ui/Hud.gd", "HUD 动态数值、状态刷新、按钮回调、Tween 和反馈动画。"),
            ("src/ui/HudSetupCoordinator.gd", "HUD 初始化 wiring，负责控制器 setup、层级/鼠标过滤、信号连接、FX/overlay/presenter setup。"),
            ("src/ui/HudBattleUiFlow.gd", "HUD 战斗 UI 生命周期编排，负责开始/停止战斗 UI、暂停/继续/退出、阻塞 overlay 判断和统一 FX reset。"),
            ("src/ui/HudDiscardHandFlow.gd", "HUD 弃牌 UI flow，负责弃牌按钮响应、弃牌动画完成回调和阻塞文案拼装。"),
            ("src/ui/HudHandQueries.gd", "HUD 手牌几何和只读查询 helper，负责当前手牌数量、点位命中、panel 索引、拖拽重排目标和卡名查询。"),
            ("src/ui/HudSnapshotPresenter.gd", "HUD snapshot 基础状态字段呈现，负责时间、关卡、波次、经验、血量、护盾、弹药、能量和英雄名刷新。"),
            ("src/ui/HudCardSnapshotPresenter.gd", "HUD 手牌 snapshot 呈现，负责把手牌卡牌数据写入已有 card widget，不负责节点复制、布局或动效。"),
            ("src/ui/HudPileOverlay.gd", "牌堆/弃牌堆弹窗 facade，负责显示状态、布局、卡牌重建和关闭输入。"),
            ("src/ui/HudPileOverlayView.gd", "牌堆/弃牌堆弹窗稳定节点树 facade，负责遮罩、居中容器、面板和内容列编排。"),
            ("src/ui/HudPileOverlayHeaderView.gd", "牌堆/弃牌堆弹窗标题栏、标题 label 和关闭按钮创建。"),
            ("src/ui/HudPileOverlayContentView.gd", "牌堆/弃牌堆弹窗滚动区、卡牌网格容器和空状态 label 创建。"),
            ("src/ui/HudCardInteraction.gd", "HUD 手牌输入状态机，负责键盘/鼠标/拖拽/重排/取消的状态推进。"),
            ("src/ui/HudCardInteractionPort.gd", "HUD 手牌交互对 Hud.gd 的纯接口适配，集中几何查询、冷却查询、出牌/重排请求和提示反馈调用。"),
            ("src/ui/HudCardVisuals.gd", "HUD 手牌视觉生命周期 facade，只编排手牌可见性、feel state、目标变换、反馈叠加、按压 FX 和插值应用。"),
            ("src/ui/HudCardVisualTarget.gd", "HUD 手牌目标变换 facade，只编排槽位、运动和按压 helper。"),
            ("src/ui/HudCardVisualTargetSlots.gd", "HUD 手牌基础槽位、重排预览、悬浮扩散和边界夹取计算。"),
            ("src/ui/HudCardVisualTargetMotion.gd", "HUD 手牌拖拽、可出牌拖拽、悬浮和选中目标运动计算。"),
            ("src/ui/HudCardVisualTargetPress.gd", "HUD 手牌按压倾斜、位移和缩放目标变换。"),
            ("src/ui/HudCardPressFeedback.gd", "HUD 手牌悬浮按压命中区域、卡面点、抬升点和按压法线计算。"),
            ("src/ui/HudCardVisualFeedback.gd", "HUD 手牌无效、抽牌、获卡、弃牌和连锁费用提示反馈叠加。"),
            ("src/ui/HudCardVisualInterpolator.gd", "HUD 手牌目标位置、缩放、旋转和 z-index 的最终插值应用。"),
            ("src/ui/HudCardWidgets.gd", "HUD 卡牌控件创建、文本填充、费用状态和手牌排布入口。"),
            ("src/ui/HudCardArtBinder.gd", "HUD 卡牌卡框/卡图 TextureRect 创建、流派图标路径和纹理加载。"),
            ("src/ui/HudCardLabelStyler.gd", "HUD 卡牌标签样式 facade 和兼容缩放 API。"),
            ("src/ui/HudCardLabelStyleGroups.gd", "HUD 卡牌费用、插图、名称、类型、描述和流派标签字体、颜色、描边和 stylebox 分组应用。"),
            ("src/ui/HudCardNodeFinder.gd", "HUD 卡牌相关递归节点查找和 unique name 清理 helper。"),
            ("src/ui/HudCardChainHintWidget.gd", "HUD 连锁费用提示 facade，保留 widget 字典同步、费用徽章闪光和珍珠闪烁更新。"),
            ("src/ui/HudCardChainHintNodes.gd", "HUD 连锁费用提示 glow panel、sparkle label 查找/创建和基础样式。"),
            ("src/ui/HudCardReadabilityRegions.gd", "HUD 卡牌可读区布局 facade，只编排矩形数据、装饰层和文字区应用。"),
            ("src/ui/HudCardReadabilityRegionFrames.gd", "HUD 卡牌费用、名称、插图、描述、流派和连锁费用闪光挂点的纯矩形数据。"),
            ("src/ui/HudCardReadabilityLayerApplier.gd", "HUD 卡牌框、禁用遮罩、连锁费用闪光和按压反馈层布局应用。"),
            ("src/ui/HudCardReadabilityTextApplier.gd", "HUD 卡牌费用、名称、类型、插图、描述和流派文本区布局应用。"),
            ("src/ui/HudCardDescriptionText.gd", "HUD 卡牌描述 RichTextLabel 创建、旧 DescLabel 兼容隐藏和 BBCode 文本应用。"),
            ("src/ui/HudCardHandLayout.gd", "HUD 手牌排布、重叠间距、基础位置/旋转/z-index 和 snap 状态。"),
            ("src/ui/HudLayoutStyler.gd", "HUD 响应式布局、稳定区域尺寸、手牌布局触发和终极条锁图标。"),
            ("src/ui/HudLayoutStyleApplier.gd", "HUD 静态主题应用 facade，只编排面板、标签和控件样式 helper。"),
            ("src/ui/HudLayoutPanelStyleApplier.gd", "HUD 面板样式 facade，只保留兼容入口并委托分组 helper。"),
            ("src/ui/HudLayoutPanelStyleGroups.gd", "HUD 面板、徽章、手牌区域和菜单/暂停面板 stylebox 分组应用。"),
            ("src/ui/HudLayoutLabelStyleApplier.gd", "HUD 非卡牌标签样式 facade，只保留兼容入口并委托分组 helper。"),
            ("src/ui/HudLayoutLabelStyleGroups.gd", "HUD 非卡牌标签基础样式、主菜单、暂停、战斗状态、资源/护盾和目标标签分组样式应用。"),
            ("src/ui/HudLayoutControlStyleApplier.gd", "HUD 按钮、进度条和结算 overlay 样式应用。"),
            ("src/ui/HudRewardOverlay.gd", "升级三选一奖励弹窗 facade，负责弹窗生命周期、按钮容器、输入和选择反馈。"),
            ("src/ui/HudRewardOverlayView.gd", "升级三选一奖励弹窗稳定节点树 facade，只保留兼容入口并委托节点 helper。"),
            ("src/ui/HudRewardOverlayViewNodes.gd", "升级三选一奖励弹窗遮罩、居中容器、面板、标题和选项容器节点创建。"),
            ("src/ui/HudRewardChoiceButtons.gd", "升级三选一奖励选项按钮清空、创建、样式和 pressed 信号绑定。"),
            ("src/ui/HudRewardChoiceContent.gd", "升级三选一奖励选项内容 facade，保留兼容入口并委托节点和文本 helper。"),
            ("src/ui/HudRewardChoiceContentNodes.gd", "升级三选一奖励选项卡标题、描述、流派行和角标节点树构建。"),
            ("src/ui/HudRewardChoiceText.gd", "升级三选一奖励选项标题、描述、费用/流派数量文本、类型标签和签名规则。"),
            ("src/ui/HudRewardChoiceBadges.gd", "升级三选一奖励选项徽章 facade，保留费用、类型、同费用/同流派数量徽章兼容入口。"),
            ("src/ui/HudRewardChoiceCostBadge.gd", "升级三选一奖励选项费用徽章和同费用数量 label 节点树与样式构建。"),
            ("src/ui/HudRewardChoiceEntryTypeBadge.gd", "升级三选一奖励选项类型徽章的 holder、panel、margin 和 label 节点树与样式构建。"),
            ("src/ui/HudRewardChoiceSchoolBadge.gd", "升级三选一奖励选项流派徽章、同流派数量 label 和流派行节点树与样式构建。"),
            ("src/ui/MainMenuScreen.gd", "独立主界面逻辑，读取关卡配置并发出开始关卡信号。"),
            ("src/ui/HudDrawCardFx.gd", "牌堆抽牌飞入手牌的计数同步、FX 队列状态、飞行动画更新、牌堆脉冲和到达反馈。"),
            ("src/ui/HudDrawCardFxSpawn.gd", "牌堆抽牌飞行动效的目标校验、卡牌节点复制初始化、起点和 fx 数据构造。"),
            ("src/ui/HudDiscardHandFx.gd", "整手弃牌飞入弃牌堆的生命周期、FX 队列状态、飞行动画更新、弃牌堆脉冲和完成回调。"),
            ("src/ui/HudDiscardHandFxSpawn.gd", "整手弃牌飞行动效的目标校验、卡牌节点复制初始化和 fx 数据构造。"),
            ("src/ui/HudPlayCardFx.gd", "出牌飞行动效生命周期、卡牌复制、飞入/停留/溶解阶段编排。"),
            ("src/ui/HudPlayCardFxFragments.gd", "出牌溶解碎片节点创建、颜色、散开轨迹、碎片淡出和释放。"),
            ("src/ui/HudAcquireCardFx.gd", "获得新卡进入手牌/牌堆的事件同步、FX 队列状态、飞行动画更新和到达反馈。"),
            ("src/ui/HudAcquireCardFxSpawn.gd", "获得新卡飞行动效的事件解析、节点初始化、起终点/缩放/旋转和 fx 数据构造。"),
            ("src/ui/HudAcquireCardFxCardBuilder.gd", "获得新卡飞行动效的卡牌节点复制、纹理、文本和样式填充。"),
        ],
    ),
    (
        "素材与资源",
        [
            (".godot-api/extension_api.json", "Godot 引擎 API dump；供 godot-api-check 校验类、成员、信号、枚举和重载。"),
            ("assets/", "游戏运行时素材根目录；正式素材必须放在这里或 addons。"),
            ("assets/sprites/", "角色、敌人、目标、场景元素和动画帧。"),
            ("assets/ui/", "HUD 图标、按钮、面板、进度条和 UI sprite。"),
            ("assets/generated/runtime/", "生成后整理进入运行时的素材包。"),
            ("assets/generated/style_candidates/", "首启风格候选图；只能作为风格锚点，不能直接当运行时素材。"),
            ("addons/", "Godot addon 和运行时可加载扩展。"),
            ("addons/vfx_library/", "内置 VFX Library，默认只接轻量反馈。"),
            ("references/", "参考资料目录，禁止运行时代码直接加载。"),
        ],
    ),
    (
        "自动化脚本",
        [
            ("scripts/check_env.py", "环境检查，快速首启和完整检查入口。"),
            ("scripts/encoding_review.py", "UTF-8 文本解码、PowerShell 问号替换和 Excel CSV BOM 规则检查。"),
            ("scripts/ai_context.py", "输出接续执行包，供新会话快速恢复上下文。"),
            ("scripts/generate_project_map.py", "生成本文件，维护 AI 最小导航。"),
            ("scripts/new_game_concept.py", "创建新游戏概念并归档旧项目文档。"),
            ("scripts/design_input.py", "保存用户原始长设定和 AI 提炼稿。"),
            ("scripts/generate_style_candidates.py", "生成首启风格候选图。"),
            ("scripts/process_spritesheet.py", "清理、切分、对齐和验证 spritesheet，输出 pipeline-meta。"),
            ("scripts/make_sprite_layout_guide.py", "生成 spritesheet 或 prop pack 的布局安全区参考图。"),
            ("scripts/extract_prop_pack.py", "从生成的 prop pack 提取透明道具并输出 prop-pack 元数据。"),
            ("scripts/compose_layered_map_preview.py", "用 base map 和道具摆放 JSON 合成分层地图 QA 预览。"),
            ("scripts/art_pipeline_review.py", "美术管线和运行时素材证据审查。"),
            ("scripts/gameplay_logic_review.py", "玩法语义、胜负、输入、概念隔离审查。"),
            ("scripts/validate_data_configs.py", "关卡、波次、怪物和卡牌 JSON 配置结构及跨表引用校验。"),
            ("scripts/card_chain_rule_check.gd", "卡牌连锁规则专项 headless 检查，覆盖连续费用、断链、继承和正负数值缩放。"),
            ("scripts/experience_design_review.py", "首版内容差异、阶段变化和决策压力审查。"),
            ("scripts/architecture_review.py", "模块职责、层级越界和运行时引用边界审查。"),
            ("scripts/godot_quality_tools.py", "GDScript Toolkit 质量门禁，GDUnit4 可选。"),
            ("scripts/godot_headless_check.py", "Godot headless 场景加载检查。"),
            ("scripts/godot_runtime_log_check.py", "模拟编辑器运行并捕获 Godot 日志。"),
            ("scripts/export_web.py", "Web 导出。"),
            ("scripts/package_playable.py", "生成 Web 本地可游玩包，包含启动游戏.cmd、本地服务脚本、www 和 zip。"),
            ("scripts/package_windows.py", "生成原生 Windows 可游玩包，包含同名 exe、pck、README 和 zip。"),
            ("scripts/experience_check.py", "Web 自动试玩、截图和 canvas/输入探针。"),
            ("scripts/visual_readability_review.py", "截图、HUD 响应式和玩家视角可读性审查。"),
            ("scripts/ai_review.py", "严格自动 review 总入口。"),
            ("scripts/export_template.py", "导出干净脚手架模板。"),
            ("scripts/package_dist.py", "打包部署 zip。"),
        ],
    ),
    (
        "AI 协作与过程状态",
        [
            (".agents/skills/", "内置 Skill；Skill 负责流程，稳定项目事实应沉淀到 docs/project 或脚手架文档。"),
            (".agents/skills/godot-api-check/", "Godot API 校验 skill；改 Godot 引擎 API 前必须查询 extension_api.json。"),
            (".agents/roles/", "多 Agent 角色说明。"),
            (".pm/project/", "PM backlog、归档和 handoff 状态源；不要手动编辑 JSON。"),
            (".pm/workspaces/", "需求 workspace、notes 和 artifacts；过程记录放这里，不放长期设定。"),
            (".runtime/", "运行缓存和临时输出。"),
            ("reports/screenshots/", "体验检查和视觉审查截图证据。"),
            ("html5/", "Web 导出中间产物。"),
            ("exports/", "部署包输出。"),
            ("tools/", "portable Python、Node、Git、Godot、Export Templates、GodotMCP 等工具。"),
            ("spec/", "机器可读模板规格、玩法蓝图和模块目录。"),
        ],
    ),
]


READING_RULES = [
    "新会话先执行 PM 状态检查；继续具体需求时先运行 `pm_cli.py info <ID>` 获取 `summary.read_first`。",
    "定位需求后再读 `AGENTS.md`、本文件、`summary.read_first` 列出的文件和当前 workspace 的 `notes.md`。",
    "开发玩法、内容、美术和 UI 时，优先读 `docs/project/`；只有需要流程、工具链、导出或质量门禁时再读脚手架流程文档。",
    "不确定某个能力是否已有实现时，先查本文件的对应目录和示例索引，再用 `rg` 定位代码。",
    "用户提出的方案若和 AGENTS、项目地图或长期文档冲突，先指出冲突并给出更稳妥路径；不要为了迎合而绕过约束。",
    "会话接近压缩、跨线程继续或长任务切换时，先用 PM handoff 保存/恢复状态，并把长期有效结论同步到对应文档。",
]


EXAMPLE_INDEX = [
    ("玩法状态入口", "src/game/PrototypeState.gd", "public API、状态提交、胜负和规则编排入口；新增系统规则先按 AGENTS 拆模块。"),
    ("完整卡牌配置加载", "src/game/CardConfigLoader.gd", "从 assets/data/cards/card_configs.json 读取完整卡牌配置，不把卡牌规则表写回 PrototypeState 或脚本常量。"),
    ("牌堆运行时", "src/game/CardDeckState.gd", "手牌/牌堆/弃牌堆移动、补牌和卡牌奖励落点示例。"),
    ("出牌运行时", "src/game/CardPlayRuntime.gd", "出牌锁、同名冷却、复制牌记忆、pending bonus 和命中后奖励示例。"),
    ("卡牌连锁状态", "src/game/CardChainState.gd", "连续费用链、链倍率和同流派前置效果继承入口。"),
    ("卡牌连锁规则", "src/game/CardChainRules.gd", "卡牌效果表、正面数值缩放和基础连锁倍率规则。"),
    ("卡牌连锁参数", "src/game/CardChainParamRules.gd", "连锁可变文本参数、BBCode 高亮和 starter 运行时缩放示例。"),
    ("卡牌文本加载", "src/game/CardTextLoader.gd", "卡牌 CSV/JSON 文案、费用和显示字段覆盖示例。"),
    ("核心技能 payload", "src/game/CoreSkillPayloadBuilder.gd", "cast event、preview payload 和卡牌链加成构造示例。"),
    ("starter 卡效果", "src/game/StarterCardEffectResolver.gd", "枪械 buff、治疗、护盾、标记、眩晕和成长牌解析示例。"),
    ("枪械运行时", "src/game/GunRuntimeState.gd", "弹药、换弹、开火、临时 buff、核心技能 runtime 和 shot log 示例。"),
    ("枪械事件入口", "src/game/modules/combat/gun/GunEvents.gd", "事件常量、register 和 get_routes 兼容 facade 示例。"),
    ("枪械 route 表", "src/game/modules/combat/gun/GunRouteTable.gd", "cast/hit/resolved route 阶段组合示例。"),
    ("枪械 cast route", "src/game/modules/combat/gun/GunCastRoutes.gd", "开火投射物生成 route 示例。"),
    ("枪械 hit route", "src/game/modules/combat/gun/GunHitRoutes.gd", "子弹命中、爆炸触发和分裂触发 hit route 示例。"),
    ("枪械 resolved route", "src/game/modules/combat/gun/GunResolvedRoutes.gd", "爆炸查询/伤害和分裂子弹生成 resolved route 示例。"),
    ("战斗运行时 facade", "src/game/CombatRuntime.gd", "战斗 tick 编排、事件路由服务入口和实体数组状态维护示例。"),
    ("战斗快照组装", "src/game/CombatSnapshotBuilder.gd", "active monsters/projectiles/areas/effects/log 的只读 snapshot 示例。"),
    ("怪物规格读取", "src/game/CombatMonsterCatalog.gd", "默认怪物规格和 ContentUnits 自定义覆盖读取示例。"),
    ("战斗目标选择", "src/game/CombatTargetSelector.gd", "目标排序、距离过滤、随机偏移和线段命中查询示例。"),
    ("战斗效果/日志", "src/game/CombatEffectLog.gd", "战斗效果显示队列、命令日志、生命周期 tick 和上限裁剪示例。"),
    ("刷怪队列运行时", "src/game/CombatSpawnRuntime.gd", "刷怪组推进、批量生成、出生分布和波次数值系数示例。"),
    ("战斗区域运行时", "src/game/CombatAreaRuntime.gd", "区域效果创建、生命周期 tick、tick payload 和区域 tick 路由示例。"),
    ("战斗投射物运行时", "src/game/CombatProjectileRuntime.gd", "投射物延迟生成、飞行推进、穿透命中和命中事件路由示例。"),
    ("战斗投射物构造", "src/game/CombatProjectileFactory.gd", "spawn delay、origin、target context 和 projectile 字典构造示例。"),
    ("战斗伤害运行时", "src/game/CombatDamageRuntime.gd", "伤害结算、状态应用、持续伤害 tick、元素和暴击判定示例。"),
    ("战斗怪物运行时", "src/game/CombatMonsterRuntime.gd", "怪物移动、到墙攻击、死亡经验、Boss 死亡标记和实体查找/索引示例。"),
    ("战斗命令 payload", "src/game/CombatCommandPayload.gd", "target 数组标准化、爆炸中心和爆炸半径 payload 解析示例。"),
    ("战斗命令服务", "src/game/CombatCommandRuntime.gd", "query targets 服务和击退命令执行示例。"),
    ("战斗单位换算", "src/game/CombatUnitScale.gd", "半径、投射物速度等单位换算公式示例。"),
    ("温压弹事件入口", "src/game/modules/combat/skills/thermobaric/ThermobaricEvents.gd", "事件常量和 get_routes 兼容 facade 示例。"),
    ("温压弹 route 表", "src/game/modules/combat/skills/thermobaric/ThermobaricRouteTable.gd", "cast/hit/resolved route 阶段组合示例。"),
    ("温压弹 cast route", "src/game/modules/combat/skills/thermobaric/ThermobaricCastRoutes.gd", "cast 阶段投射物生成 route 示例。"),
    ("温压弹 hit route", "src/game/modules/combat/skills/thermobaric/ThermobaricHitRoutes.gd", "冲击、爆炸、击退、燃烧和火花命中 hit route 示例。"),
    ("温压弹 resolved route", "src/game/modules/combat/skills/thermobaric/ThermobaricResolvedRoutes.gd", "爆炸结束后火花投射物生成 resolved route 示例。"),
    ("电磁穿刺事件入口", "src/game/modules/combat/skills/electro_pierce/ElectroPierceEvents.gd", "事件常量和 get_routes 兼容 facade 示例。"),
    ("电磁穿刺 route 表", "src/game/modules/combat/skills/electro_pierce/ElectroPierceRouteTable.gd", "cast/hit/resolved/tick route 阶段组合示例。"),
    ("电磁穿刺 cast route", "src/game/modules/combat/skills/electro_pierce/ElectroPierceCastRoutes.gd", "cast 阶段投射物生成 route 示例。"),
    ("电磁穿刺 hit route", "src/game/modules/combat/skills/electro_pierce/ElectroPierceHitRoutes.gd", "命中、麻痹、爆炸触发和裂变粒子 hit route 示例。"),
    ("电磁穿刺 resolved route", "src/game/modules/combat/skills/electro_pierce/ElectroPierceResolvedRoutes.gd", "爆炸和矩阵区域生成 resolved route 示例。"),
    ("电磁穿刺 tick route", "src/game/modules/combat/skills/electro_pierce/ElectroPierceTickRoutes.gd", "电磁矩阵 tick 查询、伤害和减速 route 示例。"),
    ("干冰弹事件入口", "src/game/modules/combat/skills/dry_ice/DryIceEvents.gd", "事件常量和 get_routes 兼容 facade 示例。"),
    ("干冰弹 route 表", "src/game/modules/combat/skills/dry_ice/DryIceRouteTable.gd", "cast/hit/resolved route 阶段组合示例。"),
    ("干冰弹 cast route", "src/game/modules/combat/skills/dry_ice/DryIceCastRoutes.gd", "cast 阶段穿透投射物生成 route 示例。"),
    ("干冰弹 hit route", "src/game/modules/combat/skills/dry_ice/DryIceHitRoutes.gd", "命中伤害、击退、冻结、冻伤和小冰晶 hit route 示例。"),
    ("干冰弹 resolved route", "src/game/modules/combat/skills/dry_ice/DryIceResolvedRoutes.gd", "首次命中分裂小冰晶 resolved route 示例。"),
    ("升级奖励运行时", "src/game/LevelRewardRuntime.gd", "三选一、已选次数、升级应用和卡牌获得事件示例。"),
    ("波次运行时", "src/game/WaveRuntimeState.gd", "波次推进、spawn log、Boss 标记和清场判断示例。"),
    ("玩法快照 facade", "src/game/GameSnapshotBuilder.gd", "HUD snapshot 分段合并顺序和战斗 snapshot 合并入口示例。"),
    ("玩法快照字段分组", "src/game/GameSnapshotSections.gd", "核心、成长、资源、牌堆、出牌、连锁和运行时日志字段组装示例。"),
    ("内容单元", "src/game/ContentUnits.gd", "关卡、波次或系统阶段差异的数据组织示例。"),
    ("运行时素材", "src/game/AssetRegistry.gd", "素材路径和 fallback 组织示例。"),
    ("场景战场背景绘制", "src/game/GameBattlefieldDrawer.gd", "战场底图、墙体 fallback、占位底座和 active_areas 区域提示绘制示例。"),
    ("场景战斗效果绘制", "src/game/GameCombatEffectDrawer.gd", "combat_effects 圆环、爆炸区域和电磁穿刺线光效绘制示例。"),
    ("场景伤害飘字绘制", "src/game/GameDamageFloatDrawer.gd", "combat_effects 玩家伤害数字、暴击强调和元素颜色绘制示例。"),
    ("场景投射物绘制", "src/game/GameProjectileDrawer.gd", "active_projectiles 的线段/弹体绘制和方向计算示例。"),
    ("Spritesheet 后处理", "scripts/process_spritesheet.py", "洋红背景清理、切帧、缩放对齐、触边检查和 pipeline-meta 输出。"),
    ("Prop pack 切分", "scripts/extract_prop_pack.py", "小型地图道具批量提取、触边检查和 prop-pack manifest 输出。"),
    ("HUD 动态逻辑", "src/ui/Hud.gd", "UI 状态刷新、提示和反馈动画示例。"),
    ("HUD 初始化 wiring", "src/ui/HudSetupCoordinator.gd", "HUD 控制器 setup、层级/鼠标过滤、信号连接和子组件注入示例。"),
    ("HUD 战斗 UI 生命周期", "src/ui/HudBattleUiFlow.gd", "开始/停止战斗 UI、暂停/继续/退出、阻塞 overlay 判断和统一 FX reset 示例。"),
    ("HUD 弃牌 UI flow", "src/ui/HudDiscardHandFlow.gd", "弃牌按钮响应、弃牌动画完成回调和阻塞文案拼装示例。"),
    ("HUD 手牌查询", "src/ui/HudHandQueries.gd", "当前手牌数量、点位命中、panel 索引、拖拽重排目标和卡名查询示例。"),
    ("HUD snapshot 呈现", "src/ui/HudSnapshotPresenter.gd", "snapshot 基础状态字段刷新到 HUD 标签和进度条的 presenter 示例。"),
    ("HUD 手牌 snapshot 呈现", "src/ui/HudCardSnapshotPresenter.gd", "手牌卡牌数据刷新到已有 card widget 的 presenter 示例。"),
    ("HUD 牌堆弹窗", "src/ui/HudPileOverlay.gd", "牌堆/弃牌堆弹窗显示、布局、卡牌重建和关闭输入示例。"),
    ("HUD 牌堆弹窗骨架 facade", "src/ui/HudPileOverlayView.gd", "牌堆/弃牌堆弹窗遮罩、居中容器、面板和内容列编排示例。"),
    ("HUD 牌堆弹窗标题栏", "src/ui/HudPileOverlayHeaderView.gd", "牌堆/弃牌堆弹窗标题 label 和关闭按钮创建示例。"),
    ("HUD 牌堆弹窗内容区", "src/ui/HudPileOverlayContentView.gd", "牌堆/弃牌堆弹窗滚动区、卡牌网格容器和空状态 label 创建示例。"),
    ("HUD 手牌输入状态机", "src/ui/HudCardInteraction.gd", "键盘/鼠标/拖拽/重排/取消的手牌交互状态推进示例。"),
    ("HUD 手牌交互接口", "src/ui/HudCardInteractionPort.gd", "手牌交互对 Hud.gd 的几何查询、冷却查询、出牌/重排请求和提示反馈适配示例。"),
    ("HUD 手牌视觉生命周期", "src/ui/HudCardVisuals.gd", "手牌可见性、feel state、目标变换、反馈叠加、按压 FX 和插值 helper 编排示例。"),
    ("HUD 手牌目标变换 facade", "src/ui/HudCardVisualTarget.gd", "槽位、运动和按压 helper 编排示例。"),
    ("HUD 手牌槽位目标", "src/ui/HudCardVisualTargetSlots.gd", "基础槽位、重排预览、悬浮扩散和边界夹取计算示例。"),
    ("HUD 手牌运动目标", "src/ui/HudCardVisualTargetMotion.gd", "拖拽、可出牌拖拽、悬浮和选中目标运动计算示例。"),
    ("HUD 手牌按压目标", "src/ui/HudCardVisualTargetPress.gd", "按压倾斜、位移和缩放目标变换示例。"),
    ("HUD 手牌按压反馈", "src/ui/HudCardPressFeedback.gd", "悬浮按压命中区域、卡面点、抬升点和按压法线计算示例。"),
    ("HUD 手牌反馈叠加", "src/ui/HudCardVisualFeedback.gd", "无效、抽牌、获卡、弃牌和连锁费用提示反馈叠加示例。"),
    ("HUD 手牌插值应用", "src/ui/HudCardVisualInterpolator.gd", "目标位置、缩放、旋转和 z-index 的最终插值应用示例。"),
    ("HUD 卡牌控件", "src/ui/HudCardWidgets.gd", "卡牌控件创建、文本填充、状态遮罩和手牌排布入口示例。"),
    ("HUD 卡牌贴图绑定", "src/ui/HudCardArtBinder.gd", "卡框/卡图 TextureRect 创建、流派图标路径和纹理加载示例。"),
    ("HUD 卡牌标签样式 facade", "src/ui/HudCardLabelStyler.gd", "卡牌标签样式兼容入口和缩放 API 示例。"),
    ("HUD 卡牌标签分组样式", "src/ui/HudCardLabelStyleGroups.gd", "费用、插图、名称、类型、描述和流派标签字体、颜色、描边和 stylebox 分组应用示例。"),
    ("HUD 卡牌节点查找", "src/ui/HudCardNodeFinder.gd", "卡牌相关递归节点查找和 unique name 清理 helper 示例。"),
    ("HUD 连锁费用提示", "src/ui/HudCardChainHintWidget.gd", "连锁费用提示 facade、widget 字典同步、费用徽章闪光和珍珠闪烁更新示例。"),
    ("HUD 连锁费用提示节点", "src/ui/HudCardChainHintNodes.gd", "连锁费用提示 glow panel、sparkle label 查找/创建和基础样式示例。"),
    ("HUD 卡牌可读区", "src/ui/HudCardReadabilityRegions.gd", "卡牌可读区 facade 示例，只编排矩形数据、装饰层和文字区应用。"),
    ("HUD 卡牌可读区矩形", "src/ui/HudCardReadabilityRegionFrames.gd", "卡牌费用、名称、插图、描述、流派和连锁费用闪光挂点矩形数据示例。"),
    ("HUD 卡牌可读区装饰层", "src/ui/HudCardReadabilityLayerApplier.gd", "卡框、禁用遮罩、连锁费用闪光和按压反馈层布局应用示例。"),
    ("HUD 卡牌可读区文字层", "src/ui/HudCardReadabilityTextApplier.gd", "费用、名称、类型、插图、描述和流派文本区布局应用示例。"),
    ("HUD 卡牌描述文本", "src/ui/HudCardDescriptionText.gd", "卡牌描述 RichTextLabel 创建、旧 Label 兼容隐藏和 BBCode 文本应用示例。"),
    ("HUD 手牌排布", "src/ui/HudCardHandLayout.gd", "手牌重叠间距、基础位置/旋转/z-index 和 snap 状态示例。"),
    ("HUD 响应式布局", "src/ui/HudLayoutStyler.gd", "响应式布局、稳定区域尺寸、手牌布局触发和终极条锁图标示例。"),
    ("HUD 静态样式 facade", "src/ui/HudLayoutStyleApplier.gd", "编排调用面板、标签和控件样式 helper，不承载具体大段样式。"),
    ("HUD 面板样式 facade", "src/ui/HudLayoutPanelStyleApplier.gd", "面板样式兼容入口示例，只委托分组 helper。"),
    ("HUD 面板分组样式", "src/ui/HudLayoutPanelStyleGroups.gd", "面板、徽章、手牌区域和菜单/暂停面板 stylebox 分组应用示例。"),
    ("HUD 标签样式 facade", "src/ui/HudLayoutLabelStyleApplier.gd", "非卡牌标签样式兼容入口示例，只委托分组 helper。"),
    ("HUD 标签分组样式", "src/ui/HudLayoutLabelStyleGroups.gd", "基础标签、主菜单、暂停、战斗状态、资源/护盾和目标标签分组样式应用示例。"),
    ("HUD 控件样式", "src/ui/HudLayoutControlStyleApplier.gd", "按钮、进度条和结算 overlay 样式应用示例。"),
    ("HUD 奖励弹窗", "src/ui/HudRewardOverlay.gd", "升级三选一弹窗生命周期、输入和选择反馈示例。"),
    ("HUD 奖励弹窗骨架 facade", "src/ui/HudRewardOverlayView.gd", "奖励弹窗稳定节点树兼容入口示例，只委托节点 helper。"),
    ("HUD 奖励弹窗节点树", "src/ui/HudRewardOverlayViewNodes.gd", "奖励弹窗遮罩、居中容器、面板、标题和选项容器节点创建示例。"),
    ("HUD 奖励选项按钮", "src/ui/HudRewardChoiceButtons.gd", "奖励选项按钮清空、创建、样式和 pressed 信号绑定示例。"),
    ("HUD 奖励选项内容 facade", "src/ui/HudRewardChoiceContent.gd", "奖励选项内容兼容入口示例，只委托节点和文本 helper。"),
    ("HUD 奖励选项节点树", "src/ui/HudRewardChoiceContentNodes.gd", "奖励选项卡标题、描述、流派行和角标节点树构建示例。"),
    ("HUD 奖励选项文本规则", "src/ui/HudRewardChoiceText.gd", "奖励选项标题、描述、费用/流派数量文本、类型标签和签名规则示例。"),
    ("HUD 奖励选项徽章 facade", "src/ui/HudRewardChoiceBadges.gd", "奖励选项费用、类型、同费用/同流派数量徽章兼容入口示例。"),
    ("HUD 奖励选项费用徽章", "src/ui/HudRewardChoiceCostBadge.gd", "奖励选项费用徽章和同费用数量 label 节点树与样式构建示例。"),
    ("HUD 奖励选项类型徽章", "src/ui/HudRewardChoiceEntryTypeBadge.gd", "奖励选项类型徽章 holder、panel、margin 和 label 节点树与样式构建示例。"),
    ("HUD 奖励选项流派徽章", "src/ui/HudRewardChoiceSchoolBadge.gd", "奖励选项流派徽章、同流派数量 label 和流派行节点树与样式构建示例。"),
    ("独立主界面", "scenes/ui/MainMenuScreen.tscn", "关卡选择、通关状态和开始入口示例。"),
    ("HUD 抽牌动效", "src/ui/HudDrawCardFx.gd", "牌堆抽牌飞入手牌的计数同步、FX 队列状态、飞行动画更新、牌堆脉冲和到达反馈示例。"),
    ("HUD 抽牌动效 spawn", "src/ui/HudDrawCardFxSpawn.gd", "牌堆抽牌飞行动效的目标校验、卡牌节点复制初始化、起点和 fx 数据构造示例。"),
    ("HUD 弃牌动效", "src/ui/HudDiscardHandFx.gd", "整手弃牌飞入弃牌堆的生命周期、FX 队列状态、飞行动画更新、弃牌堆脉冲和完成回调示例。"),
    ("HUD 弃牌动效 spawn", "src/ui/HudDiscardHandFxSpawn.gd", "整手弃牌飞行动效的目标校验、卡牌节点复制初始化和 fx 数据构造示例。"),
    ("HUD 出牌动效", "src/ui/HudPlayCardFx.gd", "出牌动效生命周期、卡牌复制、飞入/停留/溶解阶段编排示例。"),
    ("HUD 出牌碎片动效", "src/ui/HudPlayCardFxFragments.gd", "出牌溶解碎片节点创建、颜色、轨迹、淡出和释放示例。"),
    ("HUD 获得新卡动效", "src/ui/HudAcquireCardFx.gd", "获得新卡事件同步、FX 队列状态、飞行动画更新和到达反馈示例。"),
    ("HUD 获得新卡动效 spawn", "src/ui/HudAcquireCardFxSpawn.gd", "获得新卡事件解析、节点初始化、起终点/缩放/旋转和 fx 数据构造示例。"),
    ("HUD 获得新卡动效节点", "src/ui/HudAcquireCardFxCardBuilder.gd", "获得新卡飞行动效的卡牌节点复制、纹理、文本和样式填充示例。"),
    ("HUD 稳定骨架", "scenes/ui/Hud.tscn", "编辑器可见 HUD 节点、锚点布局和默认占位文案示例。"),
    ("主场景骨架", "scenes/Game.tscn", "主场景只实例化战斗根、主界面和 HUD 场景的结构示例。"),
    ("反馈入口", "src/game/FeedbackDirector.gd", "震屏、浮字、闪白和 VFX 接入示例。"),
    ("音频入口", "src/game/AudioDirector.gd", "音效触发和音频职责边界示例。"),
    ("模块边界", "src/game/modules/", "可拔插模块职责拆分示例。"),
    ("Web 体验检查", "scripts/experience_check.py", "浏览器预览、截图和输入探针脚本示例。"),
    ("数据配置校验", "scripts/validate_data_configs.py", "level_configs、monsters、waves 和 card_configs 的字段、数值和引用检查示例。"),
    ("卡牌连锁检查", "scripts/card_chain_rule_check.gd", "连续费用链、同流派继承、跨流派隔离和数值缩放断言。"),
    ("严格审查入口", "scripts/ai_review.py", "多维度 review 聚合和 FAIL/CONCERNS 处理示例。"),
    ("多 Agent 任务", "scripts/agent_task.py", "任务包和 allowed_paths 生成示例。"),
    ("Godot API 校验", ".agents/skills/godot-api-check/scripts/godot_api_check.py", "基于 .godot-api/extension_api.json 精确验证引擎类、成员、信号、枚举、单例和工具函数。"),
]


def _exists_mark(path_text: str) -> str:
    if path_text in FIXED_STATUS:
        return FIXED_STATUS[path_text]
    normalized = path_text.rstrip("/")
    path = PROJECT_ROOT / normalized
    return "存在" if path.exists() else "待创建/按需"


def build_markdown() -> str:
    lines: list[str] = [
        "# 项目地图",
        "",
        "本文件由 `python scripts/generate_project_map.py` 生成，用于给 AI Agent 提供最小导航。它不是全量文件清单；只记录稳定入口、职责边界、常用示例和接力读取规则。",
        "",
        "不要手动编辑本文件；新增稳定目录、核心脚本或长期文档时，先更新 `scripts/generate_project_map.py`，再重生成。",
        "",
        "## 读取规则",
        "",
    ]
    lines.extend(f"- {rule}" for rule in READING_RULES)
    lines.append("")

    for title, items in SECTIONS:
        lines.extend([f"## {title}", ""])
        lines.append("| 路径 | 状态 | 作用 |")
        lines.append("|---|---|---|")
        for path, purpose in items:
            lines.append(f"| `{path}` | {_exists_mark(path)} | {purpose} |")
        lines.append("")

    lines.extend(["## 示例索引", ""])
    lines.append("| 场景 | 推荐先看 | 用途 |")
    lines.append("|---|---|---|")
    for scene, path, purpose in EXAMPLE_INDEX:
        lines.append(f"| {scene} | `{path}` | {purpose} |")
    lines.append("")

    lines.extend(
        [
            "## 维护规则",
            "",
            "- 新增稳定目录、核心脚本或长期文档时，先更新 `scripts/generate_project_map.py`，再重生成本文件。",
            "- 本文件是生成产物；`python scripts/generate_project_map.py --check` 会做完整内容比较，手动改动会导致 review 失败。",
            "- 不把临时需求、一次性推演或用户未确认的设定写入本文件；这些内容属于 `.pm/` 或 `docs/design-inputs/`。",
            "- 不用本文件替代具体规范。真正开发前仍需读取对应的项目文档、脚手架流程文档或源码示例。",
            "",
        ]
    )
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description="生成 AI 项目地图")
    parser.add_argument("--output", default=str(DEFAULT_OUTPUT), help="输出路径，默认 docs/project-map.md")
    parser.add_argument("--check", action="store_true", help="只检查输出文件是否最新")
    parser.add_argument("--print", dest="print_stdout", action="store_true", help="打印到 stdout，不写文件")
    args = parser.parse_args()

    content = build_markdown()
    output_path = Path(args.output)
    if not output_path.is_absolute():
        output_path = PROJECT_ROOT / output_path

    if args.print_stdout:
        print(content)
        return 0

    if args.check:
        current = output_path.read_text(encoding="utf-8") if output_path.exists() else ""
        if current != content:
            print(f"{output_path.relative_to(PROJECT_ROOT).as_posix()} 不是最新，请运行 python scripts/generate_project_map.py")
            return 1
        print(f"{output_path.relative_to(PROJECT_ROOT).as_posix()} 已是最新。")
        return 0

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(content, encoding="utf-8", newline="\n")
    print(f"写入 {output_path.relative_to(PROJECT_ROOT).as_posix()}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
