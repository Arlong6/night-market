## LVShareCode — Lexicon Village share-code encoder/decoder.
##
## Encodes a 31-bit seed as a short base32 string (max 7 chars) suitable for
## casual sharing ("play my language: K7P2X9"). Uses a Crockford-style alphabet
## that omits visually ambiguous characters (no 0/O, no 1/I/L).
##
## Round-trip stable: encode(decode(s)) == s.upper() for any valid code.
## Invalid input → -1 from decode (caller must check).
##
## See: design/gdd/procedural-generator.md OQ-4 (per-seed phonological style)
##      and Phase C of the Integration Plan.
class_name LVShareCode
extends RefCounted

## Crockford base32-style alphabet (32 chars).
## Excludes I L O U to avoid visual confusion. Numerals first per Crockford spec.
const ALPHABET: String = "0123456789ABCDEFGHJKMNPQRSTVWXYZ"

## Maximum 31-bit positive seed → 7 chars of base32 (32^7 ≈ 34 billion).
const MAX_CODE_LENGTH: int = 7

## Encode a non-negative seed to a share code. Negative seeds use abs().
## Seed 0 → "0" (single char). Otherwise no leading zeros.
static func encode(seed: int) -> String:
	var s: int = abs(seed) & 0x7FFFFFFF
	if s == 0:
		return "0"
	var out: String = ""
	while s > 0:
		var digit: int = s & 0x1F  # mod 32
		out = ALPHABET.substr(digit, 1) + out
		s = s >> 5  # div 32
	return out

## Decode a share code back to a seed. Returns -1 on invalid input
## (empty, too long, illegal characters). Case-insensitive.
static func decode(code: String) -> int:
	if code.is_empty():
		return -1
	if code.length() > MAX_CODE_LENGTH:
		return -1
	var upper: String = code.to_upper()
	var seed: int = 0
	for i in upper.length():
		var ch: String = upper.substr(i, 1)
		var idx: int = ALPHABET.find(ch)
		if idx < 0:
			return -1  # illegal char
		seed = (seed << 5) | idx
	return seed & 0x7FFFFFFF

## Validate a share code without decoding. True if non-empty, length ≤ 7,
## and all characters are in ALPHABET (case-insensitive).
static func is_valid(code: String) -> bool:
	return decode(code) >= 0
