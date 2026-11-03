class_name InputActions
extends RefCounted

## Runtime registration of the shared gameplay/UI action vocabulary from
## design/input-and-controls.md "Action vocabulary".
##
## `project.godot` is outside this story's write boundary, so the defaults are
## installed with `InputMap.add_action()` / `InputMap.action_add_event()` at
## boot instead of being authored in the project settings. The table below
## mirrors the design page one for one: every action keeps exactly the bindings
## that page lists, and `register_defaults()` is idempotent so a second call
## never duplicates an event.

const MOVE_UP := "move_up"
const MOVE_DOWN := "move_down"
const MOVE_LEFT := "move_left"
const MOVE_RIGHT := "move_right"
const UNDO := "undo"
const RESTART := "restart"
const PAUSE := "pause"
const CAMERA_ROTATE_LEFT := "camera_rotate_left"
const CAMERA_ROTATE_RIGHT := "camera_rotate_right"
const CAMERA_ZOOM_IN := "camera_zoom_in"
const CAMERA_ZOOM_OUT := "camera_zoom_out"
const UI_BACK := "ui_back"

## Actions that drive the room, per design/input-and-controls.md.
const GAMEPLAY_ACTIONS: Array[String] = [
	MOVE_UP,
	MOVE_DOWN,
	MOVE_LEFT,
	MOVE_RIGHT,
	UNDO,
	RESTART,
	PAUSE,
	CAMERA_ROTATE_LEFT,
	CAMERA_ROTATE_RIGHT,
	CAMERA_ZOOM_IN,
	CAMERA_ZOOM_OUT,
]

const DIRECTION_ACTIONS: Array[String] = [MOVE_UP, MOVE_DOWN, MOVE_LEFT, MOVE_RIGHT]

## UI navigation is fixed and cannot be rebound; `ui_back` is registered next to
## the engine's own `ui_accept` / `ui_focus_*` defaults because the design page
## names it explicitly.
const UI_ACTIONS: Array[String] = [UI_BACK]

const UNDO_REPEAT_MODIFIER_CTRL := true


## Installs every action and binding the design page lists. Safe to call on a
## project that already declares some of them: an existing action keeps its
## bindings and only the missing defaults are added.
static func register_defaults() -> void:
	for action: String in all_actions():
		if not InputMap.has_action(action):
			InputMap.add_action(action)
	for action: String in all_actions():
		for event: InputEvent in default_events(action):
			if not InputMap.action_has_event(action, event):
				InputMap.action_add_event(action, event)


## Every action this helper owns: the gameplay vocabulary plus `ui_back`.
static func all_actions() -> Array[String]:
	var actions: Array[String] = []
	actions.append_array(GAMEPLAY_ACTIONS)
	actions.append_array(UI_ACTIONS)
	return actions


## The design defaults for one action. An unknown action returns an empty list
## instead of inventing a binding.
static func default_events(action: String) -> Array[InputEvent]:
	if DIRECTION_ACTIONS.has(action):
		return _direction_events(action)
	match action:
		UNDO, RESTART, PAUSE:
			return _control_events(action)
		CAMERA_ROTATE_LEFT, CAMERA_ROTATE_RIGHT:
			return _rotation_events(action)
		CAMERA_ZOOM_IN, CAMERA_ZOOM_OUT:
			return _zoom_events(action)
		UI_BACK:
			return [key_event(KEY_ESCAPE), joy_button_event(JOY_BUTTON_B)]
	return []


static func _direction_events(action: String) -> Array[InputEvent]:
	var events: Array[InputEvent] = []
	match action:
		MOVE_UP:
			events = [
				key_event(KEY_UP),
				key_event(KEY_W),
				joy_button_event(JOY_BUTTON_DPAD_UP),
				joy_axis_event(JOY_AXIS_LEFT_Y, -1.0),
			]
		MOVE_DOWN:
			events = [
				key_event(KEY_DOWN),
				key_event(KEY_S),
				joy_button_event(JOY_BUTTON_DPAD_DOWN),
				joy_axis_event(JOY_AXIS_LEFT_Y, 1.0),
			]
		MOVE_LEFT:
			events = [
				key_event(KEY_LEFT),
				key_event(KEY_A),
				joy_button_event(JOY_BUTTON_DPAD_LEFT),
				joy_axis_event(JOY_AXIS_LEFT_X, -1.0),
			]
		MOVE_RIGHT:
			events = [
				key_event(KEY_RIGHT),
				key_event(KEY_D),
				joy_button_event(JOY_BUTTON_DPAD_RIGHT),
				joy_axis_event(JOY_AXIS_LEFT_X, 1.0),
			]
	return events


static func _control_events(action: String) -> Array[InputEvent]:
	match action:
		UNDO:
			return [
				key_event(KEY_Z),
				key_event(KEY_Z, UNDO_REPEAT_MODIFIER_CTRL),
				joy_button_event(JOY_BUTTON_Y),
			]
		RESTART:
			return [key_event(KEY_R), joy_button_event(JOY_BUTTON_X)]
		PAUSE:
			return [
				key_event(KEY_ESCAPE),
				key_event(KEY_P),
				joy_button_event(JOY_BUTTON_START),
			]
	return []


static func _rotation_events(action: String) -> Array[InputEvent]:
	if action == CAMERA_ROTATE_LEFT:
		return [key_event(KEY_Q), joy_button_event(JOY_BUTTON_LEFT_SHOULDER)]
	return [key_event(KEY_E), joy_button_event(JOY_BUTTON_RIGHT_SHOULDER)]


static func _zoom_events(action: String) -> Array[InputEvent]:
	if action == CAMERA_ZOOM_IN:
		return [
			key_event(KEY_EQUAL),
			mouse_wheel_event(MOUSE_BUTTON_WHEEL_UP),
			joy_axis_event(JOY_AXIS_TRIGGER_RIGHT, 1.0),
		]
	return [
		key_event(KEY_MINUS),
		mouse_wheel_event(MOUSE_BUTTON_WHEEL_DOWN),
		joy_axis_event(JOY_AXIS_TRIGGER_LEFT, 1.0),
	]


static func key_event(keycode: int, ctrl: bool = false) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.ctrl_pressed = ctrl
	return event


static func joy_button_event(button_index: int) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button_index
	return event


static func joy_axis_event(axis: int, axis_value: float) -> InputEventJoypadMotion:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = axis_value
	return event


static func mouse_wheel_event(button_index: int) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button_index
	return event
