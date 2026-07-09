## FPMinimap — a small top-corner radar: player centred, police + foot cops as
## dots, so you can orient in the big city and see threats.
class_name FPMinimap
extends Control

const SIZE: float = 150.0
const WORLD_SCALE: float = 0.16   ## world units -> minimap pixels

var game = null   # FPMain (provides _player_pos(), _police, _footcops)

func _ready() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)
	size = Vector2(SIZE, SIZE)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(0.0, 0.0, SIZE, SIZE), Color(0.06, 0.07, 0.1, 0.55))
	draw_rect(Rect2(0.0, 0.0, SIZE, SIZE), Color(1.0, 1.0, 1.0, 0.25), false, 2.0)
	if game == null:
		return
	var c := Vector2(SIZE * 0.5, SIZE * 0.5)
	var pp: Vector3 = game._player_pos()
	# Player at centre.
	draw_circle(c, 4.0, Color("#4ADE6A"))
	_draw_blips(c, pp, game._police, Color("#4A78FF"))
	_draw_blips(c, pp, game._footcops, Color("#FF5454"))
	_draw_blips(c, pp, game.get_tree().get_nodes_in_group("pickup"), Color("#3ADE5A"))
	if is_instance_valid(game._heli):
		var hr: Vector3 = game._heli.global_position - pp
		var hp: Vector2 = c + Vector2(hr.x, hr.z) * WORLD_SCALE
		if Rect2(2.0, 2.0, SIZE - 4.0, SIZE - 4.0).has_point(hp):
			draw_circle(hp, 4.5, Color("#FFD23A"))

func _draw_blips(c: Vector2, pp: Vector3, arr: Array, col: Color) -> void:
	var bounds := Rect2(2.0, 2.0, SIZE - 4.0, SIZE - 4.0)
	for n in arr:
		if is_instance_valid(n):
			var rel: Vector3 = n.global_position - pp
			var mp: Vector2 = c + Vector2(rel.x, rel.z) * WORLD_SCALE
			if bounds.has_point(mp):
				draw_circle(mp, 3.0, col)
