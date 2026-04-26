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


func _draw() -> void:
	# Body fill
	var half: float = NPC_SIZE / 2.0
	draw_rect(Rect2(-half, -half, NPC_SIZE, NPC_SIZE), COLOR_STALL_BODY)
	# Top stripe (food highlight, 2px tall)
	draw_rect(Rect2(-half, -half, NPC_SIZE, 2.0), COLOR_STALL_TOP)


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
	var question: String = "買 %s NT$%d？" % [label, price]
	Dialogue.ask_choice(question, ["是", "否"], _on_choice)


func _on_choice(index: int) -> void:
	if index == 0:
		_attempt_buy()
	else:
		Dialogue.show(["好啦，看看就好"])


func _attempt_buy() -> void:
	if not Inventory.can_afford(price):
		Dialogue.show(["錢不夠喔，下次再來"])
		return
	if Inventory.buy(ingredient_id, price):
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
