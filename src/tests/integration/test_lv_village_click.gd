## Integration test for Lexicon Village NPC click → dialogue flow.
## Simulates the full happy path end-to-end headlessly:
##   spawn village → click baker → verify dialogue shown
extends GutTest

const LVVillage = preload("res://lexicon/scripts/lv_village.gd")
const LVVignetteContent = preload("res://lexicon/data/lv_vignette_content.gd")

func before_each() -> void:
	# Init session as if started from Title.
	var ss = get_node_or_null("/root/LVSessionState")
	if ss:
		ss.init_session(0, LVVignetteContent.CORRECT_TABLE, LVVignetteContent.SLOTS_IN_VIGNETTE)

func after_each() -> void:
	var ss = get_node_or_null("/root/LVSessionState")
	if ss:
		ss.destroy_session()

func test_village_baker_click_triggers_dialogue() -> void:
	# Arrange — spawn village
	var village: LVVillage = LVVillage.new()
	add_child_autofree(village)
	await get_tree().process_frame
	# Find baker NPC
	var baker: Node = null
	for ch in village.get_children():
		if ch.has_method("get_state_machine"):
			if ch.npc_id == &"BAKER":
				baker = ch
				break
	assert_not_null(baker, "Baker NPC should exist in village")
	# Verify dialogue display is registered
	var dd = get_tree().get_first_node_in_group(&"lv_dialogue_display") if get_tree() else null
	assert_not_null(dd, "Dialogue display should be in group 'lv_dialogue_display'")
	# Verify session phase is PLAYING (0)
	var ss = get_node_or_null("/root/LVSessionState")
	assert_eq(ss.get_game_phase(), 0, "Session should be in PLAYING phase")
	# Verify Area2D + collider exist
	var click_area: Area2D = baker.get_node_or_null("ClickArea")
	assert_not_null(click_area, "Baker should have ClickArea Area2D")
	assert_true(click_area.input_pickable, "ClickArea should be input_pickable")
	# Verify state machine starts in DORMANT
	var sm = baker.get_state_machine()
	assert_not_null(sm)
	assert_eq(sm.get_state(), 0, "State machine should start DORMANT (0)")  # 0 = DORMANT enum
	# Act — programmatically fire the click handler (bypasses Area2D physics picking)
	sm.on_npc_clicked()
	await get_tree().process_frame
	# Assert state machine transitioned to INTRO (1)
	assert_eq(sm.get_state(), 1, "State machine should be in INTRO after click")
	# Assert dialogue display is showing
	assert_eq(dd.get_state(), dd.DialogueState.SHOWING,
		"Dialogue display should be SHOWING after NPC click")
	# Assert tokens were shown (baker intro)
	var tokens = dd.get_current_tokens()
	assert_false(tokens.is_empty(), "Tokens should be non-empty")

func test_village_click_via_area2d_input_event() -> void:
	# This test verifies that simulating a mouse click on the Area2D itself
	# triggers the dialogue. Tests the input_event signal path.
	var village: LVVillage = LVVillage.new()
	add_child_autofree(village)
	await get_tree().process_frame
	# Find baker
	var baker: Node = null
	for ch in village.get_children():
		if ch.has_method("get_state_machine") and ch.npc_id == &"BAKER":
			baker = ch
			break
	assert_not_null(baker)
	var click_area: Area2D = baker.get_node_or_null("ClickArea")
	# Simulate Area2D input_event by emitting the signal directly
	var fake_event := InputEventMouseButton.new()
	fake_event.button_index = MOUSE_BUTTON_LEFT
	fake_event.pressed = true
	click_area.input_event.emit(get_viewport(), fake_event, 0)
	await get_tree().process_frame
	# Assert dialogue is showing
	var dd = get_tree().get_first_node_in_group(&"lv_dialogue_display")
	assert_eq(dd.get_state(), dd.DialogueState.SHOWING,
		"Dialogue should show after simulated Area2D click event")

func test_dialogue_display_in_group_after_village_ready() -> void:
	# Bare-minimum: dialogue display should be findable by group after village _ready.
	var village: LVVillage = LVVillage.new()
	add_child_autofree(village)
	await get_tree().process_frame
	var dd = get_tree().get_first_node_in_group(&"lv_dialogue_display")
	assert_not_null(dd, "Dialogue display missing from group")
