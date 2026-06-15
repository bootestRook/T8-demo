---
name: godot-asset-audit
description: 审计 Godot 4 游戏脚手架中的运行时素材和参考资源。当用户添加了图片/音频、素材加载失败、想检查 assets、references、命名、体积、缺失引用或未使用素材时使用。只读检查，输出问题清单，不自动删除文件。
---

# Godot Asset Audit

## 目标

确认素材能被 Godot 稳定加载，并把原始参考资料和运行时素材分清楚：

- `references/`：用户提供的截图、参考图、竞品资料或素材线索。用于理解和临摹，不直接作为运行时加载目录。
- `assets/`：Godot 运行时素材目录。需要在游戏里加载的图片、音频优先放这里。
- `src/`：代码引用位置。检查 `load()`、`preload()`、`res://` 路径和字符串引用。

## 检查步骤

1. 读取 `AGENTS.md` 和 `README.md`。
2. 如果存在 `references/references-manifest.json`，读取它了解原始参考资源来源。
3. 扫描：
   - `assets/**/*`
   - `references/**/*`
   - `src/**/*`
   - `scenes/**/*`
4. 使用 `rg` 查找代码中的素材引用：
   - `res://`
   - `preload\(
   - `load\(
   - `/assets/`
   - `references/`

## 检查项

### 路径

- 运行时代码应使用 `res://assets/...` 引用素材。
- 不要从 `references/` 直接加载 Godot 运行时资源。
- `references/` 中的原始图片如果要用于游戏，先复制到 `assets/`。

### 命名

推荐首版使用小写、短横线或下划线：

- `player-idle-01.png`
- `enemy-slime-idle.png`
- `bg-forest-night.png`

避免中文文件名、空格、括号、混合大小写和过长文件名。

### 格式与体积

- 图标/UI：PNG 或 WebP。
- 背景：WebP/JPG/PNG，首版单张尽量不超过 2 MB。
- 精灵：PNG/WebP，确认透明背景是否正确。
- 音效：OGG/MP3/WAV，首版单个音效尽量不超过 1 MB。

### 缺失与孤儿

- 缺失素材：代码引用了文件，但文件不存在。
- 孤儿素材：`assets/` 中有文件，但代码没有任何引用。
- 参考资源不算孤儿。

## 输出格式

```markdown
## Godot Asset Audit

### Summary
- Runtime assets scanned: N
- Reference files scanned: N
- Missing runtime assets: N
- Orphan runtime assets: N
- Naming issues: N
- Size/format warnings: N

### Missing Runtime Assets
| Code Location | Expected Path | Fix |
|---|---|---|

### Orphan Runtime Assets
| File | Size | Recommendation |
|---|---|---|

### Naming Issues
| File | Issue | Suggested Name |
|---|---|---|

### Reference Notes
| File | Use |
|---|---|

### Verdict
PASS / CONCERNS / FAIL
```

## 约束

- 这是只读 skill。不要删除、移动或重命名素材，除非用户明确要求。
- 如果要生成新素材，先使用 `asset-prompt-spec` 明确规格，再使用 `aistudio-media-generation`。
