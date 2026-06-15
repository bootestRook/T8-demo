---
name: godot-code-quality-review
description: 当用户要求优化代码层面、代码质量、架构巡检、重构建议、GDScript 检查、SOLID/KISS/DRY/YAGNI 审查、避免越写越乱时使用。用于 Godot 4 中小型 2D 游戏的轻量代码质量审查，重点发现职责混乱、重复逻辑、过度设计、状态散落和新手模板维护风险。
---

# Godot Code Quality Review

## 目标

在不把首版第一轮做重的前提下，保持代码容易让 AI 和新手继续改。

## 检查范围

优先读取：

- `src/game/PrototypeState.gd`
- `scenes/Game.gd`
- `src/game/Player.gd`
- `src/ui/Hud.gd`
- 当前 PM 需求信息：`python .agents/skills/pm-agile/scripts/pm_cli.py status`
- `docs/game-concept.md`

## 检查项

以下检查项按风险和上下文判断，不机械要求重构。只有影响职责边界、运行稳定性、维护成本、热路径性能或当前需求目标时，才列为问题；调试代码、一次性迁移代码和稳定父子编排可以标注为可接受。

- 状态规则是否集中在 `PrototypeState.gd`，避免散落在 Game.gd。
- Game.gd 是否只负责响应 PrototypeState 信号和组织画面。
- HUD 是否只负责显示，不承载玩法规则。
- `PrototypeState.gd` 作为 Autoload `Node` 是否只维护规则状态和信号，不直接依赖场景节点、素材和 VFX。
- 是否有重复魔法数字、重复文案或重复状态分支。
- 是否引入了当前首版不需要的系统或抽象。
- GDScript 类型推断是否正确（避免 `:=` 对无类型值的使用）。
- 信号是否使用 Godot 4 typed signal 和 `signal_name.emit(...)`，避免字符串式 `emit_signal()`。
- 是否用 `node != null` 判断可能已释放的节点引用；跨帧引用是否使用 `is_instance_valid()`。
- `@export` 默认值是否匹配声明类型，复杂集合是否有必要类型标注。
- 热路径是否反复 `$Node` / `get_node()`、反复分配数组/字典、频繁实例化短生命周期对象。
- 是否在热路径里 `load()`、`ResourceLoader.load()`、`PackedScene.instantiate()` 或每帧 `get_nodes_in_group()`。
- 输入是否通过 Input Map action；是否硬编码键码；一次性玩法输入是否适合放在 `_unhandled_input()`。
- 信号是否用于跨边界解耦；HUD、敌人、拾取物之间是否出现不必要硬引用。
- 是否出现 `get_parent().get_parent()` 链、全局 `find_child()` / 根节点递归搜索、双向引用或子节点直接调用父节点业务方法。
- Autoload 是否只用于真正全局能力；是否把场景私有状态塞进全局单例。
- `Resource` 是否作为配置模板使用；运行时可变数据是否先 `duplicate()`，避免修改共享资源。
- 对象池、节点状态机、场景管理器、组件节点是否满足 `docs/ARCHITECTURE_RULES.md` 的采用条件。
- 是否使用 `AnimatedTexture`；应改用 `AnimatedSprite2D` / `SpriteFrames` 或 `AnimationPlayer`。
- 同一可见属性是否被 `AnimatedSprite2D`、`AnimationPlayer`、Tween 和代码同时控制，造成动画主控冲突。
- 循环动画是否误用 `animation_finished`；一次性动画和循环动画是否分别使用正确信号。
- 切换动画并同时翻转或改可见属性时，是否需要 `advance(0)` 避免一帧错位。
- 换皮肤或替换 `SpriteFrames` 时是否需要保留 `frame_progress` 并使用 `set_frame_and_progress()`。
- 命中帧、脚步声、发射点、伤害窗口是否用帧事件或 AnimationPlayer 轨道同步，而不是散落魔法计时器。
- 同一属性的新 Tween 是否先 `kill()` 旧 Tween，并在结束或中断时清理引用。
- `AnimationTree`、2D 骨骼/IK、MultiMesh、Shader 批量动画或高分辨率动态 SpriteFrames 管理是否满足当前内容规模，避免过早引入。
- 场景是否职责单一、根节点类型合理、节点树不过深；是否滥用 `%UniqueName` 或暴露内部节点路径作为外部契约。
- 是否使用 `@tool` 编写业务逻辑；编辑器预览代码是否和运行时玩法分离。
- 是否修改了 `.tscn` 文件；只有新增稳定节点或 Autoload 无法解决时才修改。
- 主场景节点数是否超过 12 个；超过时确认是否仍易于新手理解。
- 文件命名和注释风格是否一致。

## 自动验证

默认运行：

```bash
python scripts/export_web.py
python scripts/ai_review.py --skip-runtime
```

如果只是只读审查，可不修改文件；如果用户要求直接优化，改动后必须运行 AI review。交付前补跑完整 `python scripts/ai_review.py --strict`。

## 输出格式

```markdown
## Code Quality Review

### Findings
| Priority | File | Issue | Fix |
|---|---|---|---|

### Recommended Changes
- 首版必须修: ...
- 后续增强: ...
- Not Now: ...

### Verification
- python scripts/export_web.py: PASS / FAIL / NOT RUN
```

## 原则

- KISS：优先小改，不为未来功能预埋复杂框架。
- YAGNI：删掉当前用不到的抽象或依赖。
- DRY：只抽真正重复且会继续重复的逻辑。
- SOLID：职责清楚比类和接口数量更重要。
