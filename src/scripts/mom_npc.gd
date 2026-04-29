## Mum (媽媽) NPC for Night Market Shopping (R-008).
##
## Stands at the home tile. Bumping her checks Inventory.has_all_required():
##   * If true → show "謝謝你！加菜囉～" then transition to the win scene.
##   * If false → show "回來啦？還差 N 樣，再去看看吧。"; no scene change.
class_name MomNPC
extends NPC

const COLOR_MOM: Color = Color("#9A4A8A")  ## purple shirt — distinct from vendor brown / kid yellow
const COLOR_APRON: Color = Color("#F5EDDA")  ## cream apron over the shirt
const COLOR_MOM_HAIR: Color = Color("#3A1A0A")  ## tied-back dark brown hair

## Time thresholds (seconds) for the success-line tier.
const FAST_THRESHOLD: float = 90.0
const SLOW_THRESHOLD: float = 240.0


func _draw_color() -> Color:
	return COLOR_MOM


func _draw() -> void:
	var bob: float = _idle_bob_offset()
	_draw_person(COLOR_MOM, bob)
	# Apron stripe — 6×2 cream band over the torso, makes mum legible at a glance
	draw_rect(Rect2(-3.0, 1.0 + bob, 6.0, 3.0), COLOR_APRON)
	# Hair bun — small 4×2 dark cap on top of the standard hair stripe
	draw_rect(Rect2(-2.0, -8.0 + bob, 4.0, 2.0), COLOR_MOM_HAIR)


func on_bumped() -> void:
	if Inventory.has_all_required():
		var perfect: bool = Inventory.has_all()
		Game.last_run_perfect = perfect
		var lines: Array[String]
		if perfect:
			lines = _perfect_success_lines()
		else:
			lines = _success_lines_for_time(Game.session_time)
		# Record the run (best time + counters), then set last_run_was_record
		# so end_screen can show the new-record badge.
		var bargained: bool = Game.bargain_count > 0
		var result: Dictionary = HiScore.record_run(
			Game.session_time, perfect, bargained
		)
		Game.last_run_was_record = bool(result.get("new_record", false))
		Sfx.play_win()
		var on_done: Callable = func() -> void: Game.goto_level("kitchen")
		Dialogue.show(lines, on_done)
	else:
		# v0.14: kid bumps mum without all required ingredients — sympathetic
		# "湊合著煮吧" route. Still cooks (so the player gets a payoff) but
		# the run is flagged incomplete and HiScore is NOT touched.
		Game.last_run_incomplete = true
		Game.last_run_perfect = false
		Game.last_run_was_record = false
		var on_done: Callable = func() -> void: Game.goto_level("kitchen")
		Dialogue.show(_incomplete_lines(), on_done)


## v0.14: lines used when kid comes home without the full required-list.
## Lightly disappointed but caring — mum still cooks with what she has.
func _incomplete_lines() -> Array[String]:
	return [
		"嗯…就這幾樣啊？",
		"沒關係，湊合著煮吧～",
	]


## Picks the closing line based on how long the player took. Faster = more
## praise; slower = light teasing.
func _success_lines_for_time(t: float) -> Array[String]:
	if t < FAST_THRESHOLD:
		return ["哇好快！厲害厲害！", "今晚加菜～"]
	elif t < SLOW_THRESHOLD:
		return ["謝謝你！", "今晚加菜囉～"]
	else:
		return ["怎麼這麼久才回來啊？", "餓死我了～加菜吧。"]


## v0.12: lines used when the player bought all 7 ingredients — the perfect
## "滿漢全席" branch.
func _perfect_success_lines() -> Array[String]:
	return [
		"我的天～你全部都買回來了！",
		"今晚吃滿漢全席囉！",
	]
