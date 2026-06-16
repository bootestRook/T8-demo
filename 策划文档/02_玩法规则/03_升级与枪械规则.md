# 升级三选一、枪械强化与核心技能基准强化规则

## 三选一奖励池

每次升级从以下类型中生成 3 个选项：

```text
1. 获得新卡牌
2. 强化已有卡牌
3. 枪械强化
4. 生存强化
5. 能量系统强化
6. 核心技能基准强化
```

禁止项：

```text
三选一不出现能量上限。
能量上限只在 5 / 10 / 15 / 20 级固定提升。
```

---

## 枪械强化词条

枪械不进手牌，只作为局内被动强化。

| 词条名 | 效果文本 | 程序实现 |
|---|---|---|
| 子弹爆炸 | 子弹命中怪物后爆炸。 | `bullet.on_hit_effects += explosion` |
| 分裂子弹 | 子弹命中怪物后释放 2 个次级子弹。 | `bullet.on_hit_effects += spawn_sub_bullets(count=2,target_mode=nearest)` |
| 分裂子弹四射 | 子弹命中后生成 4 个次级子弹并向 4 个方向发射。 | `bullet.on_hit_effects += spawn_sub_bullets(count=4,mode=four_direction)` |
| 弹头强化 | 子弹与次级子弹伤害 +100%。 | `bullet_damage_mul += 1.0; sub_bullet_damage_mul += 1.0` |
| 子弹增伤 | 子弹伤害 +60%。 | `bullet_damage_mul += 0.6` |
| 射速提升 | 射速 +10%。 | `fire_interval *= 0.9` |
| 连发射击 | 每次射击连发数 +1，伤害 -20%。 | `burst_count += 1; bullet_damage_mul *= 0.8` |
| 多重弹道 | 子弹弹道数量 +1，伤害 -20%。 | `gun_projectile_count += 1; bullet_damage_mul *= 0.8` |

---

## 连发与多重弹道区别

```text
连发射击：同一次开火，按短间隔连续发射多发。
多重弹道：同一次开火，同时发出多条弹道。
```

连发示例：

```text
第1发 → 0.08秒 → 第2发
```

多重弹道示例：

```text
左偏弹道 + 正中弹道 + 右偏弹道
```

---

## 枪械运行时数据

```gdscript
class_name GunRuntime

var bullet_damage_mul: float = 1.0
var sub_bullet_damage_mul: float = 1.0
var fire_interval: float = 0.8
var burst_count: int = 1
var gun_projectile_count: int = 1
var max_ammo: int = 30
var reload_time: float = 2.0
var on_hit_effects: Array[String] = []
```

---

## 子弹命中逻辑

```gdscript
func on_bullet_hit(enemy, hit_pos: Vector2, bullet_runtime: Dictionary) -> void:
    DamageService.deal_damage(enemy, base_bullet_damage * GunRuntime.bullet_damage_mul, "physical", "bullet")

    for effect_id in GunRuntime.on_hit_effects:
        execute_bullet_on_hit_effect(effect_id, enemy, hit_pos)
```

---

## 次级子弹规则

```text
次级子弹不是主子弹。
次级子弹不再次触发“分裂子弹”。
次级子弹可以吃“子弹与次级子弹伤害+100%”。
```

```gdscript
func spawn_sub_bullet(origin: Vector2, direction: Vector2, damage: float) -> void:
    ProjectileFactory.spawn({
        "type": "sub_bullet",
        "origin": origin,
        "direction": direction,
        "damage": damage * GunRuntime.sub_bullet_damage_mul,
        "can_trigger_on_hit_effect": false
    })
```

---

## 核心技能基准强化词条

这些词条不进手牌，只强化对应流派所有卡牌的基准释放。

| 词条名 | 效果文本 | 程序实现 |
|---|---|---|
| 温压弹数量+1 | 每次释放温压弹卡牌时，温压弹数量 +1。 | `CoreSkillRuntime.thermobaric.projectile_count += 1` |
| 温压弹额外释放 | 每次释放温压弹卡牌时，额外释放 1 枚温压弹。 | `CoreSkillRuntime.thermobaric.release_count += 1` |
| 干冰弹数量+1 | 每次释放干冰弹卡牌时，干冰弹数量 +1。 | `CoreSkillRuntime.dry_ice.projectile_count += 1` |
| 干冰弹额外释放 | 每次释放干冰弹卡牌时，额外释放 1 枚干冰弹。 | `CoreSkillRuntime.dry_ice.release_count += 1` |
| 电磁穿刺数量+1 | 每次释放电磁穿刺卡牌时，电磁穿刺数量 +1。 | `CoreSkillRuntime.electro_pierce.projectile_count += 1` |
| 电磁穿刺额外释放 | 每次释放电磁穿刺卡牌时，额外释放 1 次电磁穿刺。 | `CoreSkillRuntime.electro_pierce.release_count += 1` |

---

## 数量+1 与额外释放的区别

```text
数量+1：同一时间多发，优先锁定不同目标。
额外释放：延迟 0.15~0.18 秒后再释放一次，重新索敌。
```

运行时结构：

```gdscript
class_name CoreSkillRuntimeData

var projectile_count: int = 1
var release_count: int = 1
var release_interval: float = 0.16
```

---

## 其他升级类型

### 强化已有卡牌

```text
强化玩家已拥有的卡牌。
第一版建议只强化数值，不改变机制。
```

示例：

```text
伤害 +20%
范围 +15%
持续时间 +20%
击退 +20%
冻结 / 麻痹时间 +0.3 秒
```

### 生存强化

```text
城墙最大生命 +10%
立即回复城墙 20%
城墙获得 5 秒护盾
怪物攻击城墙伤害 -10%
```

### 能量系统强化

```text
能量回复 +15%
开局能量 +1
补牌速度 +15%
弃牌按钮冷却 -3 秒
手牌上限 +1
```

`手牌上限 +1` 建议设置为稀有选项。
