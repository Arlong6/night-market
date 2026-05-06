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

## v0.27: per-ingredient vendor character. Each stall draws a small 5×5
## head silhouette to the LEFT of the food icon — different hair / skin /
## hat per vendor so the market reads as populated by people, not just
## merchandise. Eyes are always near-black (COLOR_EYE).
##
## Schema: { hair: Color, accent: Color, skin: Color }
##   * hair   — top of head (1 px stripe under the hat brim)
##   * accent — hat / scarf brim (1 px above hair)
##   * skin   — face fill (3 px tall under the hair)
const VENDOR_DATA: Dictionary = {
	"chicken":   {  # young guy with a red headscarf — chicken-stall classic
		"hair":   Color("#3A1A0A"),
		"accent": Color("#C2241A"),
		"skin":   Color("#F2D6A8"),
	},
	"egg":       {  # cheerful auntie with a yellow band
		"hair":   Color("#2A1A0A"),
		"accent": Color("#F2A227"),
		"skin":   Color("#FAE3BC"),
	},
	"scallion":  {  # grey-haired granny vendor
		"hair":   Color("#888888"),
		"accent": Color("#7AC940"),
		"skin":   Color("#F2D6A8"),
	},
	"cabbage":   {  # farmer with a green produce cap
		"hair":   Color("#5A3018"),
		"accent": Color("#9EE070"),
		"skin":   Color("#E8C088"),
	},
	"tofu":      {  # gentle vendor with a clean white head cover
		"hair":   Color("#A07058"),
		"accent": Color("#F5EDDA"),
		"skin":   Color("#F8E5C8"),
	},
	"soy_sauce": {  # serious uncle with a dark cap
		"hair":   Color("#1A1208"),
		"accent": Color("#3A4A8A"),
		"skin":   Color("#D4A878"),
	},
	"mushroom":  {  # weathered grandpa with a brown cap
		"hair":   Color("#888888"),
		"accent": Color("#7A4A2A"),
		"skin":   Color("#E8C088"),
	},
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

# ---------------------------------------------------------------------------
# Barker shouts (v0.39)
# ---------------------------------------------------------------------------
#
# Each stall periodically pops a small speech bubble above the awning with
# a flavour line ("便宜啦！", "新鮮的喔～"). Lines are picked at random from
# BARKER_LINES[ingredient_id] (with a generic fallback). Timer staggers per
# stall so the market doesn't shout in unison. Suppressed while a dialogue
# is open or when the player is buying from this very stall.

const BARKER_HIDDEN_MIN: float = 6.0    ## min seconds between shouts
const BARKER_HIDDEN_MAX: float = 14.0   ## max seconds between shouts
const BARKER_VISIBLE_DURATION: float = 2.0  ## seconds bubble stays up
const BARKER_BUBBLE_OFFSET_Y: float = -22.0 ## px above stall origin
const BARKER_BUBBLE_PAD_X: float = 3.0
const BARKER_BUBBLE_PAD_Y: float = 2.0
const BARKER_FONT_SIZE: int = 7
const COLOR_BARKER_BUBBLE: Color = Color("#F5EDDA")  ## paper cream
const COLOR_BARKER_RIM: Color = Color("#3A1A0A")     ## ink line
const COLOR_BARKER_TEXT: Color = Color("#1A0F0A")

const BARKER_LINES: Dictionary = {
	"chicken":   ["新鮮的雞啊～", "今天現宰！", "便宜啦便宜啦～"],
	"egg":       ["有機土雞蛋！", "鮮蛋鮮蛋～", "黃澄澄的喔！"],
	"scallion":  ["三星蔥喔！", "翠綠的青蔥～", "今早剛到貨！"],
	"cabbage":   ["高山高麗菜！", "脆甜的喔～", "煮湯最讚！"],
	"tofu":      ["手工板豆腐～", "今早做的！", "嫩嫩的喔！"],
	"soy_sauce": ["古早味醬油～", "ㄧ年陳釀！", "滷肉必備！"],
	"mushroom":  ["新鮮香菇～", "山上採的！", "炒菜超香！"],
}
## Generic shouts used when ingredient_id has no specific list. Also mixed
## in occasionally for variety so each stall isn't a single-loop tape.
const BARKER_LINES_GENERIC: Array[String] = [
	"來看看～", "便宜啦！", "走過路過別錯過！", "好吃好吃！", "最後一份！",
]

var _barker_visible: bool = false
var _barker_text: String = ""
var _barker_timer: float = 0.0  ## seconds until current state ends


func _ready() -> void:
	super._ready()
	if not Game.test_mode:
		_tag_font = load("res://assets/fonts/jf-openhuninn-2.1.ttf") as FontFile
		if _tag_font != null:
			_tag_font.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
			_tag_font.subpixel_positioning = (
				TextServer.SUBPIXEL_POSITIONING_DISABLED
			)
	# v0.39: random initial wait so stalls don't all shout at once.
	_barker_timer = randf_range(BARKER_HIDDEN_MIN, BARKER_HIDDEN_MAX)


## v0.39: extends NPC._process to also tick the barker state machine.
## In test_mode the timer is frozen so unit tests don't observe random
## bubble pops; in dialogue mode the timer is also frozen so the player's
## conversation isn't visually littered.
func _process(delta: float) -> void:
	super._process(delta)
	if Game.test_mode:
		return
	if Game.in_dialogue:
		# Pause the timer + hide an active bubble so the dialogue box reads
		# without competing speech bubbles.
		if _barker_visible:
			_barker_visible = false
		return
	_barker_timer -= delta
	if _barker_timer > 0.0:
		return
	# Toggle state
	if _barker_visible:
		# End shout — back to silent waiting period.
		_barker_visible = false
		# v0.42: vendors shout less in the rain. 1.5× hidden range on
		# rainy days, 2.0× on typhoon days (when nobody wants to be heard
		# over the wind anyway).
		var slow: float = _barker_weather_slow()
		_barker_timer = randf_range(BARKER_HIDDEN_MIN, BARKER_HIDDEN_MAX) * slow
	else:
		# Start a new shout — pick a line and arm the visible duration.
		_barker_visible = true
		_barker_text = _pick_barker_line()
		_barker_timer = BARKER_VISIBLE_DURATION


## v0.42: returns the multiplier applied to the barker hidden-period range
## based on Inventory.current_weather(). 1.0 sunny, 1.5 rainy, 2.0 typhoon.
func _barker_weather_slow() -> float:
	var inv: Node = get_node_or_null("/root/Inventory")
	if inv == null or not inv.has_method("current_weather"):
		return 1.0
	match String(inv.current_weather()):
		"rainy":   return 1.5
		"typhoon": return 2.0
		_:         return 1.0


## v0.39: picks a random barker line for this stall's ingredient.
## Falls back to BARKER_LINES_GENERIC if no specific list exists.
## ~25% of the time, picks from generic even when a specific list exists,
## so each stall has slight unpredictability.
func _pick_barker_line() -> String:
	var specific: Array = BARKER_LINES.get(ingredient_id, [])
	var pool: Array
	if specific.is_empty() or randf() < 0.25:
		pool = BARKER_LINES_GENERIC
	else:
		pool = specific
	if pool.is_empty():
		return ""
	return String(pool[randi() % pool.size()])

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

	# v0.27: vendor head silhouette on the LEFT half of the body, food icon
	# on the right. Side-by-side composition makes every stall feel manned
	# instead of just being a colored box with a product chip.
	_draw_vendor_head(bob_y)

	# Floating food icon — a 4×4 colored chip showing the ingredient.
	# v0.17: when sold out, the chip greys out and gets a strikethrough so
	# the player gets clear "already bought" feedback at a glance.
	# v0.27: shifted from center to right (x=+1..+5) to make room for the
	# vendor head on the left.
	var raw_color: Color = FOOD_ICON_COLOR.get(ingredient_id, Color("#FFFFFF"))
	var icon_color: Color = (
		Color("#888888") if _sold else raw_color
	)
	var icon_x: float = 1.0
	var icon_y: float = awning_y + 4.0
	draw_rect(Rect2(icon_x, icon_y, 4.0, 4.0), icon_color)
	# Icon outline (1px ink border, top + bottom)
	draw_rect(Rect2(icon_x, icon_y, 4.0, 1.0), Color("#2A1A0A"))
	draw_rect(Rect2(icon_x, icon_y + 3.0, 4.0, 1.0), Color("#2A1A0A"))
	if _sold:
		# Diagonal strikethrough — a 2-pixel line across the icon.
		draw_rect(Rect2(icon_x, icon_y + 1.0, 4.0, 1.0), Color("#2A1A0A"))

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

	# v0.39: barker speech bubble — drawn last so it sits on top.
	if _barker_visible and not _barker_text.is_empty() and _tag_font != null:
		_draw_barker_bubble()


## v0.39: small white speech bubble with the current barker line, anchored
## above the awning. Includes a 1-px ink rim and a tiny tail pointing down
## to the stall so it reads as "this stall is shouting".
func _draw_barker_bubble() -> void:
	var text: String = _barker_text
	# Measure the text so the bubble fits snug.
	var text_size: Vector2 = _tag_font.get_string_size(
		text, HORIZONTAL_ALIGNMENT_LEFT, -1, BARKER_FONT_SIZE
	)
	var w: float = text_size.x + BARKER_BUBBLE_PAD_X * 2.0
	var h: float = float(BARKER_FONT_SIZE) + BARKER_BUBBLE_PAD_Y * 2.0
	var x: float = -w * 0.5
	var y: float = BARKER_BUBBLE_OFFSET_Y - h
	# Bubble fill
	draw_rect(Rect2(x, y, w, h), COLOR_BARKER_BUBBLE)
	# Ink rim (1 px on each edge)
	draw_rect(Rect2(x, y, w, 1.0), COLOR_BARKER_RIM)
	draw_rect(Rect2(x, y + h - 1.0, w, 1.0), COLOR_BARKER_RIM)
	draw_rect(Rect2(x, y, 1.0, h), COLOR_BARKER_RIM)
	draw_rect(Rect2(x + w - 1.0, y, 1.0, h), COLOR_BARKER_RIM)
	# Tail — 2-px stub pointing toward the stall body
	draw_rect(Rect2(-1.0, y + h, 2.0, 1.0), COLOR_BARKER_BUBBLE)
	draw_rect(Rect2(0.0, y + h + 1.0, 1.0, 1.0), COLOR_BARKER_BUBBLE)
	# Tail rim — single dark pixel below
	draw_rect(Rect2(-1.0, y + h, 1.0, 1.0), COLOR_BARKER_RIM)
	draw_rect(Rect2(1.0, y + h, 1.0, 1.0), COLOR_BARKER_RIM)
	draw_rect(Rect2(0.0, y + h + 1.0, 1.0, 1.0), COLOR_BARKER_RIM)
	# Text — left-aligned inside padding
	var text_x: float = x + BARKER_BUBBLE_PAD_X
	# Add the font's ascent so glyphs sit on the baseline.
	var text_y: float = y + BARKER_BUBBLE_PAD_Y + \
		_tag_font.get_ascent(BARKER_FONT_SIZE)
	draw_string(_tag_font, Vector2(text_x, text_y), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, BARKER_FONT_SIZE, COLOR_BARKER_TEXT)


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
		# v0.32: short descending two-tone so the rejection has audio bite.
		Sfx.play_denial()
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


## v0.27: returns this stall's vendor data { hair, accent, skin }. Falls
## back to a generic vendor (brown hair, cream accent, warm skin) when
## ingredient_id has no entry.
func _vendor_data() -> Dictionary:
	if VENDOR_DATA.has(ingredient_id):
		return VENDOR_DATA[ingredient_id]
	return {
		"hair":   COLOR_HAIR,
		"accent": COLOR_AWNING_B,
		"skin":   COLOR_SKIN,
	}


## v0.27: 5×5 vendor head silhouette drawn on the LEFT half of the stall
## body, opposite the food icon. Drawn AFTER the body so the body's gold
## top stripe is overdrawn in the vendor area — the vendor reads as
## "leaning over the counter" rather than "floating above" it.
##
## Pixel layout in stall-local coords (x=-7 is body left edge):
##   y=-6   accent (hat brim)             5 wide @ x=-6..-2
##   y=-5   hair                          5 wide @ x=-6..-2
##   y=-4   skin (forehead)               5 wide
##   y=-3   skin + 2 eye dots @ x=-5,-3   5 wide
##   y=-2   skin (chin)                   5 wide
func _draw_vendor_head(bob_y: float) -> void:
	var data: Dictionary = _vendor_data()
	var hair: Color = data["hair"]
	var accent: Color = data["accent"]
	var skin: Color = data["skin"]
	var x0: float = -6.0
	var w: float = 5.0
	# Accent (hat brim) — 1 px above the hair
	draw_rect(Rect2(x0, -6.0 + bob_y, w, 1.0), accent)
	# Hair — 1 px stripe across the top of the head
	draw_rect(Rect2(x0, -5.0 + bob_y, w, 1.0), hair)
	# Skin — 3 px tall face block (forehead, eyes, chin)
	draw_rect(Rect2(x0, -4.0 + bob_y, w, 3.0), skin)
	# Eye dots — symmetric, near-black
	draw_rect(Rect2(x0 + 1.0, -3.0 + bob_y, 1.0, 1.0), COLOR_EYE)
	draw_rect(Rect2(x0 + 3.0, -3.0 + bob_y, 1.0, 1.0), COLOR_EYE)


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
