## Global dialogue queue for Night Market Shopping (R-004).
##
## Lazily spawns a DialogueBox CanvasLayer on first `show()`. The box renders
## above all gameplay (layer 15) and locks `Game.in_dialogue` while active so
## PlayerGrid stops accepting movement input.
##
## Usage:
##   Dialogue.show(["你好！", "今天買什麼呢？"], func(): print("done"))
##
## Re-entrancy: returns false if a dialogue is already active. Levels are
## responsible for not stacking calls — typically a single bump triggers a
## single show() and the on_done callback chains any follow-up.
extends Node

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

signal dialogue_started
signal dialogue_finished

# ---------------------------------------------------------------------------
# Private state
# ---------------------------------------------------------------------------

var _box: DialogueBox = null
var _active: bool = false
var _on_done: Callable = Callable()

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Displays the given lines one at a time. The on_done Callable is invoked
## after the player advances past the final line. Returns false if a dialogue
## is already active (re-entrancy guard).
func show(lines: Array[String], on_done: Callable = Callable()) -> bool:
	if _active:
		return false
	_active = true
	_on_done = on_done
	Game.in_dialogue = true
	_ensure_box()
	_box.start_dialogue(lines)
	dialogue_started.emit()
	return true


## Whether a dialogue is currently being shown.
func is_active() -> bool:
	return _active

# ---------------------------------------------------------------------------
# Internal — called by DialogueBox when the player advances past the last line
# ---------------------------------------------------------------------------

func _on_box_finished() -> void:
	_active = false
	Game.in_dialogue = false
	var cb: Callable = _on_done
	_on_done = Callable()
	dialogue_finished.emit()
	if cb.is_valid():
		cb.call()


# ---------------------------------------------------------------------------
# Lazy spawn
# ---------------------------------------------------------------------------

func _ensure_box() -> void:
	if _box != null and is_instance_valid(_box):
		return
	_box = DialogueBox.new()
	_box.finished.connect(_on_box_finished)
	add_child(_box)
