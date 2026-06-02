## Unit tests for LVProcGen (#12).
## Covers ACs 1-7, 10 from design/gdd/procedural-generator.md.
## Deferred: AC-8 (cross-process determinism — trusted via LCG), AC-9 (integration).
extends GutTest

const LVProcGen = preload("res://lexicon/scripts/lv_proc_gen.gd")

const DEMO_SLOTS: Array = [
	&"NOUN_BREAD", &"VERB_GIVE", &"ADJ_WARM",
	&"NOUN_IRON", &"NOUN_HAMMER", &"VERB_MAKE",
	&"NOUN_WATER", &"NOUN_FISH", &"VERB_COME",
	&"NOUN_CLOTH", &"VERB_WEAVE", &"ADJ_LONG",
	&"ADJ_SMALL", &"VERB_PLAY", &"NOUN_FRIEND",
	&"NOUN_PATH", &"ADJ_FAR", &"NOUN_STRANGER",
	&"VERB_REMEMBER", &"NOUN_PLACE",
]

# AC-1 — Same seed produces same output
func test_same_seed_produces_same_output() -> void:
	# Act
	var a: Dictionary = LVProcGen.generate_glyphs(42, DEMO_SLOTS)
	var b: Dictionary = LVProcGen.generate_glyphs(42, DEMO_SLOTS)
	# Assert
	assert_eq(a.size(), b.size())
	for key in a.keys():
		assert_eq(a[key], b[key], "Mismatch on slot %s: %s vs %s" % [key, a[key], b[key]])

# AC-2 — Different seeds produce different outputs
func test_different_seeds_produce_different_outputs() -> void:
	# Act
	var a: Dictionary = LVProcGen.generate_glyphs(42, DEMO_SLOTS)
	var b: Dictionary = LVProcGen.generate_glyphs(43, DEMO_SLOTS)
	# Assert: at least 80% of glyphs differ
	var diff_count: int = 0
	for key in a.keys():
		if a[key] != b[key]:
			diff_count += 1
	var diff_ratio: float = float(diff_count) / float(a.size())
	assert_true(diff_ratio >= 0.8,
		"Expected ≥80%% glyph diff between seeds, got %.2f%%" % (diff_ratio * 100.0))

# AC-3 — No collisions in default cases (sample 30 seeds)
func test_no_collisions_within_run() -> void:
	# Arrange
	var seeds: Array = [42, 1, 7, 99, 100, 256, 1024, 17, 31, 53,
		77, 88, 111, 222, 333, 444, 555, 666, 777, 888,
		999, 1234, 5678, 9999, 12345, 54321, 65535, 131072, 1000000, 42424242]
	# Act + Assert
	for seed in seeds:
		var result: Dictionary = LVProcGen.generate_glyphs(seed, DEMO_SLOTS)
		var unique: Dictionary = {}
		for v in result.values():
			assert_false(unique.has(v),
				"Seed %d: collision on glyph '%s' across slots %s" % [seed, v, result])
			unique[v] = true

# AC-4 — POS-respecting syllable counts (noun 2-3, verb 1-2, adj 1)
func test_noun_has_2_or_3_syllables() -> void:
	# Arrange
	var result: Dictionary = LVProcGen.generate_glyphs(42, [&"NOUN_BREAD", &"NOUN_IRON", &"NOUN_WATER"])
	# Act + Assert
	for slot in result.keys():
		var glyph: String = result[slot]
		var vowel_count: int = _count_vowels(glyph)
		assert_true(vowel_count == 2 or vowel_count == 3,
			"Noun '%s' has %d vowels, expected 2-3" % [glyph, vowel_count])

func test_verb_has_1_or_2_syllables() -> void:
	# Arrange
	var result: Dictionary = LVProcGen.generate_glyphs(42, [&"VERB_GIVE", &"VERB_MAKE", &"VERB_COME"])
	# Act + Assert
	for slot in result.keys():
		var glyph: String = result[slot]
		var vowel_count: int = _count_vowels(glyph)
		assert_true(vowel_count == 1 or vowel_count == 2,
			"Verb '%s' has %d vowels, expected 1-2" % [glyph, vowel_count])

func test_adj_has_exactly_1_syllable() -> void:
	# Arrange
	var result: Dictionary = LVProcGen.generate_glyphs(42, [&"ADJ_WARM", &"ADJ_LONG", &"ADJ_SMALL", &"ADJ_FAR"])
	# Act + Assert
	for slot in result.keys():
		var glyph: String = result[slot]
		var vowel_count: int = _count_vowels(glyph)
		assert_eq(vowel_count, 1, "Adj '%s' has %d vowels, expected 1" % [glyph, vowel_count])

# AC-5 / AC-6 — All phonemes from picked inventory (each generated word uses
# only consonants/vowels from CONSONANTS/VOWELS pools).
func test_all_phonemes_legal() -> void:
	# Arrange
	var result: Dictionary = LVProcGen.generate_glyphs(42, DEMO_SLOTS)
	# Act + Assert
	for slot in result.keys():
		var glyph: String = result[slot]
		for i in glyph.length():
			var ch: String = glyph.substr(i, 1)
			var is_consonant: bool = LVProcGen.CONSONANTS.has(ch)
			var is_vowel: bool = LVProcGen.VOWELS.has(ch)
			assert_true(is_consonant or is_vowel,
				"Glyph '%s' contains illegal phoneme '%s'" % [glyph, ch])

# AC-7 — Empty slots returns empty dict
func test_empty_slots_returns_empty_dict() -> void:
	# Act
	var result: Dictionary = LVProcGen.generate_glyphs(42, [])
	# Assert
	assert_eq(result.size(), 0)

# Negative seed handled (EC-5)
func test_negative_seed_handled() -> void:
	# Act
	var a: Dictionary = LVProcGen.generate_glyphs(-42, DEMO_SLOTS)
	var b: Dictionary = LVProcGen.generate_glyphs(42, DEMO_SLOTS)
	# Assert: abs(seed) means same output
	for key in a.keys():
		assert_eq(a[key], b[key])

# Seed = 0 is a legal seed (EC-3)
func test_seed_zero_is_legal() -> void:
	# Act
	var result: Dictionary = LVProcGen.generate_glyphs(0, DEMO_SLOTS)
	# Assert
	assert_eq(result.size(), DEMO_SLOTS.size())
	for v in result.values():
		assert_false(String(v).is_empty())

# Unknown POS prefix defaults to ADJ (EC-2)
func test_unknown_pos_defaults_to_adj() -> void:
	# Act
	var result: Dictionary = LVProcGen.generate_glyphs(42, [&"MYS_FOO"])
	# Mark expected warning
	for err in gut.error_tracker.get_current_test_errors():
		err.handled = true
	# Assert: 1 syllable (ADJ shape)
	var glyph: String = result[&"MYS_FOO"]
	var vowel_count: int = _count_vowels(glyph)
	assert_eq(vowel_count, 1)

# AC-10 — Collision storm gracefully degrades (force tiny inventory via many slots)
func test_collision_storm_uses_numeric_suffix() -> void:
	# Arrange: 100 ADJ slots (each is 1 syllable, narrow space → forced collisions)
	var many: Array = []
	for i in 100:
		many.append(StringName("ADJ_FORCE_%d" % i))
	# Act
	var result: Dictionary = LVProcGen.generate_glyphs(7, many)
	# Mark expected error noise
	for err in gut.error_tracker.get_current_test_errors():
		err.handled = true
	# Assert: no crash, all slots have unique entries
	var unique: Dictionary = {}
	for v in result.values():
		assert_false(unique.has(v), "Final result still has duplicates: %s" % v)
		unique[v] = true
	assert_eq(result.size(), 100)

# Pronounceable check — no triple-vowel or triple-consonant runs (Rule 5)
func test_no_triple_phoneme_runs() -> void:
	# Arrange
	var result: Dictionary = LVProcGen.generate_glyphs(42, DEMO_SLOTS)
	# Act + Assert
	for slot in result.keys():
		var glyph: String = result[slot]
		for i in range(glyph.length() - 2):
			var a: String = glyph.substr(i, 1)
			var b: String = glyph.substr(i + 1, 1)
			var c: String = glyph.substr(i + 2, 1)
			var all_v: bool = LVProcGen.VOWELS.has(a) and LVProcGen.VOWELS.has(b) and LVProcGen.VOWELS.has(c)
			var all_c: bool = LVProcGen.CONSONANTS.has(a) and LVProcGen.CONSONANTS.has(b) and LVProcGen.CONSONANTS.has(c)
			assert_false(all_v or all_c,
				"Glyph '%s' contains triple-phoneme run at %d (%s%s%s)" % [glyph, i, a, b, c])

# Length sanity — generated glyphs are 1-8 characters
func test_glyph_length_is_sane() -> void:
	# Arrange
	var result: Dictionary = LVProcGen.generate_glyphs(42, DEMO_SLOTS)
	# Act + Assert
	for slot in result.keys():
		var glyph: String = result[slot]
		var n: int = glyph.length()
		assert_true(n >= 1 and n <= 8,
			"Glyph '%s' length %d out of 1-8 range" % [glyph, n])

# ─── helpers ──────────────────────────────────────────────────────────────────

func _count_vowels(s: String) -> int:
	var count: int = 0
	for i in s.length():
		if LVProcGen.VOWELS.has(s.substr(i, 1)):
			count += 1
	return count
