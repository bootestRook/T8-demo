---
name: godot-export-web
description: 当用户说导出Web、发布、上传部署、打包、做离线包时使用。用于 Godot 4 游戏的完整 Web 导出流程向导，含 Export Templates 检查、headless 导出、本地预览和 zip 打包。
---

# Godot Export Web

## 目标

引导用户完成从导出检查到最终打包的完整 Web 导出流程。

## 工作流

1. 检查 Export Templates：
   - 运行 `python scripts/setup_godot.py`。
   - 未安装时输出引导：在 Godot 编辑器内 `Editor → Manage Export Templates → Download`。
   - 已安装但无标记文件时自动写入标记。
2. 检查 Godot 4 可用性：
   - 运行 `python scripts/check_env.py`。
   - Godot 不可用时优先提示用户运行 `init.cmd` 解包 `tools/` 中的 portable Godot；再考虑配置 `GODOT4_PATH` 或放入 PATH。
3. 执行导出：
   - 运行 `python scripts/export_web.py`。
   - 验证 `html5/index.html` 和 `.wasm`、`.pck` 文件存在。
4. 启动预览（可选）：
   - 运行 `python scripts/run_web_preview.py --open --json`。
   - 浏览器打开返回的本地 URL 检查效果。
5. 打包（如需部署）：
   - 运行 `python scripts/package_dist.py`。
   - 生成 zip 包供平台部署上传。

## 常见问题

- 导出失败：检查 Godot 路径和 Export Templates。
- 浏览器白屏：必须使用 `run_web_preview.py`（底层服务自带 COOP/COEP 和 .wasm/.pck MIME），不要直接用文件浏览器打开 html5/。
- SharedArrayBuffer 错误：确认本地预览服务的 COOP/COEP 响应头生效。

## 输出格式

```markdown
## Web 导出结果

### Export Templates
- 状态：PASS / FAIL（未安装时给出安装引导）

### 导出检查
- Godot 4 可用：PASS / FAIL
- 导出成功：PASS / FAIL
- 产物文件：html5/index.html / .wasm / .pck

### 预览（可选）
- 地址：http://localhost:8080

### 打包（可选）
- zip 路径：...

### 下一步
- 浏览器试玩 → 反馈给 AI → 继续迭代
- 或直接上传 zip 到平台部署
```
