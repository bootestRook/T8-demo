---
name: godot-api-lookup
description: 当用户询问 Godot 4 API、GDScript 类、节点、信号、导出参数、Web 导出行为或报错来源时使用。优先用项目内代码和 Godot 官方文档核对，不凭记忆修改。
---

# Godot API Lookup

## 目标

在修改 Godot 代码前确认 API 用法，减少因版本差异、节点生命周期或 Web 导出限制导致的错误。

## 使用规则

1. 先读本项目相关文件，确认当前 Godot 版本和节点结构：
   - `project.godot`
   - `scenes/Game.tscn`
   - 相关 `.gd` 文件
2. 如果问题涉及 Godot API 细节，优先查 Godot 官方文档或本机 Godot 帮助。
3. 修改前确认：
   - 类是否存在于 Godot 4。
   - 方法、信号、属性名是否正确。
   - Web 导出是否支持。
   - 是否需要在 `_ready`、`_process`、`_physics_process` 或信号回调中调用。

## 常查方向

- `Node`、`Node2D`、`CanvasLayer`、`Control` 生命周期。
- `CharacterBody2D` 移动和碰撞。
- `Timer`、`Signal`、`Tween`。
- `AudioStreamGenerator` 和 Web 音频限制。
- `ResourceLoader`、`load()`、`preload()`。
- HTML5/Web 导出、SharedArrayBuffer、COOP/COEP。

## 输出格式

```markdown
## Godot API Lookup

- 问题：
- 结论：
- 项目影响：
- 建议改动：
- 验证命令：
```

## 约束

- 不为单个 API 问题引入大型抽象。
- 不直接把 `references/` 资源接入运行时。
- 对 Web 导出相关问题，改完至少运行 `python scripts/export_web.py --json`。
