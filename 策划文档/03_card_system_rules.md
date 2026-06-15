# 卡牌系统规则

## 第一版卡牌范围

第一版只开放 3 个核心流派：

```text
温压弹
干冰弹
电磁穿刺
```

所有核心技能卡牌遵循：

```text
打出该流派卡牌时，先执行该流派基准效果，再叠加该卡牌的词条效果。
```

---

## 手牌与补牌

推荐第一版参数：

| 参数 | 数值 |
|---|---:|
| 手牌上限 | 4 |
| 开局抽牌 | 抽满 4 张 |
| 打出卡牌后 | 卡牌进入弃牌堆 |
| 补牌方式 | 空手牌槽自动补牌 |
| 补牌间隔 | 1.5 秒 / 张 |
| 牌库空时 | 弃牌堆洗回牌库 |

弃牌按钮：

```text
点击后弃掉当前全部手牌。
立即补牌至手牌上限。
冷却 20 秒。
弃牌会中断当前连锁。
```

---

## 出牌流程

```gdscript
func try_play_card(card_id: String) -> bool:
    var card = ConfigDB.get_card(card_id)

    if same_name_cd.is_on_cooldown(card.same_name_key):
        return false

    if energy.current < card.cost:
        return false

    energy.consume(card.cost)
    chain_controller.on_card_played(card.cost)

    card_effect_executor.execute(card)

    same_name_cd.on_card_played(card.same_name_key)
    deck_controller.move_to_discard(card_id)
    deck_controller.schedule_refill()

    BattleBus.card_played.emit(card_id, card.cost)
    return true
```

---

## 费用与连锁倍率

规则：

```text
连锁不限制时间。
弃牌中断连锁。
倍率上限暂定 999。
0 费卡不提升倍率，但也不打断连锁。
```

推荐实现：

```gdscript
var chain_multiplier: int = 1
var last_positive_cost: int = -1

func on_card_played(cost: int) -> void:
    if cost <= 0:
        return

    if last_positive_cost == -1:
        last_positive_cost = cost
        return

    if cost > last_positive_cost:
        chain_multiplier = min(chain_multiplier + 1, 999)

    last_positive_cost = cost

func break_chain() -> void:
    chain_multiplier = 1
    last_positive_cost = -1
```

例子：

```text
1费 → 2费 → 3费 → 1费 → 2费 → 3费
倍率：1x → 2x → 3x → 3x → 4x → 5x
```

---

## 同名卡连续冷却

规则：

```text
同名卡在 10 秒内连续打出 3 次后，该同名卡进入 10 秒冷却。
中间插入其他卡牌会重置连续计数。
```

例子：

```text
A → A → A：A 冷却 10 秒
A → B → A → B → A：不触发 A 冷却
A → A，超过 10 秒后再 A：不触发 A 冷却
```

实现：

```gdscript
var streak_key: String = ""
var streak_count: int = 0
var streak_start_time: float = 0.0
var cooldown_until := {}

func on_card_played(same_name_key: String) -> void:
    var now = BattleState.battle_time

    if streak_key != same_name_key:
        streak_key = same_name_key
        streak_count = 1
        streak_start_time = now
        return

    if now - streak_start_time > 10.0:
        streak_count = 1
        streak_start_time = now
        return

    streak_count += 1

    if streak_count >= 3:
        cooldown_until[same_name_key] = now + 10.0
        streak_key = ""
        streak_count = 0
        streak_start_time = 0.0

func is_on_cooldown(same_name_key: String) -> bool:
    return cooldown_until.get(same_name_key, 0.0) > BattleState.battle_time
```

`same_name_key` 规则：

```text
默认等于卡牌名。
如果有 + 版或升级版需要共享冷却，可配置相同 same_name_key。
```

---

## 0 费卡规则

```text
1. 0费卡也可以触发核心技能基准效果。
2. 0费卡不提升连锁倍率。
3. 0费卡不打断连锁。
4. 0费卡计入同名卡连续冷却。
5. 0费卡自身伤害必须明显降低，主要用于垫牌、修正目标或强化下一张同流派卡。
```

---

## 卡牌配置字段

```text
card_id
card_name
same_name_key
core_skill
cost
icon
rarity
unlock_level
text
effect_id_list
```

卡牌执行不要硬编码卡名，应根据 `core_skill` 和 `effect_id_list` 分发执行。
