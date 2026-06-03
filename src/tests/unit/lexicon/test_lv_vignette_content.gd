## Unit tests for LVVignetteContent (#13 baker quick-spec).
## Verifies content data matches design/gdd/vignette-content-baker.md.
extends GutTest

const LVVignetteContent = preload("res://lexicon/data/lv_vignette_content.gd")

# Baker content present per spec
func test_baker_content_has_three_slots() -> void:
	# Assert
	var slots: Array = LVVignetteContent.SLOTS_IN_VIGNETTE.get(&"BAKER", [])
	assert_eq(slots.size(), 3)
	assert_true(slots.has(&"NOUN_BREAD"))
	assert_true(slots.has(&"VERB_GIVE"))
	assert_true(slots.has(&"ADJ_WARM"))

# Baker has all 4 line groups
func test_baker_content_has_all_line_groups() -> void:
	# Act
	var content: Dictionary = LVVignetteContent.get_content(&"BAKER")
	# Assert
	assert_true(content.has(&"intro_tokens"))
	assert_true(content.has(&"action_tokens"))
	assert_true(content.has(&"closing_tokens"))
	assert_true(content.has(&"idle_tokens"))
	assert_true(content.has(&"world_position"))

# Per #10 EC-11: ≥2 on-screen instances of at least one decoded word
func test_baker_dialogue_contains_noun_bread_in_multiple_lines() -> void:
	# Act: count NOUN_BREAD occurrences across all baker lines
	var content: Dictionary = LVVignetteContent.get_content(&"BAKER")
	var noun_bread_count: int = 0
	for line in content.intro_tokens + content.action_tokens + content.closing_tokens:
		for token in line:
			if token.get("value", null) == &"NOUN_BREAD":
				noun_bread_count += 1
	# Assert: at least 2 instances (per #10 EC-11 cascade-spread requirement)
	assert_gte(noun_bread_count, 2, "Baker dialogue must contain ≥2 NOUN_BREAD instances for cascade spread")

# Baker world position is inside village viewport (320×180)
func test_baker_world_position_in_viewport() -> void:
	# Act
	var pos: Vector2 = LVVignetteContent.BAKER_WORLD_POSITION
	# Assert
	assert_between(pos.x, 0.0, 320.0)
	assert_between(pos.y, 0.0, 180.0)

# Correct table has entries for all baker slots
func test_correct_table_covers_baker_slots() -> void:
	# Act
	var slots: Array = LVVignetteContent.SLOTS_IN_VIGNETTE[&"BAKER"]
	# Assert
	for slot_id in slots:
		assert_true(LVVignetteContent.CORRECT_TABLE.has(slot_id), "Missing correct table entry for %s" % slot_id)

# Seed glyphs distinct (bijection per #19 OQ + design)
func test_seed_glyphs_for_baker_distinct() -> void:
	# Act
	var glyphs := [
		LVVignetteContent.SEED_GLYPHS[&"NOUN_BREAD"],
		LVVignetteContent.SEED_GLYPHS[&"VERB_GIVE"],
		LVVignetteContent.SEED_GLYPHS[&"ADJ_WARM"],
	]
	# Assert: all distinct
	assert_ne(glyphs[0], glyphs[1])
	assert_ne(glyphs[1], glyphs[2])
	assert_ne(glyphs[0], glyphs[2])

# Render unresolved slot returns glyph form
func test_render_unresolved_slot_returns_glyph() -> void:
	# Act
	var rendered: String = LVVignetteContent.render_slot_text(&"NOUN_BREAD", false)
	# Assert
	assert_eq(rendered, "mura")

# Render resolved slot returns decoded form
func test_render_resolved_slot_returns_decoded() -> void:
	# Act
	var rendered: String = LVVignetteContent.render_slot_text(&"NOUN_BREAD", true)
	# Assert
	assert_eq(rendered, "麵包")

# Render tokens: full baker intro unresolved
func test_render_baker_intro_unresolved() -> void:
	# Arrange
	var content: Dictionary = LVVignetteContent.get_content(&"BAKER")
	var intro_line: Array = content.intro_tokens[0]
	# Act
	var rendered: String = LVVignetteContent.render_tokens(intro_line, [])
	# Assert: "mura." (no space before period)
	assert_eq(rendered, "mura.")

# Render tokens: full baker intro resolved
func test_render_baker_intro_resolved() -> void:
	# Arrange
	var content: Dictionary = LVVignetteContent.get_content(&"BAKER")
	var intro_line: Array = content.intro_tokens[0]
	# Act
	var rendered: String = LVVignetteContent.render_tokens(intro_line, [&"NOUN_BREAD"])
	# Assert
	assert_eq(rendered, "麵包.")

# Render action line 1: mixed unresolved
func test_render_baker_action_line_with_partial_resolve() -> void:
	# Arrange: VERB_GIVE resolved, NOUN_BREAD not
	var content: Dictionary = LVVignetteContent.get_content(&"BAKER")
	var action_line: Array = content.action_tokens[0]  # "tola mura."
	# Act
	var rendered: String = LVVignetteContent.render_tokens(action_line, [&"VERB_GIVE"])
	# Assert
	assert_eq(rendered, "給 mura.")

# Closing line includes question particle
func test_render_baker_closing_unresolved_includes_ka() -> void:
	# Arrange
	var content: Dictionary = LVVignetteContent.get_content(&"BAKER")
	var closing: Array = content.closing_tokens[0]
	# Act
	var rendered: String = LVVignetteContent.render_tokens(closing, [])
	# Assert
	assert_eq(rendered, "tola mura ka?")

# Unknown vignette returns empty dict
func test_unknown_vignette_returns_empty() -> void:
	# Act
	var content: Dictionary = LVVignetteContent.get_content(&"UNKNOWN_NPC")
	# Assert
	assert_true(content.is_empty())

# ─── Smith vignette ───────────────────────────────────────────────────────────

func test_smith_content_has_three_slots() -> void:
	var slots: Array = LVVignetteContent.SLOTS_IN_VIGNETTE.get(&"SMITH", [])
	assert_eq(slots.size(), 3)
	assert_true(slots.has(&"NOUN_IRON"))
	assert_true(slots.has(&"NOUN_HAMMER"))
	assert_true(slots.has(&"VERB_MAKE"))

func test_smith_content_has_all_line_groups() -> void:
	var content: Dictionary = LVVignetteContent.get_content(&"SMITH")
	assert_true(content.has(&"intro_tokens"))
	assert_true(content.has(&"action_tokens"))
	assert_true(content.has(&"closing_tokens"))
	assert_true(content.has(&"idle_tokens"))
	assert_true(content.has(&"world_position"))

func test_smith_world_position_in_viewport() -> void:
	var pos: Vector2 = LVVignetteContent.SMITH_WORLD_POSITION
	assert_between(pos.x, 0.0, 320.0)
	assert_between(pos.y, 0.0, 180.0)

func test_render_smith_intro_unresolved() -> void:
	var content: Dictionary = LVVignetteContent.get_content(&"SMITH")
	var rendered: String = LVVignetteContent.render_tokens(content.intro_tokens[0], [])
	# Expected: "krun." (iron.)
	assert_eq(rendered, "krun.")

func test_render_smith_action_line_resolved() -> void:
	var content: Dictionary = LVVignetteContent.get_content(&"SMITH")
	# Line 0: "dakka pora." → "鎚 做."
	var rendered: String = LVVignetteContent.render_tokens(
		content.action_tokens[0], [&"NOUN_HAMMER", &"VERB_MAKE"])
	assert_eq(rendered, "鎚 做.")

# ─── Fisher vignette ──────────────────────────────────────────────────────────

func test_fisher_content_has_three_slots() -> void:
	var slots: Array = LVVignetteContent.SLOTS_IN_VIGNETTE.get(&"FISHER", [])
	assert_eq(slots.size(), 3)
	assert_true(slots.has(&"NOUN_WATER"))
	assert_true(slots.has(&"NOUN_FISH"))
	assert_true(slots.has(&"VERB_COME"))

func test_fisher_content_has_all_line_groups() -> void:
	var content: Dictionary = LVVignetteContent.get_content(&"FISHER")
	assert_true(content.has(&"intro_tokens"))
	assert_true(content.has(&"action_tokens"))
	assert_true(content.has(&"closing_tokens"))
	assert_true(content.has(&"idle_tokens"))
	assert_true(content.has(&"world_position"))

func test_fisher_world_position_in_viewport() -> void:
	var pos: Vector2 = LVVignetteContent.FISHER_WORLD_POSITION
	assert_between(pos.x, 0.0, 320.0)
	assert_between(pos.y, 0.0, 180.0)

func test_render_fisher_intro_unresolved() -> void:
	var content: Dictionary = LVVignetteContent.get_content(&"FISHER")
	var rendered: String = LVVignetteContent.render_tokens(content.intro_tokens[0], [])
	# Expected: "sela." (water.)
	assert_eq(rendered, "sela.")

func test_render_fisher_action_line_2_resolved() -> void:
	var content: Dictionary = LVVignetteContent.get_content(&"FISHER")
	# Line 1: "mira nai sela." (all 3 slots) → "魚 來 水."
	var rendered: String = LVVignetteContent.render_tokens(
		content.action_tokens[1], [&"NOUN_FISH", &"VERB_COME", &"NOUN_WATER"])
	assert_eq(rendered, "魚 來 水.")

# All three NPCs have distinct world positions
func test_npc_world_positions_distinct() -> void:
	var p_baker: Vector2 = LVVignetteContent.BAKER_WORLD_POSITION
	var p_smith: Vector2 = LVVignetteContent.SMITH_WORLD_POSITION
	var p_fisher: Vector2 = LVVignetteContent.FISHER_WORLD_POSITION
	assert_ne(p_baker, p_smith)
	assert_ne(p_smith, p_fisher)
	assert_ne(p_baker, p_fisher)
	# Spread across viewport (smith leftmost, baker middle, fisher rightmost)
	assert_lt(p_smith.x, p_baker.x)
	assert_lt(p_baker.x, p_fisher.x)

# ─── Weaver / Child / Traveler / Storyteller (added VS-1.5) ────────────────────

func test_weaver_content() -> void:
	var content: Dictionary = LVVignetteContent.get_content(&"WEAVER")
	assert_true(content.has(&"world_position"))
	# Intro: "kove."
	assert_eq(LVVignetteContent.render_tokens(content.intro_tokens[0], []), "kove.")
	# Action 0: "talo lim." → "布 長."
	assert_eq(LVVignetteContent.render_tokens(
		content.action_tokens[0], [&"NOUN_CLOTH", &"ADJ_LONG"]), "布 長.")

func test_child_content() -> void:
	var content: Dictionary = LVVignetteContent.get_content(&"CHILD")
	assert_true(content.has(&"world_position"))
	# Intro: "vu."
	assert_eq(LVVignetteContent.render_tokens(content.intro_tokens[0], []), "vu.")
	# Action 0: "ela." → "跑."
	assert_eq(LVVignetteContent.render_tokens(
		content.action_tokens[0], [&"VERB_PLAY"]), "跑.")

func test_traveler_content() -> void:
	var content: Dictionary = LVVignetteContent.get_content(&"TRAVELER")
	assert_true(content.has(&"world_position"))
	# Intro: "gel."
	assert_eq(LVVignetteContent.render_tokens(content.intro_tokens[0], []), "gel.")
	# Action 0: "solar naima." → "路 遠."
	assert_eq(LVVignetteContent.render_tokens(
		content.action_tokens[0], [&"NOUN_PATH", &"ADJ_FAR"]), "路 遠.")

func test_storyteller_content() -> void:
	var content: Dictionary = LVVignetteContent.get_content(&"STORYTELLER")
	assert_true(content.has(&"world_position"))
	# Intro: "sun."
	assert_eq(LVVignetteContent.render_tokens(content.intro_tokens[0], []), "sun.")
	# Closing: "taro sun ka?" — echoes elder's question
	assert_eq(LVVignetteContent.render_tokens(content.closing_tokens[0], []), "taro sun ka?")

# All 7 vignettes in SLOTS_IN_VIGNETTE
func test_seven_vignettes_registered() -> void:
	for npc in [&"BAKER", &"SMITH", &"FISHER", &"WEAVER", &"CHILD", &"TRAVELER", &"STORYTELLER"]:
		assert_true(LVVignetteContent.SLOTS_IN_VIGNETTE.has(npc),
			"Missing vignette: %s" % npc)

# All 7 NPC world positions inside viewport
func test_all_npc_world_positions_in_viewport() -> void:
	var positions: Array = [
		LVVignetteContent.BAKER_WORLD_POSITION,
		LVVignetteContent.SMITH_WORLD_POSITION,
		LVVignetteContent.FISHER_WORLD_POSITION,
		LVVignetteContent.WEAVER_WORLD_POSITION,
		LVVignetteContent.CHILD_WORLD_POSITION,
		LVVignetteContent.TRAVELER_WORLD_POSITION,
		LVVignetteContent.STORYTELLER_WORLD_POSITION,
	]
	for p in positions:
		assert_between(p.x, 0.0, 320.0)
		assert_between(p.y, 0.0, 180.0)

# CORRECT_TABLE covers all registered slots (no orphan slot)
func test_correct_table_covers_all_slots() -> void:
	for vig_id in LVVignetteContent.SLOTS_IN_VIGNETTE.keys():
		var slots: Array = LVVignetteContent.SLOTS_IN_VIGNETTE[vig_id]
		for slot_id in slots:
			assert_true(LVVignetteContent.CORRECT_TABLE.has(slot_id),
				"CORRECT_TABLE missing %s (in vignette %s)" % [slot_id, vig_id])
