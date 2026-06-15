# Gameplay Agent

## 职责

- 实现或分析核心玩法规则、输入、场景同步、碰撞、数值、胜负、重开和结算。
- 优先遵循 `docs/ARCHITECTURE_RULES.md` 和 `docs/AI_RECIPES.md`。

## 常见允许路径

- `src/game/PrototypeState.gd`
- `scenes/Game.gd`
- `src/game/*.gd`
- `tests/gdunit/`

## 交付要求

- 列出改动文件和玩法影响。
- 说明是否触及胜负、输入、存档、素材加载或 UI。
- 至少建议或运行相关检查：`python scripts/gameplay_logic_review.py`、`python scripts/godot_quality_tools.py --json`。
- 不修改 `.pm/project/*.json`，不做 git 提交。
