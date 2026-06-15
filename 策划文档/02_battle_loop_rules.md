# 战斗与局内循环规则

## 战斗流程

```text
进入战斗
↓
加载配置表
↓
初始化城墙、枪械、能量、手牌、怪物时间轴
↓
按时间点刷怪
↓
玩家自动射击 + 手动出牌
↓
击杀怪物获得固定经验
↓
升级时暂停并弹出三选一
↓
3:00 精英怪
↓
5:00 Boss
↓
Boss 死亡或城墙死亡后结算
```

---

## 时间轴刷怪规则

所有怪物都通过配置表刷新，不在代码里硬编码波次。

第一版关键点：

```text
精英怪：180 秒
Boss：300 秒
Boss 出现不等于战斗立即结束
```

`WaveDirector` 每帧检查当前战斗时间：

```gdscript
func _process(delta: float) -> void:
    battle_time += delta
    while next_wave_index < waves.size() and waves[next_wave_index].time <= battle_time:
        spawn_wave(waves[next_wave_index])
        next_wave_index += 1
```

---

## 城墙规则

```text
城墙位于屏幕底部防线。
怪物移动到攻击范围后停止推进并攻击城墙。
城墙血量为 0 时战斗失败。
```

推荐参数：

```text
wall_max_hp = 1000
monster_attack_range_y = wall_y - 120
```

怪物攻击城墙：

```gdscript
if monster.global_position.y >= monster_attack_range_y:
    monster.enter_attack_wall_state()
```

---

## 自动枪械规则

初始枪械：

| 参数 | 数值 |
|---|---:|
| 弹匣 | 30 |
| 射击间隔 | 0.8 秒 / 发 |
| 换弹时间 | 2 秒 |
| 锁定规则 | 距离城墙最近的怪物 |

自动射击逻辑：

```gdscript
func gun_tick(delta: float) -> void:
    if is_reloading:
        reload_timer -= delta
        if reload_timer <= 0:
            ammo = max_ammo
            is_reloading = false
        return

    fire_timer -= delta
    if fire_timer <= 0:
        if ammo <= 0:
            start_reload()
        else:
            fire_once()
            fire_timer = fire_interval
```

目标规则：

```text
最近目标 = 距离城墙最近的怪物。
不要用距离玩家最近，否则防线压力感会变弱。
```

---

## 经验与等级规则

```text
局内最大等级：20
每局经验获取固定，由击杀小怪、精英、Boss 配置决定。
升级时弹出三选一。
升级选择期间战斗暂停。
```

能量上限成长：

```gdscript
func get_energy_cap_by_level(level: int) -> int:
    if level >= 20:
        return 11
    if level >= 15:
        return 9
    if level >= 10:
        return 7
    if level >= 5:
        return 5
    return 3
```

---

## 能量规则

| 参数 | 数值 |
|---|---:|
| 初始能量 | 0 |
| 初始回复 | 1 / 秒 |
| 初始上限 | 3 |
| 三选一是否出现能量上限 | 否 |

能量恢复：

```gdscript
func update_energy(delta: float) -> void:
    current_energy = min(max_energy, current_energy + energy_regen_per_sec * delta)
```

---

## Boss 战规则

```text
Boss 于 300 秒出现。
Boss 出现时可以继续刷少量小怪，但不要盖过 Boss 识别度。
Boss 死亡即胜利。
```

第一版 Boss 目标：

```text
检验玩家是否形成至少一个主流派构筑。
检验枪械强化是否提供保底输出。
检验城墙和控制类卡牌是否有价值。
```
