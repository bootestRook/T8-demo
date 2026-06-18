extends RefCounted
class_name HudCardArtBinder

const HUD_CARD_NODE_FINDER := preload("res://src/ui/HudCardNodeFinder.gd")
const CARD_SCHOOL_ICON_PATHS := {
	"温压弹": "res://assets/ui/icons_Skill/icon_keji_wenyadan.png",
	"电磁穿刺": "res://assets/ui/icons_Skill/icon_keji_diancichuanci.png",
	"干冰弹": "res://assets/ui/icons_Skill/icon_keji_ganbingdan.png",
	"枪械": "res://assets/ui/icons_Skill/icon_keji_qiang.png",
	"通用": "res://assets/ui/icons_Skill/icon_keji_tongyong.png",
}


static func ensure_card_texture_widgets(card_widgets: Array, card_frame_path: String) -> void:
	for widget in card_widgets:
		var panel: PanelContainer = widget["panel"] as PanelContainer
		if not widget.has("frame_texture") or widget["frame_texture"] == null:
			var frame_texture := HUD_CARD_NODE_FINDER.find_texture_rect_by_suffix(panel, "FrameTexture")
			if frame_texture == null:
				var cost_label: Label = widget["cost"] as Label
				var panel_body := cost_label.get_parent() as Control
				frame_texture = TextureRect.new()
				frame_texture.name = "%sFrameTexture" % String(panel.name)
				frame_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
				frame_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				frame_texture.stretch_mode = TextureRect.STRETCH_SCALE
				panel_body.add_child(frame_texture)
			frame_texture.texture = load_card_texture(card_frame_path)
			widget["frame_texture"] = frame_texture
		if widget.has("art_texture") and widget["art_texture"] != null:
			continue
		var texture_rect := HUD_CARD_NODE_FINDER.find_texture_rect_by_suffix(panel, "ArtTexture")
		if texture_rect == null:
			var art_label: Label = widget["art"] as Label
			var parent := art_label.get_parent() as Control
			texture_rect = TextureRect.new()
			texture_rect.name = "%sArtTexture" % String(panel.name)
			texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
			texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			parent.add_child(texture_rect)
		widget["art_texture"] = texture_rect


static func apply_card_art(widget: Dictionary, card: Dictionary, fallback_path: String) -> void:
	var texture_rect: TextureRect = widget.get("art_texture", null) as TextureRect
	var art_label: Label = widget["art"] as Label
	var image_path := String(card.get("image_path", card.get("art_path", "")))
	if image_path.is_empty():
		image_path = school_icon_path(card)
	var texture: Texture2D = null
	if not image_path.is_empty():
		texture = load_card_texture(image_path)
	if texture == null and not image_path.is_empty() and image_path != fallback_path:
		texture = load_card_texture(fallback_path)
	if texture_rect != null:
		texture_rect.texture = texture
		texture_rect.visible = texture != null
	var art_slot := String(card.get("art_slot", ""))
	art_label.visible = texture == null and not art_slot.is_empty()
	art_label.text = art_slot


static func school_icon_path(card: Dictionary) -> String:
	var school := String(card.get("school", "")).strip_edges()
	return String(CARD_SCHOOL_ICON_PATHS.get(school, ""))


static func load_card_texture(path: String) -> Texture2D:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return ResourceLoader.load(path) as Texture2D
