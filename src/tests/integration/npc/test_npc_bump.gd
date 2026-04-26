## GUT integration tests for NPC bump-to-talk wiring (R-004).
extends GutTest


func _reset_dialogue() -> void:
	if Dialogue._active and Dialogue._box != null:
		Dialogue._box._close()
	Dialogue._active = false
	Game.in_dialogue = false


func before_each() -> void:
	_reset_dialogue()


func after_each() -> void:
	_reset_dialogue()


func test_npc_on_bumped_triggers_dialogue() -> void:
	var npc: NPC = NPC.new()
	npc.cell = Vector2i(5, 5)
	npc.lines = ["你好！"]
	add_child_autofree(npc)
	await get_tree().process_frame

	npc.on_bumped()
	await get_tree().process_frame

	assert_true(Dialogue.is_active(),
		"Bumping NPC with non-empty lines should start a dialogue")


func test_npc_with_empty_lines_does_not_trigger_dialogue() -> void:
	var npc: NPC = NPC.new()
	npc.cell = Vector2i(5, 5)
	npc.lines = []
	add_child_autofree(npc)
	await get_tree().process_frame

	npc.on_bumped()
	await get_tree().process_frame

	assert_false(Dialogue.is_active(),
		"Empty-lines NPC should be a no-op on bump")


func test_npc_position_set_to_cell_pixel_in_ready() -> void:
	var npc: NPC = NPC.new()
	npc.cell = Vector2i(4, 7)
	add_child_autofree(npc)
	await get_tree().process_frame

	assert_eq(npc.position, GridWorld.cell_to_px(Vector2i(4, 7)),
		"NPC position should equal cell-centre pixel after _ready")


func test_market_register_npc_indexes_by_cell() -> void:
	var market: ShilinMarket = ShilinMarket.new()
	add_child_autofree(market)
	await get_tree().process_frame

	var npc: NPC = NPC.new()
	npc.cell = Vector2i(10, 6)
	npc.lines = ["test"]
	market.register_npc(npc)
	await get_tree().process_frame

	# Bump the cell — the level should dispatch to npc.on_bumped().
	market._on_player_bumped(Vector2i(10, 6))
	await get_tree().process_frame

	assert_true(Dialogue.is_active(),
		"register_npc + level bump should chain through to dialogue")
	assert_false(market.is_walkable(Vector2i(10, 6)),
		"register_npc should mark the cell unwalkable")
