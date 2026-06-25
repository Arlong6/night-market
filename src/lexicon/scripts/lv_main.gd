## LVMain — Lexicon Village root scene orchestrator.
## Wires Title / Village / Ending Controls to LVBoot state transitions.
## Hosts the Notebook UI overlay (shared across phases).
class_name LVMain
extends Node

const LVTitle = preload("res://lexicon/scripts/lv_title.gd")
const LVVillage = preload("res://lexicon/scripts/lv_village.gd")
const LVEnding = preload("res://lexicon/scripts/lv_ending.gd")
const LVNotebookUI = preload("res://lexicon/scripts/lv_notebook_ui.gd")
const LVCascadeShimmer = preload("res://lexicon/scripts/lv_cascade_shimmer.gd")
const LVThemeSetup = preload("res://lexicon/scripts/lv_theme_setup.gd")

var _title_ctrl: LVTitle = null
var _village: LVVillage = null
var _ending_ctrl: LVEnding = null
var _notebook: LVNotebookUI = null
var _shimmer: LVCascadeShimmer = null

func _ready() -> void:
	# Apply CJK font BEFORE building any UI labels (must happen first)
	LVThemeSetup.apply_default_cjk_font()
	# The project ships in Night Market's pixel-art stretch (viewport/integer) as the
	# boot default. Lexicon needs sharp CJK glyphs, so override the window to
	# canvas_items + fractional scaling at runtime whenever the village scene loads.
	var win := get_window()
	if win:
		win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		win.content_scale_stretch = Window.CONTENT_SCALE_STRETCH_FRACTIONAL
	_build_subscenes()
	_wire_boot()
	# Inhibit LVBoot's auto-scene-swap; we manage children manually
	var boot = get_node_or_null("/root/LVBoot")
	if boot:
		boot.set_scene_swap_inhibited(true)
		boot.boot_complete()  # advance BOOTING → TITLE
	_show_title()

func _build_subscenes() -> void:
	_title_ctrl = LVTitle.new()
	_title_ctrl.name = "Title"
	add_child(_title_ctrl)

	_village = LVVillage.new()
	_village.name = "Village"
	add_child(_village)
	_village.visible = false

	_ending_ctrl = LVEnding.new()
	_ending_ctrl.name = "Ending"
	add_child(_ending_ctrl)
	_ending_ctrl.visible = false

	# Notebook overlay
	_notebook = LVNotebookUI.new()
	_notebook.name = "Notebook"
	_notebook.anchor_right = 1.0
	_notebook.anchor_bottom = 1.0
	add_child(_notebook)
	# Make sure notebook renders above world
	_notebook.z_index = 100

	# Cascade shimmer
	_shimmer = LVCascadeShimmer.new()
	_shimmer.name = "Shimmer"
	add_child(_shimmer)

func _wire_boot() -> void:
	var boot = get_node_or_null("/root/LVBoot")
	if boot:
		if not boot.boot_state_changed.is_connected(_on_boot_state_changed):
			boot.boot_state_changed.connect(_on_boot_state_changed)

func _on_boot_state_changed(new_state: int) -> void:
	const LVBoot = preload("res://lexicon/autoloads/lv_boot.gd")
	match new_state:
		LVBoot.BootState.TITLE:
			_show_title()
		LVBoot.BootState.GAME:
			_show_village()
		LVBoot.BootState.ENDING:
			_show_ending()

func _show_title() -> void:
	_title_ctrl.visible = true
	_village.visible = false
	_ending_ctrl.visible = false
	if _notebook:
		_notebook.visible = false

func _show_village() -> void:
	_title_ctrl.visible = false
	_village.visible = true
	_ending_ctrl.visible = false

func _show_ending() -> void:
	_title_ctrl.visible = false
	_village.visible = false
	_ending_ctrl.visible = true
	if _ending_ctrl.has_method("_populate_data"):
		_ending_ctrl._populate_data()
	if _notebook:
		_notebook.visible = false
