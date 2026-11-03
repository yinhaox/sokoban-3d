extends Node3D

## Boot scene and screen router for the 3D Sokoban game, per issue #13 and
## design/ui-flow.md.
##
## Boot installs the runtime input actions, shows the main menu and keeps one
## room scene alive under the screens: entering a level builds the board, leaving
## hides it, and no transition restarts the process. The router model
## (`ScreenRouter`) owns which screen is visible; this node applies visibility,
## forwards the screens' intent signals to the gameplay controller and back, and
## shows the confirm modal before a destructive action runs.
##
## The capture aids below only apply to a capture run and change no gameplay
## path: `--screen=`, `--level=`, `--script=`, `--capture-instant` and
## `--window=WxH`, so `capture_command` can screenshot every screen at the
## project size and at 1280x720.

const LevelDataScript = preload("res://src/logic/level_data.gd")
const BoardBuilderScript = preload("res://src/game/board_builder.gd")
const CameraRigScript = preload("res://src/game/camera_rig.gd")
const GameplayControllerScript = preload("res://src/game/gameplay_controller.gd")
const LevelSequenceScript = preload("res://src/game/level_sequence.gd")
const LevelProgressScript = preload("res://src/logic/level_progress.gd")
const ScreenRouterScript = preload("res://src/ui/screen_router.gd")
const VictoryPanelScript = preload("res://src/ui/victory_panel.gd")
const InputActionsScript = preload("res://src/input/input_actions.gd")

const DEFAULT_LEVEL_PATH := "res://assets/data/levels/level-001.json"

## Optional capture aid: an integer 1..3 in this environment variable boots the
## room at that quarter turn, so `capture_command` can screenshot every snap
## state. Unset, the room boots at the default yaw.
const CAPTURE_QUARTER_TURNS_ENV := "STUDIO_CAPTURE_QUARTER_TURNS"

const CAPTURE_LEVEL_ARG := "--level="
const CAPTURE_SCRIPT_ARG := "--script="
const CAPTURE_INSTANT_ARG := "--capture-instant"
const CAPTURE_SCREEN_ARG := "--screen="
const CAPTURE_WINDOW_ARG := "--window="
const WINDOW_SIZE_SEPARATOR := "x"

const SCREEN_MAIN_MENU := "menu"
const SCREEN_LEVEL_SELECT := "level-select"
const SCREEN_GAMEPLAY := "gameplay"
const SCREEN_PAUSE := "pause"
const SCREEN_VICTORY := "victory"
const SCREEN_SETTINGS := "settings"
const SCREEN_CREDITS := "credits"
const SCREEN_CONFIRM := "confirm"

const SETTINGS_TITLE := "Settings"
const SETTINGS_BODY := (
	"Settings arrives in the next story. Audio, display, accessibility and "
	+ "controls will live on this screen."
)
const CREDITS_TITLE := "Credits"
const CREDITS_BODY := (
	"Sokoban 3D\nA small studio sample built with Godot 4.7.\n"
	+ "Design and levels: Sokoban 3D Studio."
)
const RESTART_QUESTION := "Discard this attempt?"
const LEAVE_QUESTION := "Leave the level and discard this attempt?"

enum ConfirmAction { NONE, RESTART, MAIN_MENU }

@export_file("*.json") var level_path: String = DEFAULT_LEVEL_PATH

@onready var _board: BoardBuilderScript = $Board as BoardBuilderScript
@onready var _camera_rig: CameraRigScript = $CameraRig as CameraRigScript
@onready var _gameplay: GameplayControllerScript = $Gameplay as GameplayControllerScript
@onready var _victory: VictoryPanelScript = $VictoryPanel as VictoryPanelScript
@onready var _hud: Hud = $HUD as Hud
@onready var _main_menu: MainMenu = $MainMenu as MainMenu
@onready var _level_select: LevelSelect = $LevelSelect as LevelSelect
@onready var _pause_menu: PauseMenu = $PauseMenu as PauseMenu
@onready var _confirm: ConfirmModal = $ConfirmModal as ConfirmModal
@onready var _settings_panel: InfoPanel = $SettingsPanel as InfoPanel
@onready var _credits_panel: InfoPanel = $CreditsPanel as InfoPanel

var router: ScreenRouterScript
var _level_paths: Array[String] = []
var _level_index: int = 0
var _completed: Dictionary = {}
var _capture_script: String = ""
var _instant_capture: bool = false
var _pending_confirm: int = ConfirmAction.NONE
var _modal_paused_gameplay: bool = false


func _ready() -> void:
	InputActionsScript.register_defaults()
	router = ScreenRouterScript.new()
	router.screen_changed.connect(_on_screen_changed)
	_level_paths = LevelSequenceScript.level_paths()
	_wire_signals()
	_settings_panel.set_content(SETTINGS_TITLE, SETTINGS_BODY)
	_credits_panel.set_content(CREDITS_TITLE, CREDITS_BODY)
	_capture_script = capture_argument(CAPTURE_SCRIPT_ARG)
	_instant_capture = has_capture_argument(CAPTURE_INSTANT_ARG) or not _capture_script.is_empty()
	_level_index = _requested_level_index()
	_apply_window_argument()
	_apply_screen(router.screen)
	_apply_capture_screen(capture_argument(CAPTURE_SCREEN_ARG))


## Which screen the player is on, as `ScreenRouter.Screen`.
func current_screen() -> int:
	return router.screen if router != null else ScreenRouterScript.Screen.MAIN_MENU


func _wire_signals() -> void:
	_main_menu.play_requested.connect(_on_play_requested)
	_main_menu.level_select_requested.connect(_open_level_select)
	_main_menu.settings_requested.connect(_open_settings)
	_main_menu.credits_requested.connect(_open_credits)
	_main_menu.quit_requested.connect(_on_quit_requested)
	_level_select.level_selected.connect(_on_level_selected)
	_level_select.back_requested.connect(_on_back_requested)
	_pause_menu.resume_requested.connect(_on_resume_requested)
	_pause_menu.restart_requested.connect(_request_restart)
	_pause_menu.settings_requested.connect(_open_settings)
	_pause_menu.main_menu_requested.connect(_request_main_menu)
	_confirm.confirmed.connect(_on_confirm_confirmed)
	_confirm.cancelled.connect(_on_confirm_cancelled)
	_settings_panel.back_requested.connect(_on_back_requested)
	_credits_panel.back_requested.connect(_on_back_requested)
	_victory.retry_requested.connect(_on_retry_requested)
	_victory.next_requested.connect(_on_next_requested)
	_victory.level_select_requested.connect(_open_level_select)
	_hud.undo_requested.connect(_on_undo_requested)
	_hud.restart_requested.connect(_request_restart)
	_hud.pause_requested.connect(_on_pause_requested)
	_gameplay.victory.connect(_on_victory)
	_gameplay.attempt_changed.connect(_on_attempt_changed)


func _process(_delta: float) -> void:
	if router == null or _gameplay.session == null:
		return
	if router.screen == ScreenRouterScript.Screen.GAMEPLAY:
		_hud.set_elapsed_ms(_gameplay.elapsed_ms())


## Global keys are resolved by the active screen, never by both: Escape pauses
## in gameplay and goes back one level everywhere else (design/input-and-controls
## .md "Context stack").
func _input(event: InputEvent) -> void:
	var screen := router.screen
	if _confirm.is_open():
		if _is_back_or_pause(event):
			_confirm.cancel()
			_accept_input()
		return
	if screen == ScreenRouterScript.Screen.GAMEPLAY and event.is_action_pressed(
		InputActionsScript.PAUSE
	):
		router.pause_game()
		_accept_input()
		return
	if screen == ScreenRouterScript.Screen.PAUSE and _is_back_or_pause(event):
		router.resume_game()
		_accept_input()
		return
	if _is_back_screen(screen) and event.is_action_pressed(InputActionsScript.UI_BACK):
		router.back()
		_accept_input()


func _is_back_or_pause(event: InputEvent) -> bool:
	return event.is_action_pressed(InputActionsScript.UI_BACK) or event.is_action_pressed(
		InputActionsScript.PAUSE
	)


func _is_back_screen(screen: int) -> bool:
	return (
		screen == ScreenRouterScript.Screen.LEVEL_SELECT
		or screen == ScreenRouterScript.Screen.SETTINGS
		or screen == ScreenRouterScript.Screen.CREDITS
	)


func _accept_input() -> void:
	if is_inside_tree():
		get_viewport().set_input_as_handled()


func _on_screen_changed(_from_screen: int, to_screen: int) -> void:
	_apply_screen(to_screen)


## Applies visibility, the input context and the default focus for one screen.
func _apply_screen(screen: int) -> void:
	var shows_room := router.shows_room()
	_board.visible = shows_room
	_camera_rig.visible = shows_room
	_main_menu.visible = screen == ScreenRouterScript.Screen.MAIN_MENU
	_level_select.visible = screen == ScreenRouterScript.Screen.LEVEL_SELECT
	_hud.visible = screen == ScreenRouterScript.Screen.GAMEPLAY
	_pause_menu.visible = screen == ScreenRouterScript.Screen.PAUSE
	_victory.visible = screen == ScreenRouterScript.Screen.VICTORY
	_settings_panel.visible = screen == ScreenRouterScript.Screen.SETTINGS
	_credits_panel.visible = screen == ScreenRouterScript.Screen.CREDITS
	_gameplay.set_paused(screen != ScreenRouterScript.Screen.GAMEPLAY)
	_gameplay.set_process_input(screen == ScreenRouterScript.Screen.GAMEPLAY)
	_camera_rig.set_process_unhandled_input(screen == ScreenRouterScript.Screen.GAMEPLAY)
	match screen:
		ScreenRouterScript.Screen.MAIN_MENU:
			_main_menu.focus_default()
		ScreenRouterScript.Screen.LEVEL_SELECT:
			_level_select.focus_default()
		ScreenRouterScript.Screen.PAUSE:
			_pause_menu.focus_default()
		ScreenRouterScript.Screen.SETTINGS:
			_settings_panel.focus_default()
		ScreenRouterScript.Screen.CREDITS:
			_credits_panel.focus_default()
	if shows_room and screen == ScreenRouterScript.Screen.GAMEPLAY:
		if is_inside_tree():
			get_viewport().gui_release_focus()


func _start_level(index: int) -> void:
	if _level_paths.is_empty():
		push_error("main: no level files found in the level directory")
		return
	_level_index = clampi(index, 0, _level_paths.size() - 1)
	var level := load_level_file(_level_paths[_level_index])
	if level == null:
		return
	_board.show()
	_camera_rig.show()
	_board.build(level)
	_camera_rig.setup(level, _board)
	_gameplay.animation_enabled = not _instant_capture
	_gameplay.win_delay_seconds = (
		0.0 if _instant_capture else GameplayControllerScript.WIN_DELAY_SECONDS
	)
	var has_next := LevelSequenceScript.has_next(_level_paths, _level_index)
	_gameplay.setup(level, _board, _camera_rig, has_next)
	_hud.set_level(_level_index + 1, level.name)
	_hud.set_attempt_stats(_gameplay.attempt_stats())
	_victory.hide_panel()
	router.start_gameplay()
	var turns := capture_quarter_turns()
	if turns != 0:
		_camera_rig.set_quarter_turns(turns)
	if _capture_script.is_empty():
		return
	if not _gameplay.apply_move_script(_capture_script):
		push_warning("main: capture script '%s' was not fully applied" % _capture_script)


func _open_level_select() -> void:
	_level_select.show_levels(_level_entries())
	router.show_level_select()


func _open_settings() -> void:
	router.show_settings()


func _open_credits() -> void:
	router.show_credits()


func _on_back_requested() -> void:
	router.back()


func _on_play_requested() -> void:
	var index := LevelProgressScript.next_level_index(_level_paths, _completed)
	if index < 0:
		push_error("main: Play has no level to open")
		return
	_start_level(index)


func _on_level_selected(index: int) -> void:
	_start_level(index)


func _on_quit_requested() -> void:
	get_tree().quit()


func _on_pause_requested() -> void:
	router.pause_game()


func _on_resume_requested() -> void:
	router.resume_game()


func _on_undo_requested() -> void:
	_gameplay.undo()


func _on_attempt_changed(stats: Dictionary) -> void:
	_hud.set_attempt_stats(stats)


func _on_victory(stats: Dictionary, has_next: bool) -> void:
	_completed[_level_paths[_level_index]] = true
	router.show_victory()
	_victory.show_result(stats, has_next)


func _on_retry_requested() -> void:
	_start_level(_level_index)


func _on_next_requested() -> void:
	if not LevelSequenceScript.has_next(_level_paths, _level_index):
		return
	_start_level(_level_index + 1)


## Restart is destructive once the attempt has a move: it asks first and Cancel
## takes the focus. At `moves == 0` it happens immediately, per
## design/core-rules.md "Restart".
func _request_restart() -> void:
	if _gameplay.session == null:
		return
	if _gameplay.session.moves == 0:
		_perform_restart()
		return
	_modal_paused_gameplay = router.screen == ScreenRouterScript.Screen.GAMEPLAY
	if _modal_paused_gameplay:
		_gameplay.set_paused(true)
	_pending_confirm = ConfirmAction.RESTART
	_confirm.ask(RESTART_QUESTION)


func _request_main_menu() -> void:
	if _gameplay.session == null or _gameplay.session.moves == 0:
		_go_main_menu()
		return
	_pending_confirm = ConfirmAction.MAIN_MENU
	_confirm.ask(LEAVE_QUESTION)


func _perform_restart() -> void:
	_gameplay.restart_level()
	if router.screen == ScreenRouterScript.Screen.PAUSE:
		router.resume_game()
	elif router.screen == ScreenRouterScript.Screen.GAMEPLAY:
		_gameplay.set_paused(false)
	_hud.set_attempt_stats(_gameplay.attempt_stats())


func _go_main_menu() -> void:
	router.show_main_menu()


func _on_confirm_confirmed() -> void:
	var action := _pending_confirm
	_pending_confirm = ConfirmAction.NONE
	_modal_paused_gameplay = false
	match action:
		ConfirmAction.RESTART:
			_perform_restart()
		ConfirmAction.MAIN_MENU:
			_go_main_menu()


func _on_confirm_cancelled() -> void:
	_pending_confirm = ConfirmAction.NONE
	if _modal_paused_gameplay:
		_modal_paused_gameplay = false
		_gameplay.set_paused(false)


## One entry per level file for the level select grid.
func _level_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for index: int in _level_paths.size():
		var level := load_level_file(_level_paths[index])
		if level == null:
			continue
		entries.append(
			{
				"index": index,
				"name": level.name,
				"par_moves": level.par_moves,
				"difficulty": level.difficulty,
				"completed": _completed.has(_level_paths[index]),
			}
		)
	return entries


## Boots the state a capture asks for. Only a capture run passes `--screen=`;
## a normal boot always lands on the main menu.
func _apply_capture_screen(screen_name: String) -> void:
	match screen_name:
		SCREEN_MAIN_MENU:
			router.show_main_menu()
			_main_menu.focus_default()
		SCREEN_LEVEL_SELECT:
			_open_level_select()
		SCREEN_GAMEPLAY:
			_start_level(_level_index)
		SCREEN_PAUSE:
			_start_level(_level_index)
			router.pause_game()
		SCREEN_VICTORY:
			_start_level(_level_index)
			if router.screen != ScreenRouterScript.Screen.VICTORY:
				push_warning("main: --screen=victory needs a --script= that solves the level")
		SCREEN_SETTINGS:
			_open_settings()
		SCREEN_CREDITS:
			_open_credits()
		SCREEN_CONFIRM:
			_start_level(_level_index)
			_request_restart()


## The level position requested with `--level=`, or 0.
func _requested_level_index() -> int:
	var requested := capture_argument(CAPTURE_LEVEL_ARG)
	if requested.is_empty():
		return 0
	var resolved := resolve_level_argument(requested, _level_paths)
	if resolved.is_empty():
		push_warning("main: --level=%s does not name a level; booting the first level" % requested)
		return 0
	return maxi(LevelSequenceScript.index_of(_level_paths, resolved), 0)


## Resizes the window for a layout capture, e.g. `--window=1280x720`. An invalid
## value is ignored with a warning so a normal run is unaffected.
func _apply_window_argument() -> void:
	var raw := capture_argument(CAPTURE_WINDOW_ARG)
	if raw.is_empty():
		return
	var parts := raw.split(WINDOW_SIZE_SEPARATOR, false)
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		push_warning("main: --window=%s is not WxH; keeping the project window size" % raw)
		return
	DisplayServer.window_set_size(Vector2i(parts[0].to_int(), parts[1].to_int()))


## Quarter turn requested by the capture aid, or 0 when it is unset.
static func capture_quarter_turns() -> int:
	var raw := OS.get_environment(CAPTURE_QUARTER_TURNS_ENV).strip_edges()
	if not raw.is_valid_int():
		return 0
	return posmod(raw.to_int(), 4)


## Value of `prefix` from the user arguments after the engine's `--`, or an
## empty string when that argument is absent.
static func capture_argument(prefix: String) -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with(prefix):
			return argument.substr(prefix.length())
	return ""


static func has_capture_argument(flag: String) -> bool:
	for argument: String in OS.get_cmdline_user_args():
		if argument == flag:
			return true
	return false


## Resolves `--level=` to a level path: a 1-based position in `paths`, a level id
## such as `level-003`, a file name, or a full `res://` path. An unknown value
## returns an empty string.
static func resolve_level_argument(value: String, paths: Array[String]) -> String:
	var trimmed := value.strip_edges()
	if trimmed.is_empty():
		return ""
	if trimmed.is_valid_int():
		var position := trimmed.to_int() - 1
		if position < 0 or position >= paths.size():
			return ""
		return paths[position]
	for path: String in paths:
		var file_name := path.get_file()
		if trimmed == path or trimmed == file_name or trimmed == file_name.get_basename():
			return path
	return ""


## Reads and validates one level file. Returns null and logs the reason when the
## file is missing, unreadable or invalid, so the boot scene never half-loads a
## room.
static func load_level_file(path: String) -> LevelDataScript:
	if not FileAccess.file_exists(path):
		push_error("main: level file not found: %s" % path)
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("main: cannot read level file: %s" % path)
		return null
	var text := file.get_as_text()
	file.close()
	var level := LevelDataScript.from_json_text(text, path.get_file().get_basename())
	if not level.is_valid():
		push_error("main: invalid level '%s': %s" % [path, level.error_summary()])
		return null
	return level
