## LVCascadeShimmer — Lexicon Village #10 Cascade shimmer (MVP scaffold)
##
## MVP implementation: simple modulate Tween on dialogue Label nodes when
## vignette_completed fires. Full ripple math + per-glyph timing is SPIKE 1 work.
##
## See: design/gdd/cascade-shimmer.md
class_name LVCascadeShimmer
extends Node

## Per Formula 3 constants
const RIPPLE_DURATION: float = 1.2
const APPROACH_DURATION: float = 0.1
const DWELL_DURATION: float = 0.4
const SETTLE_DURATION: float = 0.15

## Colors per art-directed defaults
const COLOR_FADED: Color = Color(0.7, 0.65, 0.55, 0.8)
const COLOR_PEAK: Color = Color(1.0, 0.9, 0.5, 1.0)
const COLOR_RESOLVED: Color = Color(0.15, 0.1, 0.05, 1.0)

var _session_state: Object = null
var _input: Object = null

## Signal listened by #11 Dialogue display.
signal slot_resolved(slot_id: StringName)
signal shimmer_complete

func _ready() -> void:
	_session_state = get_node_or_null("/root/LVSessionState")
	_input = get_node_or_null("/root/LVInput")
	if _session_state and not _session_state.vignette_completed.is_connected(_on_vignette_completed):
		_session_state.vignette_completed.connect(_on_vignette_completed)

func _on_vignette_completed(vignette_id: StringName) -> void:
	# Per AC-16 + EC-10: defer if notebook is open (need world view for spread)
	# MVP: don't defer (the notebook re-render will catch the resolved state anyway).
	# Set CUTSCENE state on LVInput to lock interactions during shimmer
	if _input:
		_input.set_state(_input.InputState.CUTSCENE)
	# For each slot in the cascaded vignette, fire slot_resolved
	var slots: Array = _get_vignette_slots(vignette_id)
	for slot_id in slots:
		slot_resolved.emit(slot_id)
	# Find the dialogue display Label and flash it (placeholder shimmer)
	_animate_dialogue_label()
	# Restore state after shimmer
	await _wait_total_duration()
	if _input and _input.get_state() == _input.InputState.CUTSCENE:
		_input.set_state(_input.InputState.NORMAL)
	shimmer_complete.emit()

func _animate_dialogue_label() -> void:
	# Find LVDialogueDisplay and animate its label modulate
	var dd = get_tree().get_first_node_in_group(&"lv_dialogue_display") if get_tree() else null
	if dd == null:
		return
	var label: Node = dd.get_node_or_null("Label")
	if label == null or not label is CanvasItem:
		return
	var canvas_item := label as CanvasItem
	var tween := create_tween()
	tween.tween_property(canvas_item, "modulate", COLOR_PEAK, APPROACH_DURATION)
	tween.tween_interval(DWELL_DURATION)
	tween.tween_property(canvas_item, "modulate", Color.WHITE, SETTLE_DURATION)

func _wait_total_duration() -> void:
	if get_tree():
		await get_tree().create_timer(RIPPLE_DURATION + APPROACH_DURATION + DWELL_DURATION + SETTLE_DURATION).timeout

func _get_vignette_slots(vignette_id: StringName) -> Array:
	if _session_state and _session_state.has_method("_slots_in_vignette"):
		return _session_state._slots_in_vignette.get(vignette_id, [])
	# Fall back to LVVignetteContent
	const LVVignetteContent = preload("res://lexicon/data/lv_vignette_content.gd")
	return LVVignetteContent.SLOTS_IN_VIGNETTE.get(vignette_id, [])
