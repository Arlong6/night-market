## Player money + ingredient inventory for Night Market Shopping (R-005).
##
## v0.7: 7 stalls in the market, but mum only needs ANY 5 — the player
## chooses what mix to buy. STARTING_MONEY = 180 forces at least one
## successful 殺價 (or skipping the most expensive items) to make budget.
##
## Pure state class. The HUD subscribes to its signals; StallNPC mutates
## via `buy()`; MomNPC checks `has_enough()` for the win condition.
extends Node

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

signal money_changed(new_money: int)
signal ingredient_added(ingredient_id: String)

# ---------------------------------------------------------------------------
# Constants — tuning per design/gdd/game-concept-rpg.md §7
# ---------------------------------------------------------------------------

const STARTING_MONEY: int = 180

## All sellable ingredients in the market. The player can buy any of them
## but only needs REQUIRED_COUNT of them to complete the quest.
const ALL_INGREDIENTS: PackedStringArray = [
	"scallion", "egg", "cabbage", "chicken", "soy_sauce", "tofu", "mushroom"
]

## How many distinct ingredients mum demands. Win condition: count() >= this.
const REQUIRED_COUNT: int = 5

## CJK display names for the ingredient ids above.
const INGREDIENT_DISPLAY: Dictionary = {
	"scallion": "蔥",
	"egg": "蛋",
	"cabbage": "高麗菜",
	"chicken": "雞肉",
	"soy_sauce": "醬油",
	"tofu": "豆腐",
	"mushroom": "香菇",
}

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

var money: int = STARTING_MONEY

## Maps ingredient_id → true once owned. Boolean is enough for this slice
## (no stack counts, no expiry).
var ingredients: Dictionary[String, bool] = {}

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## True iff the named ingredient has been collected.
func has(ingredient_id: String) -> bool:
	return ingredients.get(ingredient_id, false)


## True iff current money is at least `price`.
func can_afford(price: int) -> bool:
	return money >= price


## Attempts a purchase. Fails (returns false) if can't afford OR already owned.
## On success: deducts money, marks ingredient owned, emits both signals.
func buy(ingredient_id: String, price: int) -> bool:
	if has(ingredient_id):
		return false
	if not can_afford(price):
		return false
	money -= price
	ingredients[ingredient_id] = true
	money_changed.emit(money)
	ingredient_added.emit(ingredient_id)
	return true


## How many distinct ingredients have been collected so far.
func ingredient_count() -> int:
	return ingredients.size()


## True iff the player has bought at least REQUIRED_COUNT ingredients.
## (Pre-v0.7 this was `has_all_required()` — kept as alias below.)
func has_enough() -> bool:
	return ingredient_count() >= REQUIRED_COUNT


## Legacy alias used by older callsites/tests. Same semantics as has_enough().
func has_all_required() -> bool:
	return has_enough()


## v0.12: true iff every single ingredient (all 7) has been bought.
## Triggers the 滿漢全席 perfect ending branch.
func has_all() -> bool:
	return ingredient_count() >= ALL_INGREDIENTS.size()


## Returns owned ingredient ids (in ALL_INGREDIENTS order, not insertion order),
## handy for the end-screen ingredient list.
func owned_ingredients() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for id in ALL_INGREDIENTS:
		if has(id):
			out.append(id)
	return out


## Resets money and inventory back to the start of a fresh run.
## Called by R-009's title screen on START press.
func reset() -> void:
	money = STARTING_MONEY
	ingredients = {}
	money_changed.emit(money)


## Returns the CJK display name for an ingredient id.
func display_name(ingredient_id: String) -> String:
	return INGREDIENT_DISPLAY.get(ingredient_id, ingredient_id)
