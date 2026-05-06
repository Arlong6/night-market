## Umbrella vendor NPC for Night Market Shopping (v0.46).
##
## Spawns at a fixed cell near the market entrance on rainy / typhoon days
## only (ShilinMarket gates the spawn via Inventory.current_weather()).
## Sells one umbrella for UMBRELLA_PRICE NT$ — buying flips
## Inventory.has_umbrella so the player walks at full speed and renders an
## umbrella sprite.
##
## Drawn as a small kiosk topped with stacked umbrellas — visually distinct
## from the food stalls so the player can spot it immediately when they
## step into a wet market.
class_name UmbrellaVendor
extends NPC

# ---------------------------------------------------------------------------
# Visual constants
# ---------------------------------------------------------------------------

const COLOR_KIOSK_BODY: Color = Color("#2A4A6A")     ## navy plastic
const COLOR_KIOSK_TOP: Color = Color("#1A2A4A")      ## dark navy rim
const COLOR_KIOSK_FRONT: Color = Color("#3A5A7A")    ## front panel
const COLOR_BUCKET: Color = Color("#A8A8B0")         ## metal bucket holding stock
const COLOR_BUCKET_RIM: Color = Color("#5A5A60")
const UMBRELLA_DISPLAY_COLORS: Array[Color] = [
	Color("#C04848"),  ## red
	Color("#3A8AC0"),  ## blue
	Color("#D8C040"),  ## yellow
	Color("#A040A0"),  ## purple
]

# ---------------------------------------------------------------------------
# Public API — bump → buy prompt
# ---------------------------------------------------------------------------

func on_bumped() -> void:
	if Inventory.has_umbrella:
		Dialogue.show(["你已經買過傘了，路上小心啊！"])
		return
	if Inventory.current_weather() == Inventory.WEATHER_SUNNY:
		# Vendor shouldn't really be here on sunny days, but defend anyway.
		Dialogue.show(["今天不下雨，不用買傘啦！"])
		return
	if Inventory.money < Inventory.UMBRELLA_PRICE:
		Dialogue.show([
			"買一支傘吧，NT$%d" % Inventory.UMBRELLA_PRICE,
			"啊？錢不夠？那只好淋雨囉～",
		])
		return
	Dialogue.ask_choice(
		"來支傘嗎？NT$%d" % Inventory.UMBRELLA_PRICE,
		["是", "否"],
		_on_choice
	)


func _on_choice(idx: int) -> void:
	if idx != 0:
		Dialogue.show(["好啦，自己淋雨喔～"])
		return
	if not Inventory.buy_umbrella():
		# Race against money loss between prompt and confirm — fail soft.
		Dialogue.show(["欸？錢好像不夠了"])
		return
	# Sparkle FX — small blue burst around the kiosk.
	var burst: ParticleBurst = ParticleBurst.new()
	burst.position = Vector2.ZERO
	burst.count = 8
	burst.color = Color("#A0C4E0")
	burst.lifetime = 0.5
	burst.gravity_scale = 0.4
	burst.upward_bias = 0.6
	add_child(burst)
	if Sfx.has_method("play_pickup"):
		Sfx.play_pickup()
	Dialogue.show(["好嘞！這支傘很耐用喔～"])

# ---------------------------------------------------------------------------
# Drawing — small kiosk silhouette with stacked umbrellas on top
# ---------------------------------------------------------------------------

func _draw() -> void:
	var bob: float = _idle_bob_offset()
	var half: float = NPC_SIZE / 2.0
	# Kiosk body — slightly narrower than a stall so it reads "smaller booth".
	draw_rect(Rect2(-half + 1.0, -half + 2.0 + bob, NPC_SIZE - 2.0,
		NPC_SIZE - 2.0), COLOR_KIOSK_BODY)
	# Top rim
	draw_rect(Rect2(-half + 1.0, -half + 2.0 + bob, NPC_SIZE - 2.0, 2.0),
		COLOR_KIOSK_TOP)
	# Front panel highlight (where the kid hands money over)
	draw_rect(Rect2(-half + 2.0, 1.0 + bob, NPC_SIZE - 4.0, 2.0),
		COLOR_KIOSK_FRONT)
	# Bucket of umbrellas on top — a small silver pail
	var bucket_y: float = -half - 4.0 + bob
	draw_rect(Rect2(-3.0, bucket_y + 1.0, 6.0, 3.0), COLOR_BUCKET)
	draw_rect(Rect2(-4.0, bucket_y, 8.0, 1.0), COLOR_BUCKET_RIM)
	draw_rect(Rect2(-3.0, bucket_y + 4.0, 6.0, 1.0), COLOR_BUCKET_RIM)
	# Three umbrella tops poking out — one per stocked colour
	for i in 3:
		var ux: float = -2.5 + float(i) * 2.0
		var c: Color = UMBRELLA_DISPLAY_COLORS[i % UMBRELLA_DISPLAY_COLORS.size()]
		draw_rect(Rect2(ux, bucket_y - 2.0, 1.0, 2.0), c)
		# Tiny canopy bump
		draw_rect(Rect2(ux - 1.0, bucket_y - 2.0, 3.0, 1.0), c)
	# Sign — small price flag on the kiosk side
	draw_rect(Rect2(half - 4.0, -1.0 + bob, 4.0, 4.0), Color("#F5EDDA"))
	draw_rect(Rect2(half - 4.0, -1.0 + bob, 4.0, 1.0), Color("#2A1A0A"))
	# A red "傘" stripe to suggest the sign reads umbrella
	draw_rect(Rect2(half - 3.0, 0.5 + bob, 2.0, 1.0), Color("#C2241A"))
	draw_rect(Rect2(half - 3.0, 1.5 + bob, 2.0, 1.0), Color("#C2241A"))
