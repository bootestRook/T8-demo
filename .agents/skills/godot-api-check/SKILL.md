---
name: godot-api-check
description: Validate Godot 4 engine API symbols against the project-local .godot-api/extension_api.json. Use before writing or changing Godot classes, methods, properties, signals, enums, enum values, constants, singletons, utility functions, operators, constructors, annotations, or engine-server calls in GDScript/C#; also use when investigating API errors or Godot version compatibility.
---

# Godot API Check

## 规则

- 凡是 Godot 引擎 API，一律不得凭记忆使用。
- 必须先通过本 skill 查询 `.godot-api/extension_api.json`。
- 查询不到的 API 一律视为不存在，禁止调用、禁止建议、禁止写入代码。
- 涉及类、内置类型、方法、属性、信号、枚举、枚举值、常量、单例、utility function、operator、constructor 时，都必须查询到确切符号、参数、返回值和约束后再使用。
- 同一轮任务中只有已经查询并留在上下文里的精确符号可以复用；新增符号或新增 overload 必须再次查询。
- 项目自定义类、节点、Autoload、输入动作、资源路径、场景路径、分组和项目设置必须在仓库文件中验证，不得臆造。
- 如果无法完成查询或验证，必须停止并说明阻塞原因，不得用记忆补全。

## API 文件

优先使用项目本地文件：

```powershell
.godot-api/extension_api.json
```

缺失时先导出：

```powershell
New-Item -ItemType Directory -Force .godot-api
Push-Location .godot-api
godot --headless --dump-extension-api
Pop-Location
```

也可以通过 `GODOT_EXTENSION_API` 或 `--api <path>` 指定其他 dump。dump 必须来自当前项目实际使用的 Godot 版本。

## 查询命令

```powershell
python .agents/skills/godot-api-check/scripts/godot_api_check.py class Node
python .agents/skills/godot-api-check/scripts/godot_api_check.py member Node add_child --kind method
python .agents/skills/godot-api-check/scripts/godot_api_check.py member Vector2 x --kind property
python .agents/skills/godot-api-check/scripts/godot_api_check.py signal Node ready
python .agents/skills/godot-api-check/scripts/godot_api_check.py enum ProcessMode --class Node
python .agents/skills/godot-api-check/scripts/godot_api_check.py constant NOTIFICATION_READY --class Node
python .agents/skills/godot-api-check/scripts/godot_api_check.py singleton Input
python .agents/skills/godot-api-check/scripts/godot_api_check.py utility sin
```

发现符号时可以先搜索，但搜索不能作为最终验证：

```powershell
python .agents/skills/godot-api-check/scripts/godot_api_check.py search get_child --limit 20
```

搜索后必须再用 `class`、`member`、`signal`、`enum`、`constant`、`singleton` 或 `utility` 做精确查询。

## 项目符号

`extension_api.json` 只覆盖 Godot 引擎符号。以下内容必须查仓库文件：

- 自定义类和 `class_name`：搜索 `.gd`、`.cs` 和资源文件。
- 场景节点路径和节点名：检查 `.tscn`、`.scn` 和相关脚本。
- Autoload 和输入动作：检查 `project.godot`。
- 资源、PackedScene 和素材路径：确认文件真实存在。
- 自定义信号：确认声明或场景连接。

## 退出码

- `0`：找到符号，可以在满足参数和约束后使用。
- `1`：脚本或 API 文件错误，必须先修复环境。
- `2`：未找到符号，按不存在处理。
