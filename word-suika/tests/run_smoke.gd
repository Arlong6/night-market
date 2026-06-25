## Headless logic smoke test for 一字一句 (Word Suika).
##
## Standalone (no GUT addon in this prototype yet): run with
##   godot --headless -s res://tests/run_smoke.gd
## Verifies the new audio + hiscore logic without needing interactive clicks.
## Exits with code 0 on all-pass, 1 on any failure.
extends SceneTree

const WSAudio = preload("res://scripts/audio.gd")
const WSHiScore = preload("res://scripts/hiscore.gd")
const TierData = preload("res://scripts/tier_data.gd")

var _fails: int = 0
var _checks: int = 0

func _init() -> void:
	_test_audio_streams()
	_test_audio_pitch_rises()
	_test_hiscore_roundtrip()
	print("\n[smoke] %d/%d checks passed" % [_checks - _fails, _checks])
	quit(1 if _fails > 0 else 0)

func _ok(cond: bool, label: String) -> void:
	_checks += 1
	if cond:
		print("  PASS  ", label)
	else:
		_fails += 1
		print("  FAIL  ", label)

# Every tier must produce a valid non-empty 16-bit mono stream.
func _test_audio_streams() -> void:
	for t in TierData.TIER_COUNT:
		var s: AudioStreamWAV = WSAudio._make_merge_pop(t)
		_ok(s != null and s.data.size() > 0 and s.format == AudioStreamWAV.FORMAT_16_BITS,
			"merge_pop tier %d generates valid stream" % t)
	var drop: AudioStreamWAV = WSAudio._make_drop()
	_ok(drop != null and drop.data.size() > 0, "drop_thock generates valid stream")
	var fan: AudioStreamWAV = WSAudio._make_fanfare()
	_ok(fan != null and fan.data.size() > 0, "poem_fanfare generates valid stream")
	var go: AudioStreamWAV = WSAudio._make_gameover()
	_ok(go != null and go.data.size() > 0, "game_over generates valid stream")

# Higher tiers must map to higher pitch (longer/fuller stream is allowed, but the
# pentatonic ladder must be strictly ascending).
func _test_audio_pitch_rises() -> void:
	var prev: float = -1.0
	var ascending: bool = true
	for t in WSAudio.TIER_SEMITONES.size():
		var hz: float = WSAudio.ROOT_HZ * pow(2.0, float(WSAudio.TIER_SEMITONES[t]) / 12.0)
		if hz <= prev:
			ascending = false
		prev = hz
	_ok(ascending, "tier pitch ladder is strictly ascending")
	_ok(WSAudio.TIER_SEMITONES.size() == TierData.TIER_COUNT,
		"pitch ladder covers every tier")

# Best score persists and "new best" is reported only when actually beaten.
func _test_hiscore_roundtrip() -> void:
	# Preserve any existing save, then work on a clean slate.
	var had := FileAccess.file_exists(WSHiScore.SAVE_PATH)
	var backup := ""
	if had:
		backup = FileAccess.get_file_as_string(WSHiScore.SAVE_PATH)
	DirAccess.remove_absolute(WSHiScore.SAVE_PATH)

	_ok(WSHiScore.load_best() == 0, "fresh best is 0")
	_ok(WSHiScore.submit(100, 3) == true, "first run of 100 is a new best")
	_ok(WSHiScore.load_best() == 100, "best persists as 100")
	_ok(WSHiScore.submit(50, 5) == false, "lower score (50) is not a new best")
	_ok(WSHiScore.load_best() == 100, "best stays 100 after a lower run")
	_ok(WSHiScore.load_best_tier() == 5, "best_tier folds upward to 5 even on a low-score run")
	_ok(WSHiScore.submit(200, 2) == true, "higher score (200) is a new best")
	_ok(WSHiScore.load_best() == 200, "best updates to 200")

	# Restore the player's real save (or remove our test file).
	DirAccess.remove_absolute(WSHiScore.SAVE_PATH)
	if had:
		var f := FileAccess.open(WSHiScore.SAVE_PATH, FileAccess.WRITE)
		if f:
			f.store_string(backup)
			f.close()
