## LVVignetteContent — Lexicon Village #13 Vignette content authoring data
##
## Static data provider for per-NPC vignette content. MVP includes baker only;
## other 6 NPCs added in VS+.
##
## Per design/gdd/vignette-content-baker.md.
class_name LVVignetteContent
extends RefCounted

# ─── MVP language seed: hard-coded glyph strings ──────────────────────────────
# These become the "correct" icon IDs for each slot. In MVP, glyph strings
# are also the icon IDs for simplicity. VS+ separates glyphs (visual form)
# from icons (player-side palette tokens).

const CORRECT_TABLE: Dictionary = {
	&"NOUN_BREAD":    &"icon_bread",
	&"VERB_GIVE":     &"icon_give",
	&"ADJ_WARM":      &"icon_warm",
	&"NOUN_IRON":     &"icon_iron",
	&"NOUN_HAMMER":   &"icon_hammer",
	&"VERB_MAKE":     &"icon_make",
	&"NOUN_WATER":    &"icon_water",
	&"NOUN_FISH":     &"icon_fish",
	&"VERB_COME":     &"icon_come",
	&"NOUN_CLOTH":    &"icon_cloth",
	&"VERB_WEAVE":    &"icon_weave",
	&"ADJ_LONG":      &"icon_long",
	&"ADJ_SMALL":     &"icon_small",
	&"VERB_PLAY":     &"icon_play",
	&"NOUN_FRIEND":   &"icon_friend",
	&"NOUN_PATH":     &"icon_path",
	&"ADJ_FAR":       &"icon_far",
	&"NOUN_STRANGER": &"icon_stranger",
	&"VERB_REMEMBER": &"icon_remember",
	&"NOUN_PLACE":    &"icon_place",
}

# ─── Per-vignette slot lists ──────────────────────────────────────────────────

const SLOTS_IN_VIGNETTE: Dictionary = {
	&"BAKER":       [&"NOUN_BREAD", &"VERB_GIVE", &"ADJ_WARM"],
	&"SMITH":       [&"NOUN_IRON", &"NOUN_HAMMER", &"VERB_MAKE"],
	&"FISHER":      [&"NOUN_WATER", &"NOUN_FISH", &"VERB_COME"],
	&"WEAVER":      [&"NOUN_CLOTH", &"VERB_WEAVE", &"ADJ_LONG"],
	&"CHILD":       [&"ADJ_SMALL", &"VERB_PLAY", &"NOUN_FRIEND"],
	&"TRAVELER":    [&"NOUN_PATH", &"ADJ_FAR", &"NOUN_STRANGER"],
	&"STORYTELLER": [&"VERB_REMEMBER", &"NOUN_PLACE"],
}

# ─── Baker vignette content (per vignette-content-baker.md) ───────────────────

const BAKER_INTRO_TOKENS: Array = [
	# Line 1: "mura." (bread.)
	[
		{"type": "LEXICON_SLOT", "value": &"NOUN_BREAD"},
		{"type": "PUNCTUATION", "value": "."},
	]
]

const BAKER_ACTION_TOKENS: Array = [
	# Line 1 (concurrent with give-bread): "tola mura." (give bread.)
	[
		{"type": "LEXICON_SLOT", "value": &"VERB_GIVE"},
		{"type": "LEXICON_SLOT", "value": &"NOUN_BREAD"},
		{"type": "PUNCTUATION", "value": "."},
	],
	# Line 2 (concurrent with touch-warm): "ven mura." (warm bread.)
	[
		{"type": "LEXICON_SLOT", "value": &"ADJ_WARM"},
		{"type": "LEXICON_SLOT", "value": &"NOUN_BREAD"},
		{"type": "PUNCTUATION", "value": "."},
	]
]

const BAKER_CLOSING_TOKENS: Array = [
	# Line 1: "tola mura ka?" (give bread? — invitational)
	[
		{"type": "LEXICON_SLOT", "value": &"VERB_GIVE"},
		{"type": "LEXICON_SLOT", "value": &"NOUN_BREAD"},
		{"type": "PART_Q", "value": &"ka"},
		{"type": "PUNCTUATION", "value": "?"},
	]
]

const BAKER_IDLE_TOKENS: Array = [
	# Post-cascade idle: same invitational line ("tola mura ka?")
	[
		{"type": "LEXICON_SLOT", "value": &"VERB_GIVE"},
		{"type": "LEXICON_SLOT", "value": &"NOUN_BREAD"},
		{"type": "PART_Q", "value": &"ka"},
		{"type": "PUNCTUATION", "value": "?"},
	]
]

const BAKER_WORLD_POSITION: Vector2 = Vector2(120, 100)

# ─── Smith (blacksmith) vignette content ──────────────────────────────────────

const SMITH_INTRO_TOKENS: Array = [
	# Line 1: "krun." (iron.)
	[
		{"type": "LEXICON_SLOT", "value": &"NOUN_IRON"},
		{"type": "PUNCTUATION", "value": "."},
	]
]

const SMITH_ACTION_TOKENS: Array = [
	# Line 1 (concurrent with hammer-strike): "dakka pora." (hammer make.)
	[
		{"type": "LEXICON_SLOT", "value": &"NOUN_HAMMER"},
		{"type": "LEXICON_SLOT", "value": &"VERB_MAKE"},
		{"type": "PUNCTUATION", "value": "."},
	],
	# Line 2 (concurrent with finished horseshoe handed off): "pora krun." (make iron.)
	[
		{"type": "LEXICON_SLOT", "value": &"VERB_MAKE"},
		{"type": "LEXICON_SLOT", "value": &"NOUN_IRON"},
		{"type": "PUNCTUATION", "value": "."},
	]
]

const SMITH_CLOSING_TOKENS: Array = [
	# Line 1: "pora dakka ka?" (make hammer? — invitational)
	[
		{"type": "LEXICON_SLOT", "value": &"VERB_MAKE"},
		{"type": "LEXICON_SLOT", "value": &"NOUN_HAMMER"},
		{"type": "PART_Q", "value": &"ka"},
		{"type": "PUNCTUATION", "value": "?"},
	]
]

const SMITH_IDLE_TOKENS: Array = [
	# Post-cascade idle: same invitational line
	[
		{"type": "LEXICON_SLOT", "value": &"VERB_MAKE"},
		{"type": "LEXICON_SLOT", "value": &"NOUN_HAMMER"},
		{"type": "PART_Q", "value": &"ka"},
		{"type": "PUNCTUATION", "value": "?"},
	]
]

const SMITH_WORLD_POSITION: Vector2 = Vector2(50, 110)

# ─── Fisher vignette content ──────────────────────────────────────────────────

const FISHER_INTRO_TOKENS: Array = [
	# Line 1: "sela." (water.)
	[
		{"type": "LEXICON_SLOT", "value": &"NOUN_WATER"},
		{"type": "PUNCTUATION", "value": "."},
	]
]

const FISHER_ACTION_TOKENS: Array = [
	# Line 1: "mira." (fish.)
	[
		{"type": "LEXICON_SLOT", "value": &"NOUN_FISH"},
		{"type": "PUNCTUATION", "value": "."},
	],
	# Line 2: "mira nai sela." (fish come [from] water.)
	[
		{"type": "LEXICON_SLOT", "value": &"NOUN_FISH"},
		{"type": "LEXICON_SLOT", "value": &"VERB_COME"},
		{"type": "LEXICON_SLOT", "value": &"NOUN_WATER"},
		{"type": "PUNCTUATION", "value": "."},
	]
]

const FISHER_CLOSING_TOKENS: Array = [
	# Line 1: "nai mira ka?" (come fish? — invitational)
	[
		{"type": "LEXICON_SLOT", "value": &"VERB_COME"},
		{"type": "LEXICON_SLOT", "value": &"NOUN_FISH"},
		{"type": "PART_Q", "value": &"ka"},
		{"type": "PUNCTUATION", "value": "?"},
	]
]

const FISHER_IDLE_TOKENS: Array = [
	[
		{"type": "LEXICON_SLOT", "value": &"VERB_COME"},
		{"type": "LEXICON_SLOT", "value": &"NOUN_FISH"},
		{"type": "PART_Q", "value": &"ka"},
		{"type": "PUNCTUATION", "value": "?"},
	]
]

const FISHER_WORLD_POSITION: Vector2 = Vector2(250, 110)

# ─── Weaver vignette content ──────────────────────────────────────────────────

const WEAVER_INTRO_TOKENS: Array = [
	# Line 1: "kove." (weave.)
	[
		{"type": "LEXICON_SLOT", "value": &"VERB_WEAVE"},
		{"type": "PUNCTUATION", "value": "."},
	]
]

const WEAVER_ACTION_TOKENS: Array = [
	# Line 1: "talo lim." (cloth long.)
	[
		{"type": "LEXICON_SLOT", "value": &"NOUN_CLOTH"},
		{"type": "LEXICON_SLOT", "value": &"ADJ_LONG"},
		{"type": "PUNCTUATION", "value": "."},
	],
	# Line 2: "kove talo." (weave cloth.)
	[
		{"type": "LEXICON_SLOT", "value": &"VERB_WEAVE"},
		{"type": "LEXICON_SLOT", "value": &"NOUN_CLOTH"},
		{"type": "PUNCTUATION", "value": "."},
	]
]

const WEAVER_CLOSING_TOKENS: Array = [
	# Line 1: "kove talo ka?" (weave cloth? — invitational)
	[
		{"type": "LEXICON_SLOT", "value": &"VERB_WEAVE"},
		{"type": "LEXICON_SLOT", "value": &"NOUN_CLOTH"},
		{"type": "PART_Q", "value": &"ka"},
		{"type": "PUNCTUATION", "value": "?"},
	]
]

const WEAVER_IDLE_TOKENS: Array = [
	[
		{"type": "LEXICON_SLOT", "value": &"VERB_WEAVE"},
		{"type": "LEXICON_SLOT", "value": &"NOUN_CLOTH"},
		{"type": "PART_Q", "value": &"ka"},
		{"type": "PUNCTUATION", "value": "?"},
	]
]

const WEAVER_WORLD_POSITION: Vector2 = Vector2(180, 100)

# ─── Child vignette content ───────────────────────────────────────────────────

const CHILD_INTRO_TOKENS: Array = [
	# Line 1: "vu." (friend.)
	[
		{"type": "LEXICON_SLOT", "value": &"NOUN_FRIEND"},
		{"type": "PUNCTUATION", "value": "."},
	]
]

const CHILD_ACTION_TOKENS: Array = [
	# Line 1: "ela." (play/run.)
	[
		{"type": "LEXICON_SLOT", "value": &"VERB_PLAY"},
		{"type": "PUNCTUATION", "value": "."},
	],
	# Line 2: "du vu." (small friend.)
	[
		{"type": "LEXICON_SLOT", "value": &"ADJ_SMALL"},
		{"type": "LEXICON_SLOT", "value": &"NOUN_FRIEND"},
		{"type": "PUNCTUATION", "value": "."},
	]
]

const CHILD_CLOSING_TOKENS: Array = [
	# Line 1: "ela ka?" (play? — invitational)
	[
		{"type": "LEXICON_SLOT", "value": &"VERB_PLAY"},
		{"type": "PART_Q", "value": &"ka"},
		{"type": "PUNCTUATION", "value": "?"},
	]
]

const CHILD_IDLE_TOKENS: Array = [
	[
		{"type": "LEXICON_SLOT", "value": &"VERB_PLAY"},
		{"type": "PART_Q", "value": &"ka"},
		{"type": "PUNCTUATION", "value": "?"},
	]
]

const CHILD_WORLD_POSITION: Vector2 = Vector2(95, 135)

# ─── Traveler vignette content ────────────────────────────────────────────────

const TRAVELER_INTRO_TOKENS: Array = [
	# Line 1: "gel." (stranger.)
	[
		{"type": "LEXICON_SLOT", "value": &"NOUN_STRANGER"},
		{"type": "PUNCTUATION", "value": "."},
	]
]

const TRAVELER_ACTION_TOKENS: Array = [
	# Line 1: "solar naima." (path far.)
	[
		{"type": "LEXICON_SLOT", "value": &"NOUN_PATH"},
		{"type": "LEXICON_SLOT", "value": &"ADJ_FAR"},
		{"type": "PUNCTUATION", "value": "."},
	],
	# Line 2: "gel solar." (stranger path.)
	[
		{"type": "LEXICON_SLOT", "value": &"NOUN_STRANGER"},
		{"type": "LEXICON_SLOT", "value": &"NOUN_PATH"},
		{"type": "PUNCTUATION", "value": "."},
	]
]

const TRAVELER_CLOSING_TOKENS: Array = [
	# Line 1: "solar naima ka?" (path far? — invitational)
	[
		{"type": "LEXICON_SLOT", "value": &"NOUN_PATH"},
		{"type": "LEXICON_SLOT", "value": &"ADJ_FAR"},
		{"type": "PART_Q", "value": &"ka"},
		{"type": "PUNCTUATION", "value": "?"},
	]
]

const TRAVELER_IDLE_TOKENS: Array = [
	[
		{"type": "LEXICON_SLOT", "value": &"NOUN_PATH"},
		{"type": "LEXICON_SLOT", "value": &"ADJ_FAR"},
		{"type": "PART_Q", "value": &"ka"},
		{"type": "PUNCTUATION", "value": "?"},
	]
]

const TRAVELER_WORLD_POSITION: Vector2 = Vector2(270, 70)

# ─── Storyteller vignette content ─────────────────────────────────────────────

const STORYTELLER_INTRO_TOKENS: Array = [
	# Line 1: "sun." (place.)
	[
		{"type": "LEXICON_SLOT", "value": &"NOUN_PLACE"},
		{"type": "PUNCTUATION", "value": "."},
	]
]

const STORYTELLER_ACTION_TOKENS: Array = [
	# Line 1: "taro." (remember.)
	[
		{"type": "LEXICON_SLOT", "value": &"VERB_REMEMBER"},
		{"type": "PUNCTUATION", "value": "."},
	],
	# Line 2: "taro sun." (remember place.)
	[
		{"type": "LEXICON_SLOT", "value": &"VERB_REMEMBER"},
		{"type": "LEXICON_SLOT", "value": &"NOUN_PLACE"},
		{"type": "PUNCTUATION", "value": "."},
	]
]

const STORYTELLER_CLOSING_TOKENS: Array = [
	# Line 1: "taro sun ka?" (remember place? — invitational, echoes elder's question)
	[
		{"type": "LEXICON_SLOT", "value": &"VERB_REMEMBER"},
		{"type": "LEXICON_SLOT", "value": &"NOUN_PLACE"},
		{"type": "PART_Q", "value": &"ka"},
		{"type": "PUNCTUATION", "value": "?"},
	]
]

const STORYTELLER_IDLE_TOKENS: Array = [
	[
		{"type": "LEXICON_SLOT", "value": &"VERB_REMEMBER"},
		{"type": "LEXICON_SLOT", "value": &"NOUN_PLACE"},
		{"type": "PART_Q", "value": &"ka"},
		{"type": "PUNCTUATION", "value": "?"},
	]
]

const STORYTELLER_WORLD_POSITION: Vector2 = Vector2(40, 75)

# ─── Lexicon → seed glyph strings ─────────────────────────────────────────────
# Maps semantic slot → string the player sees while undecoded.
# MVP hard-coded; VS+ procedural generator produces this per seed.

const SEED_GLYPHS: Dictionary = {
	&"NOUN_BREAD": "mura",
	&"VERB_GIVE": "tola",
	&"ADJ_WARM": "ven",
	# Other NPCs (placeholder for VS+):
	&"NOUN_IRON": "krun",
	&"NOUN_HAMMER": "dakka",
	&"VERB_MAKE": "pora",
	&"NOUN_WATER": "sela",
	&"NOUN_FISH": "mira",
	&"VERB_COME": "nai",
	&"NOUN_CLOTH": "talo",
	&"VERB_WEAVE": "kove",
	&"ADJ_LONG": "lim",
	&"ADJ_SMALL": "du",
	&"VERB_PLAY": "ela",
	&"NOUN_FRIEND": "vu",
	&"NOUN_PATH": "solar",
	&"ADJ_FAR": "naima",
	&"NOUN_STRANGER": "gel",
	&"VERB_REMEMBER": "taro",
	&"NOUN_PLACE": "sun",
}

# ─── Lexicon → resolved (player UI language) ──────────────────────────────────
# Maps semantic slot → decoded form shown after cascade.
# MVP defaults Chinese; #21 Localization will hook in later.

const RESOLVED_STRINGS: Dictionary = {
	&"NOUN_BREAD": "麵包",
	&"VERB_GIVE": "給",
	&"ADJ_WARM": "暖的",
	&"NOUN_IRON": "鐵",
	&"NOUN_HAMMER": "鎚",
	&"VERB_MAKE": "做",
	&"NOUN_WATER": "水",
	&"NOUN_FISH": "魚",
	&"VERB_COME": "來",
	&"NOUN_CLOTH": "布",
	&"VERB_WEAVE": "織",
	&"ADJ_LONG": "長",
	&"ADJ_SMALL": "小",
	&"VERB_PLAY": "跑",
	&"NOUN_FRIEND": "朋友",
	&"NOUN_PATH": "路",
	&"ADJ_FAR": "遠",
	&"NOUN_STRANGER": "陌生人",
	&"VERB_REMEMBER": "記得",
	&"NOUN_PLACE": "地方",
}

# ─── Public API ───────────────────────────────────────────────────────────────

## Get content for a vignette. Returns dict with intro_tokens, action_tokens,
## closing_tokens, idle_tokens, world_position. Used by #8 Vignette state machine
## as its content provider callable.
static func get_content(vignette_id: StringName) -> Dictionary:
	match vignette_id:
		&"BAKER":
			return {
				&"intro_tokens": BAKER_INTRO_TOKENS,
				&"action_tokens": BAKER_ACTION_TOKENS,
				&"closing_tokens": BAKER_CLOSING_TOKENS,
				&"idle_tokens": BAKER_IDLE_TOKENS,
				&"world_position": BAKER_WORLD_POSITION,
			}
		&"SMITH":
			return {
				&"intro_tokens": SMITH_INTRO_TOKENS,
				&"action_tokens": SMITH_ACTION_TOKENS,
				&"closing_tokens": SMITH_CLOSING_TOKENS,
				&"idle_tokens": SMITH_IDLE_TOKENS,
				&"world_position": SMITH_WORLD_POSITION,
			}
		&"FISHER":
			return {
				&"intro_tokens": FISHER_INTRO_TOKENS,
				&"action_tokens": FISHER_ACTION_TOKENS,
				&"closing_tokens": FISHER_CLOSING_TOKENS,
				&"idle_tokens": FISHER_IDLE_TOKENS,
				&"world_position": FISHER_WORLD_POSITION,
			}
		&"WEAVER":
			return {
				&"intro_tokens": WEAVER_INTRO_TOKENS,
				&"action_tokens": WEAVER_ACTION_TOKENS,
				&"closing_tokens": WEAVER_CLOSING_TOKENS,
				&"idle_tokens": WEAVER_IDLE_TOKENS,
				&"world_position": WEAVER_WORLD_POSITION,
			}
		&"CHILD":
			return {
				&"intro_tokens": CHILD_INTRO_TOKENS,
				&"action_tokens": CHILD_ACTION_TOKENS,
				&"closing_tokens": CHILD_CLOSING_TOKENS,
				&"idle_tokens": CHILD_IDLE_TOKENS,
				&"world_position": CHILD_WORLD_POSITION,
			}
		&"TRAVELER":
			return {
				&"intro_tokens": TRAVELER_INTRO_TOKENS,
				&"action_tokens": TRAVELER_ACTION_TOKENS,
				&"closing_tokens": TRAVELER_CLOSING_TOKENS,
				&"idle_tokens": TRAVELER_IDLE_TOKENS,
				&"world_position": TRAVELER_WORLD_POSITION,
			}
		&"STORYTELLER":
			return {
				&"intro_tokens": STORYTELLER_INTRO_TOKENS,
				&"action_tokens": STORYTELLER_ACTION_TOKENS,
				&"closing_tokens": STORYTELLER_CLOSING_TOKENS,
				&"idle_tokens": STORYTELLER_IDLE_TOKENS,
				&"world_position": STORYTELLER_WORLD_POSITION,
			}
		_:
			return {}

## Render a slot's current text form. If confirmed, returns decoded; else returns glyph.
## [param runtime_override] optional Dictionary from #12 ProcGen; if a slot is
## present in the override, it takes priority over the MVP SEED_GLYPHS const.
static func render_slot_text(slot_id: StringName, is_confirmed: bool, runtime_override: Dictionary = {}) -> String:
	if is_confirmed:
		return RESOLVED_STRINGS.get(slot_id, "[%s]" % slot_id)
	if runtime_override.has(slot_id):
		return runtime_override[slot_id]
	return SEED_GLYPHS.get(slot_id, "[?%s]" % slot_id)

## Render a full token sequence to a single string given current confirmed_slots.
## Used by #11 Dialogue display for live rendering.
## [param runtime_override] optional ProcGen dict; passed through to render_slot_text.
static func render_tokens(tokens: Array, confirmed_slots: Array, runtime_override: Dictionary = {}) -> String:
	var parts: PackedStringArray = []
	var confirmed_set: Dictionary = {}
	for s in confirmed_slots:
		confirmed_set[s] = true
	for token in tokens:
		var t_type: String = String(token.get("type", ""))
		var t_value: Variant = token.get("value", "")
		match t_type:
			"LEXICON_SLOT":
				var slot: StringName = t_value as StringName
				parts.append(render_slot_text(slot, confirmed_set.has(slot), runtime_override))
			"UI_TEXT":
				parts.append(String(t_value))  # localized strings TBD via #21
			"PUNCTUATION":
				parts.append(String(t_value))
			"PART_Q":
				parts.append(String(t_value))  # particle "ka" etc.
			_:
				parts.append("[?%s]" % t_type)
	# Join with spaces for now; punctuation absorbs leading space (simple post-process)
	var result: String = ""
	for i in parts.size():
		var part: String = parts[i]
		if i > 0 and not _is_punctuation_or_attached(part):
			result += " "
		result += part
	return result

static func _is_punctuation_or_attached(s: String) -> bool:
	if s.is_empty():
		return false
	var first := s.substr(0, 1)
	return first in [".", "?", "!", ",", ";", ":"]
