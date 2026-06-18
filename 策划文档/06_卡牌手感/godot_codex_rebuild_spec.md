# Godot 卡牌手感框架研发规格书

这份文档用于交给 Codex，在一个 Godot 项目里复刻 Vampire Crawlers 的“卡牌手感架构”：输入响应、出牌队列、效果结算、动画/数值解耦、连续操作缓存与容错。

注意：这里复刻的是架构和交互手感，不复制 Vampire Crawlers 的源码、资源、文本、数值或美术。

## 给 Codex 的任务

请在当前 Godot 项目中实现一套可扩展的卡牌战斗框架。目标不是一次做完整游戏，而是先完成一个可以运行、可以调参、可以继续扩展的卡牌手感核心。

实现前必须先做环境检查：

1. 确认项目根目录存在 Godot 项目文件。
2. 确认项目内有 Godot API 导出文件，或先按项目规范生成。
3. 实现任何 Godot 脚本前，先用项目 API 导出校验引擎类、方法、属性、信号、注解和输入 API。
4. 优先沿用项目已有目录、命名、场景组织和 UI 框架。

如果当前项目还不是 Godot 项目，只生成脚本/资源/场景设计文档，不要硬写不可验证的代码。

## 目标体验

玩家应该能感受到：

- 卡牌悬停会抬起、放大、倾斜，离开时平滑回位。
- 鼠标拖动有跟手感，但不是瞬移；卡牌会根据移动速度轻微旋转。
- 手柄或键盘选择卡牌时，有明确焦点和长按进入操作的反馈。
- 卡牌拖到可出牌区域时，出现更强的缩放/高亮反馈。
- 费用不足或状态非法时，卡牌不改变牌堆，只播放无效反馈。
- 快速连点、连续拖拽、动画未播完时，不会导致同一张卡重复出牌或消失。
- 抽牌、弃牌、销毁、打出、回手、连击牌堆都有独立动画，但规则结果由模型层决定。
- 效果可以先预览，再撤销预览，再正式结算。

## 参考架构

Vampire Crawlers 的结构可抽象为五层：

```text
输入层
  控制方案、输入地图、输入层、UI 焦点、输入屏蔽

交互层
  悬停、选择、拖拽、长按、卡槽重排、当前交互卡唯一所有权

模型层
  玩家、卡牌实例、牌堆、费用、状态、回合、敌人、可否出牌

命令层
  串行消费规则命令、视图命令、等待命令

视图层
  卡牌移动、缩放、旋转、粒子、数值跳字、音效、无效反馈
```

Godot 实现时也按这五层拆，禁止把输入、规则、动画写进同一个大脚本。

## 推荐目录

根据项目现有结构调整；如果没有约定，可使用下面的组织：

```text
res://cards/
  defs/
  effects/
  feel/

res://combat/
  models/
  commands/
  states/
  services/

res://ui/cards/
  card_view
  pile_views
  hand_slots

res://tests/
  card_model_tests
  pile_tests
  command_runner_tests
  combat_flow_tests
```

具体文件扩展名和 Godot 类型由实现者在 API 校验后决定。

## 核心模块

### CardDef

静态卡牌配置。只保存卡牌定义，不保存运行时状态。

字段建议：

- `id`
- `name_key`
- `description_key`
- `card_type`
- `base_mana_cost`
- `cost_type`
- `max_level`
- `reward_weight`
- `card_limit`
- `on_play_effects`
- `on_draw_effects`
- `on_discard_effects`
- `on_end_turn_effects`
- `view_assets`
- `sound_assets`
- `feel_config_refs`

### CardInstance

运行时卡牌实例。每张进入牌堆的卡都必须是实例，不要直接把 `CardDef` 当运行时牌使用。

字段建议：

- `instance_id`
- `def_id`
- `current_level`
- `was_played`
- `is_free_to_play`
- `is_frozen`
- `temporary_cost_modifier`
- `turn_cost_modifier`
- `reduced_cost_modifier`
- `confuse_cost_modifier`
- `runtime_cost_type`
- `attached_modifiers`

职责：

- 计算当前费用。
- 判断自身是否可支付。
- 触发 `on_draw`、`on_play`、`on_discard`、`on_end_turn` 的效果列表。
- 在回合结束、遭遇结束、打出后重置临时状态。

### CardPile

纯模型牌堆。只负责卡牌数组和事件，不播放动画。

必须支持：

- 加到顶端。
- 加到底端。
- 随机位置插入。
- 移除指定卡。
- 抽顶牌。
- 抽底牌。
- 洗牌。
- 查询是否包含某张卡。
- 清空。

必须发出模型事件：

- `card_added`
- `card_removed`
- `pile_changed`

事件里带上卡牌实例、来源牌堆、目标牌堆、插入索引和原因。

### PlayerCombatModel

玩家战斗模型。等价于规则权威层。

字段建议：

- `draw_pile`
- `hand_pile`
- `discard_pile`
- `selected_pile`
- `combo_pile`
- `destroy_pile`
- `mana`
- `starting_mana`
- `card_combo`
- `current_card`
- `previous_card`
- `previous_combo_card`
- `play_card_locks`
- `queued_draw_requests`
- `is_turn_ending`
- `has_played_card_this_turn`

必须提供唯一出牌入口：

```text
try_play_card(card_instance, play_source)
```

任何输入脚本、视图脚本、卡牌节点都不能绕过这个入口直接扣费、移牌或造成伤害。

### CardEffect

效果基类或统一接口。

每个效果至少实现：

```text
can_execute(context)
preview(context)
reset_preview(context)
execute(context)
build_description(context)
```

效果分类：

- 伤害。
- 抽牌。
- 弃牌。
- 摧毁。
- 获得法力。
- 修改费用。
- 回手。
- 复制卡牌。
- 添加临时卡。
- 移除敌人意图。
- 改变玩家属性。

规则要求：

- `preview` 只能写投影值，不能改变真实数值。
- `reset_preview` 必须完整撤销投影。
- `execute` 可以修改真实模型，但不能直接操作卡牌 UI。
- 需要动画时，向命令队列追加视图命令。

### CardCommandRunner

通用串行命令队列。它是出牌队列、效果队列和动画等待的核心。

状态：

- `queue`
- `current_command`
- `is_processing`

命令类型：

- 规则命令：扣费、抽牌、弃牌、伤害、加状态。
- 视图命令：卡牌移动、翻转、slam、溶解、数值跳字。
- 等待命令：等待固定时间、等待动画完成、等待锁释放。

运行逻辑：

```text
如果没有 current_command 且 queue 不为空：
  取出下一条命令并启动

每帧更新 current_command：
  如果完成：
    清空 current_command
    继续下一条
```

命令必须可取消或可安全跳过。进入新遭遇、退出战斗、读档或关闭界面时，应清空队列并把模型恢复到安全状态。

### CardView

单张卡牌视图。只负责显示和动画，不决定规则。

职责：

- 根据 `CardInstance` 同步名称、费用、描述、类型、图标、状态标记。
- 播放移动、缩放、旋转、翻转、悬停、无效出牌、销毁、回手动画。
- 管理动画中断标记。
- 暴露“动画完成”事件给命令队列。

禁止：

- 直接修改玩家法力。
- 直接把卡加入牌堆。
- 直接造成伤害。
- 直接切换回合状态。

### CardPileView

牌堆视图。订阅 `CardPile` 的事件，播放卡牌进入/离开动画。

建议拆分：

- `HandPileView`
- `DrawPileView`
- `DiscardPileView`
- `SelectedPileView`
- `ComboPileView`
- `DestroyPileView`

每个视图都实现统一语义：

```text
sync_view()
teleport_card_to_pile(card_view)
animate_card_added(card_view, reason)
animate_card_removed(card_view, reason)
```

模型先变，视图后播。视图动画失败时，不回滚模型；只做视觉修复。

### HandSlotController

手牌槽位和交互控制器。负责卡牌位置、选择、拖拽、手柄操作和重排延迟。

状态建议：

- `current_hover_index`
- `current_dragging_card`
- `is_interaction_held`
- `is_select_held`
- `hold_timer`
- `select_hold_timer`
- `time_since_last_card_interaction`
- `card_reorder_delay`
- `are_card_positions_locked`

职责：

- 鼠标悬停选择卡牌。
- 鼠标拖拽超过阈值后进入拖拽态。
- 手柄左右切换手牌焦点。
- 手柄长按或确认键触发出牌。
- 卡牌交互结束后短暂锁定重排，防止抖动。
- 确认当前只有一张卡处于交互态。

### SelectedCardService

当前交互卡牌的唯一所有权服务。

职责：

- 记录当前正在交互的卡。
- 交互开始时拒绝第二张卡抢占，除非强制结束旧交互。
- 交互结束时释放所有权。
- 提供 `is_card_being_interacted` 和 `is_this_card_being_interacted`。

### CombatStateMachine

战斗状态机。至少包含：

```text
EncounterStart
PrePlayerTurn
PlayerTurn
PlayerEndTurn
PostPlayerEndTurn
EnemyTurn
EncounterDefeated
EncounterReset
```

职责：

- 进入玩家回合时重置法力、抽牌、刷新可出牌状态。
- 玩家回合只允许玩家出牌输入。
- 玩家结束回合时锁住出牌，结算手牌 end-turn 效果。
- 敌人回合串行执行敌人行动命令。
- 遭遇结束时清理临时卡、临时费用、命令队列和输入状态。

## 出牌流程

必须按这个方向实现：

```text
输入请求
-> HandSlotController 找到当前卡牌
-> SelectedCardService 确认交互所有权
-> PlayerCombatModel.try_play_card
   -> 检查是否玩家回合
   -> 检查 play_card_locks
   -> 检查卡牌是否仍在手牌
   -> 检查费用和状态
   -> 失败：返回失败原因
   -> 成功：
      -> 注册 play lock
      -> 扣费
      -> 从手牌模型移除
      -> 加入 selected 或 combo 相关牌堆
      -> 标记 was_played
      -> 追加卡牌移动视图命令
      -> 追加 on_play 效果命令
      -> 追加 after_play 规则命令
      -> 追加释放 play lock 命令
```

失败原因至少包括：

- 非玩家回合。
- 正在结束回合。
- 有出牌锁。
- 卡牌不在手牌。
- 费用不足。
- 卡牌被冻结或被禁用。
- 当前有其他卡正在交互。

失败时只播放反馈，不改变任何真实模型。

## 效果结算流程

```text
CardInstance 获取 on_play_effects
-> 对每个 CardEffect 创建执行上下文
-> can_execute 为 false 则跳过或记录失败
-> execute 修改模型
-> 如果需要表现，把视图命令加入 CardCommandRunner
-> 执行完成后触发 effect_resolved 事件
```

伤害效果建议拆成：

```text
构建 DamageParams
-> 目标选择
-> 计算投影
-> 正式扣护甲/生命
-> 触发死亡/击杀/连击/宝石附加效果
-> 追加伤害数字、敌人受击、武器表现命令
```

不要让武器动画决定伤害是否发生。伤害模型先结算，动画只是表现。

## 输入层和容错

必须实现四层闸门：

```text
InputLayerGate
  当前场景、模态窗口、暂停、教程是否允许战斗输入

InteractionOwner
  当前是否已有卡牌正在被交互

PlayLockCounter
  当前出牌队列或动画是否允许新出牌

CardLocalState
  当前卡牌是否还在手牌、是否可支付、是否可被操作
```

容错规则：

- 快速连点同一卡：只允许一次有效出牌。
- 快速点击多张卡：只有当前交互所有权的卡能进入出牌流程。
- 动画未结束：可以允许悬停，但禁止规则出牌。
- 抽牌堆为空：先将弃牌堆洗入抽牌堆，再执行排队的抽牌请求。
- 模态窗口打开：战斗输入层关闭，模态输入层打开。
- 模态刚打开或重掷后：短暂输入屏蔽，避免确认键穿透。
- 拖拽松手位置非法：卡牌回原槽位。
- 指针离开窗口或节点失焦：强制结束拖拽并回位。

## 手感配置

把手感参数做成可调配置，不要写死在脚本里。

### CardInteractionFeel

- `drag_detection_threshold`
- `dragged_follow_speed`
- `dragged_rotation_speed`
- `dragged_rotation_amount`
- `dragged_rotation_velocity_multiplier`
- `hold_duration_for_drag`
- `long_hold_duration_for_drag`
- `drag_height_offset`
- `drag_x_offset_from_hover`
- `controller_hold_selection_speed`

### CardHoverFeel

- `hover_move_speed`
- `hover_scale`
- `hover_height_offset`
- `tilt_speed`
- `tilt_degrees`
- `auto_tilt_speed`
- `auto_tilt_degrees`
- `invalid_scale`
- `invalid_height_offset`
- `invalid_shake_amplitude`
- `invalid_shake_time`
- `invalid_shake_vibrato`
- `playable_position_scale_multiplier`
- `playable_position_scale_duration`
- `hover_shadow_distance`

### CardDrawFeel

- `rotate_duration`
- `rotate_delay`
- `scale_duration`
- `scale_delay`
- `rotate_from`
- `post_draw_wait`

### CardDiscardFeel

- `post_discard_wait`
- `rotate_duration`
- `rotate_delay`
- `scale_duration`
- `scale_delay`
- `move_speed`
- `decelerate_distance`
- `rotate_to`
- `scale_to`

### CardDestroyFeel

- `post_destroy_wait`
- `scale_duration`
- `scale_delay`
- `move_speed`
- `decelerate_distance`
- `scale_to`
- `dissolve_time`
- `minimum_dissolve_value`
- `multi_card_speed_exponent`
- `max_card_destroy_speed`

### ComboPileFeel

- `screen_shake_amplitude`
- `screen_shake_frequency`
- `screen_shake_duration`
- `card_slam_raised_scale`
- `card_slam_raise_time`
- `card_slam_drop_time`
- `min_card_slam_particles`
- `max_card_slam_particles`
- `card_shadow_return_time`
- `enable_combo_pile_flame`
- `enable_card_flames`

## 事件命名建议

模型事件：

- `card_added_to_pile`
- `card_removed_from_pile`
- `card_play_requested`
- `card_play_failed`
- `card_play_started`
- `card_play_resolved`
- `card_discarded`
- `card_destroyed`
- `card_drawn`
- `mana_changed`
- `turn_started`
- `turn_ended`
- `effect_previewed`
- `effect_preview_reset`
- `effect_resolved`

视图事件：

- `card_move_finished`
- `card_hover_started`
- `card_hover_ended`
- `card_invalid_feedback_finished`
- `card_destroy_animation_finished`
- `pile_animation_finished`

输入事件：

- `interaction_started`
- `interaction_ended`
- `selection_started`
- `selection_canceled`
- `drag_started`
- `drag_ended`

具体实现时可按项目命名规范调整，但语义必须保留。

## 实现阶段

### 阶段 1：纯模型

实现：

- `CardDef`
- `CardInstance`
- `CardPile`
- `PlayerCombatModel`

验收：

- 可以创建卡牌实例。
- 可以抽牌、弃牌、洗牌。
- 同一张卡不能同时存在于两个牌堆。
- 费用不足时 `try_play_card` 失败且不改变牌堆。

### 阶段 2：命令队列

实现：

- `CardCommandRunner`
- 规则命令。
- 等待命令。
- 队列取消和清空。

验收：

- 命令按顺序执行。
- 当前命令未完成时不会启动下一条。
- 清空队列后不会留下半执行状态。

### 阶段 3：效果系统

实现：

- `CardEffect` 统一接口。
- 伤害、抽牌、弃牌、销毁、获得法力、修改费用。
- 预览和撤销预览。

验收：

- 预览不会改变真实数值。
- 预览撤销后投影值归零。
- 正式执行后模型状态正确。

### 阶段 4：视图层

实现：

- `CardView`
- `CardPileView`
- 手牌、抽牌、弃牌、销毁、连击牌堆视图。
- 卡牌移动、悬停、无效反馈。

验收：

- 模型变化后视图跟随。
- 视图动画失败不会复制或丢失卡牌模型。
- 费用、状态、描述能刷新。

### 阶段 5：输入和手牌槽位

实现：

- `CardInputRouter`
- `SelectedCardService`
- `HandSlotController`
- 鼠标悬停/拖拽。
- 键盘或手柄选择。
- 输入层屏蔽。

验收：

- 同时只能有一张卡被交互。
- 拖拽未达到阈值不会误出牌。
- 非法松手会回位。
- 模态窗口打开时战斗输入无效。

### 阶段 6：回合状态机

实现：

- `CombatStateMachine`
- 玩家回合。
- 玩家结束回合。
- 敌人回合。
- 遭遇开始和结束。

验收：

- 非玩家回合不能出牌。
- 回合结束时出牌锁生效。
- 遭遇结束清理临时状态。

### 阶段 7：调手感

实现：

- 所有 feel 配置资源。
- 默认调参面板或 debug 输出。
- 快速输入压力测试。

验收：

- 快速连点不会重复出牌。
- 快速拖拽不会卡死交互态。
- 抽牌、弃牌、销毁动画时模型不乱。
- 无效出牌反馈清晰但不打断后续合法操作。

## 自动化测试要求

至少覆盖：

- 费用不足不能出牌。
- 出牌成功后卡从手牌进入目标牌堆。
- 同一张卡不能重复添加到两个牌堆。
- 出牌锁存在时拒绝新出牌。
- 抽牌堆为空时，弃牌堆能洗回抽牌堆。
- `on_play` 效果只结算一次。
- 预览和撤销预览不污染真实数值。
- 队列命令串行执行。
- 队列清空后不会继续执行旧命令。
- 快速输入不会重复移动同一张卡。

## 人工 QA 清单

测试以下操作：

- 单击选中卡牌。
- 鼠标悬停每一张手牌。
- 拖拽到无效区域松手。
- 拖拽到有效区域松手。
- 费用不足时尝试出牌。
- 连续快速点击同一张卡。
- 连续快速点击不同卡。
- 出牌动画未完成时尝试再出牌。
- 打开抽牌堆/弃牌堆查看窗口时尝试出牌。
- 模态选择奖励时连续按确认。
- 回合结束瞬间尝试出牌。
- 敌人回合尝试出牌。

## 禁止事项

- 禁止输入脚本直接改法力、血量或牌堆。
- 禁止视图动画决定规则是否生效。
- 禁止一张卡没有唯一实例 ID。
- 禁止卡牌配置保存运行时状态。
- 禁止多个系统同时持有当前交互卡所有权。
- 禁止动画等待用散落的局部状态硬凑，必须走命令队列或统一锁。
- 禁止为了手感把规则判断写进 UI 节点。

## 最小可交付版本

第一版只需要实现：

- 一组测试卡牌。
- 手牌、抽牌堆、弃牌堆。
- 法力费用。
- 三种效果：伤害、抽牌、获得法力。
- 鼠标悬停、拖拽出牌、无效反馈。
- 命令队列。
- 玩家回合和敌人回合空转。
- 基础自动化测试。

做到这里后，再扩展销毁、回手、连击、宝石、敌人意图、奖励选择。

## 参考研究文件

同目录下可查：

- `vampire_crawlers_card_feel_report.md`
- `godot_card_feel_blueprint.md`
- `evidence_index.md`
- `core_class_evidence.csv`

如果实现中遇到设计取舍，以本规格书为准；如果需要追溯为什么这样拆，再看研究报告和证据表。
