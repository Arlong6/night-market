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

## v0.19: 7-day themed week. Each entry constrains how the random required
## list is generated for that day — `must_include` ingredients are forced
## into the list, `size` controls how many entries the list has total.
##
## Day-of-week is derived from `HiScore.day`: ((day - 1) % 7) → index here.
##   index 0 = Mon (家常日)
##   index 1 = Tue (湯品日)  …
##   index 6 = Sun (滿漢日)
const DAILY_THEMES: Array[Dictionary] = [
	{
		"key": "monday",   "label": "週一", "name": "家常日",
		"blurb": "媽媽今天想煮家常菜。",
		"must_include": [], "size": 5,
	},
	{
		"key": "tuesday",  "label": "週二", "name": "湯品日",
		"blurb": "今天想煮鍋暖湯。",
		"must_include": ["tofu", "cabbage"], "size": 5,
	},
	{
		"key": "wednesday","label": "週三", "name": "蛋日",
		"blurb": "今天用蛋當主角。",
		"must_include": ["egg"], "size": 5,
	},
	{
		"key": "thursday", "label": "週四", "name": "雞肉日",
		"blurb": "今天要煮雞肉。",
		"must_include": ["chicken", "soy_sauce"], "size": 5,
	},
	{
		"key": "friday",   "label": "週五", "name": "樸素日",
		"blurb": "三樣就好，吃簡單一點。",
		"must_include": [], "size": 3,
	},
	{
		"key": "saturday", "label": "週六", "name": "大菜日",
		"blurb": "週末多買幾樣加菜！",
		"must_include": [], "size": 6,
	},
	{
		"key": "sunday",   "label": "週日", "name": "滿漢日",
		"blurb": "週日大餐，全買齊吧！",
		"must_include": [], "size": 7,
	},
]

## Fallback used by `current_theme()` when HiScore isn't reachable yet
## (e.g. during autoload init order).
const DEFAULT_THEME: Dictionary = {
	"key": "monday", "label": "週一", "name": "家常日",
	"blurb": "媽媽今天想煮家常菜。",
	"must_include": [], "size": 5,
}

# ---------------------------------------------------------------------------
# v0.23 — festivals (rare special days that override the weekly theme)
# ---------------------------------------------------------------------------

const FESTIVAL_NONE: String = ""
const FESTIVAL_MID_AUTUMN: String = "mid_autumn"  ## 中秋節 — every 30 days @ +14
const FESTIVAL_NEW_YEAR: String = "new_year"      ## 過年 — every 30 days @ +29

## Day-of-month index that triggers each festival inside a 30-day cycle.
## Reading: festival fires when `(day - 1) % 30 == FESTIVAL_DAY_<X>`.
const FESTIVAL_DAY_MID_AUTUMN: int = 14   ## days 15, 45, 75, …
const FESTIVAL_DAY_NEW_YEAR: int = 29     ## days 30, 60, 90, …

## Bonus money awarded at the START of a festival run on top of STARTING_MONEY.
const FESTIVAL_BONUS_MID_AUTUMN: int = 30
const FESTIVAL_BONUS_NEW_YEAR: int = 60

## Display labels for the title screen + home_intro mum line.
const FESTIVAL_LABELS: Dictionary[String, String] = {
	FESTIVAL_MID_AUTUMN: "🌕 中秋節",
	FESTIVAL_NEW_YEAR:   "🧧 過年",
}
const FESTIVAL_BLURBS: Dictionary[String, String] = {
	FESTIVAL_MID_AUTUMN: "中秋節快樂！多買一點，今晚賞月～",
	FESTIVAL_NEW_YEAR:   "新年好！紅包拿去買菜囉～",
}

# ---------------------------------------------------------------------------
# v0.40 — 媽媽特別交代 (special requests)
# v0.41 — expanded from 2 → 5 requests on a 14-day cycle
# ---------------------------------------------------------------------------
#
# Layered on top of the normal day-theme + festival system. Special requests
# fire on a 14-day cycle (skipping festival days) so the player gets a
# narratively-flavoured shopping run roughly 5 times every 2 weeks — week 2
# uses different requests than week 1 so the cadence stays fresh.
#
# Each request:
#   * overrides must_include + size in randomize_required()
#   * gets its own title-screen + intro line
#   * awards a one-shot NT$ bonus on completion (queued via
#     HiScore.pending_special_bonus, paid out next morning the same way
#     the dream-clear bonus is)

const SPECIAL_REQUEST_NONE: String = ""
const SPECIAL_REQUEST_DAD_BIRTHDAY: String = "dad_birthday"
const SPECIAL_REQUEST_GUEST_DINNER: String = "guest_dinner"
const SPECIAL_REQUEST_GRANNY_SICK: String = "granny_sick"
const SPECIAL_REQUEST_SCHOOL_BAZAAR: String = "school_bazaar"
const SPECIAL_REQUEST_TYPHOON_STOCKPILE: String = "typhoon_stockpile"

## Length of the special-request cycle in days. (day - 1) % SPECIAL_CYCLE_LEN
## maps the current day to a cycle index; matching one of the SPECIAL_REQUEST_DAY_*
## constants below fires that request.
const SPECIAL_CYCLE_LEN: int = 14

## (day - 1) % 14 indices that trigger each request. Skipped silently when a
## festival day is also active so the festival keeps narrative priority.
## Spread out so no two requests land back-to-back.
const SPECIAL_REQUEST_DAY_DAD_BIRTHDAY: int = 2       ## days 3, 17, 31, …
const SPECIAL_REQUEST_DAY_GUEST_DINNER: int = 5       ## days 6, 20, 34, …
const SPECIAL_REQUEST_DAY_SCHOOL_BAZAAR: int = 9      ## days 10, 24, 38, …
const SPECIAL_REQUEST_DAY_GRANNY_SICK: int = 11       ## days 12, 26, 40, …
const SPECIAL_REQUEST_DAY_TYPHOON_STOCKPILE: int = 13 ## days 14, 28, 42, …

## Bonus NT$ awarded on completion of each special request. Larger lists +
## thematically-significant requests pay more.
const SPECIAL_REQUEST_BONUS_DAD_BIRTHDAY: int = 80
const SPECIAL_REQUEST_BONUS_GUEST_DINNER: int = 60
const SPECIAL_REQUEST_BONUS_GRANNY_SICK: int = 50      ## small list, smaller payout
const SPECIAL_REQUEST_BONUS_SCHOOL_BAZAAR: int = 70
const SPECIAL_REQUEST_BONUS_TYPHOON_STOCKPILE: int = 90

## Required ingredient list per special request — overrides the day-theme
## must_include + size when active. Plain Array literals are the only
## const-expression form; consumers (`randomize_required`,
## `special_request_complete`) iterate them directly without a cast.
const SPECIAL_REQUEST_REQUIRED: Dictionary = {
	# Birthday — 三杯雞 ingredients (chicken, scallion, soy_sauce) + egg.
	SPECIAL_REQUEST_DAD_BIRTHDAY: ["chicken", "scallion", "soy_sauce", "egg"],
	# Guest dinner — 滿漢全席, the full 7.
	SPECIAL_REQUEST_GUEST_DINNER: [
		"chicken", "egg", "scallion", "cabbage", "tofu", "soy_sauce", "mushroom"
	],
	# Granny sick — light healing soup: tofu + cabbage + mushroom.
	SPECIAL_REQUEST_GRANNY_SICK: ["tofu", "cabbage", "mushroom"],
	# School bazaar — 蛋餅 (egg pancake) ingredients: egg + scallion + soy_sauce.
	SPECIAL_REQUEST_SCHOOL_BAZAAR: ["egg", "scallion", "soy_sauce"],
	# Typhoon stockpile — durable goods only (no fresh chicken / scallion which
	# spoil fast in a power outage).
	SPECIAL_REQUEST_TYPHOON_STOCKPILE: [
		"soy_sauce", "tofu", "cabbage", "mushroom", "egg"
	],
}

## Short labels used by title screen + mum's intro.
const SPECIAL_REQUEST_LABELS: Dictionary[String, String] = {
	SPECIAL_REQUEST_DAD_BIRTHDAY:      "🎂 爸爸生日",
	SPECIAL_REQUEST_GUEST_DINNER:      "🍽 客人晚餐",
	SPECIAL_REQUEST_GRANNY_SICK:       "🤒 奶奶生病",
	SPECIAL_REQUEST_SCHOOL_BAZAAR:     "🏫 學校義賣",
	SPECIAL_REQUEST_TYPHOON_STOCKPILE: "🌀 颱風天",
}
## Longer flavour blurbs.
const SPECIAL_REQUEST_BLURBS: Dictionary[String, String] = {
	SPECIAL_REQUEST_DAD_BIRTHDAY:      "今天爸爸生日，要做三杯雞慶祝～",
	SPECIAL_REQUEST_GUEST_DINNER:      "客人要來晚餐，請把全部食材都買齊！",
	SPECIAL_REQUEST_GRANNY_SICK:       "奶奶感冒了，做點清淡的給她吃～",
	SPECIAL_REQUEST_SCHOOL_BAZAAR:     "學校義賣要做蛋餅，幫媽媽買材料！",
	SPECIAL_REQUEST_TYPHOON_STOCKPILE: "颱風要來了！囤點放得久的～",
}

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

## v0.35: how much "夢境餘韻" bonus was applied to `money` on the most recent
## reset(). 0 if none. The intro reads this so mum can call out the bonus
## in dialogue. Lives on Inventory rather than HiScore because by the time
## the intro plays, HiScore's pending value has already been zeroed.
var last_dream_bonus: int = 0

## v0.40: NT$ awarded on the most recent reset() for completing a special
## request the previous day (mirror of last_dream_bonus, separate so the
## intro can phrase the two thank-yous independently).
var last_special_bonus: int = 0


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


## v0.13: picks the random shopping list for this run.
## v0.19: list size + forced ingredients now come from the active day theme
## (Mon = 5 items, Fri = 3 items, Sun = 7 items, Tue forces tofu+cabbage…).
## v0.40: a special request (爸爸生日 / 客人晚餐) overrides the day theme
## entirely so mum's plot beat takes priority over the weekly cadence.
## Called on every `reset()`, after HiScore is ready.
func randomize_required() -> void:
	# v0.40 — special request override
	var special: String = current_special_request()
	if special != SPECIAL_REQUEST_NONE:
		var override: Array = SPECIAL_REQUEST_REQUIRED.get(special, [])
		if not override.is_empty():
			var packed: PackedStringArray = PackedStringArray()
			for id in override:
				packed.append(String(id))
			required_ingredients = packed
			return
	var theme: Dictionary = current_theme()
	var must: Array = theme.get("must_include", [])
	var size: int = clampi(int(theme.get("size", REQUIRED_COUNT)),
		1, ALL_INGREDIENTS.size())

	var picked: PackedStringArray = PackedStringArray()
	# Forced ingredients first — preserve order so themes with two forced
	# items always show them in the same position on the HUD.
	for id in must:
		picked.append(String(id))
	# Pool of remaining ingredients, shuffled
	var pool: Array[String] = []
	for id in ALL_INGREDIENTS:
		if id in picked:
			continue
		pool.append(id)
	pool.shuffle()
	# Fill up to size from the shuffled pool
	var needed: int = size - picked.size()
	for i in needed:
		if i >= pool.size():
			break
		picked.append(pool[i])
	required_ingredients = picked


## v0.19: returns the theme dict for the current `HiScore.day`. Falls back
## to DEFAULT_THEME if HiScore isn't reachable (autoload init race).
func current_theme() -> Dictionary:
	var hs: Node = get_node_or_null("/root/HiScore")
	if hs == null:
		return DEFAULT_THEME
	var d: int = int(hs.day)
	if d < 1:
		return DEFAULT_THEME
	var idx: int = (d - 1) % DAILY_THEMES.size()
	return DAILY_THEMES[idx]


## v0.31: true when the current day is Sat OR Sun in the rotating week
## (theme keys "saturday"/"sunday"). Drives the weekend-mode features —
## special mum dialog, the guaranteed 紅包 spawn in the market, the
## weekend banner on the title and bedroom thought-bubble variant.
##
## Reads `current_theme()` so it stays consistent with the existing
## calendar instead of duplicating modulo math.
func is_weekend() -> bool:
	var theme: Dictionary = current_theme()
	var key: String = String(theme.get("key", ""))
	return key == "saturday" or key == "sunday"


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
## v0.23: festival days drop a bonus on top of STARTING_MONEY (red envelope
## for 過年, mooncake stipend for 中秋).
func reset() -> void:
	# v0.35: claim the queued dream bonus (if any) and stack it on top of
	# starting money + festival bonus. The claim zeroes HiScore's pending
	# value, so the bonus is paid out exactly once.
	var hs: Node = get_node_or_null("/root/HiScore")
	last_dream_bonus = 0
	last_special_bonus = 0
	if hs != null and hs.has_method("claim_pending_dream_bonus"):
		last_dream_bonus = int(hs.claim_pending_dream_bonus())
	# v0.40: same pattern for special-request bonus.
	if hs != null and hs.has_method("claim_pending_special_bonus"):
		last_special_bonus = int(hs.claim_pending_special_bonus())
	money = (STARTING_MONEY + festival_bonus()
		+ last_dream_bonus + last_special_bonus)
	ingredients = {}
	randomize_required()
	money_changed.emit(money)


## v0.23: returns one of FESTIVAL_NONE / FESTIVAL_MID_AUTUMN / FESTIVAL_NEW_YEAR
## based on HiScore.day. Festivals fire on a 30-day cycle (day 15 = 中秋,
## day 30 = 過年) so a casual player hits one every couple of weeks.
func current_festival() -> String:
	var hs: Node = get_node_or_null("/root/HiScore")
	if hs == null:
		return FESTIVAL_NONE
	var d: int = int(hs.day)
	if d <= 0:
		return FESTIVAL_NONE
	var cycle: int = (d - 1) % 30
	if cycle == FESTIVAL_DAY_MID_AUTUMN:
		return FESTIVAL_MID_AUTUMN
	if cycle == FESTIVAL_DAY_NEW_YEAR:
		return FESTIVAL_NEW_YEAR
	return FESTIVAL_NONE


## v0.23: bonus NT$ given to the player at the start of a festival run
## (added on top of STARTING_MONEY in `reset()`). 0 on non-festival days.
func festival_bonus() -> int:
	match current_festival():
		FESTIVAL_MID_AUTUMN: return FESTIVAL_BONUS_MID_AUTUMN
		FESTIVAL_NEW_YEAR:   return FESTIVAL_BONUS_NEW_YEAR
		_:                   return 0


# ---------------------------------------------------------------------------
# v0.40 — special request helpers
# ---------------------------------------------------------------------------

## Returns the special-request key for today, or SPECIAL_REQUEST_NONE.
## Cycle is (HiScore.day - 1) % SPECIAL_CYCLE_LEN. Festival days take
## priority and suppress any special request that would otherwise fire.
func current_special_request() -> String:
	if current_festival() != FESTIVAL_NONE:
		return SPECIAL_REQUEST_NONE
	var hs: Node = get_node_or_null("/root/HiScore")
	if hs == null:
		return SPECIAL_REQUEST_NONE
	var d: int = int(hs.day)
	if d <= 0:
		return SPECIAL_REQUEST_NONE
	var cycle: int = (d - 1) % SPECIAL_CYCLE_LEN
	match cycle:
		SPECIAL_REQUEST_DAY_DAD_BIRTHDAY:      return SPECIAL_REQUEST_DAD_BIRTHDAY
		SPECIAL_REQUEST_DAY_GUEST_DINNER:      return SPECIAL_REQUEST_GUEST_DINNER
		SPECIAL_REQUEST_DAY_SCHOOL_BAZAAR:     return SPECIAL_REQUEST_SCHOOL_BAZAAR
		SPECIAL_REQUEST_DAY_GRANNY_SICK:       return SPECIAL_REQUEST_GRANNY_SICK
		SPECIAL_REQUEST_DAY_TYPHOON_STOCKPILE: return SPECIAL_REQUEST_TYPHOON_STOCKPILE
	return SPECIAL_REQUEST_NONE


## Short title-screen label for the active request. Empty on regular days.
func special_request_label() -> String:
	return SPECIAL_REQUEST_LABELS.get(current_special_request(), "")


## Longer flavour line for the active request. Empty on regular days.
func special_request_blurb() -> String:
	return SPECIAL_REQUEST_BLURBS.get(current_special_request(), "")


## NT$ bonus awarded if the player completes the active special request.
## 0 when no request is active.
func special_request_bonus() -> int:
	match current_special_request():
		SPECIAL_REQUEST_DAD_BIRTHDAY:      return SPECIAL_REQUEST_BONUS_DAD_BIRTHDAY
		SPECIAL_REQUEST_GUEST_DINNER:      return SPECIAL_REQUEST_BONUS_GUEST_DINNER
		SPECIAL_REQUEST_GRANNY_SICK:       return SPECIAL_REQUEST_BONUS_GRANNY_SICK
		SPECIAL_REQUEST_SCHOOL_BAZAAR:     return SPECIAL_REQUEST_BONUS_SCHOOL_BAZAAR
		SPECIAL_REQUEST_TYPHOON_STOCKPILE: return SPECIAL_REQUEST_BONUS_TYPHOON_STOCKPILE
		_:                                 return 0


## True iff every required ingredient (per the active special request OR
## the day theme if no request is active) has been bought. Mum uses this
## to decide whether to award the special-request bonus on win.
func special_request_complete() -> bool:
	var req: String = current_special_request()
	if req == SPECIAL_REQUEST_NONE:
		return false
	var needed: Array = SPECIAL_REQUEST_REQUIRED.get(req, [])
	for id in needed:
		if not ingredients.get(String(id), false):
			return false
	return true


## v0.23: human-readable label for the active festival (or "" if none).
func festival_label() -> String:
	return FESTIVAL_LABELS.get(current_festival(), "")


## v0.23: blurb for the home_intro mum line on a festival day (or "" if none).
func festival_blurb() -> String:
	return FESTIVAL_BLURBS.get(current_festival(), "")


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
