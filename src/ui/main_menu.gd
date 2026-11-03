class_name MainMenu
extends CanvasLayer

## Main menu from design/ui-flow.md: title, Play, Level Select, Settings,
## Credits and Quit, with `v<version>` in the corner when the project declares
## one. The menu owns no game state; every button emits an intent and the boot
## scene decides what happens.
##
## Every label is read from the translation table through `tr()` and
## `refresh_texts()` re-reads them after a language switch, so the menu updates
## without a restart. A damaged or newer profile shows one notice line.

signal play_requested
signal level_select_requested
signal settings_requested
signal credits_requested
signal quit_requested

const TITLE_KEY := "ui_menu_title"
const SUBTITLE_KEY := "ui_menu_subtitle"
const BUTTON_KEYS: Array[String] = [
	"ui_menu_play",
	"ui_menu_level_select",
	"ui_menu_settings",
	"ui_menu_credits",
	"ui_menu_quit",
]
const BUTTON_PATHS: Array[String] = [
	"Root/Content/Margin/Layout/Buttons/Play",
	"Root/Content/Margin/Layout/Buttons/LevelSelect",
	"Root/Content/Margin/Layout/Buttons/Settings",
	"Root/Content/Margin/Layout/Buttons/Credits",
	"Root/Content/Margin/Layout/Buttons/Quit",
]
const VERSION_FORMAT := "v%s"
const BUTTON_MIN_SIZE := Vector2(320, 48)

var _root: Control
var _title: Label
var _subtitle: Label
var _version: Label
var _notice: Label
var _buttons: Array[Button] = []
var _notice_text: String = ""
var _bound: bool = false


func _ready() -> void:
	_bind()


## Gives the primary action the focus so the menu opens keyboard-ready.
func focus_default() -> void:
	_bind()
	if is_inside_tree() and not _buttons.is_empty():
		_buttons[0].grab_focus()


## Shows one line about a damaged, newer or unsaveable profile. An empty string
## hides the label.
func set_notice(text: String) -> void:
	_bind()
	_notice_text = text
	_update_notice()


## Shows the project version in the corner, or hides the label when the project
## declares none.
func set_version(version: String) -> void:
	_bind()
	if _version == null:
		return
	_version.visible = not version.strip_edges().is_empty()
	if _version.visible:
		_version.text = VERSION_FORMAT % version.strip_edges()


func button_texts() -> Array[String]:
	_bind()
	var texts: Array[String] = []
	for button: Button in _buttons:
		texts.append(button.text)
	return texts


## Re-reads every label from the active locale.
func refresh_texts() -> void:
	_bind()
	if not _bound:
		return
	_title.text = tr(TITLE_KEY)
	_subtitle.text = tr(SUBTITLE_KEY)
	for index: int in _buttons.size():
		_buttons[index].text = tr(BUTTON_KEYS[index])
	_update_notice()


func _update_notice() -> void:
	if _notice == null:
		return
	_notice.visible = not _notice_text.is_empty()
	_notice.text = _notice_text


func _bind() -> void:
	Localization.install()
	if _bound:
		return
	_bound = true
	_root = get_node_or_null("Root") as Control
	if _root == null:
		push_error("main_menu: the Root control is missing")
		return
	if _root.theme == null:
		_root.theme = UiTheme.build()
	_title = get_node_or_null("Root/Content/Margin/Layout/Title") as Label
	_subtitle = get_node_or_null("Root/Content/Margin/Layout/Subtitle") as Label
	_version = get_node_or_null("Root/Version") as Label
	_notice = get_node_or_null("Root/Content/Margin/Layout/Notice") as Label
	for path: String in BUTTON_PATHS:
		var button := get_node_or_null(path) as Button
		if button == null:
			push_error("main_menu: missing button %s" % path)
			continue
		button.custom_minimum_size = BUTTON_MIN_SIZE
		_buttons.append(button)
	if _buttons.size() != BUTTON_PATHS.size():
		return
	refresh_texts()
	var controls: Array[Control] = []
	controls.assign(_buttons)
	UiFocus.wire_vertical(controls)
	_buttons[0].pressed.connect(_on_play_pressed)
	_buttons[1].pressed.connect(_on_level_select_pressed)
	_buttons[2].pressed.connect(_on_settings_pressed)
	_buttons[3].pressed.connect(_on_credits_pressed)
	_buttons[4].pressed.connect(_on_quit_pressed)
	set_version(str(ProjectSettings.get_setting("application/config/version", "")))


func _on_play_pressed() -> void:
	play_requested.emit()


func _on_level_select_pressed() -> void:
	level_select_requested.emit()


func _on_settings_pressed() -> void:
	settings_requested.emit()


func _on_credits_pressed() -> void:
	credits_requested.emit()


func _on_quit_pressed() -> void:
	quit_requested.emit()
