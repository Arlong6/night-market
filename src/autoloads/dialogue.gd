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


## Asks the player a yes/no (or N-way) question. Shows the question with the
## typewriter, then renders `options` as a selectable list. The Callable is
## invoked with the chosen index once the player presses interact on a choice.
## Returns false if a dialogue is already active.
func ask_choice(question: String, options: Array[String], on_choice: Callable) -> bool:
	if _active:
		return false
	_active = true
	_on_done = on_choice  # repurposed for choice callback
	Game.in_dialogue = true
	_ensure_box()
	_box.start_choice(question, options)
	dialogue_started.emit()
	return true

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


## Internal — DialogueBox calls this when the player confirms a choice option.
## Forwards the selected index to the original ask_choice callable, then
## clears the active flag.
func _on_box_choice_confirmed(index: int) -> void:
	_active = false
	Game.in_dialogue = false
	var cb: Callable = _on_done
	_on_done = Callable()
	dialogue_finished.emit()
	if cb.is_valid():
		cb.call(index)


# ---------------------------------------------------------------------------
# Lazy spawn
# ---------------------------------------------------------------------------

func _ensure_box() -> void:
	if _box != null and is_instance_valid(_box):
		return
	_box = DialogueBox.new()
	_box.finished.connect(_on_box_finished)
	_box.choice_confirmed.connect(_on_box_choice_confirmed)
	add_child(_box)
