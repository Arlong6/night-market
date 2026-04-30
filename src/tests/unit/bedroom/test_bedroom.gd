## GUT unit tests for the v0.29 bedroom bookend scene.
##
## Verifies area marker, dialogue-lock release, single-shot routing, and
## that the scene correctly funnels to "title" on advance.
extends GutTest


func _reset() -> void:
	Game.test_mode = true
	Game.current_area = ""
	Game.in_dialogue = false


func before_each() -> void:
	_reset()


func after_each() -> void:
	_reset()
	Game.test_mode = false


func _make_scene() -> Bedroom:
	var scene: Bedroom = Bedroom.new()
	add_child_autofree(scene)
	await get_tree().process_frame
	return scene


# ---------------------------------------------------------------------------
# v0.29 — boot + routing
# ---------------------------------------------------------------------------

func test_bedroom_sets_area_to_bedroom_on_ready() -> void:
	# Arrange / Act
	var _scene: Bedroom = await _make_scene()

	# Assert
	assert_eq(Game.current_area, "bedroom",
		"bedroom._ready should mark Game.current_area")


func test_bedroom_clears_dialogue_lock_on_ready() -> void:
	# Arrange — leftover dialogue lock from end_screen
	Game.in_dialogue = true

	# Act
	var _scene: Bedroom = await _make_scene()

	# Assert
	assert_false(Game.in_dialogue,
		"bedroom should release any leftover dialogue lock")


func test_bedroom_advance_routes_to_title() -> void:
	# Arrange
	var scene: Bedroom = await _make_scene()

	# Act
	scene._advance()

	# Assert
	assert_eq(Game.current_area, "title",
		"bedroom._advance should route to 'title' — got '%s'"
		% Game.current_area)


func test_bedroom_advance_is_single_shot() -> void:
	# Arrange
	var scene: Bedroom = await _make_scene()
	scene._advance()
	# Tamper to detect a second advance
	Game.current_area = "shilin"

	# Act
	scene._advance()

	# Assert: second advance must be guarded so SPACE + auto-timer don't
	# both fire and double-load the title.
	assert_eq(Game.current_area, "shilin",
		"second _advance call should be a no-op — got '%s'"
		% Game.current_area)
