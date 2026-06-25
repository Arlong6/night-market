## TierData — defines the 8-tier merge chain for 一字一句.
##
## Tier 1 → Tier 8 progresses through nature → poem.
## Two glyphs of the same tier merge into one of tier+1.
## Reaching Tier 8 (詩) is the "watermelon" — biggest payoff.
class_name TierData
extends RefCounted

## 8 tiers, ordered from smallest/lowest to biggest/poem.
## Each entry: [char, color, radius]
## Radii scaled down 25% from initial design to give the field more breathing
## room (player feedback "stuck at top").
const TIERS: Array = [
	# tier 1 — rain droplet, smallest
	{"char": "雨", "color": Color(0.55, 0.70, 0.88, 1.0), "radius": 24.0},
	# tier 2 — dew
	{"char": "露", "color": Color(0.65, 0.78, 0.90, 1.0), "radius": 32.0},
	# tier 3 — stream
	{"char": "川", "color": Color(0.45, 0.65, 0.78, 1.0), "radius": 40.0},
	# tier 4 — river
	{"char": "江", "color": Color(0.32, 0.55, 0.68, 1.0), "radius": 50.0},
	# tier 5 — sea
	{"char": "海", "color": Color(0.22, 0.42, 0.55, 1.0), "radius": 60.0},
	# tier 6 — cloud
	{"char": "雲", "color": Color(0.88, 0.86, 0.92, 1.0), "radius": 72.0},
	# tier 7 — moon
	{"char": "月", "color": Color(0.96, 0.93, 0.72, 1.0), "radius": 84.0},
	# tier 8 — poem (final, "watermelon")
	{"char": "詩", "color": Color(1.0, 0.82, 0.42, 1.0), "radius": 98.0},
]

## How many tiers exist.
const TIER_COUNT: int = 8

## Tiers that can drop from the spawner (Suika rule: drops only the smallest few).
const DROPPABLE_TIERS: Array = [0, 1, 2, 3]  # tiers 1-4 (0-indexed)

## Score awarded on merging two same-tier glyphs into the next tier.
## Higher tier merges = exponentially more score.
const MERGE_SCORES: Array = [1, 3, 6, 12, 25, 50, 100, 250]

static func get_tier(t: int) -> Dictionary:
	if t < 0 or t >= TIERS.size():
		return TIERS[0]
	return TIERS[t]

static func get_char(t: int) -> String:
	return get_tier(t).get("char", "?")

static func get_color(t: int) -> Color:
	return get_tier(t).get("color", Color.WHITE)

static func get_radius(t: int) -> float:
	return get_tier(t).get("radius", 32.0)

static func score_for_merge(t: int) -> int:
	if t < 0 or t >= MERGE_SCORES.size():
		return 0
	return MERGE_SCORES[t]

static func is_max_tier(t: int) -> bool:
	return t >= TIER_COUNT - 1

static func pick_droppable_tier(rng: RandomNumberGenerator) -> int:
	# Weighted: lower tiers more common
	var weights: Array = [50, 30, 15, 5]  # T1=50%, T2=30%, T3=15%, T4=5%
	var total: int = 0
	for w in weights: total += w
	var roll: int = rng.randi_range(1, total)
	var acc: int = 0
	for i in weights.size():
		acc += weights[i]
		if roll <= acc:
			return DROPPABLE_TIERS[i]
	return DROPPABLE_TIERS[0]
