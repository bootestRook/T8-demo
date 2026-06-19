# 当前游戏事实源

## 概念ID

- `vertical-card-defense-demo`

## 一句话目标

- 当前项目是竖屏 2D 卡牌连锁 + 塔防/幸存者战斗 Demo：玩家在 1080x1920 竖屏战场中守住防线，通过自动枪械射击、手牌出牌、费用连锁和升级三选一抵御 20 波怪物。

## 设定来源

- 用户原始输入：当前轮未提供新的长设定。
- 兼容事实源：`docs/game-concept.md`
- 当前运行时证据：`project.godot`、`scenes/Game.tscn`、`scenes/Game.gd`、`src/game/PrototypeState.gd`、`assets/data/combat/*.json`、`assets/data/cards/card_configs.json`

## 平台与目标层级

- 平台：Godot 4，Web/Windows，本地默认竖屏移动端画布 `1080x1920`。
- 目标层级：可试玩战斗 Demo，不是空脚手架。

## 核心玩法

- 应用启动先显示独立主菜单，不在菜单阶段初始化战斗局。
- 玩家选择已解锁关卡后开始战斗；关卡数据来自 `assets/data/combat/level_configs.json` 和 `waves.json`。
- 战斗中怪物从上方路线向防线推进；防线生命为 `PrototypeState.DEFAULT_WALL_HP = 3000`。
- 玩家手牌、牌堆、弃牌堆、费用、冷却和出牌锁由 `PrototypeState` 编排，HUD 只呈现 rendered state。
- 卡牌核心是连续费用连锁：按费用递增续链，同流派后置卡继承前置卡正面效果，弃牌断链。
- 胜利条件：当前关卡波次清场且防线未被摧毁。
- 失败条件：防线生命归零。
- 重开方式：结算重开按钮、战斗中 `R` 或 `ui_accept` 重置当前战斗。

## 玩法蓝图

- `common_loop`
- 塔防侧重点：路线、波次、基地生命/防线生命；当前不做防御塔建造。
- 关卡设计侧重点：关卡目标、空间、节奏和通关检查点；当前检查点体现为主菜单通关状态与下一关解锁。

## 详细文档索引

- 玩法总览：`docs/project/gameplay/README.md`
- 内容单元：`docs/project/gameplay/content-units.md`
- 数值与平衡：`docs/project/gameplay/balance.md`
- 系统文档：`docs/project/gameplay/systems/`
- 美术方向：`docs/project/art/art-direction.md`
- 风格指南：`docs/project/art/style-guide.md`
- UI/HUD：`docs/project/ui/hud-spec.md`

## 首版边界

- 当前已落地 5 个关卡配置，每关 20 波；第 5 关包含 Boss 波。
- 不在本轮新增玩法、卡牌、怪物、关卡、数值或美术资源。
- 本轮只同步事实源、收紧启动生命周期、轻拆 HUD 查询逻辑和补充数据配置校验。
- 复杂系统继续拆到独立系统文档；开发需求写入 `.pm/`。
