# 干冰弹流派规则

## 流派定位

```text
冰系弹道技能。
核心体验是穿透、击退、冻结、冻伤、分裂和齐射。
适合直线清怪、防线缓压、控制精英。
```

---

## 基准效果

每打出一张 **[干冰弹]** 卡牌，都会执行：

```text
向最近目标发射 1 枚干冰弹。
干冰弹穿透 3 个怪物造成伤害。
命中怪物时附加微弱击退。
再执行该卡牌附加效果。
```

基准参数：

```gdscript
base_damage = 80
base_pierce_count = 3
base_knockback_distance = 0.25
base_projectile_speed = 18.0
```

穿透规则：

```text
穿透 3 个怪物 = 最多命中 3 个怪物。
穿透 +2 = 最多命中 5 个怪物。
```

伤害吃连锁倍率：

```gdscript
final_damage = base_damage * damage_mul * chain_multiplier
```

---

## 干冰弹卡牌表

| 卡名 | 费用 | 卡牌文本 | 程序效果 |
|---|---:|---|---|
| 试射干冰弹 | 0 | 发射 1 枚干冰弹。本次伤害 -60%，穿透 -1。若至少命中 1 个怪物，下一张干冰弹伤害 +15%。 | `damage_mul=0.4; pierce_add=-1; on_any_hit -> add_next_modifier(damage_mul_add=0.15)` |
| 冷凝校准弹 | 0 | 发射 1 枚干冰弹。本次伤害 -70%，弹道速度 +40%。若命中怪物，下一张干冰弹穿透 +1。 | `damage_mul=0.3; speed_mul=1.4; on_any_hit -> add_next_modifier(pierce_add=1)` |
| 散射小冰弹 | 1 | 首次命中后分裂为 3 个小冰弹。小冰弹各造成主弹伤害 35%，最多命中 1 个怪物。 | `split_on_first_hit={count=3, child_damage_mul=0.35, child_pierce=1}` |
| 低温贯穿 | 2 | 伤害 +30%，穿透 +2。 | `damage_mul *= 1.3; pierce_add += 2` |
| 凝霜重冰 | 2 | 弹道速度 -30%，伤害 +50%，穿透 +1。 | `speed_mul *= 0.7; damage_mul *= 1.5; pierce_add += 1` |
| 干冰弹增伤 | 2 | 干冰弹伤害 +60%。 | `damage_mul *= 1.6` |
| 急冻寒冰 | 3 | 伤害 +30%，命中后会冻结怪物 2 秒。 | `damage_mul *= 1.3; on_hit -> apply_freeze(duration=2*monster.freeze_mul)` |
| 干冰弹连发 | 3 | 额外释放 1 枚干冰弹，每枚伤害 -20%。第二枚重新锁定目标。 | `release_count += 1; release_damage_mul=0.8; release_interval=0.18` |
| 冰冻侵袭 | 3 | 命中后施加 10 秒可叠加 5 次的冻伤。每层每秒造成该次命中伤害 3%。 | `on_hit -> add_frostbite(duration=10,max_stack=5,tick_damage=hit_damage*0.03)` |
| 干冰弹齐射 | 4 | 干冰弹数量 +1。第二枚优先攻击不同目标。 | `projectile_count += 1; prefer_different_targets=true` |
| 重冰穿透 | 3 | 击退 +100%，穿透 +2。 | `knockback_mul *= 2.0; pierce_add += 2` |

---

## 统一释放结构

```gdscript
func cast_dry_ice_card(card_spec: Dictionary) -> void:
    var runtime = CoreSkillRuntime.get_skill("dry_ice")
    var spec = merge_spec(runtime, card_spec, consume_next_modifier("dry_ice"))

    for release_index in range(spec.release_count):
        var delay = release_index * spec.release_interval
        schedule(delay, func():
            fire_dry_ice_volley(spec)
        )
```

---

## 齐射逻辑

```gdscript
func fire_dry_ice_volley(spec: Dictionary) -> void:
    var targets = TargetService.find_nearest_to_wall_enemies(spec.projectile_count)

    for projectile_index in range(spec.projectile_count):
        var target = targets[min(projectile_index, targets.size() - 1)]
        var angle_offset = get_volley_angle_offset(projectile_index, spec.projectile_count)
        fire_dry_ice_projectile(spec, target, angle_offset)
```

---

## 单枚干冰弹逻辑

```gdscript
func fire_dry_ice_projectile(spec: Dictionary, target, angle_offset: float) -> void:
    var chain = ChainController.chain_multiplier
    var damage = base_damage * spec.damage_mul * spec.release_damage_mul * chain
    var pierce_count = max(1, base_pierce_count + spec.pierce_add)

    ProjectileFactory.spawn({
        "type": "dry_ice",
        "origin": PlayerGun.fire_point.global_position,
        "target": target,
        "angle_offset": angle_offset,
        "speed": base_projectile_speed * spec.speed_mul,
        "pierce_count": pierce_count,
        "on_hit_enemy": func(enemy, hit_index, hit_pos):
            DamageService.deal_damage(enemy, damage, "ice", "projectile")
            DamageService.apply_knockback(enemy, base_knockback_distance * spec.knockback_mul, "away_from_wall")
            spec.get("on_hit", func(_e, _d): pass).call(enemy, damage)

            if hit_index == 0 and spec.has("split_on_first_hit"):
                split_small_ice_bullets(hit_pos, damage, spec.split_on_first_hit)
    })
```

---

## 冻结规则

```text
冻结会让怪物短时间无法移动和攻击。
冻结时长受怪物配置倍率影响。
```

推荐配置：

| 怪物类型 | freeze_mul |
|---|---:|
| 普通怪 | 1.0 |
| 精英怪 | 0.5 |
| Boss | 0.25 |

---

## 冻伤规则

```text
冻伤可以叠加 5 层。
每层独立记录剩余时间和每秒伤害。
达到 5 层后，新的冻伤替换最早一层。
```

```gdscript
func add_frostbite(enemy, duration: float, tick_damage: float) -> void:
    if enemy.frostbite_stacks.size() >= 5:
        enemy.frostbite_stacks.pop_front()

    enemy.frostbite_stacks.append({
        "remaining": duration,
        "tick_damage": tick_damage
    })
```
