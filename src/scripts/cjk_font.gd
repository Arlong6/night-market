## Shared CJK font loader. Bundles jf 粉圓 (Open Huninn 2.1, SIL OFL) so the
## game renders Traditional Chinese consistently across desktop AND web —
## SystemFont fallback can't reach host fonts in the browser sandbox.
class_name CjkFont
extends RefCounted

const FONT_PATH: String = "res://assets/fonts/jf-openhuninn-2.1.ttf"

## Returns the shared FontFile resource with pixel-crisp antialiasing.
## Subsequent calls return the same cached instance.
static func make() -> FontFile:
	var f: FontFile = load(FONT_PATH) as FontFile
	f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	return f
