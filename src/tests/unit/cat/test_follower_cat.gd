## GUT tests for FollowerCat (v0.50 寵物追隨).
extends GutTest


func _make_player(start: Vector2i = Vector2i(5, 5)) -> PlayerGrid:
	var p: PlayerGrid = PlayerGrid.new()
	p.start_cell = start
	p.walkable_check = func(_c: Vector2i) -> bool: return true
	add_child_autofree(p)
	await get_tree().process_frame
	return p


func before_each() -> void:
	HiScore.cat_rescues = 0


func after_each() -> void:
	HiScore.cat_rescues = 0


func test_follower_cat_constructs_without_crash() -> void:
	# Arrange / Act
	var c: FollowerCat = FollowerCat.new()
	add_child_autofree(c)
	await get_tree().process_frame
	# Assert
	assert_eq(c._cell, Vector2i(0, 0),
		"default cell should be Vector2i.ZERO before configure()")


func test_follower_cat_configure_seeds_position_to_player_cell() -> void:
	# Arrange
	var p: PlayerGrid = await _make_player(Vector2i(7, 4))
	var c: FollowerCat = FollowerCat.new()
	add_child_autofree(c)

	# Act
	c.configure(p)
	await get_tree().process_frame

	# Assert
	assert_eq(c._cell, Vector2i(7, 4),
		"cat should spawn on the same cell as the player")
	assert_eq(c.position, GridWorld.cell_to_px(Vector2i(7, 4)),
		"cat position should match the seeded cell pixel")


func test_follower_cat_trail_pre_seeded_with_follow_delay() -> void:
	# Arrange
	var p: PlayerGrid = await _make_player(Vector2i(5, 5))
	var c: FollowerCat = FollowerCat.new()
	add_child_autofree(c)

	# Act
	c.configure(p)
	await get_tree().process_frame

	# Assert — trail seeded with FOLLOW_DELAY+1 copies of player cell so
	# the cat doesn't drag the wrong way on the first step.
	assert_eq(c._trail.size(), FollowerCat.FOLLOW_DELAY + 1,
		"trail should be pre-seeded with FOLLOW_DELAY+1 entries")
	for cell in c._trail:
		assert_eq(cell, Vector2i(5, 5),
			"every seeded trail entry should equal the player's spawn cell")


func test_follower_cat_only_spawns_after_first_rescue() -> void:
	# Arrange
	HiScore.cat_rescues = 0
	# Assert
	assert_false(HiScore.has_cat_friend(),
		"with 0 rescues, has_cat_friend() must be false")

	# Arrange — record one rescue
	HiScore.cat_rescues = 1
	# Assert
	assert_true(HiScore.has_cat_friend(),
		"after 1 rescue, has_cat_friend() should return true")
