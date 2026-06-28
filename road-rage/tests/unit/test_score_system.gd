extends GutTest

const ScoreSystem = preload("res://scripts/score_system.gd")

func before_each() -> void:
	DirAccess.remove_absolute(ScoreSystem.SAVE_PATH)

func after_all() -> void:
	DirAccess.remove_absolute(ScoreSystem.SAVE_PATH)

func test_add_accumulates() -> void:
	var s = ScoreSystem.new()
	s.add(100, 1)
	s.add(50, 2)
	assert_eq(s.score, 150)
	assert_eq(s.destroyed, 3)

func test_submit_sets_new_best() -> void:
	var s = ScoreSystem.new()
	s.add(500)
	assert_true(s.submit())
	assert_eq(ScoreSystem.new().load_best(), 500)

func test_lower_score_not_new_best() -> void:
	var a = ScoreSystem.new(); a.add(500); a.submit()
	var b = ScoreSystem.new(); b.add(100)
	assert_false(b.submit())
	assert_eq(ScoreSystem.new().load_best(), 500)
