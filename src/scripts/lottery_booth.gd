## Lottery booth NPC for Night Market Shopping (v0.52).
##
## 抽獎攤 — pays NT$10 per draw, rolls for a prize bucket. Up to 3 draws
## per run so the player can press their luck or stop early. Sister mechanic
## to v0.48 算命阿婆: fortune teller is cheap (NT$5) with small refunds,
## lottery is dearer (NT$10) with bigger jackpots + chance of a free
## ingredient.
##
## Roll buckets (v1 retune — was a positive-EV money pump + 8% free required
## ingredient, which erased the budget squeeze; now a genuine press-your-luck
## gamble that loses on average). [BALANCE: needs playtest]
##   * 50%  NT$5  back  (net -5,    "銘謝惠顧")
##   * 22%  NT$10 back  (net  0,    "再接再厲")
##   * 16%  NT$20 back  (net +10,   "三等獎")
##   *  7%  NT$30 back  (net +20,   "二等獎")
##   *  3.5% free random ingredient ("特別獎")
##   *  1.5% NT$50 back (net +40,   "一等獎！")
class_name LotteryBooth
extends NPC

# ---------------------------------------------------------------------------
# Tuning
# ---------------------------------------------------------------------------

const LOTTERY_PRICE: int = 10
const MAX_DRAWS: int = 3

const ROLL_LOSE: float = 0.50       ## refund 5  (was 0.35 — pressing luck now genuinely risky)
const ROLL_BREAK_EVEN: float = 0.72 ## refund 10
const ROLL_THIRD: float = 0.88      ## refund 20
const ROLL_SECOND: float = 0.95     ## refund 30
const ROLL_BONUS: float = 0.985     ## free ingredient (band shrunk 8% → 3.5%)
# everything above ROLL_BONUS → first prize NT$50

const REFUND_LOSE: int = 5
const REFUND_BREAK_EVEN: int = 10
const REFUND_THIRD: int = 20
const REFUND_SECOND: int = 30
const REFUND_FIRST: int = 50

## Pool of ingredient ids the booth can grant. Picked at random when the
## "特別獎" bucket fires. Identical to the stall ingredient list so the
## player can luck into anything they were about to buy.
const PRIZE_INGREDIENT_POOL: Array[String] = [
	"scallion", "egg", "cabbage", "chicken",
	"mushroom", "tofu", "soy_sauce",
]

const LINES_LOSE: Array[String] = [
	"銘謝惠顧～退你 NT$%d 啦" % REFUND_LOSE,
	"再接再厲，退你 NT$%d" % REFUND_LOSE,
]
const LINES_BREAK_EVEN: Array[String] = [
	"剛好回本！NT$%d 還你" % REFUND_BREAK_EVEN,
	"打平唷～拿回 NT$%d" % REFUND_BREAK_EVEN,
]
const LINES_THIRD: Array[String] = [
	"三等獎！恭喜～ NT$%d 拿去" % REFUND_THIRD,
	"運氣不錯～退 NT$%d" % REFUND_THIRD,
]
const LINES_SECOND: Array[String] = [
	"二等獎！厲害厲害～ NT$%d" % REFUND_SECOND,
	"哎呀好運！NT$%d 給你" % REFUND_SECOND,
]
const LINES_FIRST: Array[String] = [
	"一等獎！！中了大獎啦！NT$%d！" % REFUND_FIRST,
	"哇！頭獎！趕快拿走這 NT$%d！" % REFUND_FIRST,
]

const LINES_DONE: Array[String] = [
	"今天已經抽 %d 次囉，明天再來" % MAX_DRAWS,
	"運氣要慢慢來，明天再玩",
]
const LINES_BROKE: Array[String] = [
	"NT$%d 一張喔，沒錢啦？" % LOTTERY_PRICE,
]

# ---------------------------------------------------------------------------
# Visual constants
# ---------------------------------------------------------------------------

const COLOR_BOX_RED: Color = Color("#C2241A")
const COLOR_BOX_GOLD: Color = Color("#F2A227")
const COLOR_BOX_DARK: Color = Color("#5A1208")
const COLOR_PAPER: Color = Color("#F5EDDA")
const COLOR_BANNER: Color = Color("#8A1810")

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

var _draws_used: int = 0
var _spin_t: float = 0.0


func _process(delta: float) -> void:
	super._process(delta)
	_spin_t += delta


# ---------------------------------------------------------------------------
# Bump handler
# ---------------------------------------------------------------------------

func on_bumped() -> void:
	if _draws_used >= MAX_DRAWS:
		_say_random(LINES_DONE)
		return
	if Inventory.money < LOTTERY_PRICE:
		_say_random(LINES_BROKE)
		return
	var remaining: int = MAX_DRAWS - _draws_used
	Dialogue.ask_choice(
		"抽獎一張 NT$%d？(剩 %d 次)" % [LOTTERY_PRICE, remaining],
		["是", "否"],
		_on_choice
	)


func _on_choice(idx: int) -> void:
	if idx != 0:
		Dialogue.show(["好啦，下次再來"])
		return
	if Inventory.money < LOTTERY_PRICE:
		Dialogue.show(["欸？錢好像不夠了"])
		return
	Inventory.money -= LOTTERY_PRICE
	Inventory.money_changed.emit(Inventory.money)
	_draws_used += 1
	_resolve_roll()


func _resolve_roll() -> void:
	var r: float = randf()
	var refund: int = 0
	var pool: Array[String]
	var grant_id: String = ""
	if r < ROLL_LOSE:
		refund = REFUND_LOSE
		pool = LINES_LOSE
	elif r < ROLL_BREAK_EVEN:
		refund = REFUND_BREAK_EVEN
		pool = LINES_BREAK_EVEN
	elif r < ROLL_THIRD:
		refund = REFUND_THIRD
		pool = LINES_THIRD
	elif r < ROLL_SECOND:
		refund = REFUND_SECOND
		pool = LINES_SECOND
	elif r < ROLL_BONUS:
		# 特別獎 — try to grant a random ingredient. If the player already
		# owns every option, fall back to the second-prize cash refund so
		# the bucket still feels like "good luck".
		grant_id = _pick_prize_ingredient()
		if grant_id.is_empty():
			refund = REFUND_SECOND
			pool = LINES_SECOND
		else:
			pool = ["特別獎！送你一個 %s！" % Inventory.display_name(grant_id)]
	else:
		refund = REFUND_FIRST
		pool = LINES_FIRST
	if refund > 0:
		Inventory.money += refund
		Inventory.money_changed.emit(Inventory.money)
	if not grant_id.is_empty():
		Inventory.grant_ingredient(grant_id)
		_celebrate_burst(Color("#F2A227"))
	elif refund >= REFUND_SECOND:
		_celebrate_burst(Color(COLOR_BOX_GOLD))
	var line: String = pool[randi() % pool.size()]
	Dialogue.show([line])


## Picks an ingredient the player doesn't already own. Returns "" if every
## prize-pool ingredient is already owned (player swept the market).
func _pick_prize_ingredient() -> String:
	var available: Array[String] = []
	for id in PRIZE_INGREDIENT_POOL:
		if not Inventory.has(id):
			available.append(id)
	if available.is_empty():
		return ""
	return available[randi() % available.size()]


func _celebrate_burst(color: Color) -> void:
	var burst: ParticleBurst = ParticleBurst.new()
	burst.position = Vector2(0.0, -2.0)
	burst.count = 12
	burst.color = color
	burst.lifetime = 0.6
	burst.gravity_scale = 0.4
	burst.upward_bias = 0.6
	add_child(burst)
	if Sfx.has_method("play_pickup"):
		Sfx.play_pickup()


func _say_random(pool: Array[String]) -> void:
	if pool.is_empty():
		return
	Dialogue.show([pool[randi() % pool.size()]])


# ---------------------------------------------------------------------------
# Drawing — festive red+gold lottery box
# ---------------------------------------------------------------------------

func _draw() -> void:
	var bob: float = _idle_bob_offset()
	var half: float = NPC_SIZE / 2.0
	# Box body (square, mostly red)
	draw_rect(Rect2(-half + 1.0, -half + 3.0 + bob, NPC_SIZE - 2.0,
		NPC_SIZE - 3.0), COLOR_BOX_RED)
	# Gold lid running across the top
	draw_rect(Rect2(-half + 1.0, -half + 3.0 + bob, NPC_SIZE - 2.0, 2.0),
		COLOR_BOX_GOLD)
	# Dark seam between lid and body
	draw_rect(Rect2(-half + 1.0, -half + 5.0 + bob, NPC_SIZE - 2.0, 1.0),
		COLOR_BOX_DARK)
	# Gold trim on the sides for festive shine
	draw_rect(Rect2(-half + 1.0, -half + 6.0 + bob, 1.0, NPC_SIZE - 6.0),
		COLOR_BOX_GOLD)
	draw_rect(Rect2(half - 2.0, -half + 6.0 + bob, 1.0, NPC_SIZE - 6.0),
		COLOR_BOX_GOLD)
	# Coin slot — single dark line on top of the lid
	draw_rect(Rect2(-2.0, -half + 4.0 + bob, 4.0, 1.0), COLOR_BOX_DARK)
	# Banner above the box — small triangular pennant strip
	draw_rect(Rect2(-half - 1.0, -half - 2.0 + bob, NPC_SIZE + 2.0, 2.0),
		COLOR_BANNER)
	draw_rect(Rect2(-half - 1.0, -half - 2.0 + bob, 1.0, 1.0), COLOR_BOX_GOLD)
	draw_rect(Rect2(half, -half - 2.0 + bob, 1.0, 1.0), COLOR_BOX_GOLD)
	# Spinning prize wheel up on top of the box (a single bright pixel
	# rotating around a 2-pixel ring) — sells the "lottery" idea.
	var spin_phase: float = _spin_t * 4.0
	var sx: float = roundf(cos(spin_phase) * 2.0)
	var sy: float = roundf(sin(spin_phase) * 1.0)
	draw_rect(Rect2(sx - 1.0, -half + 1.0 + sy + bob, 1.0, 1.0),
		COLOR_BOX_GOLD)
	# Centre 1px paper "獎" placeholder on the box front
	draw_rect(Rect2(-2.0, 0.0 + bob, 4.0, 4.0), COLOR_PAPER)
	draw_rect(Rect2(-1.0, 1.0 + bob, 2.0, 2.0), COLOR_BANNER)
