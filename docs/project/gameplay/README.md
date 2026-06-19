# 玩法总览

## 核心循环

- 应用启动显示主菜单，玩家查看通关状态并选择已解锁关卡。
- 点击开始后加载该关卡的 20 波配置，重置 `PrototypeState`，进入战斗 HUD。
- 战斗中怪物沿竖屏战场路线压向防线；玩家依靠自动枪械火力和手牌出牌清怪。
- 手牌通过能量、冷却、出牌锁、弃牌冷却和牌堆/弃牌堆形成资源压力。
- 连续费用递增可维持连锁，同流派卡继承前置正面效果；弃牌、跳费或同费会重启/中断当前连锁。
- 升级时弹出三选一奖励，选择后回到战斗。
- 清完关卡波次且防线未毁为胜利；防线生命归零为失败；结算可返回主菜单或重开。

## 首版范围

- 目标层级：竖屏 2D 卡牌连锁 + 塔防/幸存者战斗 Demo。
- 当前已落地 5 个关卡配置，每关 20 波，关卡差异来自怪物组合、数量、系数、节奏和 Boss 波。
- 当前不新增大玩法，不改数值表现，不改美术资源。
- 防御塔建造、背包、经济、联网、排行榜等不属于当前 Demo 范围。

## 启用系统

- 主菜单与关卡解锁：`MainMenuScreen.gd` + `ProgressStore.gd`。
- 关卡/怪物/波次配置：`ContentUnits.gd` + `assets/data/combat/*.json`。
- 战斗状态 facade：`PrototypeState.gd`。
- 战斗实体运行时：`CombatRuntime.gd` 及 combat helper。
- 卡牌配置、牌堆、出牌、连锁：`CardConfigLoader.gd`、`CardDeckState.gd`、`CardPlayRuntime.gd`、`CardChainState.gd`。
- 核心技能：温压弹、干冰弹、电磁穿刺、枪械事件路由。
- HUD rendered state：`Hud.gd` 读取 snapshot 并转发到已有 helper。

## 启动生命周期

- 应用启动：`project.godot` 进入 `scenes/Game.tscn`，实例化 `MainMenuScreen` 和 `Hud`。
- 显示主菜单：`Game._ready()` 只连接信号、加载表现层资源并调用 `_show_main_menu()`；菜单阶段不重置战斗局。
- 选择关卡：`MainMenuScreen` 发出 `start_requested(level_id)`。
- 开始战斗：`Game._on_main_menu_start_requested()` 调用 `ContentUnits.load_combat_configs(level_id)` 和 `PrototypeState.reset()`，然后显示 HUD 并启动战斗 UI。
- 退出到主菜单：HUD 发出 `main_menu_requested`，`Game._show_main_menu()` 停止战斗 UI、隐藏 HUD、显示主菜单。
- 重新开始战斗：结算重开按钮、`R` 或 `ui_accept` 调用 `PrototypeState.reset()`，保留当前关卡配置。

## 系统边界

- `PrototypeState.gd` 拥有战斗局状态、public API、规则编排和统一 snapshot。
- `Game.gd` 负责场景编排、输入转发、表现层绘制和主菜单/战斗切换，不承载卡牌或战斗规则。
- `Hud.gd` 保留节点引用、生命周期入口、信号转发和少量 orchestration；纯查询、流程和表现刷新继续放到已有 helper。
- `ContentUnits.gd` 负责把 JSON/CSV 配置转成运行时关卡、波次和怪物规格。
- 数据配置校验由 `scripts/validate_data_configs.py` 执行，并作为 `scripts/godot_headless_check.py` 的前置门禁。

## 当前连锁规则

- 连锁不限制时间，弃牌中断连锁，倍率上限暂定 999。
- 任意费用都可以作为连锁起点，起点倍率为 x1。
- 只有按费用连续递增才续链，例如 0 -> 1 -> 2 -> 3。跳费和同费都会从当前卡重新开始 x1。
- 后置卡会继承当前连锁内同流派前置卡的效果。
- 后置卡的基准技能个数、基准正面数值，以及自身和继承来的正面数值相关效果，按当前链位倍率放大。
- 负面数值效果会继承，但不按链位倍率放大。
- 所有卡牌不限制释放距离；只要有可攻击目标且满足能量/冷却等条件即可出牌，HUD 不显示释放范围圈。

## 当前版万能牌规则

- 万能牌不消耗实际能量，词条费用显示 `X`，手牌费用位显示当前连锁预览值。
- 万能牌不是独立流派；流派万能牌归入对应流派，并参与连锁继承和流派判定。
- 温压弹万能牌：作为任意费用接入连锁，并释放 1 枚温压弹。
- 干冰弹万能牌：作为任意费用接入连锁，并释放 1 枚干冰弹。
- 电磁穿刺万能牌：作为任意费用接入连锁，并释放 1 次电磁穿刺。
- 通用万能牌：作为任意费用接入连锁，并复制前一张有效牌的效果；复制效果按当前连锁倍率结算。

## 详细文档

- 内容单元：`content-units.md`
- 数值：`balance.md`
- 系统：`systems/`
