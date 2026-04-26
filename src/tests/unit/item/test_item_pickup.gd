## GUT unit tests for ItemPickup (v0.2 content pass).
extends GutTest


func before_each() -> void:
	if Dialogue._active and Dialogue._box != null:
		Dialogue._box._close()
	Dialogue._active = false
	Game.in_dialogue = false
	Inventory.reset()


func after_each() -> void:
	if Dialogue._active and Dialogue._box != null:
		Dialogue._box._close()
	Dialogue._active = false
	Game.in_dialogue = false


func _make_item(value: int = 10, line: String = "") -> ItemPickup:
	var parent: Node2D = Node2D.new()
	add_child_autofree(parent)
	var item: ItemPickup = ItemPickup.new()
	item.cell = Vector2i(5, 5)
	item.value = value
	item.pickup_line = line
	parent.add_child(item)
	await get_tree().process_frame
	return item


func test_item_collect_adds_value_to_money() -> void:
	var item: ItemPickup = await _make_item(15)
	var start: int = Inventory.money
	var ok: bool = item.collect()
	await get_tree().process_frame
	assert_true(ok, "collect should report success")
	assert_eq(Inventory.money, start + 15,
		"Money should increase by item.value — got %s" % Inventory.money)


func test_item_collect_emits_money_changed() -> void:
	var item: ItemPickup = await _make_item(10)
	watch_signals(Inventory)
	item.collect()
	assert_signal_emitted(Inventory, "money_changed",
		"money_changed should fire on collect")


func test_item_collect_frees_self() -> void:
	var item: ItemPickup = await _make_item(10)
	item.collect()
	await get_tree().process_frame
	assert_false(is_instance_valid(item), "Item should be queue_freed after collect")


func test_item_collect_with_line_shows_dialogue() -> void:
	var item: ItemPickup = await _make_item(10, "撿到 NT$10！")
	item.collect()
	await get_tree().process_frame
	assert_true(Dialogue.is_active(),
		"Pickup line should trigger dialogue when one is supplied")


func test_item_collect_with_empty_line_no_dialogue() -> void:
	var item: ItemPickup = await _make_item(10, "")
	item.collect()
	await get_tree().process_frame
	assert_false(Dialogue.is_active(),
		"Empty pickup_line should not trigger a dialogue")


func test_item_position_set_to_cell_in_ready() -> void:
	var item: ItemPickup = await _make_item(10)
	assert_eq(item.position, GridWorld.cell_to_px(Vector2i(5, 5)),
		"Item position should be cell-centre after _ready")
