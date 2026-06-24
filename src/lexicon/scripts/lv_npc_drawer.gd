## LVNPCDrawer — child Node2D that draws the NPC silhouette via _draw().
## Body (rounded rect), head (circle), distinct held item per NPC type,
## subtle idle breathing animation, gold halo when cascaded.
extends Node2D

var npc: Node = null  # set by parent LVNPC

const NPC_W: float = 16.0
const NPC_H: float = 28.0

# Idle breathing offset (modulated by parent process)
var _breath_phase: float = 0.0

func _ready() -> void:
	# Randomize initial phase so NPCs don't all bob in sync
	_breath_phase = randf() * TAU
	set_process(true)

func _process(delta: float) -> void:
	_breath_phase += delta * 1.6
	queue_redraw()

func _draw() -> void:
	if npc == null:
		return
	var body_color: Color = npc.body_color
	var skin_color: Color = npc.skin_color
	var is_cascaded: bool = _is_npc_cascaded()
	# Gold halo for cascaded NPCs (you solved them)
	if is_cascaded:
		draw_circle(Vector2(0, -NPC_H * 0.1), 13.0, Color(1.0, 0.85, 0.4, 0.18))
		draw_circle(Vector2(0, -NPC_H * 0.1), 9.0, Color(1.0, 0.9, 0.55, 0.25))
	# Drop shadow on ground (squished ellipse)
	draw_circle(Vector2(0, NPC_H * 0.5 + 1), 7.0, Color(0.1, 0.07, 0.04, 0.35))
	# Idle breathing offset
	var breath: float = sin(_breath_phase) * 0.6
	# Body (rounded rect torso)
	var body_top: float = -NPC_H * 0.5 + 10.0 + breath
	var body_rect := Rect2(-NPC_W * 0.4, body_top, NPC_W * 0.8, NPC_H * 0.5)
	draw_rect(body_rect, body_color, true)
	# Body inner highlight (a thin line for shape definition)
	draw_line(Vector2(-NPC_W * 0.35, body_top + 2), Vector2(-NPC_W * 0.35, body_top + NPC_H * 0.45),
		body_color.lightened(0.18), 1.0)
	# Legs (two small rects below body)
	var leg_y: float = body_top + NPC_H * 0.5
	draw_rect(Rect2(-4, leg_y, 3, 6), Color(0.3, 0.2, 0.12, 1.0), true)
	draw_rect(Rect2(1, leg_y, 3, 6), Color(0.3, 0.2, 0.12, 1.0), true)
	# Head (circle on top of body) — head bobs slightly less than body
	var head_center := Vector2(0, body_top - 4)
	draw_circle(head_center, 5.0, skin_color)
	# Hair / hat (top arc of head)
	draw_arc(head_center, 5.0, PI, 2 * PI, 12, Color(0.25, 0.15, 0.08, 1.0), 2.0, true)
	# Eyes (two tiny dots)
	draw_circle(head_center + Vector2(-1.5, 0), 0.8, Color(0.1, 0.05, 0.0, 1.0))
	draw_circle(head_center + Vector2(1.5, 0), 0.8, Color(0.1, 0.05, 0.0, 1.0))
	# Smile for cascaded NPCs
	if is_cascaded:
		draw_arc(head_center + Vector2(0, 2), 1.5, 0.2, PI - 0.2, 6,
			Color(0.5, 0.25, 0.1, 1.0), 0.8, true)
	# Held item — per-NPC distinctive shape + color
	if npc.is_item_visible() and npc.held_item_text != "":
		_draw_held_item(body_top)

func _draw_held_item(body_top: float) -> void:
	var item_pos := Vector2(10, body_top + 2)
	# Pick item visual by NPC id
	match npc.npc_id:
		&"BAKER":  # 麵包 — rounded loaf
			draw_circle(item_pos, 5.0, Color(0.93, 0.74, 0.42, 1.0))
			draw_arc(item_pos, 5.0, 0, TAU, 16, Color(0.42, 0.25, 0.08, 1.0), 1.0, true)
			draw_line(item_pos + Vector2(-2.5, 0), item_pos + Vector2(2.5, 0),
				Color(0.6, 0.4, 0.18, 1.0), 0.8)
		&"SMITH", &"BLACKSMITH":  # 鐵/鎚 — hammer (handle + head)
			draw_rect(Rect2(item_pos + Vector2(-0.5, -5), Vector2(1.5, 9)),
				Color(0.45, 0.3, 0.15, 1.0), true)  # handle
			draw_rect(Rect2(item_pos + Vector2(-3, -6), Vector2(7, 3)),
				Color(0.35, 0.35, 0.4, 1.0), true)  # head
		&"FISHER":  # 魚 — fish silhouette
			draw_circle(item_pos + Vector2(-1, 0), 3.5, Color(0.55, 0.7, 0.85, 1.0))
			draw_colored_polygon([
				item_pos + Vector2(2, 0),
				item_pos + Vector2(5, -3),
				item_pos + Vector2(5, 3),
			], Color(0.55, 0.7, 0.85, 1.0))
			draw_circle(item_pos + Vector2(-2.5, -1), 0.6, Color(0.1, 0.05, 0.0, 1.0))
		&"WEAVER":  # 布 — cloth bundle
			draw_rect(Rect2(item_pos + Vector2(-4, -3), Vector2(8, 7)),
				Color(0.85, 0.55, 0.65, 1.0), true)
			draw_line(item_pos + Vector2(-3, -2), item_pos + Vector2(3, -2),
				Color(0.55, 0.3, 0.4, 0.8), 0.6)
			draw_line(item_pos + Vector2(-3, 0), item_pos + Vector2(3, 0),
				Color(0.55, 0.3, 0.4, 0.8), 0.6)
			draw_line(item_pos + Vector2(-3, 2), item_pos + Vector2(3, 2),
				Color(0.55, 0.3, 0.4, 0.8), 0.6)
		&"CHILD":  # 朋友 — little ball / toy
			draw_circle(item_pos, 3.5, Color(0.95, 0.55, 0.3, 1.0))
			draw_arc(item_pos, 3.5, 0, TAU, 12, Color(0.5, 0.2, 0.1, 1.0), 0.8, true)
		&"TRAVELER":  # 杖 — walking stick
			draw_line(item_pos + Vector2(0, -5), item_pos + Vector2(2, 6),
				Color(0.45, 0.3, 0.15, 1.0), 2.0)
			draw_circle(item_pos + Vector2(0, -5), 1.5, Color(0.6, 0.4, 0.2, 1.0))
		&"STORYTELLER":  # 書 — open book
			draw_rect(Rect2(item_pos + Vector2(-5, -3), Vector2(10, 7)),
				Color(0.85, 0.78, 0.65, 1.0), true)
			draw_line(item_pos + Vector2(0, -3), item_pos + Vector2(0, 4),
				Color(0.5, 0.35, 0.2, 0.9), 0.6)
			# horizontal text lines
			draw_line(item_pos + Vector2(-3.5, -1), item_pos + Vector2(-1, -1),
				Color(0.4, 0.25, 0.12, 0.7), 0.4)
			draw_line(item_pos + Vector2(1, -1), item_pos + Vector2(3.5, -1),
				Color(0.4, 0.25, 0.12, 0.7), 0.4)
			draw_line(item_pos + Vector2(-3.5, 1), item_pos + Vector2(-1, 1),
				Color(0.4, 0.25, 0.12, 0.7), 0.4)
			draw_line(item_pos + Vector2(1, 1), item_pos + Vector2(3.5, 1),
				Color(0.4, 0.25, 0.12, 0.7), 0.4)
		_:  # Generic small parcel
			var item_size := Vector2(10, 8)
			draw_rect(Rect2(item_pos - item_size * 0.5, item_size),
				Color(0.85, 0.7, 0.45, 1.0), true)
			draw_rect(Rect2(item_pos - item_size * 0.5, item_size),
				Color(0.4, 0.25, 0.1, 1.0), false, 1.0)

func _is_npc_cascaded() -> bool:
	var ss = get_node_or_null("/root/LVSessionState")
	if ss == null or npc == null:
		return false
	return ss.is_vignette_cascaded(npc.npc_id)
