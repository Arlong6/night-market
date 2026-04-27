## Best-time persistence for Night Market Shopping (v0.5).
##
## Stores the player's fastest successful run in user://best.cfg via
## ConfigFile. On Web export, user:// is backed by IndexedDB so the value
## survives page reloads but is per-origin / per-browser-profile.
##
## API:
##   * HiScore.best_time          → float, INF if no record yet
##   * HiScore.has_record()       → bool
##   * HiScore.try_record(t)      → bool — true iff t was a new best (and saved)
extends Node

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

const SAVE_PATH: String = "user://best.cfg"
const SECTION: String = "run"
const KEY_BEST: String = "best_time"

## Sentinel for "no record yet" — easier than a separate Optional flag.
const NO_RECORD: float = INF

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

var best_time: float = NO_RECORD

# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	_load()


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Returns true iff a saved best time has been loaded.
func has_record() -> bool:
	return best_time != NO_RECORD and best_time > 0.0


## Attempts to record a new run. If `t` beats the current best (or no record
## exists yet), persists it and returns true. Returns false if `t` was slower
## (the existing record stands).
func try_record(t: float) -> bool:
	if t <= 0.0:
		return false
	if not has_record() or t < best_time:
		best_time = t
		_save()
		return true
	return false


## Returns "M:SS" for the saved best, or "—:—" if no record.
func format_best() -> String:
	if not has_record():
		return "—:——"
	var minutes: int = int(best_time) / 60
	var seconds: int = int(best_time) % 60
	return "%d:%02d" % [minutes, seconds]


## Test helper — wipes the record and the on-disk file.
func clear() -> void:
	best_time = NO_RECORD
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))


# ---------------------------------------------------------------------------
# Persistence
# ---------------------------------------------------------------------------

func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		best_time = NO_RECORD
		return
	var cfg: ConfigFile = ConfigFile.new()
	var err: Error = cfg.load(SAVE_PATH)
	if err != OK:
		push_warning("[HiScore] load failed (err=%d) — starting fresh" % err)
		best_time = NO_RECORD
		return
	best_time = float(cfg.get_value(SECTION, KEY_BEST, NO_RECORD))


func _save() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value(SECTION, KEY_BEST, best_time)
	var err: Error = cfg.save(SAVE_PATH)
	if err != OK:
		push_warning("[HiScore] save failed (err=%d)" % err)
