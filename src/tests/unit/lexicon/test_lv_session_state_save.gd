## Unit tests for LVSessionState save/restore (Phase C).
extends GutTest

const TEST_CORRECT_TABLE := {
	&"NOUN_BREAD": &"icon_bread",
	&"VERB_GIVE": &"icon_give",
	&"ADJ_WARM": &"icon_warm",
}

const TEST_SLOTS_IN_VIGNETTE := {
	&"BAKER": [&"NOUN_BREAD", &"VERB_GIVE", &"ADJ_WARM"],
}

func before_each() -> void:
	var ss = get_node_or_null("/root/LVSessionState")
	if ss:
		ss.destroy_session()

func after_each() -> void:
	var ss = get_node_or_null("/root/LVSessionState")
	if ss:
		ss.destroy_session()

# serialize produces a version-1 dict with expected keys
func test_serialize_has_expected_keys() -> void:
	var ss = get_node_or_null("/root/LVSessionState")
	ss.init_session(42, TEST_CORRECT_TABLE, TEST_SLOTS_IN_VIGNETTE)
	var d: Dictionary = ss.serialize()
	assert_eq(d.get("version"), 1)
	assert_eq(d.get("seed"), 42)
	assert_true(d.has("binding_map"))
	assert_true(d.has("confirmed_slots"))
	assert_true(d.has("vignette_cascaded"))
	assert_true(d.has("game_phase"))
	assert_true(d.has("elapsed_ms"))

# Round-trip: serialize → deserialize → state matches
func test_round_trip_preserves_seed_and_bindings() -> void:
	var ss = get_node_or_null("/root/LVSessionState")
	ss.init_session(42, TEST_CORRECT_TABLE, TEST_SLOTS_IN_VIGNETTE)
	ss.set_binding(&"NOUN_BREAD", &"icon_bread")  # correct binding → triggers slot confirm if full cascade
	ss.set_binding(&"VERB_GIVE", &"icon_give")
	var d: Dictionary = ss.serialize()
	ss.destroy_session()
	# Restore
	var ok: bool = ss.deserialize(d, TEST_CORRECT_TABLE, TEST_SLOTS_IN_VIGNETTE)
	assert_true(ok)
	assert_eq(ss.get_language_seed(), 42)
	assert_eq(ss.get_binding(&"NOUN_BREAD"), &"icon_bread")
	assert_eq(ss.get_binding(&"VERB_GIVE"), &"icon_give")

# Round-trip preserves vignette_cascaded
func test_round_trip_preserves_cascade_state() -> void:
	var ss = get_node_or_null("/root/LVSessionState")
	ss.init_session(42, TEST_CORRECT_TABLE, TEST_SLOTS_IN_VIGNETTE)
	# Cascade BAKER by setting all 3 bindings correctly
	ss.set_binding(&"NOUN_BREAD", &"icon_bread")
	ss.set_binding(&"VERB_GIVE", &"icon_give")
	ss.set_binding(&"ADJ_WARM", &"icon_warm")
	assert_true(ss.is_vignette_cascaded(&"BAKER"))
	# Save + restore
	var d: Dictionary = ss.serialize()
	ss.destroy_session()
	ss.deserialize(d, TEST_CORRECT_TABLE, TEST_SLOTS_IN_VIGNETTE)
	# Assert cascade survived
	assert_true(ss.is_vignette_cascaded(&"BAKER"))
	assert_true(ss.is_confirmed(&"NOUN_BREAD"))

# JSON round-trip
func test_json_round_trip() -> void:
	var ss = get_node_or_null("/root/LVSessionState")
	ss.init_session(42, TEST_CORRECT_TABLE, TEST_SLOTS_IN_VIGNETTE)
	ss.set_binding(&"NOUN_BREAD", &"icon_bread")
	var json_str: String = ss.to_save_json()
	assert_true(json_str.length() > 0)
	ss.destroy_session()
	var ok: bool = ss.from_save_json(json_str, TEST_CORRECT_TABLE, TEST_SLOTS_IN_VIGNETTE)
	assert_true(ok)
	assert_eq(ss.get_language_seed(), 42)
	assert_eq(ss.get_binding(&"NOUN_BREAD"), &"icon_bread")

# Deserialize bad JSON → false
func test_from_bad_json_returns_false() -> void:
	var ss = get_node_or_null("/root/LVSessionState")
	var ok: bool = ss.from_save_json("not valid json", TEST_CORRECT_TABLE, TEST_SLOTS_IN_VIGNETTE)
	# Godot's JSON.parse_string pushes an engine error on parse failure;
	# expected here, mark as handled.
	for err in gut.error_tracker.get_current_test_errors():
		err.handled = true
	assert_false(ok)

# Wrong version → false
func test_deserialize_wrong_version_returns_false() -> void:
	var ss = get_node_or_null("/root/LVSessionState")
	var bogus: Dictionary = {"version": 999, "seed": 42}
	var ok: bool = ss.deserialize(bogus, TEST_CORRECT_TABLE, TEST_SLOTS_IN_VIGNETTE)
	assert_false(ok)

# Missing seed → false
func test_deserialize_missing_seed_returns_false() -> void:
	var ss = get_node_or_null("/root/LVSessionState")
	var bogus: Dictionary = {"version": 1}
	var ok: bool = ss.deserialize(bogus, TEST_CORRECT_TABLE, TEST_SLOTS_IN_VIGNETTE)
	assert_false(ok)

# Runtime glyphs survive round-trip (same seed → same procgen output)
func test_runtime_glyphs_survive_round_trip() -> void:
	var ss = get_node_or_null("/root/LVSessionState")
	ss.init_session(42, TEST_CORRECT_TABLE, TEST_SLOTS_IN_VIGNETTE)
	var glyphs_before: Dictionary = ss.get_runtime_glyphs()
	var d: Dictionary = ss.serialize()
	ss.destroy_session()
	ss.deserialize(d, TEST_CORRECT_TABLE, TEST_SLOTS_IN_VIGNETTE)
	var glyphs_after: Dictionary = ss.get_runtime_glyphs()
	# Same seed → same procgen → same glyph dict
	for key in glyphs_before.keys():
		assert_eq(glyphs_after[key], glyphs_before[key])
