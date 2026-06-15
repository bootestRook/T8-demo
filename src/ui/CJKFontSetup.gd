extends Node
## Autoload: 为默认字体添加 CJK 回退，解决中文乱码问题。
## 默认字体负责英文/数字，DroidSansFallback 负责中日韩字符。


func _ready() -> void:
	var cjk_font: FontFile = load("res://assets/DroidSansFallback.ttf")
	if cjk_font == null:
		return
	var default_font: Font = ThemeDB.get_default_theme().get_default_font()
	if default_font:
		default_font.set_fallbacks(default_font.get_fallbacks() + [cjk_font])
