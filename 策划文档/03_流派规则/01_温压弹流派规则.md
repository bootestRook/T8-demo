# 温压弹流派规则

## 流派定位

```text
火系弹道技能。
核心体验是爆炸、击退、燃烧、火花扩散。
适合清理密集小怪和缓解城墙压力。
```

---

## 基准效果

每打出一张 **[温压弹]** 卡牌，都会执行：

```text
向最近目标发射 1 枚温压弹。
命中目标造成冲击伤害。
命中点产生爆炸。
爆炸范围内怪物受到爆炸伤害。
爆炸附带击退效果。
再执行该卡牌附加效果。
```

最近目标：

```text
默认选择距离城墙最近的怪物。
```

基准参数：

```gdscript
base_impact_damage = 100
base_explosion_damage = 70
base_explosion_radius = 1.1
base_knockback_distance = 0.7
base_projectile_speed = 16.0
```

伤害吃连锁倍率：

```gdscript
final_impact_damage = base_impact_damage * impact_mul * chain_multiplier
final_explosion_damage = base_explosion_damage * explosion_mul * chain_multiplier
```

范围、击退、弹速不吃连锁倍率。

---

## 温压弹卡牌表

| 卡名 | 费用 | 卡牌文本 | 程序效果 |
|---|---:|---|---|
| 试射温压弹 | 0 | 发射 1 枚温压弹。本次冲击和爆炸伤害 -60%，爆炸范围 -30%。若命中怪物，下一张温压弹爆炸伤害 +20%。 | `impact_mul=0.4; explosion_mul=0.4; radius_mul=0.7; on_any_hit -> add_next_modifier(explosion_mul_add=0.2)` |
| 压力校准弹 | 0 | 发射 1 枚温压弹。本次冲击和爆炸伤害 -70%，爆炸击退 +50%。若爆炸命中至少 2 个怪物，下一张温压弹爆炸范围 +20%。 | `impact_mul=0.3; explosion_mul=0.3; knockback_mul=1.5; on_explosion_end if hit_count>=2 -> add_next_modifier(radius_mul_add=0.2)` |
| 温压弹连发 | 2 | 额外释放 1 枚温压弹，伤害 -20%。 | `release_count += 1; release_damage_mul=0.8; release_interval=0.15` |
| 热能爆炸 | 2 | 温压弹的爆炸伤害 +80%。 | `explosion_mul *= 1.8` |
| 温压冲击 | 2 | 温压弹的冲击伤害 +80%，爆炸击退 +75%。 | `impact_mul *= 1.8; knockback_mul *= 1.75` |
| 热能爆发 | 3 | 温压弹的爆炸范围 +80%。 | `radius_mul *= 1.8` |
| 热能引燃 | 2 | 温压弹爆炸会燃烧怪物 6 秒。 | `on_explosion_hit -> add_burn(duration=6, total_damage=explosion_damage*0.6)` |
| 热能炙身 | 4 | 温压弹赋予的燃烧状态额外追加 3% 目标最大生命值伤害。 | `on_explosion_hit -> burn_total += target.max_hp*0.03; elite/boss use cap` |
| 富燃料填充 | 1 | 温压弹伤害 +20%。 | `impact_mul *= 1.2; explosion_mul *= 1.2` |
| 爆炸火花 | 3 | 温压弹爆炸后释放 3 个火花弹道。 | `on_explosion_end -> spawn_sparks(count=3, damage=explosion_damage*0.35)` |

---

## 统一释放结构

```gdscript
func cast_thermobaric_card(card_spec: Dictionary) -> void:
    var runtime = CoreSkillRuntime.get_skill("thermobaric")
    var spec = merge_spec(runtime, card_spec, consume_next_modifier("thermobaric"))

    for release_index in range(spec.release_count):
        var delay = release_index * spec.release_interval
        schedule(delay, func():
            fire_thermobaric_volley(spec)
        )
```

---

## 单枚温压弹逻辑

```gdscript
func fire_thermobaric_projectile(spec: Dictionary) -> void:
    var target = TargetService.find_nearest_to_wall_enemy()
    if target == null:
        return

    ProjectileFactory.spawn({
        "type": "thermobaric",
        "origin": PlayerGun.fire_point.global_position,
        "target": target,
        "speed": base_projectile_speed * spec.get("speed_mul", 1.0),
        "on_hit": func(hit_enemy, hit_pos):
            execute_thermobaric_hit(hit_enemy, hit_pos, spec)
    })
```

命中：

```gdscript
func execute_thermobaric_hit(hit_enemy, hit_pos: Vector2, spec: Dictionary) -> void:
    var chain = ChainController.chain_multiplier

    var impact_damage = base_impact_damage * spec.impact_mul * chain
    var explosion_damage = base_explosion_damage * spec.explosion_mul * chain
    var radius = base_explosion_radius * spec.radius_mul
    var knockback = base_knockback_distance * spec.knockback_mul

    DamageService.deal_damage(hit_enemy, impact_damage, "fire", "impact")

    var enemies = TargetService.query_enemies_in_circle(hit_pos, radius)
    for enemy in enemies:
        DamageService.deal_damage(enemy, explosion_damage, "fire", "explosion")
        DamageService.apply_knockback(enemy, knockback, "away_from_wall")
        spec.get("on_explosion_hit", func(_e, _d): pass).call(enemy, explosion_damage)

    spec.get("on_explosion_end", func(_p, _d, _enemies): pass).call(hit_pos, explosion_damage, enemies)
```

---

## 火花规则

```text
火花是次级弹道。
火花不算温压弹。
火花不触发温压弹基准效果。
火花不触发同名卡连续冷却。
```

火花目标：

```text
从爆炸点附近选择最多 3 个怪物。
优先选择尚未被本次爆炸命中的怪物。
```
