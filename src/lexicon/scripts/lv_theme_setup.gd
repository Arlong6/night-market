## LVThemeSetup — apply CJK font to project default theme at runtime.
## Loads jf-openhuninn (Traditional Chinese) and sets it as the global default,
## so all Label / Button / RichTextLabel nodes can render CJK on Web.
##
## Called by LVMain at startup.
class_name LVThemeSetup
extends RefCounted

const FONT_PATH: String = "res://assets/fonts/jf-openhuninn-2.1.ttf"

static func apply_default_cjk_font() -> void:
	var font: FontFile = load(FONT_PATH) as FontFile
	if font == null:
		push_error("LVThemeSetup: failed to load CJK font %s" % FONT_PATH)
		return
	# Build a theme with default font set
	var theme := Theme.new()
	theme.default_font = font
	theme.default_font_size = 12
	# Override the ThemeDB's project-level default
	ThemeDB.fallback_font = font
	ThemeDB.fallback_font_size = 12
