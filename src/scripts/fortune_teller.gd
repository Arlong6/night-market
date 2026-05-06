## Fortune teller NPC for Night Market Shopping (v0.48).
##
## 路邊算命阿婆 — bumping pays NT$5 for a random fortune. Outcome roll
## refunds 0-30 NT$ on top of a flavour line, so each consultation is a
## small risk-reward gamble. One consultation per run; subsequent bumps
## politely refuse so the kid can't grind the booth.
##
## Roll buckets (RNG once per consult):
##   * 10%  bad   (refund 0,   line "唉呀霉氣")
##   * 30%  even  (refund 5,   line "今天平平")
##   * 30%  good  (refund 8,   line "中籤")
##   * 25%  great (refund 15,  line "好籤！")
##   * 5%   epic  (refund 30,  line "超好籤！")
class_name FortuneTeller
extends NPC

# ---------------------------------------------------------------------------
# Tuning
# ---------------------------------------------------------------------------

const FORTUNE_PRICE: int = 5

## Outcome thresholds (cumulative). Roll is randf() in [0, 1).
const ROLL_BAD: float = 0.10
const ROLL_EVEN: float = 0.40
const ROLL_GOOD: float = 0.70
const ROLL_GREAT: float = 0.95
# everything above ROLL_GREAT → epic

const REFUND_BAD: int = 0
const REFUND_EVEN: int = 5
const REFUND_GOOD: int = 8
const REFUND_GREAT: int = 15
const REFUND_EPIC: int = 30

## Per-tier flavour pool — pick one randomly so repeat consults across
## different runs feel like the booth has a deck of cards, not a script.
const LINES_BAD: Array[String] = [
	"唉呀，今天霉氣有點重啊…",
	"小心一點，最近會踩到狗大便",
	"今天運氣不太好，小心走路",
]
const LINES_EVEN: Array[String] = [
	"今天平平淡淡，沒事啦",
	"運氣普普通通，剛剛好",
	"今天就是個普通的日子～",
]
const LINES_GOOD: Array[String] = [
	"嗯～有點小財運",
	"中籤！今天會有好事",
	"運氣不錯哦，去買點好東西",
]
const LINES_GREAT: Array[String] = [
	"哎呀！好籤啊！",
	"今天運氣超好，去殺價會成功",
	"財神爺今天看你比較順眼喔",
]
const LINES_EPIC: Array[String] = [
	"哇！紫氣東來！超級好籤！",
	"哎呦這個籤多少年沒見了！",
	"今天你做什麼都會贏！",
]

## Lines used when the player bumps after already consulting once.
const LINES_DONE: Array[String] = [
	"今天就到這啊～再來",
	"算過了不能再算，明天再來",
	"小弟弟，命要慢慢看，不能催的",
]

## Lines used when the player can't even afford the consult.
const LINES_BROKE: Array[String] = [
	"算命 NT$%d 喔，沒錢啦？" % FORTUNE_PRICE,
	"小弟弟，要 NT$%d 才能算啦" % FORTUNE_PRICE,
]

# ---------------------------------------------------------------------------
# Visual constants
# ---------------------------------------------------------------------------

const COLOR_BOOTH: Color = Color("#3A1A4A")     ## deep purple booth
const COLOR_BOOTH_TRIM: Color = Color("#5A2A6A")
const COLOR_DRAPE: Color = Color("#8A4A1A")     ## warm orange drape across the front
const COLOR_BALL: Color = Color("#A0C8E8")      ## crystal ball pale cyan
const COLOR_BALL_HIGHLIGHT: Color = Color("#F0F8FF")
const COLOR_GRANNY_HAIR: Color = Color("#C8C8C8")  ## granny silver

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

var _consulted: bool = false
var _glow_t: float = 0.0


func _process(delta: float) -> void:
	super._process(delta)
	# Crystal-ball glow pulses regardless of bump state — keeps the booth
	# alive even when the player isn't interacting.
	_glow_t += delta


# ---------------------------------------------------------------------------
# Bump handler
# ---------------------------------------------------------------------------

func on_bumped() -> void:
	if _consulted:
		_say_random(LINES_DONE)
		return
	if Inventory.money < FORTUNE_PRICE:
		_say_random(LINES_BROKE)
		return
	Dialogue.ask_choice(
		"算命 NT$%d 試試運氣？" % FORTUNE_PRICE,
		["是", "否"],
		_on_choice
	)


func _on_choice(idx: int) -> void:
	if idx != 0:
		Dialogue.show(["好啦，下次再來看看～"])
		return
	if Inventory.money < FORTUNE_PRICE:
		# Race guard — money could change between prompt and confirm.
		Dialogue.show(["欸？錢好像不夠了"])
		return
	# Charge first, then roll.
	Inventory.money -= FORTUNE_PRICE
	Inventory.money_changed.emit(Inventory.money)
	_consulted = true
	_resolve_roll()


func _resolve_roll() -> void:
	var r: float = randf()
	var refund: int = 0
	var pool: Array[String]
	if r < ROLL_BAD:
		refund = REFUND_BAD
		pool = LINES_BAD
	elif r < ROLL_EVEN:
		refund = REFUND_EVEN
		pool = LINES_EVEN
	elif r < ROLL_GOOD:
		refund = REFUND_GOOD
		pool = LINES_GOOD
	elif r < ROLL_GREAT:
		refund = REFUND_GREAT
		pool = LINES_GREAT
	else:
		refund = REFUND_EPIC
		pool = LINES_EPIC
	if refund > 0:
		Inventory.money += refund
		Inventory.money_changed.emit(Inventory.money)
	var line: String = pool[randi() % pool.size()]
	if refund > 0:
		line += "  (退你 NT$%d)" % refund
	Dialogue.show([line])


func _say_random(pool: Array[String]) -> void:
	if pool.is_empty():
		return
	Dialogue.show([pool[randi() % pool.size()]])


# ---------------------------------------------------------------------------
# Drawing — small booth with crystal ball + granny silhouette
# ---------------------------------------------------------------------------

func _draw() -> void:
	var bob: float = _idle_bob_offset()
	var half: float = NPC_SIZE / 2.0
	# Booth body (full square, narrower than a stall)
	draw_rect(Rect2(-half + 1.0, -half + 2.0 + bob, NPC_SIZE - 2.0,
		NPC_SIZE - 2.0), COLOR_BOOTH)
	# Trim along the top
	draw_rect(Rect2(-half + 1.0, -half + 2.0 + bob, NPC_SIZE - 2.0, 2.0),
		COLOR_BOOTH_TRIM)
	# Drape across the front (sits over the lower body)
	draw_rect(Rect2(-half + 1.0, 1.0 + bob, NPC_SIZE - 2.0, 2.0), COLOR_DRAPE)
	# Crystal ball — pale cyan circle approximated with stacked rects.
	# Pulses brighter on a slow sin so the booth has a mystical breath.
	var pulse: float = (sin(_glow_t * 1.8) + 1.0) * 0.5  # 0..1
	var ball: Color = COLOR_BALL.lerp(COLOR_BALL_HIGHLIGHT, pulse * 0.4)
	var bx: float = -2.0
	var by: float = -2.0 + bob
	draw_rect(Rect2(bx, by - 1.0, 4.0, 1.0), ball)
	draw_rect(Rect2(bx - 1.0, by, 6.0, 2.0), ball)
	draw_rect(Rect2(bx, by + 2.0, 4.0, 1.0), ball)
	# Highlight pixel — drifts slowly so the ball looks like it's swirling.
	var hx: float = roundf(sin(_glow_t * 1.2) * 1.0)
	draw_rect(Rect2(bx + 1.0 + hx, by, 1.0, 1.0), COLOR_BALL_HIGHLIGHT)
	# Granny silhouette behind the ball — head + hair stripe + scarf.
	var ghx: float = -3.0
	var ghy: float = -7.0 + bob
	draw_rect(Rect2(ghx, ghy, 6.0, 4.0), COLOR_SKIN)        # head
	draw_rect(Rect2(ghx, ghy, 6.0, 2.0), COLOR_GRANNY_HAIR) # silver hair cap
	# Side hair stubs
	draw_rect(Rect2(ghx, ghy + 2.0, 1.0, 1.0), COLOR_GRANNY_HAIR)
	draw_rect(Rect2(ghx + 5.0, ghy + 2.0, 1.0, 1.0), COLOR_GRANNY_HAIR)
	# Eyes — closed lines (granny is "seeing the future")
	draw_rect(Rect2(ghx + 1.0, ghy + 2.0, 1.0, 1.0), COLOR_EYE)
	draw_rect(Rect2(ghx + 4.0, ghy + 2.0, 1.0, 1.0), COLOR_EYE)
	# Sign — small "卜" placeholder hanging on the right side
	draw_rect(Rect2(half - 4.0, -3.0 + bob, 4.0, 5.0), Color("#F5EDDA"))
	draw_rect(Rect2(half - 4.0, -3.0 + bob, 4.0, 1.0), Color("#2A1A0A"))
	# Red character placeholder
	draw_rect(Rect2(half - 3.0, -1.5 + bob, 2.0, 3.0), Color("#C2241A"))
