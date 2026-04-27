## Mum (媽媽) NPC for Night Market Shopping (R-008).
##
## Stands at the home tile. Bumping her checks Inventory.has_all_required():
##   * If true → show "謝謝你！加菜囉～" then transition to the win scene.
##   * If false → show "回來啦？還差 N 樣，再去看看吧。"; no scene change.
class_name MomNPC
extends NPC

const COLOR_MOM: Color = Color("#9A4A8A")  ## purple — distinct from vendor brown / kid yellow

## Time thresholds (seconds) for the success-line tier.
const FAST_THRESHOLD: float = 90.0
const SLOW_THRESHOLD: float = 240.0


func _draw_color() -> Color:
	return COLOR_MOM


func on_bumped() -> void:
	if Inventory.has_all_required():
		var lines: Array[String] = _success_lines_for_time(Game.session_time)
		# Persist best time BEFORE the level transition so end_screen can read
		# the freshly-updated record (and detect "new record" via Game.last_run_was_record).
		Game.last_run_was_record = HiScore.try_record(Game.session_time)
		Sfx.play_win()
		var on_done: Callable = func() -> void: Game.goto_level("end_win")
		Dialogue.show(lines, on_done)
	else:
		var missing: int = Inventory.REQUIRED_INGREDIENTS.size() - Inventory.ingredient_count()
		var lines: Array[String] = [
			"回來啦？讓我看看…",
			"還差 %d 樣，再去看看吧。" % missing,
		]
		Dialogue.show(lines)


## Picks the closing line based on how long the player took. Faster = more
## praise; slower = light teasing.
func _success_lines_for_time(t: float) -> Array[String]:
	if t < FAST_THRESHOLD:
		return ["哇好快！厲害厲害！", "今晚加菜～"]
	elif t < SLOW_THRESHOLD:
		return ["謝謝你！", "今晚加菜囉～"]
	else:
		return ["怎麼這麼久才回來啊？", "餓死我了～加菜吧。"]
