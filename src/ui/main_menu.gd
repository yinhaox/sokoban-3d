class_name MainMenu
extends CanvasLayer

## Main menu from design/ui-flow.md: title, Play, Level Select, Settings,
## Credits and Quit, with `v<version>` in the corner when the project declares
## one. The menu owns no game state; every button emits an intent and the boot
## scene decides what happens.
##
## Localization is out of scope for this story (issue #13), so the labels are
## English literals in this script, the same convention the victory panel
## already documents; the localization story replaces them with `tr()` keys.

signal play_requested
signal level_select_requested
signal settings_requested
signal credits_requested
signal quit_requested

const TITLE_TEXT := "Sokoban 3D"
const SUBTITLE_TEXT := "A quiet puzzle in a small room"
const PLAY_TEXT := "Play"
const LEVEL_SELECT_TEXT := "Level Select"
const SETTINGS_TEXT := "Settings"
const CREDITS_TEXT := "Credits"
const QUIT_TEXT := "Quit"
const VERSION_FORMAT := "v%s"
const BUTTON_MIN_SIZE := Vector2(320, 48)

var _root: Control
var _title: Label
var _subtitle: Label
var _version: Label
var _buttons: Array[Button] = []
var _bound: bool = false


func _ready() -> void:
	_bind()


## Gives the primary action the focus so the menu opens keyboard-ready.
func focus_default() -> void:
	_bind()
	if is_inside_tree() and not _buttons.is_empty():
		_buttons[0].grab_focus()


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


func _bind() -> void:
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
	var button_paths: Array[String] = [
		"Root/Content/Margin/Layout/Buttons/Play",
		"Root/Content/Margin/Layout/Buttons/LevelSelect",
		"Root/Content/Margin/Layout/Buttons/Settings",
		"Root/Content/Margin/Layout/Buttons/Credits",
		"Root/Content/Margin/Layout/Buttons/Quit",
	]
	for index: int in button_paths.size():
		var button := get_node_or_null(button_paths[index]) as Button
		if button == null:
			push_error("main_menu: missing button %s" % button_paths[index])
			continue
		button.custom_minimum_size = BUTTON_MIN_SIZE
		_buttons.append(button)
	if _buttons.size() != button_paths.size():
		return
	if _title != null:
		_title.text = TITLE_TEXT
	if _subtitle != null:
		_subtitle.text = SUBTITLE_TEXT
	var texts: Array[String] = [PLAY_TEXT, LEVEL_SELECT_TEXT, SETTINGS_TEXT, CREDITS_TEXT, QUIT_TEXT]
	for index: int in _buttons.size():
		_buttons[index].text = texts[index]
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
