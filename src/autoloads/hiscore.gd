## Best-time + run statistics persistence for Night Market Shopping.
##
## v0.12 expanded from a single best-time field into a small stats record:
##   * best_time         — fastest completed run, sentinel INF if none
##   * total_wins        — every successful delivery
##   * perfect_runs      — runs that bought all 7 ingredients (滿漢全席)
##   * no_bargain_wins   — wins where 殺價 was never used
##   * muted             — global audio mute preference
##
## Persisted to user://best.cfg via ConfigFile. On Web export, user:// is
## backed by IndexedDB so values survive page reloads per browser-profile.
extends Node

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

const SAVE_PATH: String = "user://best.cfg"
const SECTION: String = "run"

const KEY_BEST: String = "best_time"
const KEY_TOTAL: String = "total_wins"
const KEY_PERFECT: String = "perfect_runs"
const KEY_NO_BARGAIN: String = "no_bargain_wins"
const KEY_MUTED: String = "muted"
const KEY_DAY: String = "day"
const KEY_VENDOR_PURCHASES: String = "vendor_purchases"
const KEY_DISHES_COOKED: String = "dishes_cooked"
const KEY_DREAM_BEST_KILLS: String = "dream_best_kills"
const KEY_DREAM_BOSS_CLEARS: String = "dream_boss_clears"
const KEY_PENDING_DREAM_BONUS: String = "pending_dream_bonus"

## v0.35: NT$ awarded the next time Inventory.reset() runs, after a dream
## boss-clear. One boss = one DREAM_BONUS_PER_CLEAR payout. Stacks if the
## player clears multiple dreams in a row without intervening shopping
## (e.g. weekend-Saturday-night clear then weekend-Sunday-night clear).
const DREAM_BONUS_PER_CLEAR: int = 100

## Sentinel for "no record yet" — easier than a separate Optional flag.
const NO_RECORD: float = INF

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

var best_time: float = NO_RECORD
var total_wins: int = 0
var perfect_runs: int = 0
var no_bargain_wins: int = 0
var muted: bool = false

## v0.19: current in-game day number (1-indexed). Advances by 1 on every
## successful run via record_run(). Incomplete / ESC'd runs keep the same
## day so the player gets to retry. Drives the daily-theme rotation in
## Inventory.current_theme().
var day: int = 1

## v0.20: how many times the player has bought from the vendor selling each
## ingredient. Drives the loyalty-tier greeting + discount in StallNPC.
## Persists via ConfigFile alongside the other counters.
var vendor_purchases: Dictionary[String, int] = {}

## v0.24: cookbook journal. Maps dish name → number of times cooked across
## all runs. A dish is "unlocked" iff dishes_cooked.has(name). Persisted.
var dishes_cooked: Dictionary[String, int] = {}

## v0.34: best dream-sequence kill count across all weekend nights. 0 if the
## player has never played a dream. Capped at the kill count, NOT the boss
## HP — boss-clear runs add to dream_boss_clears instead.
var dream_best_kills: int = 0

## v0.34: number of times the player has defeated 夜市大魔王. Increments on
## every boss-clear ending in the dream scene.
var dream_boss_clears: int = 0

## v0.35: NT$ queued for the next morning's market run, awarded by clearing
## 夜市大魔王 in a dream sequence. Consumed (and zeroed) by Inventory.reset().
## Persists so a player who quits between the dream and the next morning
## still gets their reward.
var pending_dream_bonus: int = 0

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	_load()


# ---------------------------------------------------------------------------
# Public API — best time
# ---------------------------------------------------------------------------

## Returns true iff a saved best time has been loaded.
func has_record() -> bool:
	return best_time != NO_RECORD and best_time > 0.0


## Attempts to record a new run's time only. Returns true iff this beat the
## existing record (and was persisted). Use `record_run()` for the full set
## of stats — this is kept for legacy callers.
func try_record(t: float) -> bool:
	if t <= 0.0:
		return false
	if not has_record() or t < best_time:
		best_time = t
		_save()
		return true
	return false


# ---------------------------------------------------------------------------
# Public API — full run record
# ---------------------------------------------------------------------------

## Records a completed run. Updates best_time + counters, then persists.
## Returns a small dictionary of "what was achieved this run":
##   {
##     "new_record": bool,         # beat the previous best_time
##     "first_perfect": bool,      # this was the FIRST perfect run ever
##     "first_no_bargain": bool,   # this was the FIRST no-bargain win ever
##   }
## Caller can use the dict to drive end-screen badges.
func record_run(elapsed: float, perfect: bool, bargained: bool) -> Dictionary:
	var was_record: bool = false
	if elapsed > 0.0 and (not has_record() or elapsed < best_time):
		best_time = elapsed
		was_record = true
	total_wins += 1
	var first_perfect: bool = false
	if perfect:
		first_perfect = perfect_runs == 0
		perfect_runs += 1
	var first_no_bargain: bool = false
	if not bargained:
		first_no_bargain = no_bargain_wins == 0
		no_bargain_wins += 1
	# v0.19: a successful run advances the calendar by one day so tomorrow's
	# theme is different. Incomplete runs go through _do_incomplete_flow and
	# never reach this function, so they leave `day` unchanged.
	day += 1
	_save()
	return {
		"new_record": was_record,
		"first_perfect": first_perfect,
		"first_no_bargain": first_no_bargain,
	}


# ---------------------------------------------------------------------------
# Public API — display helpers
# ---------------------------------------------------------------------------

## Returns "M:SS" for the saved best, or "—:—" if no record.
func format_best() -> String:
	if not has_record():
		return "—:——"
	var minutes: int = int(best_time) / 60
	var seconds: int = int(best_time) % 60
	return "%d:%02d" % [minutes, seconds]


## True iff the player has at least one win recorded — drives the "show
## stats panel" gate on the title screen.
func has_stats() -> bool:
	return total_wins > 0


# ---------------------------------------------------------------------------
# Public API — mute preference
# ---------------------------------------------------------------------------

## v0.20: increments the loyalty count for the named ingredient and saves.
## Called by StallNPC after a successful purchase.
func record_purchase(ingredient_id: String) -> void:
	var prev: int = vendor_purchases.get(ingredient_id, 0)
	vendor_purchases[ingredient_id] = prev + 1
	_save()


## v0.20: how many times the player has bought this ingredient across all
## runs. 0 if never. Used to derive the vendor-loyalty tier.
func purchase_count(ingredient_id: String) -> int:
	return vendor_purchases.get(ingredient_id, 0)


## v0.24: marks the named dish as cooked at least once and increments its
## count. Called by Kitchen after the dish lands on the plate.
func record_cooked_dish(dish_name: String) -> void:
	if dish_name.is_empty():
		return
	var prev: int = dishes_cooked.get(dish_name, 0)
	dishes_cooked[dish_name] = prev + 1
	_save()


## v0.24: how many times the player has cooked the named dish.
func cook_count(dish_name: String) -> int:
	return dishes_cooked.get(dish_name, 0)


## v0.24: how many distinct dishes the player has unlocked in the cookbook.
func unlocked_dish_count() -> int:
	return dishes_cooked.size()


## v0.34: records a finished dream sequence. `kills` is the total small-fry
## kill count and `boss_cleared` is true iff the player defeated the boss.
## Returns a small dictionary describing what was achieved this dream:
##   {
##     "new_kill_record": bool,    # beat dream_best_kills
##     "first_boss_clear": bool,   # first ever boss kill
##   }
## Caller (Dream._advance) drives any "new record" UI from the result.
func record_dream(kills: int, boss_cleared: bool) -> Dictionary:
	var new_kill_record: bool = kills > dream_best_kills
	if new_kill_record:
		dream_best_kills = kills
	var first_boss_clear: bool = false
	if boss_cleared:
		first_boss_clear = dream_boss_clears == 0
		dream_boss_clears += 1
		# v0.35: each boss clear queues a one-shot NT$ bonus for the next
		# market run. Stacking is intentional (consecutive weekend clears).
		pending_dream_bonus += DREAM_BONUS_PER_CLEAR
	_save()
	return {
		"new_kill_record": new_kill_record,
		"first_boss_clear": first_boss_clear,
	}


## v0.35: pulls and zeroes the pending dream bonus. Called by Inventory.reset()
## at the start of every market run so the bonus is awarded exactly once.
## Returns the amount that was queued (0 if none).
func claim_pending_dream_bonus() -> int:
	var amount: int = pending_dream_bonus
	if amount > 0:
		pending_dream_bonus = 0
		_save()
	return amount


## Toggles the global mute flag, persists, and pushes the change to Sfx + Music.
func toggle_mute() -> bool:
	muted = not muted
	_apply_mute()
	_save()
	return muted


## Applies current `muted` state to Sfx + Music autoloads. Called once at
## startup AND every time toggle_mute() flips the flag.
func _apply_mute() -> void:
	var sfx: Node = get_node_or_null("/root/Sfx")
	if sfx != null:
		sfx.muted = muted
	var music: Node = get_node_or_null("/root/Music")
	if music != null and music.has_method("set_muted"):
		music.set_muted(muted)


# ---------------------------------------------------------------------------
# Test helpers
# ---------------------------------------------------------------------------

## Wipes ALL state (record + counters + mute + day + loyalty + cookbook)
## and the on-disk file.
func clear() -> void:
	best_time = NO_RECORD
	total_wins = 0
	perfect_runs = 0
	no_bargain_wins = 0
	muted = false
	day = 1
	vendor_purchases = {}
	dishes_cooked = {}
	dream_best_kills = 0
	dream_boss_clears = 0
	pending_dream_bonus = 0
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


# ---------------------------------------------------------------------------
# Persistence
# ---------------------------------------------------------------------------

func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var cfg: ConfigFile = ConfigFile.new()
	var err: Error = cfg.load(SAVE_PATH)
	if err != OK:
		push_warning("[HiScore] load failed (err=%d) — starting fresh" % err)
		return
	best_time = float(cfg.get_value(SECTION, KEY_BEST, NO_RECORD))
	total_wins = int(cfg.get_value(SECTION, KEY_TOTAL, 0))
	perfect_runs = int(cfg.get_value(SECTION, KEY_PERFECT, 0))
	no_bargain_wins = int(cfg.get_value(SECTION, KEY_NO_BARGAIN, 0))
	muted = bool(cfg.get_value(SECTION, KEY_MUTED, false))
	day = maxi(1, int(cfg.get_value(SECTION, KEY_DAY, 1)))
	# v0.20: loyalty counts come back as a generic Dictionary; cast each
	# value back to int so consumers can rely on the typed get_int_default.
	vendor_purchases = {}
	var raw: Dictionary = cfg.get_value(SECTION, KEY_VENDOR_PURCHASES, {})
	for k in raw.keys():
		vendor_purchases[String(k)] = int(raw[k])
	# v0.24: cookbook counts — same shape as vendor_purchases.
	dishes_cooked = {}
	var raw_d: Dictionary = cfg.get_value(SECTION, KEY_DISHES_COOKED, {})
	for k in raw_d.keys():
		dishes_cooked[String(k)] = int(raw_d[k])
	# v0.34: dream-sequence cross-run records.
	dream_best_kills = maxi(0, int(cfg.get_value(SECTION, KEY_DREAM_BEST_KILLS, 0)))
	dream_boss_clears = maxi(0, int(cfg.get_value(SECTION, KEY_DREAM_BOSS_CLEARS, 0)))
	# v0.35: pending bonus from the most recent boss clear(s).
	pending_dream_bonus = maxi(0, int(cfg.get_value(SECTION, KEY_PENDING_DREAM_BONUS, 0)))
	# Push restored mute state to audio autoloads on next frame so they have
	# finished their own _ready (autoload init order may not guarantee it).
	call_deferred("_apply_mute")


func _save() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value(SECTION, KEY_BEST, best_time)
	cfg.set_value(SECTION, KEY_TOTAL, total_wins)
	cfg.set_value(SECTION, KEY_PERFECT, perfect_runs)
	cfg.set_value(SECTION, KEY_NO_BARGAIN, no_bargain_wins)
	cfg.set_value(SECTION, KEY_MUTED, muted)
	cfg.set_value(SECTION, KEY_DAY, day)
	cfg.set_value(SECTION, KEY_VENDOR_PURCHASES, vendor_purchases)
	cfg.set_value(SECTION, KEY_DISHES_COOKED, dishes_cooked)
	cfg.set_value(SECTION, KEY_DREAM_BEST_KILLS, dream_best_kills)
	cfg.set_value(SECTION, KEY_DREAM_BOSS_CLEARS, dream_boss_clears)
	cfg.set_value(SECTION, KEY_PENDING_DREAM_BONUS, pending_dream_bonus)
	var err: Error = cfg.save(SAVE_PATH)
	if err != OK:
		push_warning("[HiScore] save failed (err=%d)" % err)
