## Player money + ingredient inventory for Night Market Shopping (R-005).
##
## Pure state class. The HUD subscribes to its signals; StallNPC mutates
## via `buy()`; MomNPC checks `has_all_required()` for the win condition.
extends Node

# ---------------------------------------------------------------------------
# Signals
# ---------------------------------------------------------------------------

signal money_changed(new_money: int)
signal ingredient_added(ingredient_id: String)

# ---------------------------------------------------------------------------
# Constants — tuning per design/gdd/game-concept-rpg.md §7
# ---------------------------------------------------------------------------

const STARTING_MONEY: int = 200

## The 5 ingredients the player must collect to win.
const REQUIRED_INGREDIENTS: PackedStringArray = [
	"scallion", "egg", "cabbage", "chicken", "soy_sauce"
]

## CJK display names for the ingredient ids above.
const INGREDIENT_DISPLAY: Dictionary = {
	"scallion": "蔥",
	"egg": "蛋",
	"cabbage": "高麗菜",
	"chicken": "雞肉",
	"soy_sauce": "醬油",
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


## True iff every id in REQUIRED_INGREDIENTS has been collected.
func has_all_required() -> bool:
	for id in REQUIRED_INGREDIENTS:
		if not has(id):
			return false
	return true


## Resets money and inventory back to the start of a fresh run.
## Called by R-009's title screen on START press.
func reset() -> void:
	money = STARTING_MONEY
	ingredients = {}
	money_changed.emit(money)


## Returns the CJK display name for an ingredient id.
func display_name(ingredient_id: String) -> String:
	return INGREDIENT_DISPLAY.get(ingredient_id, ingredient_id)
