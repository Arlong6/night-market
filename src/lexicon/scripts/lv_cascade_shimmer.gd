## LVCascadeShimmer — Lexicon Village #10 Cascade Shimmer Animation
##
## Drives the per-glyph wavefront that celebrates vignette completion.
## Listens to LVSessionState.vignette_completed; projects NPC world position
## to screen; computes per-token t_arrive (ease-out wavefront, Formula 2);
## schedules a 3-phase modulate Tween per token Label (Approach + Dwell + Settle).
##
## Off-screen tokens resolve directly (no Tween). 80-glyph cap is a safety
## ceiling for pathological cases. Concurrent vignette_completed signals queue
## behind a QUEUE_GAP_DELAY. Notebook-open trigger defers shimmer until close.
##
## See: design/gdd/cascade-shimmer.md
class_name LVCascadeShimmer
extends Node

## Formula 1 / Rule 3 timing knobs
const RIPPLE_DURATION: float = 1.2
const APPROACH_DURATION: float = 0.1
const DWELL_DURATION: float = 0.4
const SETTLE_DURATION: float = 0.15
const QUEUE_GAP_DELAY: float = 0.3

## Safety cap (Rule 5 / AC-9)
const MAX_ANIMATED_GLYPHS: int = 80

## Formula 4 audio pan
const PAN_RANGE: float = 0.6

## Art-directed palette (locked per cascade-shimmer.md tuning knobs)
const COLOR_FADED: Color = Color(0.7, 0.65, 0.55, 0.8)
const COLOR_PEAK: Color = Color(1.0, 0.9, 0.5, 1.0)
const COLOR_RESOLVED: Color = Color(0.15, 0.1, 0.05, 1.0)

const LVChime = preload("res://lexicon/scripts/lv_chime.gd")

enum ShimmerState { IDLE, RIPPLE_ACTIVE, QUEUE_GAP }

# ─── State ────────────────────────────────────────────────────────────────────

var _state: int = ShimmerState.IDLE
var _queue: Array = []          # Array[StringName] of queued vignette_ids
var _deferred: Array = []        # Array[StringName] held while notebook open
var _notebook_open: bool = false
var _reduced_motion: bool = false

# Dependencies (autowired in _ready; injectable for tests)
var _session_state: Object = null
var _input: Object = null
var _dialogue_display: Object = null

# Cached chime stream (generated on first ripple, reused thereafter)
static var _chime_stream: AudioStreamWAV = null

# Track most-recent chime player for testability
var _last_chime_player: Node = null

# ─── Signals ──────────────────────────────────────────────────────────────────

signal slot_resolved(slot_id: StringName)
signal shimmer_started(vignette_id: StringName, origin_screen: Vector2)
signal shimmer_complete

# ─── Static helpers (pure functions) ──────────────────────────────────────────

## Formula 2 — `t_arrive(token) = RIPPLE_DURATION × (1 - sqrt(1 - dist/R_MAX))`
## Clamps to RIPPLE_DURATION for dist >= R_MAX.
static func compute_t_arrive(dist: float, r_max: float) -> float:
	if r_max <= 0.0:
		return 0.0
	var ratio: float = clampf(dist / r_max, 0.0, 1.0)
	return RIPPLE_DURATION * (1.0 - sqrt(1.0 - ratio))

## Formula 3 — total shimmer timeline.
static func total_duration() -> float:
	return RIPPLE_DURATION + APPROACH_DURATION + DWELL_DURATION + SETTLE_DURATION

## Formula 4 — `pan = (x/W - 0.5) × 2 × PAN_RANGE`
static func compute_pan(origin_x: float, viewport_width: float) -> float:
	if viewport_width <= 0.0:
		return 0.0
	return (origin_x / viewport_width - 0.5) * 2.0 * PAN_RANGE

## Visible-on-screen check (Rule 5).
static func is_on_screen(token_rect: Rect2, viewport_rect: Rect2) -> bool:
	return viewport_rect.intersects(token_rect)

## Splits an array of distances into the nearest MAX_ANIMATED_GLYPHS indices
## (animated) and the rest (direct resolve). Preserves original indices.
static func split_animated_vs_direct(distances: Array, cap: int) -> Dictionary:
	var indexed: Array = []
	for i in distances.size():
		indexed.append({"idx": i, "d": float(distances[i])})
	indexed.sort_custom(func(a, b): return a.d < b.d)
	var animated: Array = []
	var direct: Array = []
	for j in indexed.size():
		if j < cap:
			animated.append(indexed[j].idx)
		else:
			direct.append(indexed[j].idx)
	return {"animated_indices": animated, "direct_indices": direct}

# ─── Construction ─────────────────────────────────────────────────────────────

func _ready() -> void:
	_session_state = get_node_or_null("/root/LVSessionState")
	_input = get_node_or_null("/root/LVInput")
	if _session_state and _session_state.has_signal("vignette_completed"):
		if not _session_state.vignette_completed.is_connected(_on_session_vignette_completed):
			_session_state.vignette_completed.connect(_on_session_vignette_completed)

# ─── Public API ───────────────────────────────────────────────────────────────

func get_state() -> int:
	return _state

func get_queue_size() -> int:
	return _queue.size()

func has_deferred() -> bool:
	return not _deferred.is_empty()

func inject_dialogue_display(dd: Object) -> void:
	_dialogue_display = dd

func set_notebook_open(open: bool) -> void:
	var was_open := _notebook_open
	_notebook_open = open
	# On close, drain deferred ripples into the normal pipeline.
	if was_open and not open and not _deferred.is_empty():
		var drained: Array = _deferred.duplicate()
		_deferred.clear()
		for vid in drained:
			on_vignette_completed(vid)

func set_reduced_motion(on: bool) -> void:
	_reduced_motion = on

## Reduced-motion-aware t_arrive — returns 0 if reduced motion is enabled.
func compute_t_arrive_with_motion(dist: float, r_max: float) -> float:
	if _reduced_motion:
		return 0.0
	return compute_t_arrive(dist, r_max)

## Primary entry point — called by session state signal OR directly by tests.
func on_vignette_completed(vignette_id: StringName) -> void:
	# AC-16: notebook open → defer
	if _notebook_open:
		_deferred.append(vignette_id)
		return
	# AC-7: active ripple → queue
	if _state == ShimmerState.RIPPLE_ACTIVE or _state == ShimmerState.QUEUE_GAP:
		_queue.append(vignette_id)
		return
	_start_ripple(vignette_id)

# ─── Internal ─────────────────────────────────────────────────────────────────

func _on_session_vignette_completed(vignette_id: StringName) -> void:
	on_vignette_completed(vignette_id)

func _start_ripple(vignette_id: StringName) -> void:
	_state = ShimmerState.RIPPLE_ACTIVE
	if _input and _input.has_method("set_state"):
		_input.set_state(_input.InputState.CUTSCENE)
	# Emit slot_resolved for each slot in the vignette (informs UI re-render)
	var slots: Array = _slots_for(vignette_id)
	for slot_id in slots:
		slot_resolved.emit(slot_id)
	# Compute origin (NPC world position projected to screen)
	var origin_screen: Vector2 = _vignette_origin_screen(vignette_id)
	shimmer_started.emit(vignette_id, origin_screen)
	# Gather token labels and viewport rect
	var labels: Array = _gather_animation_targets()
	var viewport_rect: Rect2 = _get_viewport_rect()
	# Split visible vs off-screen
	var visible_labels: Array = []
	var offscreen_labels: Array = []
	for lbl in labels:
		if not is_instance_valid(lbl):
			continue
		if is_on_screen(lbl.get_global_rect(), viewport_rect):
			visible_labels.append(lbl)
		else:
			offscreen_labels.append(lbl)
	# AC-6: off-screen tokens resolve direct
	for lbl in offscreen_labels:
		if is_instance_valid(lbl):
			lbl.modulate = COLOR_RESOLVED
	# AC-9: cap at MAX_ANIMATED_GLYPHS — pick nearest
	var r_max: float = _compute_r_max(viewport_rect)
	var distances: Array = []
	for lbl in visible_labels:
		var rect: Rect2 = lbl.get_global_rect()
		distances.append(origin_screen.distance_to(rect.get_center()))
	var split: Dictionary = split_animated_vs_direct(distances, MAX_ANIMATED_GLYPHS)
	# Excess (above cap): direct resolve
	for idx in split.direct_indices:
		var ex_lbl: Label = visible_labels[idx]
		if is_instance_valid(ex_lbl):
			ex_lbl.modulate = COLOR_RESOLVED
	# Animated: schedule per-token tweens
	for idx in split.animated_indices:
		var ani_lbl: Label = visible_labels[idx]
		var dist: float = distances[idx]
		var t_arrive: float = compute_t_arrive_with_motion(dist, r_max)
		_animate_label(ani_lbl, t_arrive)
	# Audio chime (Formula 4 pan)
	_play_chime(origin_screen, viewport_rect)
	# Schedule end-of-ripple
	_schedule_ripple_end()

func _animate_label(lbl: Label, delay: float) -> void:
	if not is_instance_valid(lbl):
		return
	# Set initial modulate so the tween's "from" reads the intended faded baseline.
	# Keep alpha at 1 (text already visible); peak/resolved drive RGB.
	var tween := create_tween()
	if delay > 0.0:
		tween.tween_interval(delay)
	# Approach: faded → peak
	tween.tween_method(_apply_modulate.bind(lbl), Color.WHITE, COLOR_PEAK, APPROACH_DURATION)
	# Dwell: hold at peak (load-bearing for "wave" percept)
	tween.tween_interval(DWELL_DURATION)
	# Settle: peak → resolved
	tween.tween_method(_apply_modulate.bind(lbl), COLOR_PEAK, COLOR_RESOLVED, SETTLE_DURATION)

func _apply_modulate(c: Color, lbl: Label) -> void:
	# EC-9 / AC-10: is_instance_valid guard against freed-mid-shimmer
	if is_instance_valid(lbl):
		lbl.modulate = c

func _schedule_ripple_end() -> void:
	# After total wavefront duration, transition to QUEUE_GAP, then drain queue.
	if get_tree() == null:
		# No tree (headless test partial setup) — synchronously finalize for safety.
		_on_ripple_end()
		return
	var t := get_tree().create_timer(RIPPLE_DURATION)
	t.timeout.connect(_on_ripple_end)

func _on_ripple_end() -> void:
	# Wavefront finished propagating. Per Rule 4, queue gap before next.
	if _queue.is_empty():
		_state = ShimmerState.IDLE
		if _input and _input.has_method("get_state") and _input.has_method("set_state"):
			if _input.get_state() == _input.InputState.CUTSCENE:
				_input.set_state(_input.InputState.NORMAL)
		shimmer_complete.emit()
		return
	_state = ShimmerState.QUEUE_GAP
	if get_tree() == null:
		_drain_queue()
		return
	var gap := get_tree().create_timer(QUEUE_GAP_DELAY)
	gap.timeout.connect(_drain_queue)

func _drain_queue() -> void:
	if _queue.is_empty():
		_state = ShimmerState.IDLE
		shimmer_complete.emit()
		return
	var next_id: StringName = _queue.pop_front()
	_start_ripple(next_id)

func _gather_animation_targets() -> Array:
	var dd: Object = _dialogue_display
	if dd == null and get_tree():
		dd = get_tree().get_first_node_in_group(&"lv_dialogue_display")
	if dd and dd.has_method("get_lexicon_slot_labels"):
		return dd.get_lexicon_slot_labels()
	return []

func _get_viewport_rect() -> Rect2:
	var vp := get_viewport()
	if vp:
		return vp.get_visible_rect()
	# Defensive default for partial test setup
	return Rect2(Vector2.ZERO, Vector2(320, 180))

func _compute_r_max(viewport_rect: Rect2) -> float:
	# R_MAX = viewport diagonal (Formula 1)
	var s := viewport_rect.size
	return sqrt(s.x * s.x + s.y * s.y)

func _vignette_origin_screen(vignette_id: StringName) -> Vector2:
	# Look up world position via LVVignetteContent
	const LVVignetteContent = preload("res://lexicon/data/lv_vignette_content.gd")
	var content: Dictionary = LVVignetteContent.get_content(vignette_id)
	var world_pos: Vector2 = content.get(&"world_position", Vector2.ZERO)
	# EC-7: missing origin → viewport center (logged)
	if world_pos == Vector2.ZERO and not content.has(&"world_position"):
		push_error("LVCascadeShimmer: vignette '%s' missing world_position" % [vignette_id])
		return _get_viewport_rect().size * 0.5
	# Project through scene camera if available. For Camera2D, the simplest
	# correct mapping is `world_pos - camera.global_position + viewport/2`.
	# In headless tests with no camera, fall back to world_pos directly.
	var cam: Camera2D = null
	if get_tree() and get_tree().current_scene:
		cam = _find_camera_2d(get_tree().current_scene)
	if cam:
		var vp_size: Vector2 = _get_viewport_rect().size
		return world_pos - cam.global_position + vp_size * 0.5
	return world_pos

func _find_camera_2d(node: Node) -> Camera2D:
	if node is Camera2D and (node as Camera2D).enabled:
		return node
	for child in node.get_children():
		var c := _find_camera_2d(child)
		if c:
			return c
	return null

func _slots_for(vignette_id: StringName) -> Array:
	const LVVignetteContent = preload("res://lexicon/data/lv_vignette_content.gd")
	return LVVignetteContent.SLOTS_IN_VIGNETTE.get(vignette_id, [])

func _play_chime(origin_screen: Vector2, viewport_rect: Rect2) -> void:
	# AC-11: pan via AudioStreamPlayer2D position relative to viewport center.
	#         Default AudioListener2D origin is (0,0), so positioning the 2D player
	#         at (origin_screen - viewport_center) yields natural stereo pan.
	# AC-13: if audio bus is muted at the Server level, the call is a no-op; visual is unaffected.
	if get_tree() == null:
		return
	var stream: AudioStreamWAV = _get_chime_stream()
	if stream == null:
		return
	var player := AudioStreamPlayer2D.new()
	player.stream = stream
	var viewport_center: Vector2 = viewport_rect.size * 0.5
	player.position = origin_screen - viewport_center
	player.attenuation = 0.5  # gentle drop — keep audibility across small viewport
	player.max_distance = 800.0
	add_child(player)
	player.play()
	# Cleanup after playback finishes
	if player.finished.is_connected(player.queue_free) == false:
		player.finished.connect(player.queue_free)
	_last_chime_player = player

func _get_chime_stream() -> AudioStreamWAV:
	if _chime_stream == null:
		_chime_stream = LVChime.generate()
	return _chime_stream

## Test hook — returns true if a chime player was created on the most recent ripple.
func did_play_chime() -> bool:
	return is_instance_valid(_last_chime_player)
