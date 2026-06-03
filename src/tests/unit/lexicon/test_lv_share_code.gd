## Unit tests for LVShareCode (Phase C seed share-codes).
extends GutTest

const LVShareCode = preload("res://lexicon/scripts/lv_share_code.gd")

# Round-trip a small seed
func test_round_trip_small_seed() -> void:
	var code: String = LVShareCode.encode(42)
	assert_eq(LVShareCode.decode(code), 42)

# Seed 0 → "0"
func test_seed_zero_encodes_to_single_char() -> void:
	assert_eq(LVShareCode.encode(0), "0")
	assert_eq(LVShareCode.decode("0"), 0)

# Round-trip several arbitrary seeds
func test_round_trip_various_seeds() -> void:
	for seed in [1, 7, 42, 99, 1234, 65535, 1000000, 2147483647]:
		var code: String = LVShareCode.encode(seed)
		assert_eq(LVShareCode.decode(code), seed, "Round-trip failed for seed %d (code=%s)" % [seed, code])

# Encoded codes ≤ 7 chars for all valid 31-bit seeds
func test_code_length_capped_at_7_chars() -> void:
	for seed in [42, 999999, 2147483647]:
		var code: String = LVShareCode.encode(seed)
		assert_true(code.length() <= LVShareCode.MAX_CODE_LENGTH,
			"Code '%s' for seed %d exceeded max length" % [code, seed])

# Negative seed treated as abs (matches LVProcGen EC-5)
func test_negative_seed_encodes_as_abs() -> void:
	assert_eq(LVShareCode.encode(-42), LVShareCode.encode(42))

# Case-insensitive decode
func test_decode_is_case_insensitive() -> void:
	var code: String = LVShareCode.encode(12345)
	assert_eq(LVShareCode.decode(code.to_lower()), LVShareCode.decode(code.to_upper()))

# Empty string → -1
func test_decode_empty_returns_minus_one() -> void:
	assert_eq(LVShareCode.decode(""), -1)

# Over-length code → -1
func test_decode_over_length_returns_minus_one() -> void:
	assert_eq(LVShareCode.decode("12345678"), -1)  # 8 chars > MAX_CODE_LENGTH

# Illegal chars → -1
func test_decode_illegal_char_returns_minus_one() -> void:
	# 'I' is excluded from the Crockford alphabet
	assert_eq(LVShareCode.decode("I"), -1)
	# 'O' is excluded
	assert_eq(LVShareCode.decode("O"), -1)
	# Hyphen is not in alphabet
	assert_eq(LVShareCode.decode("A-B"), -1)

# is_valid mirrors decode result
func test_is_valid_for_valid_code() -> void:
	assert_true(LVShareCode.is_valid("42"))
	assert_true(LVShareCode.is_valid(LVShareCode.encode(42)))

func test_is_valid_for_invalid_code() -> void:
	assert_false(LVShareCode.is_valid(""))
	assert_false(LVShareCode.is_valid("I"))
	assert_false(LVShareCode.is_valid("ABCDEFGH"))  # too long
