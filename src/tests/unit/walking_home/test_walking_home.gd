## GUT unit tests for the v0.28 回家路上 walking-home interlude.
##
## Verifies that the scene boots cleanly, sets the area marker, and that
## the SPACE skip path advances to "kitchen" — covering the routing
## contract the mom_npc + kitchen flows depend on.
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


func _make_scene() -> WalkingHome:
	var scene: WalkingHome = WalkingHome.new()
	add_child_autofree(scene)
	await get_tree().process_frame
	return scene


# ---------------------------------------------------------------------------
# v0.28 — boot + routing
# ---------------------------------------------------------------------------

func test_walking_home_sets_area_to_walking_home_on_ready() -> void:
	# Arrange / Act
	var _scene: WalkingHome = await _make_scene()

	# Assert
	assert_eq(Game.current_area, "walking_home",
		"walking_home._ready should mark Game.current_area")


func test_walking_home_clears_dialogue_lock_on_ready() -> void:
	# Arrange — simulate a leftover dialogue lock from the prior scene.
	Game.in_dialogue = true

	# Act
	var _scene: WalkingHome = await _make_scene()

	# Assert
	assert_false(Game.in_dialogue,
		"walking_home should release any leftover dialogue lock")


func test_walking_home_advance_routes_to_kitchen() -> void:
	# Arrange
	var scene: WalkingHome = await _make_scene()

	# Act — call the advance path that SPACE / the auto timer both invoke.
	scene._advance()

	# Assert
	assert_eq(Game.current_area, "kitchen",
		"walking_home._advance should route to 'kitchen' — got '%s'"
		% Game.current_area)


func test_walking_home_advance_is_single_shot() -> void:
	# Arrange
	var scene: WalkingHome = await _make_scene()
	scene._advance()
	# Tamper with current_area so a second _advance would be visible.
	Game.current_area = "shilin"

	# Act
	scene._advance()

	# Assert: the second _advance should have been guarded, leaving the
	# tampered value untouched. Prevents SPACE + auto-timer racing into
	# double scene loads.
	assert_eq(Game.current_area, "shilin",
		"second _advance call should be a no-op — got '%s'"
		% Game.current_area)
