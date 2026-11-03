class_name ScreenRouter
extends RefCounted

## The screen graph from design/ui-flow.md "Screen graph", as pure state so a
## headless test can walk it without a window.
##
## The router owns only which screen is visible and where `back()` returns to.
## It never loads a level, mutates a session or touches a node: `src/main.gd`
## listens to `screen_changed` and applies visibility and input context. An
## undefined transition is refused and leaves the current screen unchanged.

signal screen_changed(from_screen: int, to_screen: int)

enum Screen { MAIN_MENU, LEVEL_SELECT, GAMEPLAY, PAUSE, VICTORY, SETTINGS, CREDITS }

const SCREEN_NAMES := {
	Screen.MAIN_MENU: "main_menu",
	Screen.LEVEL_SELECT: "level_select",
	Screen.GAMEPLAY: "gameplay",
	Screen.PAUSE: "pause",
	Screen.VICTORY: "victory",
	Screen.SETTINGS: "settings",
	Screen.CREDITS: "credits",
}

var screen: int = Screen.MAIN_MENU

var _return_screen: int = Screen.MAIN_MENU


## The name of a screen constant, for logs and assertions.
static func screen_name(value: int) -> String:
	return str(SCREEN_NAMES.get(value, "unknown"))


## True while the 3D room is part of what the player sees.
func shows_room() -> bool:
	return screen == Screen.GAMEPLAY or screen == Screen.PAUSE or screen == Screen.VICTORY


## Only the gameplay screen forwards movement, undo, restart and camera input.
func accepts_gameplay_input() -> bool:
	return screen == Screen.GAMEPLAY


func show_main_menu() -> bool:
	return _set_screen(Screen.MAIN_MENU)


func show_level_select() -> bool:
	if not (screen == Screen.MAIN_MENU or screen == Screen.VICTORY):
		return false
	_return_screen = Screen.MAIN_MENU
	return _set_screen(Screen.LEVEL_SELECT)


func start_gameplay() -> bool:
	if not (
		screen == Screen.MAIN_MENU
		or screen == Screen.LEVEL_SELECT
		or screen == Screen.VICTORY
	):
		return false
	return _set_screen(Screen.GAMEPLAY)


func pause_game() -> bool:
	if screen != Screen.GAMEPLAY:
		return false
	return _set_screen(Screen.PAUSE)


func resume_game() -> bool:
	if screen != Screen.PAUSE:
		return false
	return _set_screen(Screen.GAMEPLAY)


func show_victory() -> bool:
	if screen != Screen.GAMEPLAY:
		return false
	return _set_screen(Screen.VICTORY)


func show_settings() -> bool:
	if not (screen == Screen.MAIN_MENU or screen == Screen.PAUSE):
		return false
	_return_screen = screen
	return _set_screen(Screen.SETTINGS)


func show_credits() -> bool:
	if screen != Screen.MAIN_MENU:
		return false
	_return_screen = Screen.MAIN_MENU
	return _set_screen(Screen.CREDITS)


## Returns to the screen that opened the current one. Pause resumes the game;
## level select, settings and credits return to their opener; every other screen
## has no back edge and the call is refused.
func back() -> bool:
	match screen:
		Screen.LEVEL_SELECT, Screen.SETTINGS, Screen.CREDITS:
			return _set_screen(_return_screen)
		Screen.PAUSE:
			return resume_game()
	return false


func _set_screen(next_screen: int) -> bool:
	if next_screen == screen:
		return false
	var previous := screen
	screen = next_screen
	screen_changed.emit(previous, next_screen)
	return true
