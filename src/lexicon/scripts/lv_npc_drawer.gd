## LVNPCDrawer — child Node2D that draws the NPC silhouette via _draw().
## Body (rounded rect), head (circle), optional held item.
extends Node2D

var npc: Node = null  # set by parent LVNPC

const NPC_W: float = 16.0
const NPC_H: float = 28.0

func _draw() -> void:
	if npc == null:
		return
	var body_color: Color = npc.body_color
	var skin_color: Color = npc.skin_color
	# Drop shadow on ground (ellipse)
	draw_circle(Vector2(0, NPC_H * 0.5 + 1), 7.0, Color(0.1, 0.07, 0.04, 0.35))
	# Body (rounded rect torso)
	var body_top: float = -NPC_H * 0.5 + 10.0
	var body_rect := Rect2(-NPC_W * 0.4, body_top, NPC_W * 0.8, NPC_H * 0.5)
	draw_rect(body_rect, body_color, true)
	# Legs (two small rects below body)
	var leg_y: float = body_top + NPC_H * 0.5
	draw_rect(Rect2(-4, leg_y, 3, 6), Color(0.3, 0.2, 0.12, 1.0), true)
	draw_rect(Rect2(1, leg_y, 3, 6), Color(0.3, 0.2, 0.12, 1.0), true)
	# Head (circle on top of body)
	var head_center := Vector2(0, body_top - 4)
	draw_circle(head_center, 5.0, skin_color)
	# Hair / hat (top arc of head)
	draw_arc(head_center, 5.0, PI, 2 * PI, 12, Color(0.25, 0.15, 0.08, 1.0), 2.0, true)
	# Eyes (two tiny dots)
	draw_circle(head_center + Vector2(-1.5, 0), 0.8, Color(0.1, 0.05, 0.0, 1.0))
	draw_circle(head_center + Vector2(1.5, 0), 0.8, Color(0.1, 0.05, 0.0, 1.0))
	# Held item (during tableau)
	if npc.is_item_visible() and npc.held_item_text != "":
		# A small rectangle in front of body suggesting the item
		var item_pos := Vector2(8, body_top + 4)
		draw_rect(Rect2(item_pos - Vector2(4, 3), Vector2(8, 6)),
			Color(0.95, 0.78, 0.45, 1.0), true)
		draw_rect(Rect2(item_pos - Vector2(4, 3), Vector2(8, 6)),
			Color(0.4, 0.25, 0.1, 1.0), false, 1.0)
