## End screen for Night Market Shopping (R-008 / R-009).
##
## Shows: thank-you header, money remaining (with bounce tween), the 5
## ingredients ticked off, total session time, "press any key to return"
## prompt. Any input returns to the title screen.
class_name EndScreen
extends Control

const VIEWPORT_W: int = 320
const VIEWPORT_H: int = 180


func _ready() -> void:
	anchor_right = 1.0
	anchor_bottom = 1.0
	Music.stop()  # win arpeggio plays from MomNPC; let the silence land here
	_build_ui()
	set_process_unhandled_input(true)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEvent and event.is_pressed():
		Game.goto_level("title")


func _build_ui() -> void:
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.size = Vector2(VIEWPORT_W, VIEWPORT_H)
	vbox.position = Vector2(0, 0)
	vbox.add_theme_constant_override("separation", 6)
	add_child(vbox)

	# Header
	var header: Label = _make_label("謝謝，今晚加菜！", 16, Color("#F5EDDA"))
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(header)

	# Money remaining (bounce-tweened from 0 to actual value)
	var money: Label = _make_label("剩 $0", 12, Color("#F2A227"))
	money.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(money)
	_bounce_money(money, Inventory.money)

	# Ingredients list (each as a row with checkmark)
	for id in Inventory.REQUIRED_INGREDIENTS:
		var row: Label = _make_label(
			"  ✓ %s" % Inventory.display_name(id),
			10, Color("#C8E66D")
		)
		row.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(row)

	# Elapsed time
	var time_label: Label = _make_label(
		"用時 %.1fs" % Game.session_time,
		10, Color("#F5EDDA")
	)
	time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(time_label)

	# Continue prompt
	var prompt: Label = _make_label("按任何鍵回到首頁", 10, Color("#888888"))
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(prompt)


func _bounce_money(label: Label, target: int) -> void:
	# Tween a temporary float from 0 → target with EASE_OUT + TRANS_BOUNCE,
	# updating label.text each step.
	var holder: Array[float] = [0.0]
	var t: Tween = create_tween()
	t.set_ease(Tween.EASE_OUT)
	t.set_trans(Tween.TRANS_BOUNCE)
	t.tween_method(
		func(v: float) -> void: label.text = "剩 $%d" % int(v),
		0.0, float(target), 0.6
	)


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_override("font", _make_cjk_font())
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	return l


func _make_cjk_font() -> SystemFont:
	var f: SystemFont = SystemFont.new()
	f.font_names = PackedStringArray([
		"PingFang TC", "Heiti TC", "Microsoft JhengHei",
		"Noto Sans CJK TC", "Noto Sans TC", "sans-serif"
	])
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	return f
