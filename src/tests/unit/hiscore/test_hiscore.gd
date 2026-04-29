## GUT unit tests for HiScore autoload (v0.5).
extends GutTest


func before_each() -> void:
	HiScore.clear()
	Game.last_run_was_record = false


func after_each() -> void:
	HiScore.clear()


func test_hiscore_starts_with_no_record() -> void:
	assert_false(HiScore.has_record(),
		"Fresh state (post-clear) should report no record")
	assert_eq(HiScore.format_best(), "—:——",
		"format_best() should return em-dashes when no record exists")


func test_hiscore_first_run_is_always_a_new_record() -> void:
	var was_new: bool = HiScore.try_record(120.5)
	assert_true(was_new, "First completed run is implicitly a new record")
	assert_true(HiScore.has_record())
	assert_almost_eq(HiScore.best_time, 120.5, 0.001)


func test_hiscore_slower_run_does_not_overwrite() -> void:
	HiScore.try_record(60.0)
	var beat: bool = HiScore.try_record(75.0)
	assert_false(beat, "75s should NOT beat existing 60s record")
	assert_almost_eq(HiScore.best_time, 60.0, 0.001,
		"best_time should still be 60s")


func test_hiscore_faster_run_overwrites() -> void:
	HiScore.try_record(60.0)
	var beat: bool = HiScore.try_record(45.0)
	assert_true(beat, "45s should beat existing 60s record")
	assert_almost_eq(HiScore.best_time, 45.0, 0.001)


func test_hiscore_zero_or_negative_time_is_rejected() -> void:
	assert_false(HiScore.try_record(0.0), "0s should not be saved")
	assert_false(HiScore.try_record(-5.0), "Negative should not be saved")
	assert_false(HiScore.has_record())


func test_hiscore_format_renders_minutes_and_seconds() -> void:
	HiScore.try_record(125.0)  # 2:05
	assert_eq(HiScore.format_best(), "2:05")


func test_hiscore_persists_across_clear_and_reload() -> void:
	HiScore.try_record(90.0)
	# Force a fresh in-memory state without wiping the file.
	HiScore.best_time = HiScore.NO_RECORD
	HiScore._load()
	assert_almost_eq(HiScore.best_time, 90.0, 0.001,
		"saved record should round-trip via ConfigFile")


# ---------------------------------------------------------------------------
# v0.12 — record_run aggregates best-time + counters
# ---------------------------------------------------------------------------

func test_hiscore_record_run_increments_total_wins() -> void:
	HiScore.record_run(60.0, false, true)
	HiScore.record_run(80.0, false, true)
	assert_eq(HiScore.total_wins, 2,
		"every record_run() call should increment total_wins")


func test_hiscore_record_run_perfect_increments_perfect_runs() -> void:
	var result: Dictionary = HiScore.record_run(60.0, true, false)
	assert_eq(HiScore.perfect_runs, 1)
	assert_true(result["first_perfect"],
		"first ever perfect should report first_perfect=true")
	HiScore.record_run(70.0, true, true)
	assert_eq(HiScore.perfect_runs, 2)


func test_hiscore_record_run_no_bargain_counts_only_when_unused() -> void:
	HiScore.record_run(60.0, false, true)   # bargained
	HiScore.record_run(60.0, false, false)  # didn't bargain
	HiScore.record_run(60.0, false, true)   # bargained
	assert_eq(HiScore.no_bargain_wins, 1,
		"only the run with bargained=false should count")


func test_hiscore_record_run_returns_new_record_flag() -> void:
	var first: Dictionary = HiScore.record_run(120.0, false, false)
	assert_true(first["new_record"], "first run sets a new record")
	var faster: Dictionary = HiScore.record_run(90.0, false, false)
	assert_true(faster["new_record"], "faster run sets a new record")
	var slower: Dictionary = HiScore.record_run(150.0, false, false)
	assert_false(slower["new_record"], "slower run does NOT")


func test_hiscore_has_stats_only_after_first_win() -> void:
	assert_false(HiScore.has_stats(),
		"Fresh HiScore should report has_stats() == false")
	HiScore.record_run(60.0, false, true)
	assert_true(HiScore.has_stats())


func test_hiscore_toggle_mute_flips_and_persists() -> void:
	assert_false(HiScore.muted, "Pre-condition: muted starts false")
	var after: bool = HiScore.toggle_mute()
	assert_true(after, "toggle_mute() should return new state (true)")
	assert_true(HiScore.muted)
	# Round-trip through file
	HiScore.muted = false
	HiScore._load()
	assert_true(HiScore.muted, "muted should persist via ConfigFile")


# ---------------------------------------------------------------------------
# v0.19 — calendar / day counter
# ---------------------------------------------------------------------------

func test_hiscore_day_starts_at_one() -> void:
	# clear() is called in before_each; day should default to 1.
	assert_eq(HiScore.day, 1,
		"day should default to 1 after a fresh HiScore.clear()")


func test_hiscore_record_run_advances_day() -> void:
	HiScore.day = 3
	HiScore.record_run(60.0, false, true)
	assert_eq(HiScore.day, 4,
		"record_run should advance the day by 1")


func test_hiscore_day_persists_via_config_file() -> void:
	HiScore.day = 12
	HiScore._save()
	# Reset in-memory and reload from disk
	HiScore.day = 1
	HiScore._load()
	assert_eq(HiScore.day, 12,
		"day should round-trip through the ConfigFile")


func test_hiscore_clear_resets_day_to_one() -> void:
	HiScore.day = 17
	HiScore.clear()
	assert_eq(HiScore.day, 1,
		"clear() should reset the day counter to 1")


# ---------------------------------------------------------------------------
# v0.20 — vendor loyalty / purchase counts
# ---------------------------------------------------------------------------

func test_hiscore_purchase_count_starts_at_zero() -> void:
	assert_eq(HiScore.purchase_count("chicken"), 0,
		"purchase_count should default to 0 for unknown ingredients")


func test_hiscore_record_purchase_increments_count() -> void:
	HiScore.record_purchase("chicken")
	HiScore.record_purchase("chicken")
	HiScore.record_purchase("chicken")
	assert_eq(HiScore.purchase_count("chicken"), 3,
		"3 record_purchase calls should yield count = 3")


func test_hiscore_record_purchase_isolates_per_ingredient() -> void:
	HiScore.record_purchase("chicken")
	HiScore.record_purchase("egg")
	HiScore.record_purchase("egg")
	assert_eq(HiScore.purchase_count("chicken"), 1)
	assert_eq(HiScore.purchase_count("egg"), 2)
	assert_eq(HiScore.purchase_count("scallion"), 0,
		"untouched ingredients should remain at 0")


func test_hiscore_vendor_purchases_persist_via_config_file() -> void:
	HiScore.record_purchase("chicken")
	HiScore.record_purchase("chicken")
	HiScore.record_purchase("egg")
	# Wipe in-memory and reload
	HiScore.vendor_purchases = {}
	HiScore._load()
	assert_eq(HiScore.purchase_count("chicken"), 2,
		"vendor_purchases should round-trip via the ConfigFile")
	assert_eq(HiScore.purchase_count("egg"), 1)


func test_hiscore_clear_wipes_vendor_purchases() -> void:
	HiScore.record_purchase("chicken")
	HiScore.record_purchase("egg")
	HiScore.clear()
	assert_eq(HiScore.purchase_count("chicken"), 0,
		"clear() should drop loyalty counts to 0")
	assert_eq(HiScore.purchase_count("egg"), 0)
