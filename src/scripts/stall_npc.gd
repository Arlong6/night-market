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
# Constants — visual identity
# ---------------------------------------------------------------------------

const COLOR_STALL_BODY: Color = Color("#D94F2B")  ## stall red (vendor)
const COLOR_STALL_TOP: Color = Color("#F2A227")   ## food highlight stripe

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

var _sold: bool = false

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
}


func _draw() -> void:
	# Body fill
	var half: float = NPC_SIZE / 2.0
	var bob_y: float = _idle_bob_offset()
	draw_rect(Rect2(-half, -half + bob_y, NPC_SIZE, NPC_SIZE), COLOR_STALL_BODY)
	# Top stripe (food highlight, 2px tall) — sits on top of body
	draw_rect(Rect2(-half, -half + bob_y, NPC_SIZE, 2.0), COLOR_STALL_TOP)

	# Floating food icon — a 4×4 colored chip 4px above the body
	var icon_color: Color = FOOD_ICON_COLOR.get(ingredient_id, Color("#FFFFFF"))
	# Icon also bobs but with a small phase offset to feel alive
	var icon_y: float = -half - 6.0 + bob_y
	draw_rect(Rect2(-2.0, icon_y, 4.0, 4.0), icon_color)
	# Icon outline (1px ink border)
	draw_rect(Rect2(-2.0, icon_y, 4.0, 1.0), Color("#2A1A0A"))
	draw_rect(Rect2(-2.0, icon_y + 3.0, 4.0, 1.0), Color("#2A1A0A"))


# ---------------------------------------------------------------------------
# Bump handler
# ---------------------------------------------------------------------------

func on_bumped() -> void:
	if _sold:
		Dialogue.show(sold_out_lines)
		return
	# Show intro then chain into the buy choice via on_done callback.
	var on_intro_done: Callable = func() -> void: _open_buy_choice()
	Dialogue.show(intro_lines, on_intro_done)


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


## Current price after the discount multiplier (rounded to integer NT$).
func effective_price() -> int:
	return int(roundf(float(price) * discount))


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
	var success: bool = randf() < 0.5
	if success:
		discount = maxf(discount * 0.8, 0.5)  # never below 50%
		var line: String = "好啦好啦，再 20%% 給你！"  # %% renders one %
		var on_done: Callable = func() -> void: _open_buy_choice()
		Dialogue.show([line], on_done)
	else:
		discount = minf(discount * 1.1, 1.5)  # cap at 150%
		var line: String = "你這小鬼，貴 10%%！"
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
		Dialogue.show(["好喔，多謝！"])


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
