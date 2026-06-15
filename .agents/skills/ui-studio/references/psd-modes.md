# PSD Sprite 拆分：3 种子模式

PSD 输入时，图层已有名称和透明通道，不需要 AI 生成、OCR、去背景等步骤。根据画板数量选择子模式。

## 入口（3 种模式共用）

```bash
python ui-studio-cli.py workspace init-extract --files design.psd [--source-format auto] [--artboard-mode auto/unified/independent] [--comment "意图"] [--background]
```

画板检测与模式选择：
1. detect-artboard 步骤检测 PSD 画板数量
2. 单画板 → **single**
3. 多画板 + `--artboard-mode auto`（默认）：LLM 分析 --comment → 识别"独立切分"意图 → independent，否则 → unified
4. 可显式指定 `--artboard-mode unified/independent`

---

## Single 模式（单画板 PSD）

产物与 PNG 流程相同，支持 layout。

### 内部流程

```
prepare-source → detect-artboard(1画板→single) → parse-psd → [skip crop] → [skip ocr] → detect(读现有) → [skip alpha rembg] → preview → [skip validate-detect] → [skip verify-loop] → detect-9slice → sprite-list-preview → extract-sprites
```

### 最终产物

| 文件 | 说明 |
|------|------|
| sprite-map.json | sprite 元数据（含位置信息） |
| sprite-alpha.png | RGBA atlas |
| output/sprites/<label>.png | 各 sprite 独立 PNG（透明背景） |
| output/sprites/sprite-atlas.json | TexturePacker 格式元数据 |
| output/sprite-list-preview.png | sprite 列表预览 |

### Layout

```bash
python ui-studio-cli.py workflow layout --id <ws_id> [--background]
```

### 下载

```bash
python ui-studio-cli.py workspace download-sprites --id <ws_id> --output-dir ./output
```

---

## Unified 模式（多画板统一切分，默认）

所有画板 sprite 统一到一个文件夹，共享组件去重，无 atlas/位置信息。**不支持 layout**。

### 内部流程

```
prepare-source → detect-artboard(多画板→unified) → parse-psd(--no-atlas) → [skip crop] → [skip ocr] → detect → [skip alpha rembg] → [skip preview] → [skip validate-detect] → [skip verify-loop] → [skip detect-9slice] → [skip sprite-list-preview] → extract-sprites
```

parse-psd 使用 `--no-atlas`，选项，所有 sprite 坐标 x=0/y=0，不生成 atlas 图。

### 最终产物

| 文件 | 说明 |
|------|------|
| sprite-map.json | 所有 sprite 元数据（x=0/y=0） |
| output/sprites/<label>.png | 各 sprite PNG（共享组件仅一份） |
| output/sprites/sprite-atlas.json | TexturePacker 格式元数据（mode=unified，无 atlas 图引用） |

**不生成**: sprite-alpha.png, preview-labeled.png, sprite-list-preview.png

**⚠️ 不支持 layout**（无位置信息，调用会报错）

### 下载

```bash
python ui-studio-cli.py workspace download-sprites --id <ws_id> --output-dir ./output
```

---

## Independent 模式（按画板独立切分）

每个画板独立走完整 extract 流程，输出到 `artboards/N_name/` 子目录，支持 layout。

### 内部流程

```
prepare-source → detect-artboard(多画板→independent) → parse-psd(per-artboard) → [skip crop] → [skip ocr] → detect(读现有) → [skip alpha rembg] → preview(每画板) → [skip validate-detect] → [skip verify-loop] → detect-9slice(每画板) → sprite-list-preview(每画板) → extract-sprites(每画板)
```

每个画板独立解析到 `artboards/N_name/` 子目录。

### 最终产物（每画板子目录）

每个画板子目录 `artboards/N_name/` 包含完整产物集：

| 文件 | 说明 |
|------|------|
| sprite-map.json | 该画板 sprite 元数据（含位置信息） |
| sprite-alpha.png | 该画板 RGBA atlas |
| output/sprites/<label>.png | 该画板各 sprite PNG |
| output/sprites/sprite-atlas.json | 该画板 TexturePacker 格式元数据 |
| debug/preview-labeled.png | 该画板带标签预览 |
| output/sprite-list-preview.png | 该画板 sprite 列表预览 |

### Layout

```bash
python ui-studio-cli.py workflow layout --id <ws_id> [--background]
```

### 下载

```bash
python ui-studio-cli.py workspace download-sprites --id <ws_id> --output-dir ./output
```

---

## PSD 通用规则

适用于所有 PSD 模式：
- 隐藏图层自动跳过；图层组递归展开；过小图层（< 4px）自动过滤
- PSD 模式跳过：crop, ocr, alpha(rembg), validate-detect, verify-loop
- detect-9slice 在 single/independent 模式执行；unified 模式因无 atlas/位置信息会跳过
- PSD 合成预览保存到 `debug/psd-composite.png`
- 并发保护：同一 workspace 同时只允许一个 extract 运行
