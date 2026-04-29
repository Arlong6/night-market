## Vendor stall NPC for Night Market Shopping (R-006).
##
## Sells one ingredient at a fixed price. On bump:
##   1. Show intro line(s) (typewriter)
##   2. After advance, ask "買 [食材] NT$XX？ 是/否"
##   3. If 是 + affordable + new → Inventory.buy() + sparkle FX + "好喔，多謝！"
##   4. If 是 + can't afford → "錢不夠喔，下次再來"
##   5. If 否 → "好啦，看看就好"
##   6. Once sold, future bumps show sold_out_lines instead of intro
class_name StallNPC
extends NPC

# ---------------------------------------------------------------------------
# Exports
# ---------------------------------------------------------------------------

@export var ingredient_id: String = ""
@export var price: int = 0

## Lines spoken before the buy prompt on first bump.
@export var intro_lines: Array[String] = ["看看吧！"]

## Lines spoken on subsequent bumps after the sale completes.
@export var sold_out_lines: Array[String] = ["再來啊"]

## Multiplier applied to price on the buy prompt. 1.0 = full price,
## 0.8 = 20% discount. Set by the level if this stall is the daily-discount
## pick. Doesn't change `price` itself so display logic can show the original.
@export var discount: float = 1.0

## Whether the player has already bargained at this stall this run.
## Once true, the 殺價 option disappears from the buy prompt.
var _bargained: bool = false

# ---------------------------------------------------------------------------
# v0.20 — vendor loyalty (across runs)
# ---------------------------------------------------------------------------

## Loyalty thresholds — `purchase_count >= threshold` selects this tier.
## Tier 0 = stranger, tier 3 = old friend. Discount is multiplicative on top
## of the per-run `discount` and any bargain result.
const LOYALTY_THRESHOLDS: PackedInt32Array = [0, 1, 3, 6]
const LOYALTY_DISCOUNTS: PackedFloat32Array = [1.0, 0.95, 0.90, 0.85]

## Greeting line per tier — overrides the configured intro_lines on bump
## when the player has visited before. Tier 0 falls through to intro_lines.
const LOYALTY_GREETINGS: Array[String] = [
	"",                       # 0 — first visit, use intro_lines
	"啊，上次來過齁～",        # 1 — recognised
	"又是你～小弟弟。",        # 2 — semi-regular
	"老朋友來啦！算你便宜～",  # 3 — regular
]

## Color of the heart marker that floats above stalls where the player
## hits tier ≥ 1 — small visual cue that this stall remembers them.
const COLOR_LOYALTY_HEART: Color = Color("#F2A227")

# ---------------------------------------------------------------------------
# Constants — visual identity
# ---------------------------------------------------------------------------

const COLOR_STALL_BODY: Color = Color("#D94F2B")  ## stall red (vendor)
const COLOR_STALL_TOP: Color = Color("#F2A227")   ## food highlight stripe

## Default awning stripes — used when an ingredient has no entry in
## AWNING_PALETTE. Match the original v0.5 chicken stall.
const COLOR_AWNING_A: Color = Color("#C2241A")    ## awning stripe — deep red
const COLOR_AWNING_B: Color = Color("#F5EDDA")    ## awning stripe — cream

## v0.26: per-ingredient awning palette so the market reads as variety,
## not "rows of red boxes". Each entry is [stripe_a, stripe_b]; stripe_a
## is the heavier / saturated one, stripe_b the lighter alternate. Picked
## to evoke each ingredient's identity (e.g. tofu = cream + grey, chicken
## = red + amber, soy_sauce = dark brown + amber).
const AWNING_PALETTE: Dictionary = {
	"chicken":   [Color("#C2241A"), Color("#F5EDDA")],  # red + cream (signature)
	"egg":       [Color("#F2A227"), Color("#FFE9B0")],  # amber + pale yolk
	"scallion":  [Color("#3A6A2A"), Color("#C8E66D")],  # forest + scallion-green
	"cabbage":   [Color("#5A8030"), Color("#B8E890")],  # mid-green + leaf-light
	"tofu":      [Color("#888888"), Color("#F5EDDA")],  # grey + cream (clean)
	"soy_sauce": [Color("#3A1A0A"), Color("#F2A227")],  # dark brown + amber
	"mushroom":  [Color("#5A3018"), Color("#A06A4A")],  # mushroom dark + tan
}

# ---------------------------------------------------------------------------
# v0.26 — hanging price tag
# ---------------------------------------------------------------------------

const COLOR_TAG_BG: Color = Color("#F5EDDA")        ## tag cream
const COLOR_TAG_BORDER: Color = Color("#3A1A0A")    ## tag border ink
const COLOR_TAG_TEXT: Color = Color("#3A1A0A")      ## price text ink
const COLOR_TAG_SOLD_BG: Color = Color("#5A4030")   ## tag faded brown when sold
const COLOR_TAG_SOLD_TEXT: Color = Color("#888888") ## sold text grey

const TAG_WIDTH: int = 18
const TAG_HEIGHT: int = 9

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

var _sold: bool = false

## Cached CJK font for the price-tag draw call. Loaded once in _ready so
## `_draw` doesn't pay the load cost every frame. Test mode skips load.
var _tag_font: FontFile = null


func _ready() -> void:
	super._ready()
	if not Game.test_mode:
		_tag_font = load("res://assets/fonts/jf-openhuninn-2.1.ttf") as FontFile
		if _tag_font != null:
			_tag_font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
			_tag_font.subpixel_positioning = (
				TextServer.SUBPIXEL_POSITIONING_DISABLED
			)

# ---------------------------------------------------------------------------
# Override draw — stall body + 2px gold top stripe
# ---------------------------------------------------------------------------

func _draw_color() -> Color:
	return COLOR_STALL_BODY


## Maps each ingredient_id to a small icon colour drawn floating above the stall.
const FOOD_ICON_COLOR: Dictionary = {
	"scallion":  Color("#7AC940"),  # green
	"egg":       Color("#FFE9B0"),  # cream
	"cabbage":   Color("#9EE070"),  # pale green
	"chicken":   Color("#C58A4A"),  # tan
	"soy_sauce": Color("#3A1A0A"),  # dark brown
	"tofu":      Color("#F8F0D8"),  # off-white tofu
	"mushroom":  Color("#7A4A2A"),  # mushroom brown
}


func _draw() -> void:
	var half: float = NPC_SIZE / 2.0
	var bob_y: float = _idle_bob_offset()

	# Body fill (the stall counter)
	draw_rect(Rect2(-half, -half + bob_y, NPC_SIZE, NPC_SIZE), COLOR_STALL_BODY)
	# Top stripe (food highlight, 2px tall) — sits on top of body
	draw_rect(Rect2(-half, -half + bob_y, NPC_SIZE, 2.0), COLOR_STALL_TOP)
	# Wood-grain highlight: 1px horizontal lighter strip mid-counter
	draw_rect(Rect2(-half + 1.0, 4.0 + bob_y, NPC_SIZE - 2.0, 1.0),
		COLOR_STALL_BODY.lightened(0.2))

	# Awning — 2 angled striped panels hovering above the stall, evoking the
	# canvas-tarp covers you'd see at every Taiwan night-market booth.
	# v0.26: stripe pair varies per ingredient via AWNING_PALETTE.
	var awning_y: float = -half - 4.0 + bob_y
	var palette: Array = _awning_palette()
	var stripe_a: Color = palette[0]
	var stripe_b: Color = palette[1]
	for i in 4:
		var x: float = -half + float(i) * 4.0
		var c: Color = stripe_a if i % 2 == 0 else stripe_b
		draw_rect(Rect2(x, awning_y, 4.0, 2.0), c)
	# Awning bottom hem — 1px dark line for definition
	draw_rect(Rect2(-half, awning_y + 2.0, NPC_SIZE, 1.0), Color("#2A1A0A"))

	# Floating food icon — a 4×4 colored chip suspended below the awning.
	# v0.17: when sold out, the chip greys out and gets a strikethrough so
	# the player gets clear "already bought" feedback at a glance.
	var raw_color: Color = FOOD_ICON_COLOR.get(ingredient_id, Color("#FFFFFF"))
	var icon_color: Color = (
		Color("#888888") if _sold else raw_color
	)
	var icon_y: float = awning_y + 4.0
	draw_rect(Rect2(-2.0, icon_y, 4.0, 4.0), icon_color)
	# Icon outline (1px ink border, top + bottom)
	draw_rect(Rect2(-2.0, icon_y, 4.0, 1.0), Color("#2A1A0A"))
	draw_rect(Rect2(-2.0, icon_y + 3.0, 4.0, 1.0), Color("#2A1A0A"))
	if _sold:
		# Diagonal strikethrough — a 2-pixel line across the icon.
		draw_rect(Rect2(-2.0, icon_y + 1.0, 4.0, 1.0), Color("#2A1A0A"))

	# v0.26: hanging price tag mounted on the lower half of the counter.
	# Reads NT$XX while available, "完售" + brown bg once sold. Drawn after
	# the body so it occludes the wood-grain stripe.
	_draw_price_tag(bob_y)

	# v0.20: regulars get a small heart sitting above the awning so the
	# player can see at a glance which stalls remember them. Heart bobs
	# in time with the awning so it looks attached.
	var tier: int = _loyalty_tier()
	if tier >= 1:
		var heart_y: float = awning_y - 4.0
		# 3-pixel stylised heart — two top dots + a bottom point
		draw_rect(Rect2(-2.0, heart_y, 1.0, 1.0), COLOR_LOYALTY_HEART)
		draw_rect(Rect2(0.0, heart_y, 1.0, 1.0), COLOR_LOYALTY_HEART)
		draw_rect(Rect2(-2.0, heart_y + 1.0, 3.0, 1.0), COLOR_LOYALTY_HEART)
		draw_rect(Rect2(-1.0, heart_y + 2.0, 1.0, 1.0), COLOR_LOYALTY_HEART)


# ---------------------------------------------------------------------------
# Bump handler
# ---------------------------------------------------------------------------

func on_bumped() -> void:
	if _sold:
		Dialogue.show(sold_out_lines)
		return
	# v0.20: regulars get a personalised greeting before the buy prompt
	# instead of the generic intro_lines.
	var greeting_lines: Array[String] = _greeting_lines_for_tier(_loyalty_tier())
	var on_intro_done: Callable = func() -> void: _open_buy_choice()
	Dialogue.show(greeting_lines, on_intro_done)


## v0.20: maps the current cross-run purchase count to one of 4 loyalty tiers.
## Tier 0 = first visit, tier 3 = old friend. Used for both greeting and
## discount selection.
func _loyalty_tier() -> int:
	var count: int = HiScore.purchase_count(ingredient_id)
	var tier: int = 0
	for i in LOYALTY_THRESHOLDS.size():
		if count >= LOYALTY_THRESHOLDS[i]:
			tier = i
	return tier


## v0.20: multiplier applied on top of `discount` and bargain results so
## the regular keeps getting a small extra cut off the listed price.
func _loyalty_discount() -> float:
	var tier: int = _loyalty_tier()
	if tier < LOYALTY_DISCOUNTS.size():
		return LOYALTY_DISCOUNTS[tier]
	return 1.0


## Returns the dialogue lines used as the bump intro for the current
## loyalty tier. Tier 0 falls through to a random line from intro_lines.
## v0.23: intro_lines is now a POOL — pick one per bump for variety.
func _greeting_lines_for_tier(tier: int) -> Array[String]:
	if tier <= 0 or tier >= LOYALTY_GREETINGS.size():
		return _pick_random_intro()
	var line: String = LOYALTY_GREETINGS[tier]
	if line.is_empty():
		return _pick_random_intro()
	var out: Array[String] = [line]
	return out


## v0.23: picks a single intro line at random from the configured pool.
## Pool of size 1 always returns that line (backwards compat).
func _pick_random_intro() -> Array[String]:
	if intro_lines.is_empty():
		return ["..."]
	var picked: String = intro_lines[randi() % intro_lines.size()]
	var out: Array[String] = [picked]
	return out


func _open_buy_choice() -> void:
	var label: String = Inventory.display_name(ingredient_id)
	var effective: int = effective_price()
	var question: String
	if discount < 0.999:
		question = "買 %s NT$%d (打折！原價 %d)？" % [label, effective, price]
	else:
		question = "買 %s NT$%d？" % [label, effective]

	# 3-way prompt while bargain is still available; collapses to 2-way after.
	var options: Array[String]
	if _bargained:
		options = ["是", "否"]
	else:
		options = ["是", "殺價", "否"]
	Dialogue.ask_choice(question, options, _on_choice)


## Current price after the discount + loyalty multipliers (rounded to NT$).
## v0.20: loyalty discount stacks multiplicatively on top of `discount`
## (which itself stacks the daily-special slot + any bargain success).
func effective_price() -> int:
	return int(roundf(float(price) * discount * _loyalty_discount()))


func _on_choice(index: int) -> void:
	# Index ↔ option label depends on whether bargain is still on the table.
	if _bargained:
		# 2-way: 是 / 否
		if index == 0:
			_attempt_buy()
		else:
			Dialogue.show(["好啦，看看就好"])
	else:
		# 3-way: 是 / 殺價 / 否
		match index:
			0: _attempt_buy()
			1: _start_bargain()
			_: Dialogue.show(["好啦，看看就好"])


# ---------------------------------------------------------------------------
# Bargain mini-game — 50/50 roll. Success: discount stacks an extra 20% off.
# Failure: surcharge of 10%. Either way, the bargain option is consumed.
# ---------------------------------------------------------------------------

func _start_bargain() -> void:
	_bargained = true
	Game.bargain_count += 1   # v0.12: tracks for no-bargain achievement
	# v0.22: skill-based bargain. Test mode uses a deterministic legacy roll
	# (matches the v0.7.1 60% chance) so existing tests stay green.
	if Game.test_mode:
		_apply_bargain_tier(2 if randf() < 0.6 else 0)
		return
	# Spawn the meter on the level (this NPC's parent) so it lives at the
	# scene level rather than under this NPC.
	var parent: Node = get_parent()
	if parent == null:
		_apply_bargain_tier(0)
		return
	var meter: BargainMeter = BargainMeter.new()
	meter.resolved.connect(_apply_bargain_tier)
	parent.add_child(meter)


## v0.22: outcome of the bargain minigame mapped to discount / line.
##   tier 0 → fail   (+10%)   "你這小鬼，貴 10%！"
##   tier 1 → partial (-10%)  "好吧，給你 10% 吧～"
##   tier 2 → jackpot (-20%)  "好啦好啦，再 20% 給你！"
func _apply_bargain_tier(tier: int) -> void:
	var line: String
	match tier:
		2:
			discount = maxf(discount * 0.8, 0.5)
			line = "好啦好啦，再 20%% 給你！"  # %% → %
		1:
			discount = maxf(discount * 0.9, 0.5)
			line = "好吧，給你 10%% 吧～"
		_:
			discount = minf(discount * 1.1, 1.5)
			line = "你這小鬼，貴 10%%！"
	var on_done: Callable = func() -> void: _open_buy_choice()
	Dialogue.show([line], on_done)


func _attempt_buy() -> void:
	var pay: int = effective_price()
	if not Inventory.can_afford(pay):
		Dialogue.show(["錢不夠喔，下次再來"])
		return
	if Inventory.buy(ingredient_id, pay):
		_sold = true
		_spawn_sparkle()
		Sfx.play_buy()
		# v0.20: bump the cross-run loyalty count for this vendor.
		HiScore.record_purchase(ingredient_id)
		Dialogue.show(["好喔，多謝！"])


## v0.26: returns this stall's awning stripe pair as [stripe_a, stripe_b].
## Falls back to the default red+cream when ingredient_id has no entry —
## defensive against unknown IDs.
func _awning_palette() -> Array:
	if AWNING_PALETTE.has(ingredient_id):
		return AWNING_PALETTE[ingredient_id]
	return [COLOR_AWNING_A, COLOR_AWNING_B]


## v0.26: hanging price-tag draw. Mounts on the bottom half of the counter
## with the current effective price, swaps to "完售" once `_sold` flips.
## Skips the text in test_mode (font isn't loaded then) so headless tests
## don't pay for the draw_string call.
func _draw_price_tag(bob_y: float) -> void:
	var tag_w: float = float(TAG_WIDTH)
	var tag_h: float = float(TAG_HEIGHT)
	var tag_x: float = -tag_w * 0.5
	var tag_y: float = 0.0 + bob_y
	var bg: Color = COLOR_TAG_SOLD_BG if _sold else COLOR_TAG_BG
	# Border (1px ink frame around the tag)
	draw_rect(Rect2(tag_x - 1.0, tag_y - 1.0, tag_w + 2.0, tag_h + 2.0),
		COLOR_TAG_BORDER)
	# Tag body
	draw_rect(Rect2(tag_x, tag_y, tag_w, tag_h), bg)
	# Mounting nails — two 1×1 dots on the corners for a hand-painted feel
	draw_rect(Rect2(tag_x + 1.0, tag_y + 1.0, 1.0, 1.0), COLOR_TAG_BORDER)
	draw_rect(Rect2(tag_x + tag_w - 2.0, tag_y + 1.0, 1.0, 1.0), COLOR_TAG_BORDER)
	# Text — centred horizontally; vertical alignment via baseline at tag bottom
	if _tag_font == null:
		return
	var text: String = "完售" if _sold else "NT$%d" % effective_price()
	var text_color: Color = COLOR_TAG_SOLD_TEXT if _sold else COLOR_TAG_TEXT
	draw_string(_tag_font,
		Vector2(tag_x, tag_y + tag_h - 1.0),
		text,
		HORIZONTAL_ALIGNMENT_CENTER,
		tag_w,
		7,
		text_color)


## Spawns a 6-particle gold burst at this stall's position. Particles are
## added as a sibling so they live on after this NPC continues to exist.
func _spawn_sparkle() -> void:
	var parent: Node = get_parent()
	if parent == null:
		return
	var burst: ParticleBurst = ParticleBurst.new()
	burst.position = position
	burst.count = 6
	burst.color = Color("#F2A227")
	burst.speed_min = 35.0
	burst.speed_max = 80.0
	burst.particle_size = 2.0
	burst.lifetime = 0.40
	burst.gravity_scale = 0.6
	burst.upward_bias = 0.6
	parent.add_child(burst)
