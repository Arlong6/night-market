## CityGen — deterministic district layout from a seed (橫衝直撞).
## Roads run every 4th row/column (a drivable street grid); the 3×3 blocks
## between them get buildings (impassable) and smashable props.
class_name CityGen
extends RefCounted

func generate(seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var buildings: Array[Vector2i] = []
	var props: Array[Dictionary] = []
	for y in RRTuning.CITY_ROWS:
		for x in RRTuning.CITY_COLS:
			# Every 4th row/col is a road — keep it clear for driving.
			var is_road: bool = (x % 4 == 0) or (y % 4 == 0)
			if is_road:
				continue
			if rng.randf() < RRTuning.BUILDING_CHANCE:
				buildings.append(Vector2i(x, y))
			elif rng.randf() < RRTuning.PROP_CHANCE:
				var roll: float = rng.randf()
				var kind: String = "prop" if roll < 0.7 else ("car" if roll < 0.9 else "ped")
				props.append({"cell": Vector2i(x, y), "kind": kind})
	return {"buildings": buildings, "props": props}

## Is a given cell a road cell? Used to place the player on clear tarmac.
static func is_road(cell: Vector2i) -> bool:
	return (cell.x % 4 == 0) or (cell.y % 4 == 0)
