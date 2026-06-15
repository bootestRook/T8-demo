---
name: godot-sprite-pipeline
description: 当用户要生成、切分、导入、登记或修复 Godot 2D 精灵、spritesheet、动画条、角色帧、敌人帧、UI sprite 时使用。先确认规格，首版少量资产，运行时落到 assets/。
---

# Godot Sprite Pipeline

## 目标

把 AI 生成或外部提供的 spritesheet 变成 Godot 运行时可用的素材，并保持路径、命名、帧规格、透明背景、缩放和锚点一致。

## 开始前

读取：

- `docs/ART_PIPELINE.md`
- `assets/README.md`
- `src/game/AssetRegistry.gd`
- 当前需要接入的 `Game.gd`、`PlayerVisual.gd` 或相关表现脚本。

## 规格确认

每批只确认并处理 1-3 类素材：

- 用途：玩家、敌人、道具、UI、特效。
- 尺寸：单帧宽高，例如 `64x64`。
- 帧数：优先矩阵 spritesheet，例如 4 帧用 `2x2`、6 帧用 `2x3`、9 帧用 `3x3`；角色和敌人不默认用原始 `1x4` 横条。
- 背景：透明背景优先；如果生成模型不稳定，使用纯 `#FF00FF` 洋红背景，再由脚本清理为透明。
- 落地路径：`assets/sprites/<actor>/<action>/` 或 `assets/ui/`。
- Godot 路径：`res://assets/...`。
- 来源清单：更新 `docs/project/art/asset-manifest.json`，记录 source、prompt/provider、源图、切图输出、后处理元数据、是否接入和截图可见性。

## 生成策略

角色、敌人、NPC、召唤物和动画道具必须把每个动作作为一个独立 sheet 生成和验收：

- 玩家多动作：先分别生成 idle/run/attack/hurt 等动作，再按 Godot 需要组合 `SpriteFrames` 或 atlas。
- 攻击身体帧默认不包含大范围刀光、弹道、命中特效、烟尘和拖尾；这些应作为 `fx`、`projectile` 或 `impact` 单独生成。
- 每个角色动作要求主体在每格居中或底部对齐，比例一致，不碰格子边缘。
- 需要固定格子时，先用 `scripts/make_sprite_layout_guide.py` 生成布局参考图，只作为安全区和网格参考，不作为最终素材。

示例：

```bash
python scripts/make_sprite_layout_guide.py --rows 2 --cols 3 --output assets/generated/runtime/player-run-guide.png
```

## 后处理

如果是规则网格 spritesheet，使用：

```bash
python scripts/process_spritesheet.py assets/generated/runtime/player-walk-sheet.png \
  --rows 2 --cols 2 \
  --out-dir assets/sprites/player/walk \
  --output-width 128 --output-height 128 \
  --align feet --shared-scale --reject-edge-touch \
  --prompt-file docs/project/art/prompts/player-walk.md
```

脚本会输出：

- `raw-sheet.png` / `raw-sheet-clean.png`
- `frame-01.png` 等透明单帧
- `sheet-transparent.png`
- `animation.gif`
- `pipeline-meta.json`
- `prompt-used.txt`

正式动画素材必须把 `pipeline-meta.json` 登记到 `asset-manifest.json` 的 `postprocess_meta` 字段；`art_pipeline_review.py` 会阻断 edge touch、帧数量不一致和坏元数据。

脚本依赖 Pillow 和 numpy；缺失时会给出安装提示。不要把临时下载目录作为运行时路径。

## Prop Pack

小型静态地图道具可以用 prop pack 批处理。只允许紧凑道具使用方形 `2x2`、`3x3` 或 `4x4` pack，例如石头、草丛、木箱、罐子、小灯、小路标。平台、桥、墙、梯子、门、建筑、长陷阱、地形块、碰撞精确物必须单独生成或使用条带/tileset。

提取示例：

```bash
python scripts/extract_prop_pack.py assets/generated/runtime/forest-props-sheet.png \
  --rows 3 --cols 3 \
  --labels rock,shrub,log,lamp,sign,flowers,stump,crate,grass \
  --out-dir assets/sprites/props/forest \
  --reject-edge-touch
```

输出的 `prop-pack.json` 必须登记到相关素材的 `prop_pack_meta` 字段。

## Godot 接入

轻量接入优先级：

1. 静态图：`Sprite2D.texture = load("res://assets/...")`。
2. 少量帧：在表现脚本中按帧数组切换。
3. 复杂动画：再创建 `SpriteFrames` 或 `AnimatedSprite2D`。

运行时素材路径优先登记到 `AssetRegistry.gd`，避免路径散落。
切图后的每个动作或 UI sheet 输出至少登记一个代表性运行时素材到 `docs/project/art/asset-manifest.json`；如果仍是程序化、占位或调试图形，`source` 必须写 `procedural`、`placeholder` 或 `debug`，不能写成正式素材。

示例：

```json
{
  "id": "player_walk",
  "role": "player_actor",
  "source": "ai_generated",
  "prompt_file": "docs/project/art/prompts/player-walk.md",
  "provider": "gpt-image-2",
  "source_path": "assets/generated/runtime/player-walk-sheet.png",
  "runtime_path": "assets/sprites/player/walk/frame-01.png",
  "postprocess_meta": "assets/sprites/player/walk/pipeline-meta.json",
  "transparent_background": true,
  "runtime_bound": true,
  "screenshot_visible": true
}
```

## 验收

- 素材位于 `assets/`，不直接引用 `references/`。
- 文件名小写、短横线或下划线，无空格和超长中文名。
- 首帧能在 Godot 中显示。
- `pipeline-meta.json` 中 `edge_touch_frames` 为空，帧数等于 `rows * cols`。
- `docs/project/art/asset-manifest.json` 中 source、runtime_path、postprocess_meta、runtime_bound 和 screenshot_visible 与实际状态一致。
- `python scripts/export_web.py --json` 通过。
- 接入后运行 `godot-asset-audit`。
