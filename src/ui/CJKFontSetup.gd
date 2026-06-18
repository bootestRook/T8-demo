extends Node
## Autoload: 使用同一套 CJK 字体作为默认 UI 字体，避免中英文/数字混用不同字库。


func _ready() -> void:
	var cjk_font: FontFile = load("res://assets/DroidSansFallback.ttf")
	if cjk_font == null:
		return
	var default_theme := ThemeDB.get_default_theme()
	var previous_font: Font = default_theme.get_default_font()
	if previous_font != null and previous_font != cjk_font:
		cjk_font.set_fallbacks(cjk_font.get_fallbacks() + [previous_font])
	default_theme.set_default_font(cjk_font)
