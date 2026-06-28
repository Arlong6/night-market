## ScoreSystem — run score + destruction count + persistent bests.
class_name ScoreSystem
extends RefCounted

const SAVE_PATH: String = "user://road_rage.cfg"
const SECTION: String = "scores"

var score: int = 0
var destroyed: int = 0

func add(points: int, count: int = 1) -> void:
	score += points
	destroyed += count

func load_best() -> int:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK: return 0
	return int(cfg.get_value(SECTION, "best", 0))

func load_best_destroyed() -> int:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK: return 0
	return int(cfg.get_value(SECTION, "best_destroyed", 0))

func submit() -> bool:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)
	var prev: int = int(cfg.get_value(SECTION, "best", 0))
	var prev_d: int = int(cfg.get_value(SECTION, "best_destroyed", 0))
	var is_new: bool = score > prev
	if is_new: cfg.set_value(SECTION, "best", score)
	if destroyed > prev_d: cfg.set_value(SECTION, "best_destroyed", destroyed)
	cfg.save(SAVE_PATH)
	return is_new
