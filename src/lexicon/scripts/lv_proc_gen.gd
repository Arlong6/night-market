## LVProcGen — Lexicon Village #12 Procedural Lexicon Generator
##
## Deterministic seed → glyph dictionary producer. Each run gets a fresh
## "language" that still feels phonologically coherent. See:
## design/gdd/procedural-generator.md
##
## Public API:
##   generate_glyphs(seed: int, slot_ids: Array) -> Dictionary
##
## Pure static functions. No state, no side effects.
class_name LVProcGen
extends RefCounted

# ─── Phoneme inventories ──────────────────────────────────────────────────────

const CONSONANTS: Array = ["m", "n", "t", "k", "p", "v", "s", "r", "l", "d"]
const VOWELS: Array = ["a", "e", "i", "o", "u"]
## Consonants legal at syllable coda (CVC pattern).
const CLOSING_CONSONANTS: Array = ["n", "l", "m", "k", "t"]
## Vowels always included to guarantee minimum diversity (per EC-6).
const REQUIRED_VOWELS: Array = ["a", "i", "u"]

# ─── Inventory size knobs ─────────────────────────────────────────────────────

const CONSONANT_INVENTORY_SIZE_MIN: int = 5
const CONSONANT_INVENTORY_SIZE_MAX: int = 7
const VOWEL_INVENTORY_SIZE_MIN: int = 3
const VOWEL_INVENTORY_SIZE_MAX: int = 5

# ─── Probability knobs ────────────────────────────────────────────────────────
# Both per-seed-derived around these defaults to give each run its own
# phonological "voice".

const CV_PROB_DEFAULT: float = 0.7
const V_INITIAL_PROB_DEFAULT: float = 0.1

# ─── Collision handling ──────────────────────────────────────────────────────

const MAX_COLLISION_RETRIES: int = 16

# ─── LCG constants (Numerical Recipes-style) ──────────────────────────────────

const LCG_MULT: int = 1103515245
const LCG_INC: int = 12345
const LCG_MASK: int = 0x7FFFFFFF  # 31-bit positive range to dodge overflow drift

# ─── POS shape table ──────────────────────────────────────────────────────────

const POS_SYLLABLES: Dictionary = {
	"NOUN": [2, 3],
	"VERB": [1, 2],
	"ADJ":  [1, 1],
	"PART": [1, 1],
}
const POS_DEFAULT: String = "ADJ"

# ─── Public API ───────────────────────────────────────────────────────────────

## Generate glyph dictionary from seed + slot_id list.
## Returns Dictionary[StringName, String]. Collision-free within the run.
static func generate_glyphs(seed: int, slot_ids: Array) -> Dictionary:
	if slot_ids.is_empty():
		return {}
	var global_seed: int = abs(seed)
	# Pick inventory for this seed (fixed per run — Rule 2)
	var inventory: Dictionary = _pick_inventory(global_seed)
	# Generate per slot with collision avoidance
	var result: Dictionary = {}
	var used_glyphs: Dictionary = {}  # for O(1) collision check
	for slot_id_v in slot_ids:
		var slot_id: StringName = slot_id_v as StringName
		var pos: String = _pos_for(slot_id)
		var slot_seed: int = _hash_slot(global_seed, slot_id)
		var glyph: String = ""
		var attempts: int = 0
		while attempts < MAX_COLLISION_RETRIES:
			glyph = _generate_word(slot_seed, pos, inventory)
			if not used_glyphs.has(glyph):
				break
			# Collision — perturb slot_seed and retry
			slot_seed = ((slot_seed * 2654435769) + 1) & LCG_MASK
			attempts += 1
		if used_glyphs.has(glyph):
			# Storm fallback — append numeric suffix (EC-4)
			var n: int = 2
			while used_glyphs.has(glyph + "_" + str(n)):
				n += 1
			glyph = glyph + "_" + str(n)
			push_error("LVProcGen: collision storm for slot '%s' — using suffix '%s'" % [slot_id, glyph])
		used_glyphs[glyph] = true
		result[slot_id] = glyph
	return result

# ─── Internal: inventory ──────────────────────────────────────────────────────

static func _pick_inventory(seed: int) -> Dictionary:
	var s: int = seed & LCG_MASK
	# Consonant inventory size
	s = _lcg_step(s)
	var c_size: int = CONSONANT_INVENTORY_SIZE_MIN + (s % (CONSONANT_INVENTORY_SIZE_MAX - CONSONANT_INVENTORY_SIZE_MIN + 1))
	# Pick consonants
	var consonants: Array = _pick_subset(CONSONANTS, c_size, s)
	# Vowel inventory size
	s = _lcg_step(s)
	var v_size: int = VOWEL_INVENTORY_SIZE_MIN + (s % (VOWEL_INVENTORY_SIZE_MAX - VOWEL_INVENTORY_SIZE_MIN + 1))
	var vowels: Array = _pick_subset(VOWELS, v_size, s)
	# Guarantee minimum diversity — force-include required vowels
	for rv in REQUIRED_VOWELS:
		if not vowels.has(rv):
			vowels.append(rv)
	# Closing consonants must be subset of picked consonants
	var closing: Array = []
	for cc in CLOSING_CONSONANTS:
		if consonants.has(cc):
			closing.append(cc)
	# CV probability — seed-derived around default
	s = _lcg_step(s)
	var cv_prob: float = CV_PROB_DEFAULT + (float(s % 21) - 10.0) * 0.01  # ±0.10
	s = _lcg_step(s)
	var v_init_prob: float = V_INITIAL_PROB_DEFAULT + (float(s % 11) - 5.0) * 0.01  # ±0.05
	return {
		"consonants": consonants,
		"vowels": vowels,
		"closing": closing,
		"cv_prob": cv_prob,
		"v_initial_prob": v_init_prob,
	}

static func _pick_subset(pool: Array, count: int, seed: int) -> Array:
	var s: int = seed & LCG_MASK
	var working: Array = pool.duplicate()
	# Fisher-Yates shuffle using LCG
	var n: int = working.size()
	for i in range(n - 1, 0, -1):
		s = _lcg_step(s)
		var j: int = s % (i + 1)
		var tmp: Variant = working[i]
		working[i] = working[j]
		working[j] = tmp
	count = clampi(count, 1, n)
	return working.slice(0, count)

# ─── Internal: word generation ────────────────────────────────────────────────

static func _generate_word(slot_seed: int, pos: String, inventory: Dictionary) -> String:
	var s: int = slot_seed & LCG_MASK
	var range_pair: Array = POS_SYLLABLES.get(pos, POS_SYLLABLES[POS_DEFAULT])
	var min_syl: int = range_pair[0]
	var max_syl: int = range_pair[1]
	s = _lcg_step(s)
	var syllable_count: int = min_syl + (s % (max_syl - min_syl + 1))
	var consonants: Array = inventory.consonants
	var vowels: Array = inventory.vowels
	var closing: Array = inventory.closing
	var cv_prob: float = inventory.cv_prob
	var v_init_prob: float = inventory.v_initial_prob
	var word: String = ""
	for i in syllable_count:
		# Decide syllable pattern
		s = _lcg_step(s)
		var roll: float = float(s % 1000) / 1000.0
		var is_first: bool = i == 0
		# Word-initial vowel-only syllable possible
		if is_first and roll < v_init_prob:
			s = _lcg_step(s)
			word += vowels[s % vowels.size()]
			continue
		# Consonant onset
		s = _lcg_step(s)
		var c: String = consonants[s % consonants.size()]
		# Vowel
		s = _lcg_step(s)
		var v: String = vowels[s % vowels.size()]
		word += c + v
		# Coda (CVC) possible only if closing inventory is non-empty
		s = _lcg_step(s)
		var coda_roll: float = float(s % 1000) / 1000.0
		# CV_PROB is probability of CV (no coda). Inverse = coda probability.
		if not closing.is_empty() and coda_roll > cv_prob:
			s = _lcg_step(s)
			word += closing[s % closing.size()]
	return word

# ─── Internal: utilities ──────────────────────────────────────────────────────

static func _lcg_step(seed: int) -> int:
	return ((seed * LCG_MULT) + LCG_INC) & LCG_MASK

static func _hash_slot(global_seed: int, slot_id: StringName) -> int:
	# Combine global seed with slot_id hash for per-slot determinism (Formula 1).
	# `String(slot_id).hash()` returns a 32-bit hash; mask to 31-bit positive.
	var h: int = String(slot_id).hash() & LCG_MASK
	return (global_seed ^ h) & LCG_MASK

static func _pos_for(slot_id: StringName) -> String:
	var s: String = String(slot_id)
	for prefix in POS_SYLLABLES.keys():
		if s.begins_with(prefix + "_"):
			return prefix
	push_warning("LVProcGen: unknown POS prefix in slot_id '%s' — defaulting to ADJ" % [slot_id])
	return POS_DEFAULT
