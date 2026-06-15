# 可拔插模块

本目录记录 `src/game/modules/` 下的游戏基础模块。空脚手架不预置玩法模块；新游戏确认玩法和系统边界后，再按需实例化、挂到对应场景或注册为 Autoload。

AI 选择模块前先读 `docs/ARCHITECTURE_RULES.md` 和 `docs/AI_RECIPES.md`。机器可读清单见 `spec/module_catalog.json`。

## 接入原则

- 一个模块只处理一个职责：移动、生成、拾取、背包、装备、任务、对话、波次、菜单、场景切换或教程。
- 模块通过信号和 `GameEvents` 对外通知，不直接改 `PrototypeState.gd`、HUD 或结算。
- 数据模块优先提供 `serialize()` / `deserialize()`，由 `SaveStore` 或具体游戏存档统一调用。
- 玩法规则仍以 `PrototypeState.gd` 为主；模块只提供能力，不决定胜负。
- 空脚手架不能默认注册物品、敌人、任务、对话或内容单元。

## 第一批模块

| 模块 | 层 | 文件 | 用途 |
|---|---|---|---|
| 输入配置 | 表现 | `InputProfile.gd` | 注册 WASD、方向键、主/副操作和取消动作。 |
| 玩家控制 | 表现 | `PlayerController2D.gd` | 俯视 2D 移动控制器，可直接挂到 `CharacterBody2D`。 |
| 敌人 AI | 规则 | `EnemyAI2D.gd` | 轻量追踪/游荡，不绑定伤害和胜负。 |
| 生成器 | 规则 | `Spawner.gd` | 按 `PackedScene` 和 payload 生成节点并发事件。 |
| 道具拾取 | 规则 | `Pickup.gd` | `Area2D` 拾取入口，发出 `pickup_collected`。 |
| 物品目录 | 数据 | `ItemCatalog.gd` | 物品定义、堆叠、类型和可装备槽位。 |
| 背包 | 数据 | `InventoryStore.gd` | 格子、堆叠、移除、换位和序列化。 |
| 装备栏 | 数据 | `EquipmentStore.gd` | 武器/护甲/饰品等槽位和属性汇总。 |
| 掉落表 | 规则 | `LootTable.gd` | 权重掉落，返回物品 id 和数量。 |
| 波次 | 规则 | `WaveDirector.gd` | 按时间发出生成请求，不直接生成敌人。 |
| 任务 | 数据 | `QuestStore.gd` | 任务目标、进度、完成状态和序列化。 |
| 对话 | 表现 | `DialogueRunner.gd` | 逐行推进对话数据，不绑定 UI 皮肤。 |
| 存档 | 工具 | `SaveStore.gd` | 注册 provider，统一保存/加载模块数据。 |
| 菜单 UI | 表现 | `MenuPresenter.gd` | 程序化开始/暂停/结算菜单，发出菜单动作。 |
| 场景切换 | 工具 | `SceneRouter.gd` | 统一场景切换、重载和失败信号。 |
| 教程提示 | 表现 | `TutorialHints.gd` | 一次性或可重复提示触发器。 |

## 推荐组合

动作/生存首版：

- `InputProfile`
- `PlayerController2D`
- `EnemyAI2D`
- `Spawner`
- `Pickup`
- `WaveDirector`
- `MenuPresenter`
- `TutorialHints`

RPG/暗黑/搜打撤首版：

- `ItemCatalog`
- `InventoryStore`
- `EquipmentStore`
- `LootTable`
- `Pickup`
- `SaveStore`
- `QuestStore`
- `MenuPresenter`

剧情/任务驱动首版：

- `DialogueRunner`
- `QuestStore`
- `TutorialHints`
- `SaveStore`
- `SceneRouter`

## 扩展系统接入

- 复杂词条、强化、套装、商店经济、多页仓库、行为树、寻路、阵营仇恨、技能系统、关卡编辑器、ECS、依赖注入容器和插件市场都可以按游戏目标扩展。
- 接入前必须写清玩家价值、职责边界、数据归属、UI/素材需求、存档关系和验收方式。
- 不为展示能力把模块接入空脚手架主场景；模块必须服务当前游戏概念或用户明确要求。
