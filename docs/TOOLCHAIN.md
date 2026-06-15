# 内置依赖与离线启动

## 目标

让新手尽量只运行一次 `init.cmd`。脚手架只使用 `tools/` 中的 portable 工具或工具压缩包，不再依赖 `installers/` 安装包链路。

## 目录

- `tools/`：portable 工具和工具压缩包。
- `scripts/bootstrap-cn.ps1`：Windows 首启脚本，负责解包和环境检查。
- `init.cmd`：新手双击入口。

## 工具发现顺序

脚本和 OpenCode 插件按固定顺序找依赖：

1. `tools/` 中已解包的 portable 工具。
2. `tools/` 中的工具压缩包，首启时自动解包。
3. 系统 `PATH` 和 `GODOT4_PATH`。

推荐稳定结构：

```text
tools/
├── python/python.exe
├── node/node.exe
├── node/npm.cmd
├── node/npx.cmd
├── git/cmd/git.exe
├── godot/Godot.exe
├── gdtoolkit/python/                 # 必选，gdtoolkit Python 包
├── agent-browser/agent-browser.exe   # 可选，完整自动试玩用
├── godot-mcp-node/                   # 内置，Coding-Solo/godot-mcp npm 本地包
└── godotmcp/                         # 可选，xulek/godotmcp 本地仓库
```

支持直接放入的压缩包：

```text
tools/
├── python-3.x.x-embed-amd64.zip
├── node-v24.x.x-win-x64.zip
├── PortableGit-2.x.x-64-bit.7z.exe
├── Godot_v4.x-stable_win64.exe.zip
└── Godot_v4.x-stable_export_templates.tpz
```

`init.cmd` 不会联网下载依赖，也不会安装 Python/Node.js/Git 到系统目录。PortableGit 的 `.7z.exe` 只会解包到 `tools/git/`；Godot zip 只会解包到 `tools/godot/`；Python embeddable zip 只会解包到 `tools/python/`；Node.js zip 只会解包到 `tools/node/`。解包和基础检查后，`init.cmd` 会执行 `python scripts/setup_ai_mcp.py --apply-project`，只写入项目级 AI MCP 配置，不修改用户全局配置。

首启后，如果系统没有 `python` 命令，可以直接使用：

```text
tools/python/python.exe scripts/check_env.py --json --fast
tools/python/python.exe scripts/ai_review.py --strict
```

`init` 默认使用 `check_env.py --fast`，只做快速可用性检查；交付前由 `ai_review.py` 执行完整环境、体验结构、导出和浏览器体验检查。

`Node.js` 是可选但推荐的 AI 工具链基础依赖。把官方 Windows zip 放入 `tools/` 后，`init.cmd` 会自动解包到 `tools/node/`，`check_env.py` 会检测 `node`、`npm`、`npx`。GodotMCP、部分浏览器工具、UI/PSD 工具或未来 Node CLI 都优先使用 `tools/node/`，再回退系统 PATH。

`experience_check.py` 默认使用 `--browser-backend auto`：优先尝试 Playwright Python 浏览器后端，失败后回退 `agent-browser`。`godot_native_screenshot_check.py` 可在日常开发中直接运行 Godot 并保存 viewport 截图，不依赖浏览器自动化；但 Web 交付前仍需要真实浏览器检查。

`Playwright Python` 是可选浏览器后端。若当前 Python 环境已安装 `playwright` 且浏览器包可用，体验检查会自动使用它。安装 Playwright 或下载 Chromium 属于联网/外部依赖操作，执行前必须先获得用户确认。

`agent-browser` 是可选的兼容浏览器自动化 CLI。它不随轻量模板默认打包，因为浏览器运行时和安装方式具有平台差异。完整 QA 或离线交付环境可以：

- 把可执行命令放到 `tools/agent-browser/agent-browser.exe`、`agent-browser.cmd` 或 `agent-browser.ps1`；
- 或设置 `AGENT_BROWSER_PATH`；
- 或安装到系统 `PATH`。

如果 Playwright 和 `agent-browser` 都不可用，`python scripts/experience_check.py --strict` 会完成导出和预览检查，但浏览器自动试玩会降级为 `CONCERNS` 并返回非 0。

`GDScript Toolkit` 是必选质量门禁，`GDUnit4` 为可选检查，由统一入口调度：

```bash
python scripts/check_env.py --json
python scripts/setup_quality_tools.py
python scripts/godot_quality_tools.py --json
```

接入边界：

- GDScript Toolkit：依赖清单在 `spec/quality_tools.json`，默认安装到 `tools/gdtoolkit/python/`；门禁运行 `gdlint` 和 `gdformat --check`，不自动改格式。
- GDUnit4（可选）：addon 位于 `addons/gdUnit4/`，测试位于 `tests/gdunit/` 或 `test/`；报告写入 `reports/gdunit4/`。

默认开箱即用模板会保留 `tools/gdtoolkit/python/`，保证解压后不联网也能跑默认质量门禁。`addons/gdUnit4/` 保留为可选能力。只有显式导出 `--no-tools` 瘦身包时，才需要接收方重新运行安装命令。

首次运行 `python scripts/setup_quality_tools.py --install --yes` 会联网安装 `gdtoolkit`；如需 GDUnit4 addon，额外执行 `python scripts/setup_quality_tools.py --install-gdunit --yes`。执行前必须先获得明确确认；默认门禁缺失 GDScript Toolkit 时返回 `FAIL`。

Windows bootstrap 也提供显式安装入口，但不会由默认 `init.cmd` 静默触发：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/bootstrap-cn.ps1 -InstallQualityTools
```

`GodotMCP` 是内置的可选编辑器桥接能力，不参与游戏运行时。轻量启动、运行和调试默认使用 `tools/godot-mcp-node/node_modules/@coding-solo/godot-mcp/build/index.js`；深度编辑器控制仍可把 `xulek/godotmcp` 放到 `tools/godotmcp/`。脚手架按当前项目根目录和当前 Godot 路径动态生成 MCP 客户端配置：

```bash
python scripts/check_env.py --json
python scripts/setup_godot_mcp.py --provider auto
python scripts/setup_ai_mcp.py --apply-project
```

如果 `tools/godot-mcp-node/` 缺失，确认允许联网后可运行 `python scripts/setup_godot_mcp.py --provider coding-solo --install-coding-solo --yes` 安装到项目内 `tools/godot-mcp-node/`。仍缺包时脚本会退回到 `npx @coding-solo/godot-mcp` 配置；首次执行 `npx`、下载外部仓库、`pip install` 或复制外部 Godot addon 前，必须先获得明确确认。即使 `tools/node/npx.cmd` 已存在，也不代表可以静默联网拉包。详细流程见 `docs/GODOT_MCP.md`。

`setup_ai_mcp.py --apply-project` 会写入：

- `opencode.json`：添加 `mcp.godot`，OpenCode 重启或刷新后自动加载。
- `.mcp.json`：Claude Code 项目级 MCP 配置，本地生成且不随 Git 提交或模板导出。
- `.codex/config.toml`：Codex 项目级 MCP 配置，本地生成且不随 Git 提交或模板导出；为避免 Codex 启动 MCP 时工作目录不在项目根，脚本会写入当前机器的绝对 wrapper 路径。

需要把当前项目注册到用户全局 AI 配置时，必须显式运行：

```bash
python scripts/setup_ai_mcp.py --client codex --apply-user
python scripts/setup_ai_mcp.py --client claude --apply-user
```

GDScript 和场景启动错误可先用 headless 检查定位；用户在编辑器运行后才出现的错误，再用正常运行日志检查定位：

```bash
python scripts/godot_headless_check.py
python scripts/godot_runtime_log_check.py
python scripts/godot_crash_diagnostics.py --json
```

如果 Windows 上出现 `0xC0000005` / “内存不能为 read”，先运行 `godot_crash_diagnostics.py`。该脚本只读 Windows 事件日志和 WER 报告；若输出 `likely_external_injection: true`，说明崩溃与系统级注入模块同现，优先处理安全/管控软件排除项或禁用注入组件后复测。脚手架侧的规避策略是减少非必要 Godot GUI 启动、优先 console/headless/Web 检查，并避免把这类崩溃误判为 GDScript 逻辑错误。

## 推荐分发方式

开箱即用模板，默认携带 `tools/` 下的 portable 工具或工具压缩包：

```bash
python scripts/export_template.py
```

兼容旧命令，也会导出开箱即用模板：

```bash
python scripts/export_template.py --include-tools
```

瘦身模板，不携带 portable 工具：

```bash
python scripts/export_template.py --no-tools
```

如果 `tools/` 里同时存在原始压缩包和本机解包目录，导出时优先携带原始压缩包，排除 `tools/python/`、`tools/node/`、`tools/git/`、`tools/godot/` 这类可由 `init.cmd` 再生成的目录，避免包体重复膨胀。`tools/gdtoolkit/python/` 是质量门禁运行依赖，`tools/godot-mcp-node/` 是编辑器运行诊断依赖，默认保留；外部 GodotMCP 本地仓库目录 `tools/godotmcp/`、`tools/godot-mcp/` 不会进入干净模板。

导出包会自动生成一个新的空 `.git/`，不携带当前脚手架仓库历史。这样小白解压后已经是 Git 仓库，AI 可以直接把 Git 当作“存档点”工具使用。

## AI 行为边界

- AI 可以检查 `tools/`，也可以运行只写入项目目录的解包流程。
- 下载 Godot/Python/Node.js/Git/agent-browser/GodotMCP、GDScript Toolkit、GDUnit4（可选）、全局安装依赖、执行会联网拉包的 `npx`、下载 Chrome 或修改系统配置前必须获得用户明确确认。
- 默认 init 只能写项目内 MCP 配置；调用 `codex mcp add`、`claude mcp add` 或修改用户全局 AI 配置前必须获得用户明确确认。
- 默认模板包含 `tools/` portable 工具包，保证小白解压后运行 `init.cmd` 能自动解包。需要瘦身包时显式使用 `--no-tools`。
- 成果验收前仍以 `python scripts/ai_review.py --strict` 为最终 review gate。

## 内置资产处理脚本

素材后处理脚本是项目内工具，不依赖 Node.js 或 Godot 运行时；需要当前 Python 环境有 Pillow，部分透明 GIF 输出和图像数组处理需要 numpy：

```bash
python scripts/make_sprite_layout_guide.py --rows 2 --cols 2 --output assets/generated/runtime/player-guide.png
python scripts/process_spritesheet.py assets/generated/runtime/player-walk-sheet.png --rows 2 --cols 2 --out-dir assets/sprites/player/walk --align feet --shared-scale --reject-edge-touch
python scripts/extract_prop_pack.py assets/generated/runtime/forest-props-sheet.png --rows 3 --cols 3 --labels rock,shrub,crate --out-dir assets/sprites/props/forest --reject-edge-touch
python scripts/compose_layered_map_preview.py --base assets/generated/runtime/forest-base.png --placements docs/project/art/forest-props-placement.json --output assets/generated/runtime/forest-preview.png
```

这些脚本只处理已经生成或导入的图片，不调用外部图片生成服务，不写系统目录。正式素材需要把 `pipeline-meta.json` 或 `prop-pack.json` 登记到 `docs/project/art/asset-manifest.json`，由 `python scripts/art_pipeline_review.py` 校验。

相关处理思路吸收了 MIT 许可的 Agent Sprite Forge，许可证说明见 `docs/THIRD_PARTY_NOTICES.md`。

## 常见问题

### 找不到 Godot

优先把 Godot 放到：

```text
tools/godot/Godot.exe
```

或把 Godot zip 放到：

```text
tools/Godot_v4.x-stable_win64.exe.zip
```

然后双击 `init.cmd`。也可以设置 `GODOT4_PATH` 或把 Godot 加入 PATH。

Windows 示例：

```powershell
$env:GODOT4_PATH = "D:/godot/Godot_v4.x-stable_win64.exe"
```

### Web Export Templates 缺失

如果已有离线包，把 `Godot_v4.x-stable_export_templates.tpz` 放入 `tools/`，再双击 `init.cmd`。

兜底方式是在 Godot 编辑器中安装：

```text
Editor -> Manage Export Templates -> Download
```

安装后可运行：

```bash
python scripts/setup_godot.py --mark
```

### 预览白屏

优先检查：

- `python scripts/export_web.py --json`
- `python scripts/godot_headless_check.py`
- `python scripts/godot_runtime_log_check.py`
- 出现 Godot `0xC0000005` 时：`python scripts/godot_crash_diagnostics.py --json`
- `python scripts/godot_native_screenshot_check.py --json`
- `python scripts/run_web_preview.py --json`
- `python scripts/experience_check.py --strict`
- 浏览器控制台错误。
- 是否运行时引用了 `references/`。

### 自动试玩缺失浏览器后端

`experience_check.py` 先尝试 Playwright Python，再自动寻找：

```text
AGENT_BROWSER_PATH
tools/agent-browser/agent-browser.exe
tools/agent-browser/agent-browser.cmd
tools/agent-browser/agent-browser.ps1
系统 PATH 中的 agent-browser
```

如果都没有，完整浏览器自动试玩会跳过。可选安装方式：

```bash
npm i -g agent-browser
agent-browser install
```

全局安装或下载 Chrome 前必须先得到用户确认。不要把浏览器 profile、cookies、state、HAR、截图缓存提交进仓库。

### 质量工具缺失

统一检查：

```bash
python scripts/setup_quality_tools.py
python scripts/godot_quality_tools.py --json
```

处理顺序：

- 运行 `python scripts/setup_quality_tools.py --install --yes` 准备 gdtoolkit；需要 GDUnit4 时再执行 `python scripts/setup_quality_tools.py --install-gdunit --yes`。
- 重新运行 `python scripts/godot_quality_tools.py --json` 和 `python scripts/ai_review.py --strict`。

### .wasm 或 .pck MIME 错误

必须使用 `python scripts/run_web_preview.py` 启动本地服务，不要直接双击 `html5/index.html`。

### 素材不显示

- 确认素材在 `assets/` 或 `addons/`。
- 确认路径以 `res://` 开头。
- 不要从 `references/` 加载。
- 检查是否存在 `.gdignore` 阻止 Godot 导入。

### 图片生成失败

- 检查 `MEDIA_API_KEY` 或 `X_DODJOY_TOKEN`。
- 默认 provider 是 `gpt-image-2`。
- 不要把 token 写进项目文件。

## 本地存档点和回档

这个模板可以用 Git 管理每一轮 AI 变更。面向新手时，把它理解为“存档点”和“回档”即可。

从 `scripts/export_template.py` 导出的脚手架默认已经包含一个空 Git 仓库；如果是直接从源码目录复制出来的项目，也可以运行下面的初始化命令补齐。

约束：

- 默认不自动创建 Git 提交。
- `git commit`、`git push`、`git reset --hard` 必须由用户明确确认。
- 回档先预览，再确认。
- 不会执行 `git push` 上传代码。
- 不使用 `git reset --hard` 直接删除历史。

初始化：

```bash
python scripts/git_ai.py init
```

手动存档点：

```bash
python scripts/git_ai.py checkpoint
```

指定存档说明：

```bash
python scripts/git_ai.py checkpoint --message "feat: add first playable loop"
```

安全回档预览：

```bash
python scripts/git_ai.py rollback
```

确认后执行：

```bash
python scripts/git_ai.py rollback --yes
```

诊断：

```bash
python scripts/git_ai.py doctor
```

策略文件 `.ai-git-policy.json` 默认关闭自动提交：

```json
{
  "autoCommit": false,
  "commitOnSessionIdle": false,
  "includeUntracked": true,
  "runBuildBeforeCommit": false,
  "messagePrefix": "ai"
}
```
