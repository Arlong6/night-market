## Mum (媽媽) NPC for Night Market Shopping (R-008).
##
## Stands at the home tile. Bumping her checks Inventory.has_all_required():
##   * If true → show "謝謝你！加菜囉～" then transition to the win scene.
##   * If false → show "回來啦？還差 N 樣，再去看看吧。"; no scene change.
class_name MomNPC
extends NPC

const COLOR_MOM: Color = Color("#9A4A8A")  ## purple — distinct from vendor brown / kid yellow

@export var success_lines: Array[String] = ["謝謝你！加菜囉～"]


func _draw_color() -> Color:
	return COLOR_MOM


func on_bumped() -> void:
	if Inventory.has_all_required():
		var on_done: Callable = func() -> void: Game.goto_level("end_win")
		Dialogue.show(success_lines, on_done)
	else:
		var missing: int = Inventory.REQUIRED_INGREDIENTS.size() - Inventory.ingredient_count()
		var lines: Array[String] = [
			"回來啦？讓我看看…",
			"還差 %d 樣，再去看看吧。" % missing,
		]
		Dialogue.show(lines)
