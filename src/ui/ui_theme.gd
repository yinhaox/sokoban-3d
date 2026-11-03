class_name UiTheme
extends RefCounted

## The single runtime theme for every screen, built from the palette and the UI
## numbers in design/ui-flow.md and design/camera-and-presentation.md.
##
## The screens carry no per-node colour, font-size or spacing overrides
## (.dsh/rules/ui.md): `src/main.gd` assigns this theme to each screen root, so
## a focus ring, a body size or a panel colour changes in one place. Font sizes
## are never below `font_body_px` = 18 (the design minimum is 16).

const FONT_BODY := 18
const FONT_HEADING := 32
const FONT_TITLE := 64
const FOCUS_RING_PX := 3
const MIN_TARGET_PX := 44
const CORNER_RADIUS_PX := 6
const PANEL_PADDING_PX := 24
const BUTTON_PADDING_X := 18
const BUTTON_PADDING_Y := 10

const BACKGROUND := Color("#10131A")
const TEXT := Color("#E8EAF0")
const MUTED := Color("#A8B0BF")
const FOCUS := Color("#FFD166")
const PANEL_BG := Color(0.062, 0.075, 0.102, 0.96)
const DIM_BG := Color(0.0, 0.0, 0.0, 0.55)
const BUTTON_BG := Color("#1E2633")
const BUTTON_HOVER := Color("#2A3446")
const BUTTON_PRESSED := Color("#3A4760")
const BUTTON_DISABLED := Color("#171C26")
const STAR_FILLED := Color("#FFD166")
const STAR_EMPTY := Color(0.9, 0.92, 0.96, 0.3)
const HUD_BG := Color(0.062, 0.075, 0.102, 0.86)

const SCREEN_MARGIN_PX := 48
const CARD_MARGIN_PX := 12
const HUD_MARGIN_PX := 6
const VBOX_SEPARATION_PX := 12
const HBOX_SEPARATION_PX := 8
const GRID_SEPARATION_PX := 16
## The settings rows are compact so all seven settings fit 1152x648 without
## scrolling while each interactive control still keeps `min_target_px`.
const COMPACT_ROW_SEPARATION_PX := 2

## System font fallbacks for the Chinese UI, per design/accessibility.md "Text
## and UI size". The first named family the OS has renders both Latin and CJK, so
## no font file is shipped. `allow_system_fallback` covers a machine where the
## named families are absent.
const UI_FONT_NAMES: Array[String] = [
	"Microsoft YaHei UI",
	"Microsoft YaHei",
	"Noto Sans CJK SC",
	"Noto Sans SC",
	"Source Han Sans SC",
	"SimHei",
	"sans-serif",
]


## Builds the shared theme. Called once by the boot scene; safe to call again in
## a test because it creates a fresh resource every time.
static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font = _ui_font()
	theme.default_font_size = FONT_BODY
	_style_buttons(theme)
	_style_labels(theme)
	_style_panels(theme)
	_style_containers(theme)
	theme.set_color("filled", "StarRow", STAR_FILLED)
	theme.set_color("empty", "StarRow", STAR_EMPTY)
	return theme


## One system font for Latin and CJK, so a Chinese label never renders tofu.
static func _ui_font() -> SystemFont:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(UI_FONT_NAMES)
	font.allow_system_fallback = true
	return font


static func _style_buttons(theme: Theme) -> void:
	theme.set_stylebox("normal", "Button", _button_box(BUTTON_BG, Color.TRANSPARENT))
	theme.set_stylebox("hover", "Button", _button_box(BUTTON_HOVER, Color.TRANSPARENT))
	theme.set_stylebox("pressed", "Button", _button_box(BUTTON_PRESSED, Color.TRANSPARENT))
	theme.set_stylebox("disabled", "Button", _button_box(BUTTON_DISABLED, Color.TRANSPARENT))
	theme.set_stylebox("focus", "Button", _button_box(BUTTON_HOVER, FOCUS))
	theme.set_font_size("font_size", "Button", FONT_BODY)
	theme.set_font_size("font_size", "Label", FONT_BODY)
	theme.set_color("font_color", "Button", TEXT)
	theme.set_color("font_hover_color", "Button", TEXT)
	theme.set_color("font_pressed_color", "Button", FOCUS)
	theme.set_color("font_focus_color", "Button", TEXT)
	theme.set_color("font_disabled_color", "Button", MUTED)


static func _style_labels(theme: Theme) -> void:
	theme.set_color("font_color", "Label", TEXT)
	_add_label_variation(theme, "TitleLabel", FONT_TITLE, TEXT)
	_add_label_variation(theme, "HeadingLabel", FONT_HEADING, TEXT)
	_add_label_variation(theme, "MutedLabel", FONT_BODY, MUTED)


static func _add_label_variation(
	theme: Theme, variation: String, font_size: int, color: Color
) -> void:
	theme.set_type_variation(variation, "Label")
	theme.set_font_size("font_size", variation, font_size)
	theme.set_color("font_color", variation, color)


static func _style_panels(theme: Theme) -> void:
	theme.set_type_variation("ModalPanel", "PanelContainer")
	theme.set_stylebox("panel", "ModalPanel", _panel_box(PANEL_BG))
	theme.set_type_variation("HudStrip", "PanelContainer")
	theme.set_stylebox("panel", "HudStrip", _panel_box(HUD_BG))
	theme.set_type_variation("ScreenBackground", "PanelContainer")
	theme.set_stylebox("panel", "ScreenBackground", _panel_box(BACKGROUND, false))
	theme.set_type_variation("DimBackground", "PanelContainer")
	theme.set_stylebox("panel", "DimBackground", _panel_box(DIM_BG, false))


static func _style_containers(theme: Theme) -> void:
	theme.set_type_variation("ScreenMargin", "MarginContainer")
	_style_margin(theme, "ScreenMargin", SCREEN_MARGIN_PX)
	theme.set_type_variation("CardMargin", "MarginContainer")
	_style_margin(theme, "CardMargin", CARD_MARGIN_PX)
	theme.set_type_variation("HudMargin", "MarginContainer")
	_style_margin(theme, "HudMargin", HUD_MARGIN_PX)
	theme.set_type_variation("CompactMargin", "MarginContainer")
	_style_margin(theme, "CompactMargin", CARD_MARGIN_PX * 2)
	theme.set_type_variation("CompactRows", "VBoxContainer")
	theme.set_constant("separation", "CompactRows", COMPACT_ROW_SEPARATION_PX)
	theme.set_constant("separation", "VBoxContainer", VBOX_SEPARATION_PX)
	theme.set_constant("separation", "HBoxContainer", HBOX_SEPARATION_PX)
	theme.set_constant("h_separation", "GridContainer", GRID_SEPARATION_PX)
	theme.set_constant("v_separation", "GridContainer", GRID_SEPARATION_PX)


static func _style_margin(theme: Theme, variation: String, margin: int) -> void:
	theme.set_constant("margin_left", variation, margin)
	theme.set_constant("margin_top", variation, margin)
	theme.set_constant("margin_right", variation, margin)
	theme.set_constant("margin_bottom", variation, margin)


static func _button_box(background: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = background
	box.border_color = border
	box.set_border_width_all(FOCUS_RING_PX if border.a > 0.0 else 0)
	box.set_corner_radius_all(CORNER_RADIUS_PX)
	box.set_content_margin(SIDE_LEFT, BUTTON_PADDING_X)
	box.set_content_margin(SIDE_RIGHT, BUTTON_PADDING_X)
	box.set_content_margin(SIDE_TOP, BUTTON_PADDING_Y)
	box.set_content_margin(SIDE_BOTTOM, BUTTON_PADDING_Y)
	return box


static func _panel_box(background: Color, padded: bool = true) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = background
	box.set_corner_radius_all(CORNER_RADIUS_PX)
	if padded:
		box.set_content_margin(SIDE_LEFT, PANEL_PADDING_PX)
		box.set_content_margin(SIDE_RIGHT, PANEL_PADDING_PX)
		box.set_content_margin(SIDE_TOP, PANEL_PADDING_PX)
		box.set_content_margin(SIDE_BOTTOM, PANEL_PADDING_PX)
	return box
