## GUT tests for StreetMusician (v0.49 街頭藝人).
extends GutTest


func _reset() -> void:
	if Dialogue._active and Dialogue._box != null:
		Dialogue._box._close()
	Dialogue._active = false
	Game.in_dialogue = false
	HiScore.day = 1
	Inventory.reset()


func before_each() -> void:
	_reset()


func after_each() -> void:
	_reset()


func _make_musician() -> StreetMusician:
	var parent: Node2D = Node2D.new()
	add_child_autofree(parent)
	var m: StreetMusician = StreetMusician.new()
	m.cell = Vector2i(22, 9)
	parent.add_child(m)
	await get_tree().process_frame
	return m


func test_street_musician_constructs_and_draws_without_crash() -> void:
	# Arrange / Act
	var m: StreetMusician = await _make_musician()
	# Assert
	assert_eq(m.cell, Vector2i(22, 9),
		"cell @export should round-trip")
	assert_false(m._tipped,
		"_tipped should default false on a fresh musician")


func test_street_musician_bump_when_broke_does_not_charge() -> void:
	# Arrange
	var m: StreetMusician = await _make_musician()
	Inventory.money = StreetMusician.TIP_AMOUNT - 1
	var before: int = Inventory.money
	# Act
	m.on_bumped()
	await get_tree().process_frame
	# Assert
	assert_eq(Inventory.money, before,
		"insufficient-funds bump must not deduct money")
	assert_false(m._tipped,
		"insufficient-funds bump must not flip _tipped")


func test_street_musician_already_tipped_bump_does_not_charge() -> void:
	# Arrange
	var m: StreetMusician = await _make_musician()
	m._tipped = true
	var before: int = Inventory.money
	# Act
	m.on_bumped()
	await get_tree().process_frame
	# Assert
	assert_eq(Inventory.money, before,
		"already-tipped bump must not deduct money on subsequent bumps")


func test_street_musician_tip_amount_constant() -> void:
	# Lock the public tip price so callers can rely on it.
	assert_eq(StreetMusician.TIP_AMOUNT, 2,
		"TIP_AMOUNT should be NT$2")


func test_street_musician_freezes_in_test_mode() -> void:
	# Arrange — test_mode is enabled in the test runner; make sure note
	# integration is gated correctly so unit tests stay deterministic.
	Game.test_mode = true
	var m: StreetMusician = await _make_musician()
	var spawn_t_before: float = m._spawn_t
	# Act
	m._process(2.0)  # under test_mode this should NOT advance _spawn_t
	# Assert
	assert_almost_eq(m._spawn_t, spawn_t_before, 0.001,
		"test_mode should freeze note spawn timer")
	Game.test_mode = false
