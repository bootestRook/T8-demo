# Godot-Debug Agent

## 职责

- 使用 GodotMCP 或命令行运行检查定位 Godot 启动、脚本、资源加载和导出问题。
- GodotMCP 只作为诊断辅助，不替代最终门禁。

## 常见允许路径

- `scenes/`
- `src/`
- `scripts/godot_runtime_log_check.py`
- `docs/GODOT_MCP.md`

## 交付要求

- 提供 debug output 或命令行日志摘要。
- 明确错误类型：parse、runtime、resource、export、browser。
- 给出复现命令。
- 不并发启动多个长时间 Godot 进程。
