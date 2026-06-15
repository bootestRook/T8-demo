# Godot 工程结构规则

## 版本与语言

```text
Godot：4.x
脚本：GDScript
项目类型：2D 竖屏手机游戏
```

GDScript 要求：

```text
1. 优先使用静态类型标注。
2. Manager / Controller 只负责逻辑，不直接写 UI 表现。
3. 热路径避免频繁 instantiate/free，弹体、怪物、区域效果使用对象池。
4. 配置表读取后缓存到 ConfigDB，不在战斗中重复解析文件。
```

---

## 推荐目录结构

```text
res://
  scenes/
    battle/
      BattleRoot.tscn
      Wall.tscn
      PlayerGun.tscn
      Monster.tscn
      Projectile.tscn
      AreaEffect.tscn
    ui/
      BattleHUD.tscn
      CardHandView.tscn
      UpgradeChoiceView.tscn

  scripts/
    autoload/
      config_db.gd
      battle_bus.gd
      object_pool.gd
    battle/
      battle_root.gd
      battle_state.gd
      wave_director.gd
      target_service.gd
      damage_service.gd
      energy_controller.gd
      level_controller.gd
    card/
      deck_controller.gd
      card_runtime.gd
      card_effect_executor.gd
      chain_controller.gd
      same_name_cooldown_controller.gd
    gun/
      player_gun.gd
      bullet_runtime.gd
    skill/
      core_skill_runtime.gd
      thermobaric_executor.gd
      dry_ice_executor.gd
      electro_pierce_executor.gd
    monster/
      monster.gd
      monster_runtime.gd
    ui/
      battle_hud.gd
      card_hand_view.gd
      upgrade_choice_view.gd

  configs/
    cards.csv
    card_effects.csv
    upgrades.csv
    monsters.csv
    waves.csv
    exp_curve.csv

  art/
  audio/
  vfx/
```

---

## BattleRoot 场景结构

```text
BattleRoot (Node2D)
  BattleState
  WaveDirector
  TargetService
  DamageService
  EnergyController
  LevelController
  DeckController
  ChainController
  SameNameCooldownController

  World (Node2D)
    MonsterLayer (Node2D)
    ProjectileLayer (Node2D)
    AreaEffectLayer (Node2D)
    Wall (Node2D)
    PlayerGun (Node2D)

  CanvasLayer
    BattleHUD
    CardHandView
    UpgradeChoiceView
```

职责边界：

| 节点 / 脚本 | 职责 |
|---|---|
| `BattleRoot` | 战斗初始化、模块引用装配、战斗结束控制 |
| `WaveDirector` | 按时间点刷怪，只读 `waves.csv` |
| `TargetService` | 提供最近目标、近墙目标、密集区域等查询 |
| `DamageService` | 统一处理伤害、击退、死亡、经验掉落 |
| `DeckController` | 手牌、牌库、弃牌、补牌、弃牌按钮 |
| `ChainController` | 连锁倍率计算 |
| `SameNameCooldownController` | 同名卡连续释放冷却 |
| `CardEffectExecutor` | 解析卡牌效果，分发到核心技能执行器 |
| `PlayerGun` | 自动射击、弹匣、换弹、枪械升级应用 |

---

## Autoload 规则

只允许以下全局单例：

| 单例 | 用途 |
|---|---|
| `ConfigDB` | 加载和查询配置表 |
| `BattleBus` | 战斗事件信号总线 |
| `ObjectPool` | 怪物、弹体、区域效果对象池 |

不要把战斗状态放进 Autoload。战斗状态必须存在于 `BattleRoot` 下，方便单局重置。

---

## 信号规则

推荐事件：

```gdscript
signal monster_killed(monster_id: String, exp_value: int)
signal card_played(card_id: String, cost: int)
signal player_level_up(new_level: int)
signal energy_changed(current: float, max_value: int)
signal wall_hp_changed(current: int, max_value: int)
signal boss_spawned(monster_id: String)
signal battle_ended(result: String)
```

规则：

```text
1. UI 只监听信号，不主动拉取复杂战斗逻辑。
2. 伤害、经验、能量、升级必须由对应 Controller 修改，不允许多个脚本直接改同一字段。
3. 卡牌执行器不直接刷新 UI，只发事件或调用 Controller。
```

---

## 对象池规则

必须使用对象池的对象：

```text
Monster
Projectile
SubProjectile
AreaEffect
DamageNumber
VFXNode
```

释放对象时：

```text
1. 停止计时器。
2. 清空状态和回调。
3. 隐藏节点。
4. 放回池。
```

不要在弹体命中时直接 `queue_free()`。
