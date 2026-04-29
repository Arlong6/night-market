## GUT integration tests for v0.20 vendor loyalty (cross-run discounts +
## tier greetings).
##
## Loyalty is driven by HiScore.purchase_count(ingredient_id). Each tier
## discounts effective_price multiplicatively on top of the per-run
## `discount` field.
extends GutTest


func _reset() -> void:
	if Dialogue._active and Dialogue._box != null:
		Dialogue._box._close()
	Dialogue._active = false
	Game.in_dialogue = false
	Inventory.reset()
	HiScore.clear()


func before_each() -> void:
	_reset()


func after_each() -> void:
	_reset()


func _make_stall(ingredient: String = "egg", price: int = 50) -> StallNPC:
	var parent: Node2D = Node2D.new()
	add_child_autofree(parent)
	var stall: StallNPC = StallNPC.new()
	stall.cell = Vector2i(5, 5)
	stall.ingredient_id = ingredient
	stall.price = price
	var intro: Array[String] = ["test"]
	stall.intro_lines = intro
	parent.add_child(stall)
	await get_tree().process_frame
	return stall


# ---------------------------------------------------------------------------
# Tier ↔ purchase count
# ---------------------------------------------------------------------------

func test_stall_loyalty_tier_zero_on_first_visit() -> void:
	var stall: StallNPC = await _make_stall("egg", 50)
	assert_eq(stall._loyalty_tier(), 0,
		"Tier should be 0 with no prior purchases")
	assert_almost_eq(stall._loyalty_discount(), 1.0, 0.001,
		"Tier 0 discount should be 1.0 (full price)")


func test_stall_loyalty_tier_one_after_first_purchase() -> void:
	HiScore.vendor_purchases = {"egg": 1}
	var stall: StallNPC = await _make_stall("egg", 50)
	assert_eq(stall._loyalty_tier(), 1,
		"After 1 purchase tier should be 1")


func test_stall_loyalty_tier_caps_at_three() -> void:
	HiScore.vendor_purchases = {"egg": 99}
	var stall: StallNPC = await _make_stall("egg", 50)
	assert_eq(stall._loyalty_tier(), 3,
		"99 purchases should cap at the highest tier (3)")


func test_stall_loyalty_discount_stacks_with_per_run_discount() -> void:
	# Tier 3 (15% off) × per-run 0.8 discount × price 50
	# = 50 * 0.8 * 0.85 = 34
	HiScore.vendor_purchases = {"egg": 10}
	var stall: StallNPC = await _make_stall("egg", 50)
	stall.discount = 0.8
	assert_eq(stall.effective_price(), 34,
		"effective_price should stack run discount × loyalty discount — got %d" %
			stall.effective_price())


# ---------------------------------------------------------------------------
# Greeting line per tier
# ---------------------------------------------------------------------------

func test_stall_loyalty_greeting_uses_intro_at_tier_zero() -> void:
	var stall: StallNPC = await _make_stall("egg", 50)
	var lines: Array[String] = stall._greeting_lines_for_tier(0)
	assert_eq(lines, stall.intro_lines,
		"Tier 0 should fall through to the configured intro_lines")


func test_stall_loyalty_greeting_personalised_at_tier_three() -> void:
	var stall: StallNPC = await _make_stall("egg", 50)
	var lines: Array[String] = stall._greeting_lines_for_tier(3)
	assert_ne(lines, stall.intro_lines,
		"Tier 3 should use the personalised regular-customer greeting")
	assert_eq(lines.size(), 1,
		"Greeting should be a single line at tier 3")


# ---------------------------------------------------------------------------
# Persistence — record_purchase wires through HiScore
# ---------------------------------------------------------------------------

func test_stall_buy_increments_hiscore_purchase_count() -> void:
	var stall: StallNPC = await _make_stall("egg", 30)
	var before: int = HiScore.purchase_count("egg")
	stall._attempt_buy()
	await get_tree().process_frame
	# Snap-close any post-buy dialogue
	if Dialogue.is_active():
		Dialogue._box._advance()
		Dialogue._box._advance()
	await get_tree().process_frame
	assert_eq(HiScore.purchase_count("egg"), before + 1,
		"Successful buy should bump HiScore.purchase_count('egg') by 1")
