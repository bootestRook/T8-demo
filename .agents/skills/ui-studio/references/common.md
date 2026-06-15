# 功能 1 & 3：执行流程详情

## 功能 1：PNG/JPG Sprite 提取

完整流程 4 步： init-generate → extract → layout → download

支持 `.png/.jpg/.jpeg` 输入；后端生成流程会统一产出 workspace 根目录的 `001.png`，后续 extract 只依赖这个内部文件名。

### Step 1/4： init-generate

```bash
python ui-studio-cli.py workspace init-generate --files <PNG/JPG设计图> [--comment "描述"] [--prompt txt] [--size 1536x1024] [--background]
```

一步完成 init + upload + generate（AI 生成 sprite sheet `001.png`）。内部流程：prepare-prompt → generate → generate-poll → rename-output → validate-granularity。耗时 2-3 分钟。若使用 `--background`，命令只返回 `run_id`/`session_id`，必须轮询 `workflow generate-status --run-id <id> --session-id <id>` 到成功后，再进入 extract。

### Step 2/4: extract

```bash
python ui-studio-cli.py workflow extract --id <ws_id> [--background]
```

前置依赖：必须先 init-generate（需要 001.png）。

内部流程：prepare-source → detect-artboard → [skip parse-psd] → crop → OCR → detect → alpha → preview → validate-detect → verify-loop → detect-9slice → sprite-list-preview → extract-sprites

- validate-detect：vision agent 对比源图和检测结果；FAIL 表示本次检测质量不可信，workflow 终止，必须新建 workspace 重新生成/提取，不在原 workspace 继续 layout 或下载
- detect-9slice：识别可拉伸区域并写入 sprite metadata，供布局/引擎侧使用
- 耗时 5-10 分钟

### Step 3/4: layout（可选）

```bash
python ui-studio-cli.py workflow layout --id <ws_id> [--frame-index 0] [--background]
```

前置依赖：必须先 extract。多源图时自动执行 per-page-layout → merge-layouts → render-final-preview。耗时 10-15 分钟，**可能超 HTTP 超时**。

### Step 4/4: download

```bash
python ui-studio-cli.py workspace download-sprites --id <ws_id> --output-dir ./output
```

`download-sprites` 仅在 extract 成功并生成 `output/` 后有效；layout 相关文件只有执行 layout 后才存在。实际保存到 `<output-dir>/<ws_id>/`。

| 文件 | 说明 | 生成条件 |
|------|------|----------|
| `output/sprites/sprite-atlas.json` | sprite 图集元数据 | extract 成功 |
| `output/sprites/<label>.png` | 单个透明 sprite PNG | extract 成功 |
| `output/sprite-list-preview.png` | sprite 列表预览 | extract 成功 |
| `output/sprite-layout.xml` | layout XML | layout 成功 |
| `output/preview-*.png` / `output/layout-preview-xml.png` | layout 预览 | layout 成功 |
| `output/restore-manifest.json` | PNG/PSD 原始组合还原清单 | layout 成功 |

### validate-detect 失败处理

extract 返回 `success: false` 且 message 包含 `Sprite detection quality check FAILED` 时，视为检测结果不可用：**必须创建新 workspace 重新走 init-generate → extract 完整流程**。不要在原 workspace 继续 layout、download-sprites，或只重跑 extract。

---

## 功能 3：PSD→Figma 转换

**⚠️ 核心认知**：正式转换的唯一正确入口是 **Figma 插件**。`init-convert` / `workflow convert` 仅生成离线调试 JSON，无法直接导入 Figma。

CLI convert 离线调试流程：prepare-source → parse-psd-deep → classify-layers → map-to-figma → optimize-layout → resolve-effects → generate-figma-json → validate-conversion。

### Step 1/4: 下载插件 + 启动 parse-server（AI 自动执行）

```bash
mkdir -p figma-plugin && cd figma-plugin
curl -O http://192.168.1.53:8008/figma-plugin/manifest.json
curl -O http://192.168.1.53:8008/figma-plugin/code.js
curl -O http://192.168.1.53:8008/figma-plugin/ui.html
curl -o parse-server.zip http://192.168.1.53:8008/figma-plugin/parse-server.zip
unzip -o parse-server.zip -d parse-server
# 启动 parse-server
cd parse-server && nohup bash start.sh > parse-server.log 2>&1 &
# 验证启动：curl http://localhost:8008/health，若无响应试 curl http://localhost:9000/health
```

parse-server 默认 localhost:8008，8008 被占用自动回退 9000。两个端口均在 Figma devAllowedDomains 白名单中。

**Windows 启动**：
```powershell
cd figma-plugin\parse-server
Start-Process -NoNewWindow -FilePath "powershell" -ArgumentList "-ExecutionPolicy RemoteSigned -File start.ps1" -RedirectStandardOutput "parse-server.log" -RedirectStandardError "parse-server-error.log"
```

### Step 2/4: 安装插件（用户操作）

1. 打开 Figma → Plugins → Development → Import from manifest…
2. 选择下载的 manifest.json → 安装完成

### Step 3/4: 使用插件导入 PSD（用户操作）

1. 打开 Figma 文件 → Plugins → PSD to Figma
2. 点击「导入 PSD」→ 选择 PSD 文件
3. 插件自动上传到 parse-server → 解析 → 在 Figma 创建节点

### Step 4/4: 清理（可选）

终止 parse-server：`pkill -f "parse-server/main.py"`（macOS/Linux）

**插件使用教程**：https://dodjoyfs.feishu.cn/wiki/MhzNw3rt7iPF5ykqtHwcRc9An1d

---

## 共用规则

### CLI stdout / JSON 解析

CLI stdout 输出最终 JSON；部分一体化命令的进度信息输出到 stderr。若调用环境合并 stdout/stderr，自动化调用时应按行提取最后一个包含 `success` 的完整 JSON 对象解析，不要假设整段输出都能直接 `json.loads()`。

### 超时处理

| 步骤 | 正常耗时 | 超时风险 |
|------|----------|----------|
| init-generate | 2-3 分钟 | 低 |
| extract | 5-10 分钟 | 低 |
| layout | 10-15 分钟 | **高** |

所有 workflow 命令，以及 `workspace init-generate/init-extract/init-rename/init-convert` 支持 `--background`（后台执行，立即返回 `run_id`/`session_id`）。后台任务必须轮询对应 `*-status` 到成功/失败终态，不能只查一次。`layout` 正常耗时可能超过 CLI HTTP timeout，建议默认后台执行：

```bash
python ui-studio-cli.py workflow extract --id <ws_id> --background
python ui-studio-cli.py workflow extract-status --run-id <id> --session-id <id>
```

### 错误处理

- `workspace_not_found` → workspace 不存在
- `file_not_found` → 上传文件路径错误
- `no_files` → download-sprites 时无文件（extract/rename 未完成，或该流程不产生 sprite output）
- `no_upload` → init-generate 时未上传文件
- PNG/JPG 流程只 init 不 generate → 报错 `001.png not found`（正确：用 init-generate）
- PSD 流程用 init-extract（不需要 generate）

### 流程后清理

AI 必须删除自己创建的中间文件（辅助脚本、临时配置），保留：ui-studio-cli.py、output/ 最终产物、用户源文件、Figma 插件文件。

### 配置

- CLI 客户端只需要 `UI_STUDIO_URL`（默认 http://192.168.1.53:8008）。
- workflow-service 服务端 `.env` 负责 `UI_STUDIO_REMBG_SERVICE_URL`、`UI_STUDIO_REMBG_DEFAULT_MODEL`、`UI_STUDIO_SVN_URLS`、`UI_STUDIO_SVN_USER`、`UI_STUDIO_SVN_PASS`、`MEDIA_API_KEY`、`MEDIA_API_SCRIPT` 等运行时配置。
