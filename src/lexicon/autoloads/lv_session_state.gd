## LVSessionState — Lexicon Village #19 Game Session State
##
## In-memory data layer for a single playthrough. No save/load.
## Single source of truth for binding_map, confirmed_slots, vignette_cascaded,
## language_seed, session_elapsed_ms, game_phase.
##
## See: design/gdd/game-session-state.md
## ADR: ADR-TBD-game-session-state (Autoload pattern locked here for MVP)
extends Node

# ─── Constants ────────────────────────────────────────────────────────────────

## Total semantic slots; per registry (lexicon-village-elder-question.md §3)
const TOTAL_SEMANTIC_SLOTS: int = 25

## Total vignettes; per registry
const VIGNETTE_COUNT: int = 7

## Game phase enum (mirrored by #1 Boot Manager; this is the data source of truth)
enum GamePhase { PLAYING, ENDING, TITLE }

# ─── State (private; mutated only via documented APIs) ────────────────────────

## Per-slot binding: slot_id (StringName) → meaning_icon (StringName) or null
## Populated by #9 Symbol-binding via [method set_binding]
var _binding_map: Dictionary = {}

## Slot IDs that are part of a fully-cascaded vignette (immutable once set).
## Set type semantics via Dictionary[StringName, bool].
var _confirmed_slots: Dictionary = {}

## Per-vignette cascade flag: vignette_id (StringName) → bool. Write-once true.
var _vignette_cascaded: Dictionary = {}

## Authoritative correct binding table; produced by #12 generator at game start.
## slot_id (StringName) → correct meaning_icon (StringName)
var _correct_table: Dictionary = {}

## Per-vignette slot list (authored content per #13).
## vignette_id (StringName) → Array[StringName] of slot_ids
var _slots_in_vignette: Dictionary = {}

## Deterministic language seed for #12 procedural generator (0 is legal per AC-20)
var _language_seed: int = 0

## Runtime glyph dict produced by #12 LVProcGen. Empty when MVP fallback is in
## use; populated when init_session is called with seed-driven generation.
var _runtime_glyphs: Dictionary = {}

## Wall-clock start snapshot (Time.get_ticks_msec at PLAYING entry)
var _timer_start_ms: int = 0

## Wall-clock end snapshot (set on PLAYING→ENDING transition)
var _timer_end_ms: int = 0

## Current game phase. See [enum GamePhase].
var _game_phase: int = GamePhase.TITLE

# ─── Signals ──────────────────────────────────────────────────────────────────

## Emitted exactly once per vignette when it transitions from incomplete to
## fully-bound + correct. [param vignette_id] is the cascading vignette.
signal vignette_completed(vignette_id: StringName)

## Emitted at PLAYING → ENDING transition AFTER session_elapsed_ms is computed.
## Listeners may safely read session_elapsed_ms when this fires.
signal session_ended

# ─── Public API ───────────────────────────────────────────────────────────────

## Initialize a fresh session with the given language seed and authored content.
## Called by #1 Boot Manager at Title→Game transition. [param seed] may be 0.
## [param correct_table_in] is slot_id → correct icon mapping from #12.
## [param slots_in_vignette_in] is vignette_id → Array[slot_id] mapping from #13.
func init_session(seed: int, correct_table_in: Dictionary, slots_in_vignette_in: Dictionary) -> void:
	_language_seed = seed
	_correct_table = correct_table_in.duplicate(true)
	_slots_in_vignette = slots_in_vignette_in.duplicate(true)
	_binding_map.clear()
	_confirmed_slots.clear()
	_vignette_cascaded.clear()
	_timer_start_ms = Time.get_ticks_msec()
	_timer_end_ms = 0
	_game_phase = GamePhase.PLAYING
	# Generate runtime glyphs from seed (Phase B integration). Seed 0 → fall back
	# to MVP const SEED_GLYPHS; non-zero → procedural per-run language.
	_runtime_glyphs.clear()
	if seed != 0:
		const LVProcGen = preload("res://lexicon/scripts/lv_proc_gen.gd")
		var slot_ids: Array = _collect_unique_slots(slots_in_vignette_in)
		_runtime_glyphs = LVProcGen.generate_glyphs(seed, slot_ids)

## Destroy all session state. Called by #1 Boot at Ending→Title transition.
func destroy_session() -> void:
	_binding_map.clear()
	_confirmed_slots.clear()
	_vignette_cascaded.clear()
	_correct_table.clear()
	_slots_in_vignette.clear()
	_runtime_glyphs.clear()
	_language_seed = 0
	_timer_start_ms = 0
	_timer_end_ms = 0
	_game_phase = GamePhase.TITLE

## Set or clear a slot binding. Returns true on success; false if rejected
## (e.g., slot is confirmed-immutable, or game_phase != PLAYING).
## [param slot_id] semantic slot identifier from keystone §3.
## [param icon_id] meaning-icon identifier, or [code]&""[/code] / null to clear.
func set_binding(slot_id: StringName, icon_id: Variant) -> bool:
	if _game_phase != GamePhase.PLAYING:
		return false  # AC-6: phase gate
	if _confirmed_slots.has(slot_id):
		return false  # AC-9: write-once on confirmed
	if icon_id == null or (icon_id is StringName and String(icon_id).is_empty()):
		_binding_map.erase(slot_id)
	else:
		_binding_map[slot_id] = icon_id
	_validate_owning_vignette(slot_id)
	return true

## Read the current binding for a slot. Returns null if unbound.
func get_binding(slot_id: StringName) -> Variant:
	return _binding_map.get(slot_id, null)

## Read-only access to the full binding map (defensive copy).
func get_binding_map() -> Dictionary:
	return _binding_map.duplicate()

## Read-only set of confirmed slot IDs.
func get_confirmed_slots() -> Array:
	return _confirmed_slots.keys()

## Check if a slot is part of a cascaded vignette (immutable).
func is_confirmed(slot_id: StringName) -> bool:
	return _confirmed_slots.has(slot_id)

## Check if a vignette has cascaded.
func is_vignette_cascaded(vignette_id: StringName) -> bool:
	return _vignette_cascaded.get(vignette_id, false)

## Compute the [code]"N/M 待解"[/code] counter for a vignette.
## See Formula 1 in game-session-state.md: |slots_in(v)| - |intersection with correctly_bound|.
func unresolved_count(vignette_id: StringName) -> int:
	var slots: Array = _slots_in_vignette.get(vignette_id, [])
	if slots.is_empty():
		return 0
	var correct_count: int = 0
	for slot_id in slots:
		if _is_slot_correctly_bound(slot_id):
			correct_count += 1
	return slots.size() - correct_count

## Check if every slot in a vignette is correctly bound (cascade predicate).
## See Formula 2 in game-session-state.md.
func vignette_valid(vignette_id: StringName) -> bool:
	var slots: Array = _slots_in_vignette.get(vignette_id, [])
	if slots.is_empty():
		# AC-19 authoring constraint: zero-slot vignettes forbidden.
		# Returning false defensively prevents accidental vacuous cascade.
		push_error("LVSessionState: vignette %s has zero slots — authoring error" % vignette_id)
		return false
	for slot_id in slots:
		if not _is_slot_correctly_bound(slot_id):
			return false
	return true

## Current game phase.
func get_game_phase() -> int:
	return _game_phase

## Get current language seed.
func get_language_seed() -> int:
	return _language_seed

## Runtime glyphs (procedural). Empty Dictionary means "use MVP fallback".
## Returned as a defensive copy.
func get_runtime_glyphs() -> Dictionary:
	return _runtime_glyphs.duplicate()

## Manually set runtime glyphs (overrides what init_session generated).
## Useful for tests + share-code workflows.
func set_runtime_glyphs(glyphs: Dictionary) -> void:
	_runtime_glyphs = glyphs.duplicate(true)

# ─── Save / Restore (Phase C) ─────────────────────────────────────────────────

## Serialize current session to a Dictionary suitable for JSON save or
## round-trip testing. Keys are plain Strings (JSON-safe).
func serialize() -> Dictionary:
	return {
		"version": 1,
		"seed": _language_seed,
		"binding_map": _stringify_keys_and_values(_binding_map),
		"confirmed_slots": _stringify_array(_confirmed_slots.keys()),
		"vignette_cascaded": _stringify_array(_vignette_cascaded.keys()),
		"game_phase": _game_phase,
		"elapsed_ms": session_elapsed_ms(),
	}

## Restore from a serialized Dictionary. Returns true on success, false on
## version mismatch or malformed input. NOTE: restoration replays state but
## does NOT re-emit vignette_completed (those signals already happened in the
## original session). UI must re-render on its own.
func deserialize(d: Dictionary, correct_table_in: Dictionary, slots_in_vignette_in: Dictionary) -> bool:
	if d.get("version", 0) != 1:
		return false
	if not d.has("seed"):
		return false
	# Re-init with the saved seed; this regenerates runtime_glyphs identically.
	init_session(int(d.seed), correct_table_in, slots_in_vignette_in)
	# Replay binding_map without firing cascade — set internal dict directly.
	for key in d.get("binding_map", {}).keys():
		var sn_key: StringName = StringName(String(key))
		var v_val: Variant = d.binding_map[key]
		_binding_map[sn_key] = StringName(String(v_val)) if v_val is String or v_val is StringName else v_val
	for s in d.get("confirmed_slots", []):
		_confirmed_slots[StringName(String(s))] = true
	for v in d.get("vignette_cascaded", []):
		_vignette_cascaded[StringName(String(v))] = true
	# Phase restoration (best-effort)
	if d.has("game_phase"):
		_game_phase = int(d.game_phase)
	return true

## Serialize to JSON string.
func to_save_json() -> String:
	return JSON.stringify(serialize())

## Restore from JSON. Returns false on parse failure or version mismatch.
func from_save_json(json_str: String, correct_table_in: Dictionary, slots_in_vignette_in: Dictionary) -> bool:
	var parsed: Variant = JSON.parse_string(json_str)
	if not (parsed is Dictionary):
		return false
	return deserialize(parsed, correct_table_in, slots_in_vignette_in)

func _stringify_keys_and_values(d: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k in d.keys():
		out[String(k)] = String(d[k]) if d[k] is StringName else d[k]
	return out

func _stringify_array(arr: Array) -> Array:
	var out: Array = []
	for v in arr:
		out.append(String(v))
	return out

## Transition PLAYING → ENDING. Snapshots timer atomically BEFORE emitting signal
## (AC-10). Idempotent: a second call has no effect.
func transition_to_ending() -> void:
	if _game_phase != GamePhase.PLAYING:
		return
	_timer_end_ms = Time.get_ticks_msec()
	_game_phase = GamePhase.ENDING
	session_ended.emit()

## Elapsed session time in milliseconds. Valid after [method transition_to_ending].
## During PLAYING, returns elapsed-so-far.
func session_elapsed_ms() -> int:
	if _timer_start_ms == 0:
		return 0
	var end_ms: int = _timer_end_ms if _timer_end_ms > 0 else Time.get_ticks_msec()
	return end_ms - _timer_start_ms

# ─── Private helpers ──────────────────────────────────────────────────────────

## Collect unique slot IDs across all vignettes (used for proc gen kick-off).
func _collect_unique_slots(slots_in_vignette_in: Dictionary) -> Array:
	var seen: Dictionary = {}
	var out: Array = []
	for vignette_id in slots_in_vignette_in.keys():
		for slot_id in slots_in_vignette_in[vignette_id]:
			if not seen.has(slot_id):
				seen[slot_id] = true
				out.append(slot_id)
	return out

func _is_slot_correctly_bound(slot_id: StringName) -> bool:
	if not _binding_map.has(slot_id):
		return false
	return _binding_map[slot_id] == _correct_table.get(slot_id, null)

## Run vignette validation after a slot change. Fires cascade exactly once per vignette.
func _validate_owning_vignette(changed_slot: StringName) -> void:
	for vignette_id in _slots_in_vignette.keys():
		var slots: Array = _slots_in_vignette[vignette_id]
		if not slots.has(changed_slot):
			continue
		if _vignette_cascaded.get(vignette_id, false):
			continue  # AC-8: write-once guard
		if vignette_valid(vignette_id):
			_vignette_cascaded[vignette_id] = true
			for slot_id in slots:
				_confirmed_slots[slot_id] = true
			vignette_completed.emit(vignette_id)
