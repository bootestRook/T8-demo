---
name: ui-studio
description: |
  UI Studio：PSD/PNG/JPG UI sprite 提取、layout 参考生成、PSD→Figma 可编辑格式转换、PSD 组件自动命名。Use when the user explicitly mentions "ui-studio" or "ui-studio-cli", provides UI design images/sprite sheets/PSD files, asks to extract UI sprites/layout, convert PSD to Figma, or rename/name PSD layers/components. Do not trigger for generic art style boards unless the task is to extract UI sprites, buttons, icons, panels, layout, Figma layers, or PSD names.
---

# UI Studio Skill

通过 `ui-studio-cli.py` 调用 UI Studio API。命令 stdout 输出最终 JSON，可用 `json.loads()` 解析；`workspace init-generate/init-extract/init-rename/init-convert/init-rename-prep` 的中间进度会输出到 stderr，若调用环境合并 stdout/stderr，应按行提取最后一个包含 `success` 的 JSON 作为结果，并保留最早出现的 `workspace_id` 便于超时恢复。

**服务地址**：`http://192.168.1.53:8008`

## 四大功能与路由

| # | 功能 | 输入 | 输出 | 流程详情 |
|---|------|------|------|----------|
| 1 | **PNG/JPG Sprite 提取** | UI 设计图 (PNG/JPG/JPEG) | sprite 图集 + layout XML | 读 `references/common.md` §功能1 |
| 2 | **PSD Sprite 拆分** | PSD 文件 | sprite 图集 + (layout XML, 仅single/independent) | 读 `references/psd-modes.md` |
| 3 | **PSD→Figma 转换** | PSD 文件 | Figma 可编辑图层 | 读 `references/common.md` §功能3 |
| 4 | **PSD 组件命名** | PSD 文件 + 前缀 | rename-map.json + JSX 脚本 | 见下方 §命名功能 |

**⚠️ 功能选择规则（按优先级从高到低匹配）**：

1. 用户提及 **命名 / 重命名 / rename / 组件命名 / 图层命名** → **功能 4**
2. 用户提及 **figma / Figma / 转换 / 转化 / 转成 / 转为 / convert / 转Figma** → **功能 3**
3. 输入是 **PNG/JPG 图片** → **功能 1**
4. 输入是 **PSD** 且未提及 figma/转换/命名 → **功能 2**

**关键区分**：功能 2 和功能 3 输入相同（PSD），但输出完全不同：
- 功能 2 输出 **sprite 图片**（栅格化 PNG，文字不可编辑）
- 功能 3 输出 **Figma 可编辑图层**（文字可改、形状可调）

只要用户意图涉及"figma"或"转换格式"，**必须选功能 3**。

### PSD 子模式路由（功能 2）

| 条件 | 模式 | 详情 |
|------|------|------|
| PSD 只有 1 个画板 | **single** | 支持layout |
| 多画板 + 默认/统一切分 | **unified** | 不支持layout，共享去重 |
| 多画板 + 独立切分意图 | **independent** | 每画板独立，支持layout |

详细步骤、内部流程、产物列表 → 读 `references/psd-modes.md`

---

## §命名功能（功能 4）

为 PSD 中所有图层自动生成规范命名 `{prefix}{category}{seq}`。流程本地规则优先（OpenCV 形状分类 + pHash 内容去重），并在初始预览后进行一次多模态审计和一次纯 LLM 安全规划；AI 失败时自动回退本地结果，不影响最终 JSX 输出。

**命名格式**：`{prefix}{category}{seq}`，seq=1 省略数字（如 `btn` 而非 `btn1`）。同组同内容共享名称，跨组始终不同编号。通用名/原画自动保留。

**类别**：后端自动分类为 20 个类别（bg, btn, icon, tab, frame, title, mask, tag, label, avatar, bar, dk, input, progress, sep, badge, dialog, checkbox, arrow, card），匹配不到时 fallback `item`。

**前缀必填**：用户触发功能 4 但未提供 `prefix` / 前缀时，必须先询问用户提供命名前缀（例如：`兑换商店_不灭火种_`）。在获得前缀前，不要调用 `workspace init-rename` 或 `workflow rename`。

### 运行命名工作流

```bash
# 一步完成（推荐）
python ui-studio-cli.py workspace init-rename \
  --files design.psd \
  --prefix "兑换商店_不灭火种_" \
  --hash-threshold 10
```

通用名库 (`common-names.json`) 和命名词典 (`naming-dictionary.json`, 20类) 位于服务端 `data/workspaces/`，无需客户端手动采集。rename workflow 每次启动时会按 `common-names.json` 中记录的 `svn_revisions` 检查 SVN 目录版本；版本变化时通过 `scripts/svn_fetch_names.py` 重新拉取通用名并刷新全局缓存。

**SVN 配置（服务端）**：由 workflow-service 的 `.env` 提供：`UI_STUDIO_SVN_URLS`、`UI_STUDIO_SVN_USER`、`UI_STUDIO_SVN_PASS`。这些是服务端配置，不是 CLI 客户端配置；不要在命令行参数或日志中输出 SVN 密码。后端向 helper 进程传递密码时使用环境变量，helper 调用 SVN 时使用 `--password-from-stdin` + `--no-auth-cache`，避免密码出现在进程参数或 SVN 本地认证缓存中。

### 命名产物

| 文件 | 说明 |
|------|------|
| output/rename-map.json | 旧名→新名映射表 |
| output/rename-map.ai-reviewed.json | AI 安全审计后的最终映射表；不存在时表示使用本地映射 |
| output/rename-script.jsx | Photoshop ExtendScript，在 PS 中一键执行重命名 |
| output/rename-preview.png | 最终重命名预览图，已和 JSX 使用的 map 对齐 |
| output/rename-components/manifest.json | 组件集合审阅清单 |
| output/rename-components/*.png | 每个待重命名组件/组合件的审阅裁剪图 |
| debug/rename/ai-visual-audit.json | 多模态审计结果 |
| debug/rename/ai-rename-plan.json | 纯 LLM 安全 patch plan |
| debug/rename/apply-ai-rename-plan-report.json | 本地白名单应用报告 |

`rename-components/` 只包含组件类审阅图：`merge_and_rename` 组级组件，以及已经整理好 PSD 结构中的 `list/<item>/<part>` preview-only `component_candidate`。`component_candidate` 只用于 manifest 与裁剪图审阅，不会进入 Photoshop JSX 执行，也不会直接改 PSD 结构。

最终标准路径始终是 `output/rename-preview.png` 和 `output/rename-components/`；初始 AI 审计用预览保存在 `debug/rename/initial/`，通常只用于排查。

下载：
```bash
python ui-studio-cli.py workspace download --id <ws_id> --path output/rename-map.json -o ./rename-map.json
python ui-studio-cli.py workspace download --id <ws_id> --path output/rename-script.jsx -o ./rename-script.jsx
```

---

## 命令速查

### 一步完成（推荐）

| 命令 | 功能 |
|------|------|
| `workspace init-generate --files <PNG/JPG>...` | 功能 1：创建 + 上传 + 生成 |
| `workspace init-extract --files <PSD>... [--artboard-mode auto/unified/independent]` | 功能 2：创建 + 上传 + PSD 提取 |
| `workspace init-rename --files <PSD> --prefix <前缀>` | 功能 4：创建 + 上传 + 命名 |
| `workspace init` | 手动创建 workspace + 上传文件，不自动启动 workflow |
| `workspace init-rename-prep --files <PSD>...` | 命名样本准备：创建 workspace + 上传已命名 PSD，不自动执行 rename |

> **功能 3 默认不通过 CLI 完成正式导入**。AI 下载插件 + parse-server，告知用户在 Figma 中使用。CLI 中的 `workspace init-convert` / `workflow convert` 只生成离线调试 JSON（`output/figma-document.json`），无法直接导入 Figma；除非用户明确要求离线调试，否则不要自动调用。

### Workflow 命令

| 命令 | 用途 |
|------|------|
| `workflow generate --id <ws_id>` | 对已创建 workspace 执行 sprite-sheet-generate |
| `workflow extract --id <ws_id>` | Sprite 提取 |
| `workflow layout --id <ws_id>` | Layout 重构 |
| `workflow convert --id <ws_id>` | PSD→Figma 离线调试 JSON（非正式 Figma 导入入口） |
| `workflow rename --id <ws_id> --prefix <前缀>` | PSD 组件命名 |

### 状态查询

| 命令 | 用途 |
|------|------|
| `workflow generate-status --run-id <id> --session-id <id>` | generate 状态 |
| `workflow extract-status --run-id <id> --session-id <id>` | extract 状态 |
| `workflow layout-status --run-id <id> --session-id <id>` | layout 状态 |
| `workflow convert-status --run-id <id> --session-id <id>` | convert 离线调试状态 |
| `workflow rename-status --run-id <id> --session-id <id>` | rename 状态 |

### 下载

| 命令 | 用途 |
|------|------|
| `workspace download-sprites --id <ws_id> --output-dir <目录>` | 批量下载 sprite 产物；仅适用于功能 1/2 的 sprite 输出，需 extract 完成后执行，实际保存到 `<目录>/<ws_id>/` |
| `workspace download --id <ws_id> --path <相对路径> [-o <输出路径>]` | 单文件下载 |

### 辅助

| 命令 | 用途 |
|------|------|
| `health` | 检查服务运行 |
| `workflow list` | 列出服务端注册的 workflow |
| `workspace status --id <ws_id>` | workspace 状态 |
| `workspace list-files --id <ws_id>` | 列出可下载产物 |

### 后台执行

所有 workflow 命令，以及 `workspace init-generate/init-extract/init-rename/init-convert` 均支持 `--background`。后台执行会立即返回 `run_id` 和 `session_id`，后续必须用对应 `*-status` 命令查询状态。轮询时必须成对使用返回的 `run_id` + `session_id`，直到状态进入成功/失败终态；不要只查询一次就继续下一步。长任务建议优先使用 `--background`，尤其是 layout。

功能 1 失败策略：如果 `workflow extract` 或 `extract-status` 返回 `Sprite detection quality check FAILED`，停止当前 workspace。不要在同一 workspace 重试 extract 或 layout；创建新 workspace 重新执行 `init-generate → extract → layout(optional)`。旧 workspace 仅用于诊断，不下载其部分产物作为最终结果。

---

## 输出产物

### Sprite 提取产物（功能 1、2）

`workspace download-sprites` 下载 `output/` 下的 sprite 产物。核心文件：

| 文件 | 说明 | 生成条件 |
|------|------|----------|
| `output/sprites/sprite-atlas.json` | TexturePacker 格式图集元数据 | extract 完成 |
| `output/sprites/<label>.png` | 单个 sprite PNG（透明背景） | extract 完成 |
| `output/sprite-list-preview.png` | sprite 列表预览 | extract 完成；部分 PSD unified 模式不生成 |
| `output/sprite-layout.xml` | Layout 重构 XML | 执行 layout 后 |
| `output/restore-manifest.json` | PNG/PSD 原始组合还原清单 | 执行 layout 后 |

### PSD→Figma 产物（功能 3）

| 文件/目录 | 说明 | 生成条件 |
|----------|------|----------|
| `manifest.json` + `code.js` + `ui.html` + `parse-server/` | 服务端 `/figma-plugin/*` 提供的插件文件；AI 自动下载，不是单个 workspace 的产物 | 正式 Figma 插件流程 |
| `output/figma-document.json` | CLI convert 生成的离线调试 JSON；无法导入 Figma，仅调试用 | 仅显式执行 CLI convert |

### PSD 组件命名产物（功能 4）

| 文件 | 说明 | 生成条件 |
|------|------|----------|
| `output/rename-map.json` | 旧名→新名映射 | rename 完成 |
| `output/rename-map.ai-reviewed.json` | AI-reviewed 最终映射；JSX 优先读取它 | apply-ai-rename-plan 完成 |
| `output/rename-script.jsx` | Photoshop 一键重命名脚本 | rename 完成 |
| `output/rename-preview.png` | 最终预览图 | preview-final 完成 |
| `output/rename-components/manifest.json` | 组件集合审阅清单 | preview-final 完成且组件图生成成功 |
| `output/rename-components/*.png` | 每个待重命名组件/组合件的审阅裁剪图；来自 PSD composite 裁剪，不是生产级独立 sprite | preview-final 完成且组件图生成成功 |
| `debug/rename/ai-visual-audit.json` | 多模态视觉审计结果 | ai-visual-audit 完成或跳过 |
| `debug/rename/ai-rename-plan.json` | 安全 patch plan | ai-rename-plan 完成 |
| `debug/rename/apply-ai-rename-plan-report.json` | 本地 apply 报告 | apply-ai-rename-plan 完成 |

---

## ⚠️ 流程结束后清理

AI 必须删除自己创建的中间文件（辅助脚本、临时配置），保留：ui-studio-cli.py、output/ 最终产物、用户源文件、Figma 插件文件。

---

## 配置

- **CLI 客户端配置**：`UI_STUDIO_URL`（默认 http://192.168.1.53:8008）
- **workflow-service 服务端配置**：`UI_STUDIO_REMBG_SERVICE_URL`、`UI_STUDIO_REMBG_DEFAULT_MODEL`、`UI_STUDIO_SVN_URLS`、`UI_STUDIO_SVN_USER`、`UI_STUDIO_SVN_PASS`、`MEDIA_API_KEY`、`MEDIA_API_SCRIPT` 等。服务端配置写入 `backend/workflow-service/.env`，CLI 不直接读取这些变量。
- **rembg-service 服务端配置**：`DEFAULT_MODEL`、`MODEL_CACHE_DIR`、`SERVICE_PORT`，写入 `backend/rembg-service/.env`。

**端口区分**：
- `192.168.1.53:8008` = 远程正式服务器（CLI 调用、下载文件）
- `localhost:8008/9000` = 本地 parse-server（Figma 插件连接，与远程 workflow-service 无关）
