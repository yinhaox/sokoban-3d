extends Node3D

## Boot scene for the 3D Sokoban room.
##
## Loads one level through the logic layer, builds the visible room, places the
## isometric camera and hands the level to the gameplay controller, which owns
## movement, undo, restart and the win. It also routes the victory overlay's
## intent signals back into the controller, so the overlay never touches game
## state itself.

const LevelDataScript = preload("res://src/logic/level_data.gd")
const BoardBuilderScript = preload("res://src/game/board_builder.gd")
const CameraRigScript = preload("res://src/game/camera_rig.gd")
const GameplayControllerScript = preload("res://src/game/gameplay_controller.gd")
const LevelSequenceScript = preload("res://src/game/level_sequence.gd")
const VictoryPanelScript = preload("res://src/ui/victory_panel.gd")

const DEFAULT_LEVEL_PATH := "res://assets/data/levels/level-001.json"

## Optional capture aid: an integer 1..3 in this environment variable boots the
## room at that quarter turn, so `capture_command` can screenshot every snap
## state. Unset, the room boots at the default yaw.
const CAPTURE_QUARTER_TURNS_ENV := "STUDIO_CAPTURE_QUARTER_TURNS"

## Capture aids read from the user arguments after the engine's `--`:
##   --level=<position|id>  boot another level (1-based position in the list)
##   --script=right,right   apply moves through the normal move path
##   --capture-instant      skip the tile tweens and the win delay for the frame
## A script always implies `--capture-instant`, because the capture addon takes
## the frame 0.2 s after boot and a 0.16 s push tween plus a 0.4 s win delay
## would otherwise still be running.
const CAPTURE_LEVEL_ARG := "--level="
const CAPTURE_SCRIPT_ARG := "--script="
const CAPTURE_INSTANT_ARG := "--capture-instant"

@export_file("*.json") var level_path: String = DEFAULT_LEVEL_PATH

@onready var _board: BoardBuilderScript = $Board as BoardBuilderScript
@onready var _camera_rig: CameraRigScript = $CameraRig as CameraRigScript
@onready var _gameplay: GameplayControllerScript = $Gameplay as GameplayControllerScript
@onready var _victory: VictoryPanelScript = $VictoryPanel as VictoryPanelScript

var _level_paths: Array[String] = []
var _level_index: int = 0
var _capture_script: String = ""
var _instant_capture: bool = false


func _ready() -> void:
	_level_paths = LevelSequenceScript.level_paths()
	_capture_script = capture_argument(CAPTURE_SCRIPT_ARG)
	_instant_capture = has_capture_argument(CAPTURE_INSTANT_ARG) or not _capture_script.is_empty()
	_gameplay.victory.connect(_on_victory)
	_victory.retry_requested.connect(_on_retry_requested)
	_victory.next_requested.connect(_on_next_requested)
	var boot_path := level_path
	var requested := capture_argument(CAPTURE_LEVEL_ARG)
	if not requested.is_empty():
		var resolved := resolve_level_argument(requested, _level_paths)
		if resolved.is_empty():
			push_warning("main: --level=%s does not name a level; booting %s" % [requested, level_path])
		else:
			boot_path = resolved
	_level_index = maxi(LevelSequenceScript.index_of(_level_paths, boot_path), 0)
	_show_level(boot_path)


## Loads one level, rebuilds the room, starts a fresh attempt and applies the
## capture aids for this boot.
func _show_level(path: String) -> void:
	var level := load_level_file(path)
	if level == null:
		return
	_board.build(level)
	_camera_rig.setup(level, _board)
	_gameplay.animation_enabled = not _instant_capture
	_gameplay.win_delay_seconds = (
		0.0 if _instant_capture else GameplayControllerScript.WIN_DELAY_SECONDS
	)
	var has_next := LevelSequenceScript.has_next(_level_paths, _level_index)
	_gameplay.setup(level, _board, _camera_rig, has_next)
	_victory.hide_panel()
	var turns := capture_quarter_turns()
	if turns != 0:
		_camera_rig.set_quarter_turns(turns)
	if not _capture_script.is_empty() and not _gameplay.apply_move_script(_capture_script):
		push_warning("main: capture script '%s' was not fully applied" % _capture_script)


func _on_victory(stats: Dictionary, has_next: bool) -> void:
	_victory.show_result(stats, has_next)


func _on_retry_requested() -> void:
	_victory.hide_panel()
	_gameplay.restart_level()


func _on_next_requested() -> void:
	if not LevelSequenceScript.has_next(_level_paths, _level_index):
		return
	_level_index += 1
	_victory.hide_panel()
	_show_level(_level_paths[_level_index])


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
