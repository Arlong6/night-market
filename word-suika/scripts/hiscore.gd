## WSHiScore — persistent best-score for 一字一句 (Word Suika).
##
## The cheapest, highest-leverage retention hook for a score-chase game: a
## number the player owns and relaunches to beat. Without it, every run's score
## evaporates on restart and there is no reason to play again.
##
## Stored in user://word_suika.cfg (survives across sessions; on Web this maps
## to IndexedDB-backed persistent storage).
class_name WSHiScore
extends RefCounted

const SAVE_PATH: String = "user://word_suika.cfg"
const SECTION: String = "scores"

## Load the saved best score (0 if none yet).
static func load_best() -> int:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return 0
	return int(cfg.get_value(SECTION, "best", 0))

## Load the highest tier ever reached (0-indexed; 0 if none yet).
static func load_best_tier() -> int:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return 0
	return int(cfg.get_value(SECTION, "best_tier", 0))

## Commit a finished run. Returns true if it set a NEW best score (for the
## "NEW BEST!" celebration). Always folds best_tier upward too.
static func submit(score: int, tier_reached: int) -> bool:
	var cfg := ConfigFile.new()
	cfg.load(SAVE_PATH)  # ignore failure — fresh file is fine
	var prev_best: int = int(cfg.get_value(SECTION, "best", 0))
	var prev_tier: int = int(cfg.get_value(SECTION, "best_tier", 0))
	var is_new_best: bool = score > prev_best
	if is_new_best:
		cfg.set_value(SECTION, "best", score)
	if tier_reached > prev_tier:
		cfg.set_value(SECTION, "best_tier", tier_reached)
	cfg.save(SAVE_PATH)
	return is_new_best
