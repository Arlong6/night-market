## GUT integration tests for v0.26 stall visual identity.
##
## Verifies that each ingredient maps to a distinct awning stripe pair, and
## that unknown ingredients fall back to the default red+cream pair.
extends GutTest


func _reset() -> void:
	Game.test_mode = true
	Inventory.reset()
	HiScore.clear()


func before_each() -> void:
	_reset()


func after_each() -> void:
	_reset()
	Game.test_mode = false


func _make_stall(ingredient: String) -> StallNPC:
	var parent: Node2D = Node2D.new()
	add_child_autofree(parent)
	var stall: StallNPC = StallNPC.new()
	stall.cell = Vector2i(5, 5)
	stall.ingredient_id = ingredient
	stall.price = 50
	parent.add_child(stall)
	await get_tree().process_frame
	return stall


# ---------------------------------------------------------------------------
# v0.26 — awning palette
# ---------------------------------------------------------------------------

func test_stall_awning_palette_returns_pair_for_known_ingredient() -> void:
	# Arrange / Act
	var stall: StallNPC = await _make_stall("chicken")
	var palette: Array = stall._awning_palette()

	# Assert
	assert_eq(palette.size(), 2,
		"awning palette should be a 2-element [stripe_a, stripe_b] array")
	assert_true(palette[0] is Color,
		"stripe_a should be a Color — got %s" % typeof(palette[0]))
	assert_true(palette[1] is Color)


func test_stall_awning_palette_differs_between_ingredients() -> void:
	# Arrange
	var chicken_stall: StallNPC = await _make_stall("chicken")
	var tofu_stall: StallNPC = await _make_stall("tofu")

	# Act
	var chicken_palette: Array = chicken_stall._awning_palette()
	var tofu_palette: Array = tofu_stall._awning_palette()

	# Assert: chicken (red+cream) and tofu (grey+cream) must NOT be identical.
	# Stripe A is the saturated half — that's where the per-ingredient
	# differentiation lives.
	assert_ne(chicken_palette[0], tofu_palette[0],
		"chicken vs tofu stalls should have distinct stripe_a colors")


func test_stall_awning_palette_falls_back_for_unknown_ingredient() -> void:
	# Arrange / Act
	var stall: StallNPC = await _make_stall("nonexistent_ingredient")
	var palette: Array = stall._awning_palette()

	# Assert: fallback is the default red+cream pair (matches v0.5 behaviour
	# so any data error stays visually safe rather than crashing).
	assert_eq(palette[0], StallNPC.COLOR_AWNING_A,
		"unknown ingredient should fall back to default stripe_a")
	assert_eq(palette[1], StallNPC.COLOR_AWNING_B,
		"unknown ingredient should fall back to default stripe_b")


func test_stall_awning_palette_covers_all_seven_ingredients() -> void:
	# Arrange: full set of recipe-relevant ingredients.
	var ingredients: Array[String] = [
		"chicken", "egg", "scallion", "cabbage",
		"tofu", "soy_sauce", "mushroom",
	]

	# Act / Assert: every shipping ingredient has its own palette entry, so
	# the night market reads as 7 distinct stalls rather than 6+default.
	for ing in ingredients:
		assert_true(StallNPC.AWNING_PALETTE.has(ing),
			"ingredient '%s' should have a dedicated awning palette" % ing)


# ---------------------------------------------------------------------------
# v0.27 — vendor characters
# ---------------------------------------------------------------------------

func test_stall_vendor_data_returns_full_schema_for_known_ingredient() -> void:
	# Arrange / Act
	var stall: StallNPC = await _make_stall("chicken")
	var data: Dictionary = stall._vendor_data()

	# Assert: schema must include hair / accent / skin so _draw_vendor_head
	# never has to handle missing keys.
	assert_true(data.has("hair"), "vendor data missing 'hair'")
	assert_true(data.has("accent"), "vendor data missing 'accent'")
	assert_true(data.has("skin"), "vendor data missing 'skin'")
	assert_true(data["hair"] is Color, "hair should be a Color")
	assert_true(data["accent"] is Color, "accent should be a Color")
	assert_true(data["skin"] is Color, "skin should be a Color")


func test_stall_vendor_data_differs_between_ingredients() -> void:
	# Arrange
	var chicken_stall: StallNPC = await _make_stall("chicken")
	var scallion_stall: StallNPC = await _make_stall("scallion")

	# Act
	var chicken_vendor: Dictionary = chicken_stall._vendor_data()
	var scallion_vendor: Dictionary = scallion_stall._vendor_data()

	# Assert: the chicken vendor (young guy, red scarf, dark hair) and the
	# scallion granny (grey hair, green band) MUST differ on at least one
	# field so the player can visually tell them apart.
	var differs_on_any: bool = (
		chicken_vendor["hair"] != scallion_vendor["hair"]
		or chicken_vendor["accent"] != scallion_vendor["accent"]
		or chicken_vendor["skin"] != scallion_vendor["skin"]
	)
	assert_true(differs_on_any,
		"chicken vs scallion vendors should be visually distinct")


func test_stall_vendor_data_falls_back_for_unknown_ingredient() -> void:
	# Arrange / Act
	var stall: StallNPC = await _make_stall("nonexistent_ingredient")
	var data: Dictionary = stall._vendor_data()

	# Assert: fallback uses NPC base palette so unknown ids stay drawable.
	assert_eq(data["hair"], NPC.COLOR_HAIR,
		"unknown ingredient should fall back to default NPC hair")
	assert_eq(data["skin"], NPC.COLOR_SKIN,
		"unknown ingredient should fall back to default NPC skin")


func test_stall_vendor_data_covers_all_seven_ingredients() -> void:
	# Arrange
	var ingredients: Array[String] = [
		"chicken", "egg", "scallion", "cabbage",
		"tofu", "soy_sauce", "mushroom",
	]

	# Act / Assert
	for ing in ingredients:
		assert_true(StallNPC.VENDOR_DATA.has(ing),
			"ingredient '%s' should have a dedicated vendor entry" % ing)
