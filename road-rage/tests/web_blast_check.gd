## WEB BLAST CHECK — scripted proof that dying to an explosion does not kill the
## renderer on the gl_compatibility (web / mobile) path.
##
## The user reported the browser build "跳掉" (crashed) when the player was killed
## by a blast. That path is GPU-side, so a headless run can never catch it: the
## suspects were the per-explosion OmniLight + particle budget under WebGL2.
## This scene drives the REAL fp_main through a full blast-death in BOTH modes
## (driving and on foot), then soaks for a few more seconds, and prints a verdict
## line to stdout — which on web lands in the JS console where CDP can read it.
##
## Desktop: godot --path road-rage res://tests/web_blast_check.tscn
## Web:     exported with this scene as the main scene (see tools/web_blast_check.sh)
extends Node

const PREFIX: String = "WEB_BLAST_CHECK"

## Frames to let the city build and draw its first real frames before touching it.
const WARMUP: int = 90
## Frames between detonations — short enough that health regen never catches up.
const BLAST_GAP: int = 18
## Frames to keep rendering after the last death; a deferred GPU fault shows here.
const SOAK: int = 240

var _game: Node = null
var _f: int = 0
var _step: int = 0
var _next_blast: int = 0
var _blasts: int = 0
var _reported: bool = false

# Evidence collected per mode.
var _car_deaths: int = 0
var _foot_deaths: int = 0
var _hp_prev: float = -1.0
var _min_hp: float = 9999.0
var _frames_after_last_death: int = 0
var _last_death_frame: int = -1

func _ready() -> void:
	_game = load("res://scenes/fp_main.tscn").instantiate()
	add_child(_game)
	print("%s boot renderer=%s" % [PREFIX, RenderingServer.get_video_adapter_name()])

func _process(_delta: float) -> void:
	if _reported:
		return
	_f += 1

	# Watch for a respawn: _damage() drives hp to 0 then _respawn() refills it.
	var hp: float = float(_game._hp)
	_min_hp = minf(_min_hp, hp)
	if _hp_prev >= 0.0 and hp > _hp_prev + 1.0 and _hp_prev < 30.0:
		# Health jumped back up from near-death => _respawn() fired.
		if _step <= 2:
			_car_deaths += 1
		else:
			_foot_deaths += 1
		_last_death_frame = _f
		_blasts = 0
		_step += 1   # advance out of the blasting step
	_hp_prev = hp

	match _step:
		0:
			if _f >= WARMUP:
				_game._start_game()
				print("%s started mode=%s lite=%s hp=%.0f" % [PREFIX, _game._mode, _game._lite, hp])
				_step = 1
				_next_blast = _f + 20
		1:
			# Blast-death while DRIVING.
			_step = 2
		2:
			if _f >= _next_blast:
				_detonate_on_player()
				_next_blast = _f + BLAST_GAP
		3:
			# Died in the car. Get out and do it again on foot.
			if _f >= _last_death_frame + 30:
				_game._exit_car()
				print("%s car_death_ok deaths=%d mode_now=%s" % [PREFIX, _car_deaths, _game._mode])
				_hp_prev = -1.0
				_step = 4
				_next_blast = _f + 20
		4:
			if _f >= _next_blast:
				_detonate_on_player()
				_next_blast = _f + BLAST_GAP
		5:
			# Died on foot too. Soak: keep rendering and let the FX finish.
			_frames_after_last_death = _f - _last_death_frame
			if _frames_after_last_death >= SOAK:
				_report()

	# Hard stop so a stuck run still reports instead of hanging the browser.
	if _f > 3000 and not _reported:
		_report()

## Spawn a barrel right on top of the player and set it off, wiring it through
## the game's real explosion handler so the full blast path runs (damage, flash,
## hit-stop, shockwave, debris, ped alarm) exactly as it does in play.
func _detonate_on_player() -> void:
	var ex := FPExplosive.new()
	_game.add_child(ex)
	ex.global_position = _game._player_pos()
	ex.exploded.connect(_game._on_explosion)
	ex.explode()
	_blasts += 1

func _report() -> void:
	_reported = true
	var ok: bool = _car_deaths >= 1 and _foot_deaths >= 1 \
			and _frames_after_last_death >= SOAK \
			and is_instance_valid(_game)
	print("%s RESULT ok=%s car_deaths=%d foot_deaths=%d min_hp=%.0f hp_now=%.0f soak_frames=%d total_frames=%d" \
			% [PREFIX, ok, _car_deaths, _foot_deaths, _min_hp, float(_game._hp), _frames_after_last_death, _f])
	print("%s DONE" % PREFIX)
	get_tree().quit(0 if ok else 1)
