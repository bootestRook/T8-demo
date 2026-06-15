---
name: asset-prompt-spec
description: 为 Godot 4 游戏编写轻量素材规格和 AI 图片生成提示词。当用户需要角色、道具、背景、图标、按钮、特效帧、宣传图，或准备使用 aistudio-media-generation 生成素材时使用。先确认用途、尺寸、风格、数量和落地路径，再产出可直接交给图片生成 skill 的 prompt。
---

# Asset Prompt Spec

## 目标

在生成图片前先把素材说清楚，避免一次生成太多、尺寸不对、风格不统一或无法接入 Godot。

## 使用时机

- 用户说"生成角色/道具/背景/图标/按钮/特效"。
- 用户想复刻或借鉴 `references/` 中的原始游戏视觉。
- 用户准备调用 `aistudio-media-generation`。
- 游戏里缺少某个可见元素，但还没确定素材尺寸和用途。

## 先读上下文

按需读取：

- `docs/game-concept.md`
- `docs/ART_PIPELINE.md`
- `src/game/PrototypeState.gd`
- `scenes/Game.gd`
- `.agents/skills/aistudio-media-generation/SKILL.md`

只读取和当前素材有关的内容，不要把所有参考资料都展开。

## 新手问题

一轮最多问 5 个问题。优先问：

1. 用途：这个素材在游戏里做什么？
2. 类型：角色、敌人、道具、背景、UI、特效还是宣传图？
3. 尺寸：例如 `64x64`、`128x128`、`1024x576`。
4. 风格：参考原游戏、像素风、手绘、扁平、Q 版、写实、赛博等。
5. 背景：透明背景、纯色背景、完整场景还是可平铺。
6. 数量：首版每类 1-3 张；不要一开始批量生成几十张。
7. 动画：是否需要 idle/walk/attack 等帧；如果不确定，先做静态图。

## 规格格式

```markdown
## Asset Spec: [asset-id]

- Role:
- Source: `ai_generated` / `hand_drawn` / `third_party` / `procedural` / `placeholder` / `debug`
- Prompt file: `docs/project/art/prompts/[asset-id].md`
- Provider: `gpt-image-2`
- Runtime path: `assets/[category]/[file-name].png`
- Godot load path: `res://assets/[category]/[file-name].png`
- Source reference: `references/...` 或 `none`
- Size:
- Format:
- Background:
- Style:
- Needs slicing: yes/no
- Manifest entry: `docs/project/art/asset-manifest.json`
- Must include:
- Must avoid:
- Godot usage: `preload("res://assets/...")` 或 `load("res://assets/...")`
```

## Prompt 格式

为每个素材输出：

```markdown
### [asset-id] Prompt
Create a [asset type] for a Godot web game, [style], [camera/framing],
[shape/color/material details], [transparent background or scene background],
target size [size]. Keep the silhouette readable at game scale.
Avoid: [things to avoid].
```

如果需要透明背景，必须明确写 `transparent background`。如果是 UI 图标，强调 `clean silhouette` 和 `readable at small size`。

## 与图片生成 skill 衔接

生成 prompt 后，建议用户使用 `aistudio-media-generation`：

1. 把本 skill 输出的规格和 prompt 交给 `aistudio-media-generation`。
2. 生成少量候选图。
3. 如果是 spritesheet、UI sheet 或外部 PNG，继续用 `godot-sprite-pipeline` / `ui-studio` 切图整理。
4. 用户确认风格后，再放入 `assets/` 并通过 `res://assets/...` 接入 Godot。
5. 更新 `docs/project/art/asset-manifest.json`，记录 source、prompt/provider、源图、运行时路径、透明背景、接入状态和截图可见性。
6. 接入后使用 `godot-asset-audit` 检查路径、命名和缺失引用。

## 输出格式

```markdown
## Asset Prompt Plan

### Assumptions
- ...

### Assets
| ID | Role | Source | Size | Runtime Path | Godot Load Path | Needs Slicing |
|---|---|---|---|---|---|---|

### Prompts
[按素材列出 prompt]

### Next Step
- 用 `aistudio-media-generation` 生成图片。
- 生成后放入 `assets/generated/runtime/`，切图或整理后再放入 `assets/sprites/` 或 `assets/ui/`。
- 更新 `docs/project/art/asset-manifest.json`。
- 接入后运行 `godot-asset-audit` 和 `godot-smoke-check`。
```

不要直接生成或写入二进制素材，除非用户明确要求继续调用图片生成流程。
