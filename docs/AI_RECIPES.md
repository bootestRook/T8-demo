# AI 接入配方

这份文档给 AI 快速接入常见玩法能力。先选最小配方，不要一次启用整套系统。

## 新玩法内容单元

1. 在 `docs/game-concept.md` 写清目标、核心操作、结束条件、3 个内容单元差异和素材落地状态。
2. 在 `PrototypeState.gd` 定义阶段、数值、胜负、重开和对外信号。
3. 在 `Game.gd` 接输入、对象同步、碰撞或点击命中。
4. 在 `Hud.gd` 显示目标、状态、结算和下一步。
5. 需要反馈时发 `GameEvents.FEEDBACK_REQUESTED` 或调用 `FeedbackDirector` 的现有入口。
6. 跑玩法、美术、体验和导出检查。

## 加输入处理

1. 先在 `project.godot` 的 Input Map 中确认或新增动作名，玩法代码只读 action，不硬编码键码。
2. 连续移动用 `Input.get_axis()` 或 `Input.get_vector()`，通常放在 `_physics_process()`。
3. 暂停、确认、攻击触发等一次性动作优先在 `_unhandled_input(event)` 里处理，并在需要时调用 `get_viewport().set_input_as_handled()`。
4. UI 打开、结算弹窗、暂停菜单出现时，明确当前是否还接收玩法输入。
5. 平台跳跃、动作、格斗等对手感敏感的玩法，再加输入缓冲、土狼时间或短时间容错；点击或低频操作不要默认加输入系统。
6. 只有用户明确要求设置、手柄/键鼠自定义或可访问性目标时，才加入输入重绑定和保存。

## 加场景组合

1. 先判断是否真的需要新 `.tscn`；能在现有 `Game.gd` 编排的小内容单元不要拆太早。
2. 新场景只负责一个实体或界面单元，例如玩家、敌人、拾取物、HUD 面板、关卡容器。
3. 根节点类型匹配职责：物理移动用 `CharacterBody2D`，触发检测用 `Area2D`，视觉装饰用 `Node2D`，UI 用 `Control`。
4. 外部只依赖导出参数、信号和少量公共方法，不依赖场景内部节点路径。
5. 关键稳定节点可以设 `%UniqueName` 并用 `%NodeName` 引用；普通子节点继续用清晰相对路径。
6. 节点树超过 3-4 层、主场景节点过多或职责混杂时，再拆子场景或模块。

## 维护 HUD / UI 场景

1. 稳定 UI 骨架进 `.tscn`：`CanvasLayer`、full rect `Control`、`MarginContainer`、顶部状态栏、中心提示/结算面板、底部提示或按钮。
2. 动态内容留在脚本：数值刷新、阶段文案、按钮回调、Tween、音效和反馈事件。
3. 空脚手架也要在编辑器里可读：默认占位文案说明当前目标、状态、下一步，不依赖运行时脚本才知道 HUD 在哪里。
4. 节点名表达玩家信息职责，例如 `ObjectiveLabel`、`StatusLabel`、`MessageLabel`、`RestartButton`；不要沿用 `Label1`、`HpLabel` 这类与具体玩法强绑定的名字作为模板契约。
5. 正式首版没有声明程序化占位时，再把 HUD 图标、按钮、面板、进度条或状态徽章素材放入 `assets/ui/` 并真实加载。

## 加波次或刷怪

1. 内容差异写进 `ContentUnits.gd` 或当前游戏的内容配置。
2. 实例化 `WaveDirector`，调用 `configure(waves)` 和 `start(index)`。
3. 监听 `spawn_requested(request)`，由 `Spawner` 或 `Game.gd` 生成敌人。
4. 敌人死亡、逃脱或超时后回到 `PrototypeState.gd` 结算波次。
5. HUD 显示当前波次、剩余目标和下一波提示。

## 加拾取和背包

1. 用 `ItemCatalog` 注册本轮实际会出现的 3-8 个物品。
2. 拾取节点挂 `Pickup`，碰到玩家时发 `pickup_collected`。
3. `Game.gd` 或规则模块把拾取转换为 `InventoryStore.add_item()`。
4. HUD 只显示背包摘要或关键物品数量，不直接改背包。
5. 需要存档时把 `InventoryStore.serialize/deserialize` 注册给 `SaveStore`。

## 加装备或属性

1. `ItemCatalog` 标明装备槽位和基础属性。
2. `InventoryStore` 负责持有物品。
3. `EquipmentStore` 负责装备槽位和属性汇总。
4. `PrototypeState.gd` 查询属性汇总并用于伤害、速度或防御。
5. 不在装备模块里直接决定胜负。

## 加任务或对话

1. `QuestStore.register_quest()` 定义任务目标。
2. 玩法事件发生时调用 `add_progress()`。
3. 对话用 `DialogueRunner` 逐行推进，UI 只负责展示当前行。
4. 任务完成后由 `PrototypeState.gd` 或当前规则模块决定奖励、解锁或结算。

## 加存档

1. 数据模块实现 `serialize()` 和 `deserialize(data)`。
2. 创建 `SaveStore` 或使用当前游戏已有存档入口。
3. 用 `register_provider(id, save_callable, load_callable)` 注册模块。
4. 保存内容必须有 `version`，读不到文件时保持默认初始状态。
5. 不把临时表现节点、粒子、一次性动画写进存档。

## 加 Resource 配置

1. 只有武器、敌人、关卡、卡牌等配置需要复用或编辑器配置时才新增 `Resource`。
2. 资源脚本只放配置字段和少量校验，不承载胜负、输入、UI 或场景节点逻辑。
3. 每局会变化的生命、耐久、冷却、随机词条等必须从模板 `duplicate()` 出运行时副本。
4. 配置资源路径放在 `assets/` 或当前游戏数据目录，并由 `AssetRegistry.gd` 或内容配置统一引用。
5. 读不到资源时提供清晰错误或降级占位，不从 `references/` 运行时加载。

## 加对象池

1. 仅用于高频生成对象，例如子弹、伤害数字、命中爆裂、掉落碎片。
2. 先确认普通实例化已经有卡顿风险或对象生命周期非常短；低频对象直接实例化更清楚。
3. 池化对象提供 `on_spawn()`、`on_despawn()` 或等效重置入口，避免残留速度、计时器、可见性、碰撞状态。
4. 回收到池时禁用处理和隐藏节点，不直接 `queue_free()`。
5. 对象池只管理生命周期，不决定分数、胜负或关卡推进。

## 加角色状态

1. 少量阶段优先在当前脚本用 enum / `match` 表达。
2. 只有动作分支明显增多，且每个状态都有独立进入、退出、输入和物理逻辑时，才新增节点状态机。
3. 状态机只管理角色局部行为，不接管一局游戏阶段和结算。
4. 状态切换用显式方法或信号通知规则层，不让状态节点直接改 HUD 或进度存档。
5. 改完后检查状态名、输入动作和动画名是否有缺失分支。

## 加场景切换

1. 单主场景首版优先重开当前局，不新增通用场景管理器。
2. 出现主菜单、关卡选择、加载界面、转场复用或多主场景时，再创建轻量 `SceneManager`。
3. 场景切换入口只负责加载和替换场景，不承载玩法规则或存档结构。
4. 异步加载只在场景资源明显较大、切换会卡顿或需要进度 UI 时使用。
5. Web 导出后必须跑运行日志和浏览器体验检查，确认切换没有白屏。

## 加菜单和结算

1. 结算结果由 `PrototypeState.gd` 产生。
2. `Hud.gd` 或 `MenuPresenter` 展示标题、表现、重试/下一关按钮。
3. 按钮发意图，例如 `start`、`retry`、`next_unit`。
4. `Game.gd` 把 UI 意图转发给 `PrototypeState.gd` 或场景切换模块。

## 加反馈、音效和 VFX

1. 玩法命中、受伤、拾取、胜利、失败时发事件或调用 director。
2. `FeedbackDirector` 处理震屏、闪白、浮字、轻量 VFX。
3. `AudioDirector` 处理基础音效。
4. 不在敌人、拾取物或 HUD 里复制反馈实现。

## 加 2D 动画反馈

1. 先选动画主控：简单帧动画用 `AnimatedSprite2D`，多属性时间轴或命中帧同步用 `AnimationPlayer`，复杂混合再考虑 `AnimationTree`。
2. 同一可见属性只交给一个主控，避免 AnimationPlayer、Tween 和代码同时改 `frame`、`animation`、`scale`、`modulate` 等属性。
3. `AnimatedSprite2D` 节点用 `@onready` 缓存；`SpriteFrames` 优先共享或 `preload()`，不要在热路径反复 `load()`。
4. 循环动画用 `animation_looped` 触发脚步、尘土等循环反馈；一次性攻击、受击、死亡动画才用 `animation_finished` 回到 idle 或结算。
5. 切换动画并同步翻转、朝向或材质时，如果出现一帧错位，在 `play()` 后调用 `advance(0)`。
6. 需要保留动画进度换皮肤或替换 `SpriteFrames` 时，记录 `frame` / `frame_progress`，再用 `set_frame_and_progress()` 恢复。
7. 命中帧、脚步声、发射点、伤害窗口通过 `frame_changed`、Method Track 或 Value Track 绑定，不用裸 `Timer` 猜时间。
8. UI pop、受击闪白、squash/stretch 用 Tween 或轻量脚本即可；同一属性启动新 Tween 前先 `kill()` 旧 Tween。
9. 2D 骨骼、IK、AnimationTree、MultiMesh 和 Shader 批量动画只在动作复杂度或实体数量已经需要时接入，不作为首版默认方案。

## GDScript 性能小检查

1. `_process()`、`_physics_process()` 和大量循环里不要反复 `$Node` / `get_node()`，用 `@onready` 缓存。
2. 热路径中避免每帧新建临时数组、字典、`PackedScene.instantiate()`；需要时复用容器或引入对象池。
3. 不需要每帧处理的节点用 `set_process(false)` 或 `set_physics_process(false)` 关闭。
4. 信号、公共方法、导出字段和复杂集合尽量写类型。
5. 跨帧持有节点引用时使用 `is_instance_valid()`，不要只靠 `node != null`。
6. 需要频繁找同类节点时，用生成/销毁事件维护集合，不要每帧 `get_nodes_in_group()`。
7. 优化只针对实际热路径，不为了“看起来专业”提前重构。

## 改完必查

```bash
python scripts/gameplay_logic_review.py
python scripts/art_pipeline_review.py
python scripts/experience_design_review.py
python scripts/godot_quality_tools.py --json
python scripts/godot_headless_check.py
python scripts/godot_runtime_log_check.py
python scripts/export_web.py --json
python scripts/experience_check.py --strict
python scripts/ai_review.py --strict
```
