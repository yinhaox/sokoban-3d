class_name PauseMenu
extends CanvasLayer

## Pause overlay from design/ui-flow.md "Gameplay -> Pause": Resume, Restart,
## Settings and Main Menu over the frozen room. The destructive actions ask the
## confirm modal before they run; this screen only emits the intent.
##
## Localization is out of scope for this story, so the labels are English
## literals in this script until the localization story swaps them for `tr()`.

signal resume_requested
signal restart_requested
signal settings_requested
signal main_menu_requested

const TITLE_TEXT := "Paused"
const RESUME_TEXT := "Resume"
const RESTART_TEXT := "Restart"
const SETTINGS_TEXT := "Settings"
const MAIN_MENU_TEXT := "Main Menu"
const BUTTON_MIN_SIZE := Vector2(300, 48)

var _root: Control
var _title: Label
var _buttons: Array[Button] = []
var _bound: bool = false


func _ready() -> void:
	_bind()


## Focuses Resume, the safe default, when the pause menu opens.
func focus_default() -> void:
	_bind()
	if is_inside_tree() and not _buttons.is_empty():
		_buttons[0].grab_focus()


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
		push_error("pause_menu: the Root control is missing")
		return
	if _root.theme == null:
		_root.theme = UiTheme.build()
	_title = get_node_or_null("Root/Center/Panel/Content/Title") as Label
	var button_paths: Array[String] = [
		"Root/Center/Panel/Content/Resume",
		"Root/Center/Panel/Content/Restart",
		"Root/Center/Panel/Content/Settings",
		"Root/Center/Panel/Content/MainMenu",
	]
	for path: String in button_paths:
		var button := get_node_or_null(path) as Button
		if button == null:
			push_error("pause_menu: missing button %s" % path)
			continue
		button.custom_minimum_size = BUTTON_MIN_SIZE
		_buttons.append(button)
	if _buttons.size() != button_paths.size():
		return
	if _title != null:
		_title.text = TITLE_TEXT
	var texts: Array[String] = [RESUME_TEXT, RESTART_TEXT, SETTINGS_TEXT, MAIN_MENU_TEXT]
	for index: int in _buttons.size():
		_buttons[index].text = texts[index]
	var controls: Array[Control] = []
	controls.assign(_buttons)
	UiFocus.wire_vertical(controls)
	_buttons[0].pressed.connect(_on_resume_pressed)
	_buttons[1].pressed.connect(_on_restart_pressed)
	_buttons[2].pressed.connect(_on_settings_pressed)
	_buttons[3].pressed.connect(_on_main_menu_pressed)


func _on_resume_pressed() -> void:
	resume_requested.emit()


func _on_restart_pressed() -> void:
	restart_requested.emit()


func _on_settings_pressed() -> void:
	settings_requested.emit()


func _on_main_menu_pressed() -> void:
	main_menu_requested.emit()
