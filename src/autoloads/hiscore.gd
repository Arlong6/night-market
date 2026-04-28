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

## Wipes ALL state (record + counters + mute) and the on-disk file.
func clear() -> void:
	best_time = NO_RECORD
	total_wins = 0
	perfect_runs = 0
	no_bargain_wins = 0
	muted = false
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
	var err: Error = cfg.save(SAVE_PATH)
	if err != OK:
		push_warning("[HiScore] save failed (err=%d)" % err)
