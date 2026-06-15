# 电磁穿刺流派规则

## 流派定位

```text
电系技能。
核心体验是电磁穿刺、小范围爆炸、麻痹、矩阵减速、粒子裂变和多次释放。
```

---

## 基准效果

每打出一张 **[电磁穿刺]** 卡牌，都会执行：

```text
向最近目标释放 1 次电磁穿刺。
命中目标造成穿刺伤害。
命中目标会短暂麻痹。
再执行该卡牌附加效果。
```

基准参数：

```gdscript
base_pierce_damage = 90
base_paralyze_duration = 0.3
base_explosion_damage = 55
base_explosion_radius = 1.0
```

说明：

```text
电磁穿刺基准不默认带爆炸。
带“电磁爆炸”的卡牌，才会给本次电磁穿刺附加爆炸。
```

---

## 电磁穿刺卡牌表

| 卡名 | 费用 | 卡牌文本 | 程序效果 |
|---|---:|---|---|
| 电容试放 | 0 | 释放 1 次电磁穿刺。本次伤害 -70%，麻痹时间 -0.2 秒。若命中怪物，下一张电磁穿刺伤害 +20%。 | `pierce_damage_mul=0.3; paralyze_add=-0.2; on_hit -> add_next_modifier(pierce_damage_mul_add=0.2)` |
| 磁极校准 | 0 | 释放 1 次电磁穿刺。本次伤害 -80%。若命中怪物，下一张电磁穿刺优先锁定精英、Boss 或近墙怪物，且爆炸范围 +20%。 | `pierce_damage_mul=0.2; on_hit -> add_next_modifier(target_priority,bomb_radius_mul_add=0.2)` |
| 电磁爆炸 | 1 | 电磁穿刺命中时附带小范围爆炸。 | `explosion_enabled=true` |
| 电磁爆炸增伤 | 2 | 爆炸伤害 +80%。 | `explosion_enabled=true; explosion_damage_mul=1.8` |
| 电磁爆炸扩张 | 2 | 爆炸范围 +80%。 | `explosion_enabled=true; explosion_radius_mul=1.8` |
| 电磁矩阵 | 3 | 爆炸范围内生成低伤害和减速效果的电磁矩阵，持续 4 秒。 | `explosion_enabled=true; on_explosion_end -> spawn_matrix(duration=4,tick=0.5,slow=35%)` |
| 电磁分流 | 2 | 额外释放 1 次，伤害 -20%。第二次重新锁定目标。 | `release_count += 1; release_damage_mul=0.8; release_interval=0.18` |
| 麻痹增伤 | 3 | 电磁穿刺伤害 +30%，麻痹时间 +1.5 秒。 | `pierce_damage_mul=1.3; paralyze_add=1.5` |
| 电磁裂变 | 4 | 电磁穿刺命中后向 6 个方向释放穿透 5 的电磁粒子。 | `on_hit -> spawn_particles(count=6,pierce=5,damage=pierce_damage*0.35)` |
| 电磁分流+ | 4 | 电磁穿刺额外释放 1 次，无伤害衰减。第二次重新锁定目标。 | `release_count += 1; release_damage_mul=1.0; release_interval=0.18` |

---

## 统一释放结构

```gdscript
func cast_electro_pierce_card(card_spec: Dictionary) -> void:
    var runtime = CoreSkillRuntime.get_skill("electro_pierce")
    var spec = merge_spec(runtime, card_spec, consume_next_modifier("electro_pierce"))

    for release_index in range(spec.release_count):
        var delay = release_index * spec.release_interval
        schedule(delay, func():
            fire_electro_pierce_volley(spec)
        )
```

---

## 单次电磁穿刺逻辑

```gdscript
func fire_electro_pierce(spec: Dictionary, target) -> void:
    if target == null:
        return

    var chain = ChainController.chain_multiplier
    var damage = base_pierce_damage * spec.pierce_damage_mul * spec.release_damage_mul * chain
    var hit_pos = target.global_position

    DamageService.deal_damage(target, damage, "electric", "pierce")

    DamageService.apply_paralyze(
        target,
        max(0.0, base_paralyze_duration + spec.paralyze_add) * target.paralyze_mul
    )

    spec.get("on_hit", func(_target, _hit_pos, _damage): pass).call(target, hit_pos, damage)

    if spec.explosion_enabled:
        execute_electro_explosion(hit_pos, spec)
```

---

## 电磁爆炸逻辑

```gdscript
func execute_electro_explosion(center: Vector2, spec: Dictionary) -> void:
    var chain = ChainController.chain_multiplier
    var damage = base_explosion_damage * spec.explosion_damage_mul * spec.release_damage_mul * chain
    var radius = base_explosion_radius * spec.explosion_radius_mul
    var enemies = TargetService.query_enemies_in_circle(center, radius)

    for enemy in enemies:
        DamageService.deal_damage(enemy, damage, "electric", "explosion")

    spec.get("on_explosion_end", func(_center, _radius, _enemies): pass).call(center, radius, enemies)
```

---

## 电磁矩阵逻辑

```gdscript
func spawn_electro_matrix(center: Vector2, radius: float, duration: float) -> void:
    AreaEffectFactory.spawn({
        "type": "electro_matrix",
        "center": center,
        "radius": radius,
        "duration": duration,
        "tick_interval": 0.5,
        "on_tick": func(area):
            var enemies = TargetService.query_enemies_in_circle(area.center, area.radius)
            for enemy in enemies:
                DamageService.deal_damage(enemy, 10 * ChainController.chain_multiplier, "electric", "matrix")
                enemy.apply_temp_speed_multiplier("electro_matrix", 0.65, 0.6)
    })
```

---

## 电磁粒子规则

```text
电磁粒子是次级弹道。
电磁粒子不是电磁穿刺。
电磁粒子不触发电磁穿刺基准效果。
电磁粒子不触发同名卡连续冷却。
电磁粒子不会再次裂变。
```

```gdscript
func spawn_electro_particles(origin: Vector2, count: int, pierce: int, damage: float) -> void:
    for i in range(count):
        var angle = TAU / count * i
        ProjectileFactory.spawn({
            "type": "electro_particle",
            "origin": origin,
            "angle": angle,
            "speed": 20.0,
            "pierce_count": pierce,
            "on_hit_enemy": func(enemy, _hit_index, _hit_pos):
                DamageService.deal_damage(enemy, damage, "electric", "particle")
        })
```
