## LVSymbolBinding — Lexicon Village #9 Symbol-to-meaning binding
##
## Gesture LOGIC layer. Owns CARRIED state and per-icon/per-slot state transitions.
## Visual rendering (hover lift, settle tween) is the responsibility of #16 Notebook UI.
##
## NOT an Autoload — instantiated by #16 Notebook UI as a peer Object.
##
## See: design/gdd/symbol-binding.md
class_name LVSymbolBinding
extends RefCounted

## Reference to LVSessionState autoload (injected; nullable for tests without autoload).
var _session_state: Object = null

## Currently carried icon (null if nothing carried). Per-instance state.
var _carried_icon: Variant = null

## If carried icon was picked up from a slot, remember the slot for restore-on-cancel.
var _carried_origin_slot: Variant = null  # StringName or null

# ─── Signals ──────────────────────────────────────────────────────────────────

## Emitted when icon enters CARRIED state.
signal icon_picked_up(icon_id: StringName, origin_slot: Variant)

## Emitted when carried icon is placed onto a slot.
signal icon_placed(slot_id: StringName, icon_id: StringName)

## Emitted when carried icon is cancelled/deselected without placement.
signal carry_cancelled

## Emitted when a slot is cleared (icon picked up from it without immediate replacement).
signal slot_emptied(slot_id: StringName)

# ─── Construction ─────────────────────────────────────────────────────────────

func _init(session_state: Object = null) -> void:
	_session_state = session_state

## Set or change the session state reference (used by #16 at construction time).
func set_session_state(ss: Object) -> void:
	_session_state = ss

# ─── Public API ───────────────────────────────────────────────────────────────

## Pick up an icon from the palette. Per AC-1.
## Returns true on success; false if rejected (already carrying = first returned, then new).
func pick_up_from_palette(icon_id: StringName) -> bool:
	if _is_phase_locked():
		return false
	# AC-15: if already carrying, return current to origin and pick up new.
	if _carried_icon != null:
		_return_current_to_origin_silently()
	_carried_icon = icon_id
	_carried_origin_slot = null  # from palette, not from slot
	icon_picked_up.emit(icon_id, null)
	return true

## Pick up an icon from a slot (re-arrangement). Per AC-6.
## Returns true on success; false if slot is confirmed-immutable or empty.
func pick_up_from_slot(slot_id: StringName) -> bool:
	if _is_phase_locked():
		return false
	if _is_confirmed(slot_id):
		return false  # AC-5: confirmed slot non-interactive
	var current_binding: Variant = _get_binding(slot_id)
	if current_binding == null:
		return false  # nothing to pick up
	# If already carrying, return current to origin first
	if _carried_icon != null:
		_return_current_to_origin_silently()
	_carried_icon = current_binding
	_carried_origin_slot = slot_id
	# Clear the slot at data layer
	if _session_state:
		_session_state.set_binding(slot_id, null)
	slot_emptied.emit(slot_id)
	icon_picked_up.emit(current_binding, slot_id)
	return true

## Place carried icon onto a slot. Per AC-2/AC-3.
## Returns true if placement succeeded; false if rejected (no carry, confirmed slot, phase locked).
func place_on_slot(slot_id: StringName) -> bool:
	if _is_phase_locked():
		return false
	if _carried_icon == null:
		return false
	if _is_confirmed(slot_id):
		# AC-4: silently rejected — caller animates snap-back to origin
		return false
	# AC-3: if slot already has icon, swap (return existing to palette first)
	var existing: Variant = _get_binding(slot_id)
	if existing != null:
		# Return existing to PALETTE_IDLE (we don't track palette positions here;
		# #16 manages palette grid; we just emit slot_emptied for the existing)
		if _session_state:
			_session_state.set_binding(slot_id, null)
	# Write the new binding
	var icon_to_place: StringName = _carried_icon
	if _session_state:
		_session_state.set_binding(slot_id, icon_to_place)
	_carried_icon = null
	_carried_origin_slot = null
	icon_placed.emit(slot_id, icon_to_place)
	return true

## Cancel current carry (Esc, click background, click carried icon again). Per AC-7/AC-8/AC-16/AC-18.
## Returns the icon to its origin without firing slot_assignment_changed.
func cancel_carry() -> void:
	if _carried_icon == null:
		return
	if _carried_origin_slot != null and _session_state:
		# AC-8: restore prior binding via a write back to #19
		_session_state.set_binding(_carried_origin_slot, _carried_icon)
	_carried_icon = null
	_carried_origin_slot = null
	carry_cancelled.emit()

## Currently carrying an icon?
func is_carrying() -> bool:
	return _carried_icon != null

## Currently carried icon (or null).
func get_carried_icon() -> Variant:
	return _carried_icon

## Origin slot of carried icon (or null if from palette / not carrying).
func get_carried_origin_slot() -> Variant:
	return _carried_origin_slot

## Check if a palette icon is currently "placed" somewhere (UI uses this to dim
## palette entries). Per AC-9 prevent double-binding.
func is_icon_placed_somewhere(icon_id: StringName) -> bool:
	if _session_state == null:
		return false
	var binding_map: Dictionary = _session_state.get_binding_map()
	for v in binding_map.values():
		if v == icon_id:
			return true
	return false

# ─── Internal ─────────────────────────────────────────────────────────────────

func _return_current_to_origin_silently() -> void:
	# Used when player picks up a different icon while already carrying.
	# Restores current carried icon to its origin without firing user-facing signals.
	if _carried_origin_slot != null and _session_state:
		_session_state.set_binding(_carried_origin_slot, _carried_icon)
	_carried_icon = null
	_carried_origin_slot = null

func _is_phase_locked() -> bool:
	# AC-14: ENDING phase locks all interactive elements
	if _session_state == null:
		return false
	# LVSessionState.GamePhase.PLAYING = 0; if not PLAYING, lock
	return _session_state.get_game_phase() != 0  # PLAYING

func _is_confirmed(slot_id: StringName) -> bool:
	if _session_state == null:
		return false
	return _session_state.is_confirmed(slot_id)

func _get_binding(slot_id: StringName) -> Variant:
	if _session_state == null:
		return null
	return _session_state.get_binding(slot_id)
