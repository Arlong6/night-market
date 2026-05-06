## Street musician NPC for Night Market Shopping (v0.49).
##
## 街頭藝人 — sits in a corner cell strumming a 月琴, periodically emitting
## small music-note particles. Bumping prompts a "丟錢給他？NT$2" choice.
## Tipping plays a thank-you line and gives the player a 1.0× → 0.95× cross-run
## morale boost… wait, no, scope creep. Tipping is pure flavour: thank-you
## line + sparkle FX. The kid feels good.
##
## Tipped state persists for the run only — fresh runs reset, and a happily
## tipped musician switches to a louder song line on subsequent bumps.
class_name StreetMusician
extends NPC

# ---------------------------------------------------------------------------
# Tuning
# ---------------------------------------------------------------------------

const TIP_AMOUNT: int = 2

## Note pitch cycles through this chord so the visual notes feel musical.
const NOTE_LIFETIME: float = 1.6
const NOTE_SPAWN_PERIOD: float = 1.1
const NOTE_FLOAT_SPEED: float = 14.0
const NOTE_DRIFT_AMP: float = 3.0

## Note glyphs drawn (rotated through). Pixel-art "♪" approximation: a
## stem with a flag + a head. We just colour-cycle from a small palette.
const NOTE_COLORS: Array[Color] = [
	Color("#F2A227"),  ## warm amber
	Color("#C2548A"),  ## rose
	Color("#7AC940"),  ## green
	Color("#A0C4E0"),  ## pale blue
]

const LINES_INTRO: Array[String] = [
	"♪ 月琴叮叮咚咚的～",
	"♪ 這首曲子是「望春風」",
	"♪ 阿伯彈了三十年了～",
]

const LINES_TIP_THANKS: Array[String] = [
	"啊！多謝小弟弟，再彈一首給你聽！",
	"哎呀！心意收到了～繼續努力",
	"小朋友很有愛心，給你彈個更厲害的！",
]

const LINES_TIP_BROKE: Array[String] = [
	"沒錢沒關係，靜靜聽就好",
	"心意到了就好，多謝多謝～",
]

const LINES_AFTER_TIP: Array[String] = [
	"♪♪ 月光暝下嘩嘩響～",
	"♪♪ 這首是專門彈給你聽的",
	"♪♪ 阿伯越彈越開心了～",
]

# ---------------------------------------------------------------------------
# Visual constants
# ---------------------------------------------------------------------------

const COLOR_HAT: Color = Color("#3A2A1A")        ## flat brown straw hat
const COLOR_SHIRT: Color = Color("#7A4A2A")      ## warm earth shirt
const COLOR_LUTE_BODY: Color = Color("#C8884A")  ## wood lute round body
const COLOR_LUTE_NECK: Color = Color("#5A3220")  ## darker wood neck
const COLOR_STOOL: Color = Color("#3A2A1A")      ## small wooden stool

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

class _Note:
	var x: float = 0.0
	var y: float = 0.0
	var t: float = 0.0
	var color: Color = Color.WHITE


var _notes: Array[_Note] = []
var _spawn_t: float = 0.0
var _tipped: bool = false


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	super._process(delta)
	if Game.test_mode:
		return
	_spawn_t += delta
	# After tipping, notes spawn ~1.5× faster (musician is happy).
	var period: float = (NOTE_SPAWN_PERIOD * 0.66) if _tipped else NOTE_SPAWN_PERIOD
	if _spawn_t >= period:
		_spawn_t = 0.0
		_emit_note()
	# Tick existing notes, drop expired ones.
	var keep: Array[_Note] = []
	for n in _notes:
		n.t += delta
		if n.t < NOTE_LIFETIME:
			keep.append(n)
	_notes = keep


func _emit_note() -> void:
	var n: _Note = _Note.new()
	# Notes start near the lute (right side of musician body).
	n.x = 4.0 + randf() * 2.0
	n.y = -3.0
	n.t = 0.0
	n.color = NOTE_COLORS[randi() % NOTE_COLORS.size()]
	_notes.append(n)


# ---------------------------------------------------------------------------
# Bump handler
# ---------------------------------------------------------------------------

func on_bumped() -> void:
	if Inventory.money < TIP_AMOUNT:
		Dialogue.show([_pick(LINES_TIP_BROKE)])
		return
	if _tipped:
		# Already tipped — bumping again just plays a song line.
		Dialogue.show([_pick(LINES_AFTER_TIP)])
		return
	# First bump: small intro, then choice
	var intro: String = _pick(LINES_INTRO)
	Dialogue.show([intro], _open_tip_choice)


func _open_tip_choice() -> void:
	Dialogue.ask_choice(
		"丟個 NT$%d 給阿伯？" % TIP_AMOUNT,
		["是", "否"],
		_on_choice
	)


func _on_choice(idx: int) -> void:
	if idx != 0:
		Dialogue.show(["好啦，繼續聽就好～"])
		return
	if Inventory.money < TIP_AMOUNT:
		Dialogue.show([_pick(LINES_TIP_BROKE)])
		return
	Inventory.money -= TIP_AMOUNT
	Inventory.money_changed.emit(Inventory.money)
	_tipped = true
	# Sparkle of music-note colours
	var burst: ParticleBurst = ParticleBurst.new()
	burst.position = Vector2(0.0, -2.0)
	burst.count = 8
	burst.color = Color("#F2A227")
	burst.lifetime = 0.5
	burst.gravity_scale = 0.2
	burst.upward_bias = 0.8
	add_child(burst)
	if Sfx.has_method("play_pickup"):
		Sfx.play_pickup()
	Dialogue.show([_pick(LINES_TIP_THANKS)])


func _pick(pool: Array[String]) -> String:
	if pool.is_empty():
		return ""
	return pool[randi() % pool.size()]


# ---------------------------------------------------------------------------
# Drawing — seated musician with 月琴 + floating notes
# ---------------------------------------------------------------------------

func _draw() -> void:
	var bob: float = _idle_bob_offset()
	# Stool (under the body, 2px tall)
	draw_rect(Rect2(-3.0, 5.0 + bob, 6.0, 2.0), COLOR_STOOL)
	draw_rect(Rect2(-3.0, 7.0 + bob, 1.0, 2.0), COLOR_STOOL)
	draw_rect(Rect2(2.0, 7.0 + bob, 1.0, 2.0), COLOR_STOOL)
	# Body — sits compact on the stool
	draw_rect(Rect2(-3.0, 0.0 + bob, 6.0, 5.0), COLOR_SHIRT)
	# Head
	draw_rect(Rect2(-3.0, -5.0 + bob, 6.0, 5.0), COLOR_SKIN)
	# Hat — flat brown brim across top
	draw_rect(Rect2(-4.0, -7.0 + bob, 8.0, 2.0), COLOR_HAT)
	draw_rect(Rect2(-3.0, -5.0 + bob, 6.0, 1.0), COLOR_HAT.darkened(0.30))
	# Eyes — closed (concentrating on the music). Two horizontal slits.
	draw_rect(Rect2(-2.0, -3.0 + bob, 1.0, 1.0), COLOR_EYE)
	draw_rect(Rect2(1.0, -3.0 + bob, 1.0, 1.0), COLOR_EYE)
	# 月琴 lute — round body to the right of the musician, neck pointing up-left.
	# Body: stacked rects approximating a circle.
	draw_rect(Rect2(3.0, 0.0 + bob, 4.0, 1.0), COLOR_LUTE_BODY)
	draw_rect(Rect2(2.0, 1.0 + bob, 6.0, 3.0), COLOR_LUTE_BODY)
	draw_rect(Rect2(3.0, 4.0 + bob, 4.0, 1.0), COLOR_LUTE_BODY)
	# Sound hole — 1px dark dot in the middle.
	draw_rect(Rect2(4.0, 2.0 + bob, 1.0, 1.0), Color("#2A1408"))
	# Neck — thin diagonal pointing up-left.
	draw_rect(Rect2(2.0, -1.0 + bob, 1.0, 1.0), COLOR_LUTE_NECK)
	draw_rect(Rect2(1.0, -2.0 + bob, 1.0, 1.0), COLOR_LUTE_NECK)
	draw_rect(Rect2(0.0, -3.0 + bob, 1.0, 1.0), COLOR_LUTE_NECK)
	# Arm strumming — small skin rectangle resting on the lute body.
	draw_rect(Rect2(2.0, 0.0 + bob, 2.0, 2.0), COLOR_SKIN)
	# Floating notes
	_draw_notes(bob)


func _draw_notes(bob: float) -> void:
	for n in _notes:
		# Vertical rise: y decreases over lifetime.
		var rise: float = -n.t * NOTE_FLOAT_SPEED
		# Sin drift on x for that "music floating" feel.
		var drift: float = sin(n.t * 4.0) * NOTE_DRIFT_AMP
		var nx: float = n.x + drift
		var ny: float = n.y + rise + bob
		# Fade alpha across lifetime
		var alpha: float = clampf(1.0 - n.t / NOTE_LIFETIME, 0.0, 1.0)
		var c: Color = n.color
		c.a = alpha
		# Pixel-art ♪ — note head (2x2) + stem (1x3) + flag (1x1)
		draw_rect(Rect2(nx, ny, 2.0, 2.0), c)              ## head
		draw_rect(Rect2(nx + 1.0, ny - 3.0, 1.0, 3.0), c)  ## stem
		draw_rect(Rect2(nx + 2.0, ny - 3.0, 1.0, 1.0), c)  ## flag
