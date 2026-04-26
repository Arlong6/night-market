## Chatter / world-flavour NPC for Night Market Shopping (v0.2 content pass).
##
## Doesn't sell anything. On bump, picks one or more lines from `chatter_pool`
## (or all `lines` if pool is empty) and shows them. Adds variety + atmosphere
## without affecting the buy loop.
class_name ChatterNPC
extends NPC

## Pool of one-shot lines to pick from on each bump. Set in level. If empty,
## falls back to the base `lines` array. Lets one NPC have rotating dialogue
## without writing a multi-line script.
@export var chatter_pool: Array[String] = []

## Override colour (passed at spawn). Default leaves it as the brown vendor
## colour so subclasses can colour by personality.
@export var body_color: Color = Color("#7A3A2A")


func _draw_color() -> Color:
	return body_color


func on_bumped() -> void:
	if chatter_pool.is_empty():
		Dialogue.show(lines)
		return
	# Pick one random line per bump for replay variety.
	var pick: String = chatter_pool[randi() % chatter_pool.size()]
	var picked: Array[String] = [pick]
	Dialogue.show(picked)
