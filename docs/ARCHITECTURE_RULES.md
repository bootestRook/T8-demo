# AI 架构规则

这份文档给 AI 判断“该改哪里、不能越过什么边界”。不要把它当大型框架设计；当前项目仍以 Godot 节点、Autoload、信号和少量模块为主。

## 分层词汇

| 层 | 负责什么 | 典型文件 |
|---|---|---|
| 表现层 | 输入、画面同步、HUD、菜单、场景节点编排 | `scenes/Game.gd`、`src/ui/Hud.gd`、`MenuPresenter.gd` |
| 规则层 | 一局游戏状态、胜负、分数、波次、反馈触发 | `PrototypeState.gd`、`WaveDirector.gd`、`FeedbackDirector.gd`、`AudioDirector.gd` |
| 数据层 | 进度、内容单元、背包、装备、任务、成就 | `ProgressStore.gd`、`ContentUnits.gd`、`InventoryStore.gd`、`EquipmentStore.gd`、`QuestStore.gd`、`AchievementStore.gd` |
| 工具层 | 存档、资源路径、平台/序列化等基础能力 | `SaveStore.gd`、`AssetRegistry.gd` |

## 默认修改入口

新游戏或玩法内容单元优先改这 3 个文件：

- `src/game/PrototypeState.gd`：核心规则、状态、数值、胜负、重开。
- `scenes/Game.gd`：输入、节点生成、碰撞、场景对象同步。
- `src/ui/Hud.gd`：目标、状态、结算、下一步提示。

需要游戏系统能力时按职责接入 `src/game/modules/`；空脚手架不预置模块，新游戏按玩法目标选择。

UI/HUD 的稳定节点结构属于场景资产：`CanvasLayer`、full rect `Control`、容器、关键标签、按钮和面板应保留在 `.tscn` 或独立 UI 场景中，便于用户打开 Godot 编辑器时理解结构；`Hud.gd` 只负责把这些节点绑定到运行时状态、反馈和交互。

## 状态变更规则

- 表现层可以读取规则层/数据层状态，但不要直接决定胜负、进度或结算。
- HUD 只显示状态和发出 UI 意图，不写核心玩法字段。
- 模块之间优先用信号或 `GameEvents.emit_event()` 通知。
- 数据模块如果需要存档，提供 `serialize()` 和 `deserialize(data)`。
- 玩法规则仍由 `PrototypeState.gd` 或一个明确规则模块统一收口。

## 节点通信规则

- 默认遵循“子节点发信号，父节点调用子节点”：子节点不要假设父节点层级，父节点可以编排已知子节点。
- 跨模块、跨场景或全局反馈优先使用 `GameEvents.emit_event()`；不要让 HUD、敌人、拾取物、VFX 彼此硬引用。
- 禁止用 `get_parent().get_parent()` 链访问业务对象；需要上下文时由父节点注入引用，或通过信号、组、规则模块传递。
- 禁止用全局 `find_child()` / 根节点递归搜索作为业务通信手段；少量调试代码除外。
- 组适合查找同类运行时对象，例如敌人、可伤害对象、拾取物；不要把组当全局状态或模块 API。
- 高频组查询要缓存或由生成/销毁事件维护集合，避免每帧全树查询。
- 场景内关键稳定节点可以使用 `%UniqueName`，但不要为了规避混乱层级给所有节点都设唯一名。

## 禁止越界

- 运行时代码不得加载 `references/`。
- 模块不得直接修改 HUD、结算 UI 或 `PrototypeState.gd` 内部字段。
- 空脚手架不得默认注册物品、敌人、任务、对话或内容单元。
- ECS、依赖注入容器、大型状态机、复杂经济或编辑器工具链可以按玩法目标引入；引入前必须写清玩家价值、职责边界、数据归属和验证方式。
- 不把 Node/npm/npx 作为 Godot 游戏运行时依赖。

## 何时新增模块

只有满足任一条件才新增 `src/game/modules/*.gd`：

- 这段能力会被 2 个以上场景、关卡或玩法单元复用。
- 它有独立状态和明确接口，例如背包、任务、波次、存档。
- 放在 `Game.gd` 或 `PrototypeState.gd` 会让单文件职责明显混乱。

新增模块必须能用一句话说明职责，并通过信号或返回值对外沟通。

## Godot 模式采用规则

常见 Godot/GDScript 模式只在解决当前问题时使用，不作为空脚手架默认系统。

| 模式 | 适合使用 | 暂不使用 |
|---|---|---|
| 信号 / `GameEvents` | 表现、反馈、音效、成就、模块之间需要解耦通知 | 同一文件内的简单顺序逻辑 |
| Autoload | 全局规则状态、事件总线、存档、资源注册等确实跨场景共享的能力 | 某个场景私有对象、单个关卡临时状态 |
| `Resource` 数据 | 武器、敌人、关卡、卡牌等配置需要复用、编辑器可配置或运行时复制 | 只有 1-2 个字段的临时参数 |
| 运行时 `duplicate()` | 需要从资源模板生成每局可变状态，例如生命、耐久、冷却 | 直接修改共享 `.tres` 或只读配置 |
| 对象池 | 子弹、飘字、命中特效等高频生成并造成卡顿风险的对象 | 低频生成、生命周期简单的对象 |
| 轻量状态枚举 | 一局游戏阶段、玩家少量动作、UI 面板状态 | 为首版默认引入节点状态机框架 |
| 节点状态机 | 角色动作分支已经明显膨胀，且每个状态有独立输入、进入、退出和物理逻辑 | 只有 idle/move/jump 等少量分支且 `match` 足够清楚 |
| 场景切换管理器 | 多主场景、加载界面、异步切换或转场复用已经出现 | 单主场景首版、只需要重开当前局 |
| 组件节点 | 生命、碰撞、拾取、交互等能力会被多类实体复用 | 只有一个实体使用，直接脚本字段更清楚 |
| 输入缓冲 | 平台跳跃、动作、格斗等需要提前按键容错和手感优化 | 点击、菜单、低频策略操作 |
| 输入重绑定 | 用户明确要求设置界面、键鼠/手柄自定义或可访问性目标 | 首版没有设置界面或只有少量固定操作 |
| `AnimatedSprite2D` / `SpriteFrames` | 角色、敌人、道具的帧动画，首版 1-2 个动作快速落地 | 需要驱动命中帧、骨骼、Shader、复杂属性轨道 |
| `AnimationPlayer` | 同步 VFX/SFX/命中帧、Tween 难以表达的多属性时间轴、骨骼或 Shader 参数 | 只播放简单循环 sprite 帧 |
| `AnimationTree` | 多方向混合、复杂 locomotion 或多状态过渡已经影响可维护性 | 少量 idle/run/jump/attack 分支 |
| Tween 动画 | UI 弹出、受击闪白、缩放回弹、一次性程序化反馈 | 长时间角色状态、可被多个系统同时控制的核心属性 |
| 2D 骨骼 / IK | 明确需要 cutout、换装、肢体 IK、坡面脚步等复杂表现 | 首版普通帧动画已经能表达角色动作 |

使用这些模式时要先满足当前脚手架分层：规则仍收口在 `PrototypeState.gd` 或明确规则模块，表现节点不决定胜负，数据模块通过 `serialize()` / `deserialize(data)` 暴露存档能力。

## 2D 动画规则

- 同一可见属性必须只有一个动画主控：`AnimatedSprite2D`、`AnimationPlayer`、`AnimationTree` 或代码/Tween 中选一个负责该属性，避免互相抢 `frame`、`animation`、`scale`、`modulate`。
- 不使用 `AnimatedTexture`；帧动画优先使用 `AnimatedSprite2D` + `SpriteFrames`，复杂时间轴使用 `AnimationPlayer`。
- 循环动画监听 `animation_looped`，一次性动画才依赖 `animation_finished`。
- 同一帧内切换动画并修改 `flip_h`、材质或关键可见属性时，如出现一帧错位，可在 `play()` 后调用 `advance(0)` 强制同步。
- 切换皮肤、帧资源或动画但要保留播放进度时，记录 `frame` 和 `frame_progress`，再用 `set_frame_and_progress(frame, progress)` 恢复。
- 攻击命中、脚步声、发射点、受击窗口等帧事件优先通过 `frame_changed`、`AnimationPlayer` Method Track 或 Value Track 同步，不用散落的魔法计时器。
- 同一属性的新 Tween 启动前先 `kill()` 旧 Tween，并在完成或中断后清理引用，避免动画互抢和泄漏。
- 程序化 squash/stretch、受击闪白、UI pop 属于表现层反馈，触发源可以来自规则层事件，但不要让动画脚本决定胜负、伤害或进度。
- 像 `AnimationTree`、2D 骨骼、IK、MultiMesh、Shader 批量动画和高分辨率动态 SpriteFrames 管理，只在玩法和素材规模确实需要时启用。

## GDScript 编码规则

- 热路径中缓存节点引用，避免在 `_process()`、`_physics_process()` 或大量循环里反复 `$Node` / `get_node()`。
- 公共方法、信号参数、导出字段和复杂数组/字典尽量显式类型化，避免无类型值配合 `:=` 造成推断错误。
- 信号使用 Godot 4 写法：声明参数类型并用 `signal_name.emit(...)`；不要回到字符串式 `emit_signal("name")`。
- 已释放节点引用不能只判断 `node != null`；跨帧持有节点引用时使用 `is_instance_valid(node)`。
- 导出变量默认值要匹配声明类型，例如 `@export var speed: float = 100.0`。
- 频繁生成的临时数组、字典、对象要评估是否可以复用；只有实际高频或检查发现卡顿时才引入对象池。
- 连接信号时优先连接到当前职责边界内的方法，跨模块事件优先通过 `GameEvents`，不要让 HUD、敌人、拾取物彼此硬引用。
- `Resource` 默认视为配置模板；需要记录运行时变化时先复制，避免污染共享资源。
- Autoload 要少而稳定；新增前先确认它是否真的跨场景、跨模块、跨局共享。
- 输入读取使用 Input Map action，不硬编码键码；玩法一次性动作优先放在 `_unhandled_input()`，连续移动可放在 `_physics_process()`。
- `load()`、`ResourceLoader.load()`、`PackedScene.instantiate()` 不放在每帧热路径；小型关键资源优先 `preload()` 或初始化时缓存。
- 业务逻辑不使用 `@tool`；编辑器预览脚本必须和运行时玩法代码分离。

## 场景组合规则

- 场景应该有单一职责：玩家、敌人、拾取物、HUD、关卡容器各自封装，不做“万能场景”。
- 首版主场景保持浅层和可读；深度超过 3-4 层或主场景节点过多时，优先拆成可复用子场景。
- 根节点类型服务实际职责：物理角色用 `CharacterBody2D`，触发区用 `Area2D`，UI 用 `Control` / `CanvasLayer`。
- 脚本优先跟随对应场景或当前 `src/game/` 模块边界，不为了套外部目录模板迁移项目结构。
- 子场景公开的 API 是信号、导出参数和少量公共方法；内部节点路径不作为外部契约。
- 不为临时玩法数值或调试对象改 `.tscn`；但稳定 HUD 骨架、菜单、结算面板、实体预制体、碰撞形状和相机/容器节点应进入场景文件，并通过 `%UniqueName` 或清晰相对路径供脚本绑定。

## AI 自查问题

- 我是在改默认入口，还是确实需要启用模块或新增系统？
- 我有没有让 HUD 或模块决定核心胜负？
- 这个状态应该存在规则层、数据层还是只是当前节点的临时表现状态？
- 新增素材是否放在 `assets/`，并由运行时代码真实加载？
- 我是否引入了状态机、对象池、场景管理器或组件系统；它是否已经满足上面的采用条件？
- 我是否在热路径里重复查节点、重复分配对象，或直接修改共享 `Resource`？
- 我是否用了硬编码键码、字符串信号、`get_parent()` 链、全局树搜索或每帧组查询？
- 我持有的节点引用是否可能已释放；是否需要 `is_instance_valid()`？
- 新场景是否职责单一、节点树浅、根节点类型正确，并且没有把内部节点路径暴露给外部？
- 同一动画属性是否只有一个主控；循环/一次性动画信号、Tween 生命周期和帧事件同步是否正确？
- 改完是否需要跑 `python scripts/ai_review.py --strict`？
