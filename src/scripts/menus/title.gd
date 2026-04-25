## Title screen placeholder for Night Market Shopping (R-001).
##
## Story R-009 will replace this with a full title (subtitle, START button,
## flow wiring). For now it just renders the game name so we can verify the
## project boots end-to-end.
class_name TitleScreen
extends Control

func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0

	var title: Label = Label.new()
	title.text = "夜市採購大作戰"
	title.add_theme_font_override("font", _make_cjk_font())
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color("#F5EDDA"))
	title.set_anchors_preset(Control.PRESET_CENTER, true)
	title.position = Vector2(160 - 56, 90 - 8)  # rough centre
	add_child(title)


## Builds a SystemFont with an explicit CJK fallback chain so Chinese
## characters render correctly across macOS / Windows / Linux without
## bundling a TTF in this MVP slice.
func _make_cjk_font() -> SystemFont:
	var f: SystemFont = SystemFont.new()
	f.font_names = PackedStringArray([
		"PingFang TC", "Heiti TC", "Microsoft JhengHei",
		"Noto Sans CJK TC", "Noto Sans TC", "sans-serif"
	])
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	return f
