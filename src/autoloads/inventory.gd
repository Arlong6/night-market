## Player money + ingredient inventory for Night Market Shopping (R-005).
##
## v0.13: mum now requests a SPECIFIC random 5-of-7 each run instead of "any
## 5". The picked list lives in `required_ingredients` (regenerated on reset)
## and drives the HUD checklist + the home_intro dialogue. STARTING_MONEY
## bumped 180→220 to keep most random selections feasible while still leaving
## bargain pressure on the expensive end.
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

const STARTING_MONEY: int = 220

## All sellable ingredients in the market. The player can buy any of them
## but only needs REQUIRED_COUNT of them to complete the quest.
const ALL_INGREDIENTS: PackedStringArray = [
	"scallion", "egg", "cabbage", "chicken", "soy_sauce", "tofu", "mushroom"
]

## How many distinct ingredients mum demands. Win condition: every entry of
## `required_ingredients` has been bought.
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

## v0.13: 1-CJK-char abbreviations used by the HUD checklist (where the full
## display name is too wide). Falls back to display_name if missing.
const INGREDIENT_ABBREV: Dictionary = {
	"scallion": "蔥",
	"egg": "蛋",
	"cabbage": "菜",
	"chicken": "雞",
	"soy_sauce": "醬",
	"tofu": "腐",
	"mushroom": "菇",
}

## v0.15: dish recipes — kitchen + end_screen call cooked_dishes() to render
## the night's menu based on what was actually bought. Each dish lists the
## ingredient ids it needs; if all of them are owned, the dish "cooks". The
## list is ordered by display priority (more impressive dishes first), so a
## perfect run that matches every recipe shows 三杯雞 ahead of a side dish.
const RECIPES: Array[Dictionary] = [
	{ "name": "三杯雞",       "needs": ["chicken", "soy_sauce", "scallion"] },
	{ "name": "醬油雞",       "needs": ["chicken", "soy_sauce"] },
	{ "name": "蔥蛋",         "needs": ["scallion", "egg"] },
	{ "name": "香菇炒蛋",     "needs": ["mushroom", "egg"] },
	{ "name": "紅燒豆腐",     "needs": ["tofu", "soy_sauce"] },
	{ "name": "豆腐高麗菜湯", "needs": ["tofu", "cabbage"] },
	{ "name": "清炒高麗菜",   "needs": ["cabbage"] },
]

## v0.15: cap the dish list shown in UI so a perfect run doesn't overflow.
const MAX_DISHES_DISPLAYED: int = 3

# ---------------------------------------------------------------------------
# State
# ---------------------------------------------------------------------------

var money: int = STARTING_MONEY

## Maps ingredient_id → true once owned. Boolean is enough for this slice
## (no stack counts, no expiry).
var ingredients: Dictionary[String, bool] = {}

## v0.13: the specific 5 ingredients mum requested for this run. Populated
## by `randomize_required()` on every `reset()`, also seeded on _ready so
## that HUD/intro reads before any reset still get a valid list.
var required_ingredients: PackedStringArray = PackedStringArray()


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	if required_ingredients.is_empty():
		randomize_required()


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


## v0.13: true iff the given id is in the random required-list for this run.
## HUD uses this to decide which ingredients show on the checklist.
func is_required(id: String) -> bool:
	return id in required_ingredients


## v0.13: how many of the random required-list have been bought so far.
## Drives the HUD's "N/5" progress counter.
func required_owned_count() -> int:
	var n: int = 0
	for id in required_ingredients:
		if has(id):
			n += 1
	return n


## True iff every entry in `required_ingredients` has been bought. v0.13
## replaced the old "any-5-of-7" semantics with "the specific 5 mum asked
## for". Win condition for MomNPC.
func has_enough() -> bool:
	if required_ingredients.is_empty():
		return false
	for id in required_ingredients:
		if not has(id):
			return false
	return true


## Legacy alias used by older callsites/tests. Same semantics as has_enough().
func has_all_required() -> bool:
	return has_enough()


## v0.12: true iff every single ingredient (all 7) has been bought.
## Triggers the 滿漢全席 perfect ending branch.
func has_all() -> bool:
	return ingredient_count() >= ALL_INGREDIENTS.size()


## v0.13: shuffles ALL_INGREDIENTS and picks REQUIRED_COUNT of them as the
## random shopping list for this run. Called on every `reset()`.
func randomize_required() -> void:
	var pool: Array[String] = []
	for id in ALL_INGREDIENTS:
		pool.append(id)
	pool.shuffle()
	var picked: PackedStringArray = PackedStringArray()
	for i in REQUIRED_COUNT:
		picked.append(pool[i])
	required_ingredients = picked


## Returns owned ingredient ids (in ALL_INGREDIENTS order, not insertion order),
## handy for the end-screen ingredient list.
func owned_ingredients() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for id in ALL_INGREDIENTS:
		if has(id):
			out.append(id)
	return out


## Resets money and inventory back to the start of a fresh run.
## Called by R-009's title screen on START press. v0.13 also re-rolls the
## required-ingredient list so each run is a different shopping puzzle.
func reset() -> void:
	money = STARTING_MONEY
	ingredients = {}
	randomize_required()
	money_changed.emit(money)


## Returns the CJK display name for an ingredient id.
func display_name(ingredient_id: String) -> String:
	return INGREDIENT_DISPLAY.get(ingredient_id, ingredient_id)


## v0.13: 1-CJK-char abbreviation for HUD checklists. Falls back to display
## name when missing.
func display_abbrev(ingredient_id: String) -> String:
	return INGREDIENT_ABBREV.get(ingredient_id, display_name(ingredient_id))


## v0.15: returns the names of every dish whose ingredient list is fully
## owned, in RECIPES order, capped to MAX_DISHES_DISPLAYED. Returns an empty
## array if nothing matches — caller decides the fallback name.
func cooked_dishes() -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for recipe in RECIPES:
		if out.size() >= MAX_DISHES_DISPLAYED:
			break
		var needs: Array = recipe["needs"]
		var ok: bool = true
		for id in needs:
			if not has(id):
				ok = false
				break
		if ok:
			out.append(recipe["name"])
	return out
