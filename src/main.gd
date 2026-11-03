extends Node3D

## Boot scene and screen router for the 3D Sokoban game.
##
## Boot installs the runtime input actions, resolves the versioned profile,
## applies the stored settings, shows the main menu and keeps one room scene
## alive under the screens. The router model (`ScreenRouter`) owns which screen is
## visible; this node applies visibility, forwards the screens' intent signals to
## the gameplay controller and back, persists progress and settings through
## `SaveStore`, and shows the confirm modal before a destructive action runs.
##
## The capture aids below only apply to a capture run and change no gameplay
## path: `--screen=`, `--level=`, `--script=`, `--capture-instant`,
## `--window=WxH`, `--save=`, `--fresh-save`, `--language=` and `--colorblind=`,
## so `capture_command` can screenshot each state and each locale.

const LevelDataScript = preload("res://src/logic/level_data.gd")
const BoardBuilderScript = preload("res://src/game/board_builder.gd")
const CameraRigScript = preload("res://src/game/camera_rig.gd")
const GameplayControllerScript = preload("res://src/game/gameplay_controller.gd")
const LevelSequenceScript = preload("res://src/game/level_sequence.gd")
const LevelProgressScript = preload("res://src/logic/level_progress.gd")
const StarRatingScript = preload("res://src/logic/star_rating.gd")
const ScreenRouterScript = preload("res://src/ui/screen_router.gd")
const VictoryPanelScript = preload("res://src/ui/victory_panel.gd")
const SettingsScreenScript = preload("res://src/ui/settings_screen.gd")
const SaveStoreScript = preload("res://src/logic/save_store.gd")
const SettingsModelScript = preload("res://src/logic/settings_model.gd")
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
const CAPTURE_SAVE_ARG := "--save="
const CAPTURE_FRESH_SAVE_ARG := "--fresh-save"
const CAPTURE_LANGUAGE_ARG := "--language="
const CAPTURE_COLORBLIND_ARG := "--colorblind="
const WINDOW_SIZE_SEPARATOR := "x"

const SCREEN_MAIN_MENU := "menu"
const SCREEN_LEVEL_SELECT := "level-select"
const SCREEN_GAMEPLAY := "gameplay"
const SCREEN_PAUSE := "pause"
const SCREEN_VICTORY := "victory"
const SCREEN_SETTINGS := "settings"
const SCREEN_CREDITS := "credits"
const SCREEN_CONFIRM := "confirm"

const CREDITS_TITLE_KEY := "ui_credits_title"
const CREDITS_BODY_KEY := "ui_credits_body"
const CONFIRM_RESTART_KEY := "ui_confirm_restart"
const CONFIRM_LEAVE_KEY := "ui_confirm_leave"

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
@onready var _settings_screen: SettingsScreenScript = $SettingsPanel as SettingsScreenScript
@onready var _credits_panel: InfoPanel = $CreditsPanel as InfoPanel

var router: ScreenRouterScript
var save_store: SaveStoreScript

var _level_paths: Array[String] = []
var _level_index: int = 0
var _current_level: LevelDataScript
var _completed: Dictionary = {}
var _capture_script: String = ""
var _instant_capture: bool = false
var _pending_confirm: int = ConfirmAction.NONE
var _modal_paused_gameplay: bool = false
var _notice_key: String = ""
var _notice_arg: String = ""


func _ready() -> void:
	InputActionsScript.register_defaults()
	Localization.install()
	router = ScreenRouterScript.new()
	router.screen_changed.connect(_on_screen_changed)
	_level_paths = LevelSequenceScript.level_paths()
	_wire_signals()
	_setup_save_store()
	_apply_capture_settings()
	_apply_settings()
	if get_tree() != null:
		get_tree().auto_accept_quit = false
	_capture_script = capture_argument(CAPTURE_SCRIPT_ARG)
	_instant_capture = has_capture_argument(CAPTURE_INSTANT_ARG) or not _capture_script.is_empty()
	_level_index = _requested_level_index()
	_apply_window_argument()
	_apply_screen(router.screen)
	_apply_capture_screen(capture_argument(CAPTURE_SCREEN_ARG))


## Which screen the player is on, as `ScreenRouter.Screen`.
func current_screen() -> int:
	return router.screen if router != null else ScreenRouterScript.Screen.MAIN_MENU


## Persists the profile when the window is closed through the normal close path.
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if save_store != null:
			save_store.flush()
		if get_tree() != null:
			get_tree().quit()


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
	_settings_screen.setting_changed.connect(_on_setting_requested)
	_settings_screen.back_requested.connect(_on_back_requested)
	_confirm.confirmed.connect(_on_confirm_confirmed)
	_confirm.cancelled.connect(_on_confirm_cancelled)
	_credits_panel.back_requested.connect(_on_back_requested)
	_victory.retry_requested.connect(_on_retry_requested)
	_victory.next_requested.connect(_on_next_requested)
	_victory.level_select_requested.connect(_open_level_select)
	_hud.undo_requested.connect(_on_undo_requested)
	_hud.restart_requested.connect(_request_restart)
	_hud.pause_requested.connect(_on_pause_requested)
	_gameplay.victory.connect(_on_victory)
	_gameplay.attempt_changed.connect(_on_attempt_changed)


## Creates the save store, resolves the profile and reports a damaged or newer
## file once on the main menu. A capture run can point at a throwaway profile.
func _setup_save_store() -> void:
	save_store = SaveStoreScript.new()
	save_store.name = "SaveStore"
	add_child(save_store)
	save_store.save_failed.connect(_on_save_failed)
	var requested_path := capture_argument(CAPTURE_SAVE_ARG)
	if not requested_path.is_empty():
		save_store.configure(requested_path)
	if has_capture_argument(CAPTURE_FRESH_SAVE_ARG):
		save_store.erase_profile_files()
	var summary: Dictionary = save_store.load_profile()
	if not save_store.read_only:
		save_store.ensure_unlocked(_first_level_id())
		if summary.get("status", "") != SaveStoreScript.STATUS_OK:
			save_store.save_now()
	_notice_key = str(summary.get("notice_key", ""))
	_notice_arg = str(summary.get("notice_arg", ""))
	_completed.clear()
	for level_id: String in _level_ids():
		if save_store.is_completed(level_id):
			_completed[level_id] = true


func _level_ids() -> Array[String]:
	var ids: Array[String] = []
	for path: String in _level_paths:
		ids.append(path.get_file().get_basename())
	return ids


func _first_level_id() -> String:
	var ids := _level_ids()
	return ids[0] if not ids.is_empty() else SaveStoreScript.FIRST_LEVEL_ID


func _index_of_level(level_id: String) -> int:
	for index: int in _level_paths.size():
		if _level_paths[index].get_file().get_basename() == level_id:
			return index
	return -1


## Applies every stored setting to the running game. Called at boot and after
## every change, so a settings row never needs an Apply button.
func _apply_settings() -> void:
	var settings := save_store.settings()
	Localization.set_locale(str(settings.get(SettingsModelScript.LANGUAGE, "en")))
	_apply_audio(settings)
	_apply_fullscreen(settings)
	_camera_rig.reduce_motion = bool(settings.get(SettingsModelScript.REDUCE_MOTION, false))
	_camera_rig.sensitivity = float(settings.get(SettingsModelScript.CAMERA_SENSITIVITY, 1.0))
	_gameplay.reduce_motion = bool(settings.get(SettingsModelScript.REDUCE_MOTION, false))
	_board.set_colorblind_mode(
		str(settings.get(SettingsModelScript.COLORBLIND_MODE, "off")) != "off"
	)
	_refresh_texts()
	_refresh_notice()


func _apply_audio(settings: Dictionary) -> void:
	var master := AudioServer.get_bus_index("Master")
	_apply_bus_volume(master, float(settings.get(SettingsModelScript.MASTER_VOLUME, 0.8)))
	var sfx := AudioServer.get_bus_index("SFX")
	if sfx < 0:
		AudioServer.add_bus()
		sfx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(sfx, "SFX")
		AudioServer.set_bus_send(sfx, "Master")
	_apply_bus_volume(sfx, float(settings.get(SettingsModelScript.SFX_VOLUME, 0.9)))


func _apply_bus_volume(bus: int, linear: float) -> void:
	if bus < 0:
		return
	AudioServer.set_bus_mute(bus, linear <= 0.0)
	AudioServer.set_bus_volume_db(bus, SettingsModelScript.volume_to_db(linear))


func _apply_fullscreen(settings: Dictionary) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var mode := SettingsModelScript.window_mode_for(
		bool(settings.get(SettingsModelScript.FULLSCREEN, false))
	)
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)


## Applies the optional capture-only overrides before any screen reads them.
func _apply_capture_settings() -> void:
	var language := capture_argument(CAPTURE_LANGUAGE_ARG)
	if SettingsModelScript.LANGUAGES.has(language):
		save_store.set_setting(SettingsModelScript.LANGUAGE, language)
	var colorblind := capture_argument(CAPTURE_COLORBLIND_ARG)
	if SettingsModelScript.COLORBLIND_MODES.has(colorblind):
		save_store.set_setting(SettingsModelScript.COLORBLIND_MODE, colorblind)


func _refresh_texts() -> void:
	_main_menu.refresh_texts()
	_level_select.refresh_texts()
	_pause_menu.refresh_texts()
	_hud.refresh_texts()
	if _current_level != null:
		_hud.set_level(_level_index + 1, _level_display_name(_current_level))
	_victory.refresh_texts()
	_settings_screen.refresh_texts()
	_credits_panel.refresh_texts()
	_credits_panel.set_content(tr(CREDITS_TITLE_KEY), tr(CREDITS_BODY_KEY))


func _refresh_notice() -> void:
	if _notice_key.is_empty():
		_main_menu.set_notice("")
		return
	_main_menu.set_notice(tr(_notice_key) % _notice_arg)


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
	_settings_screen.visible = screen == ScreenRouterScript.Screen.SETTINGS
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
			_settings_screen.focus_default()
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
	_current_level = level
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
	_hud.set_level(_level_index + 1, _level_display_name(level))
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


## The translated level name, falling back to the data name when the table has no
## key yet.
func _level_display_name(level: LevelDataScript) -> String:
	if level.name_key.is_empty():
		return level.name
	var translated := tr(level.name_key)
	return level.name if translated == level.name_key else translated


func _open_level_select() -> void:
	_level_select.show_levels(_level_entries())
	router.show_level_select()


func _open_settings() -> void:
	_settings_screen.bind_values(save_store.settings())
	_settings_screen.refresh_texts()
	router.show_settings()


func _open_credits() -> void:
	_credits_panel.set_content(tr(CREDITS_TITLE_KEY), tr(CREDITS_BODY_KEY))
	router.show_credits()


func _on_back_requested() -> void:
	router.back()


func _on_play_requested() -> void:
	var next_id := save_store.next_unfinished(_level_ids())
	var index := _index_of_level(next_id)
	if index < 0:
		index = LevelProgressScript.next_level_index(_level_paths, _completed)
	if index < 0:
		push_error("main: Play has no level to open")
		return
	_start_level(index)


func _on_level_selected(index: int) -> void:
	if index < 0 or index >= _level_paths.size():
		return
	var level_id := _level_paths[index].get_file().get_basename()
	if not save_store.is_unlocked(level_id):
		push_warning("main: level %s is locked" % level_id)
		return
	_start_level(index)


func _on_quit_requested() -> void:
	if save_store != null:
		save_store.flush()
	get_tree().quit()


func _on_pause_requested() -> void:
	router.pause_game()


func _on_resume_requested() -> void:
	router.resume_game()


func _on_undo_requested() -> void:
	_gameplay.undo()


func _on_attempt_changed(stats: Dictionary) -> void:
	_hud.set_attempt_stats(stats)


## Stores the completion, merges the best record, unlocks the next level and
## flushes immediately, then shows the result overlay.
func _on_victory(stats: Dictionary, has_next: bool) -> void:
	var level_id := _level_paths[_level_index].get_file().get_basename()
	var stars := StarRatingScript.stars_for_moves(
		int(stats.get("moves", 0)), int(stats.get("par_moves", 0))
	)
	var completion := stats.duplicate()
	completion["stars"] = stars
	save_store.complete_level(level_id, _level_ids(), completion)
	save_store.flush()
	_completed[level_id] = true
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
	_confirm.ask(tr(CONFIRM_RESTART_KEY))


func _request_main_menu() -> void:
	if _gameplay.session == null or _gameplay.session.moves == 0:
		_go_main_menu()
		return
	_pending_confirm = ConfirmAction.MAIN_MENU
	_confirm.ask(tr(CONFIRM_LEAVE_KEY))


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


## Stores one setting through the save manager, applies it immediately and shows
## the clamped value back on the screen.
func _on_setting_requested(key: String, value: Variant) -> void:
	save_store.set_setting(key, value)
	_apply_settings()
	_settings_screen.bind_values(save_store.settings())


func _on_save_failed() -> void:
	_notice_key = SaveStoreScript.NOTICE_SAVE_FAILED
	_notice_arg = ""
	_refresh_notice()


## One entry per level file for the level select grid, with the lock state and
## the stored best record.
func _level_entries() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	for index: int in _level_paths.size():
		var level := load_level_file(_level_paths[index])
		if level == null:
			continue
		var level_id := _level_paths[index].get_file().get_basename()
		var record := save_store.record_for(level_id)
		entries.append(
			{
				"index": index,
				"name": _level_display_name(level),
				"par_moves": level.par_moves,
				"difficulty": level.difficulty,
				"completed": bool(record.get("completed", false)),
				"unlocked": save_store.is_unlocked(level_id),
				"stars": int(record.get("stars", 0)),
				"best_moves": int(record.get("best_moves", 0)),
				"best_time_ms": int(record.get("best_time_ms", 0)),
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
