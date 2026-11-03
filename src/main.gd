extends Node3D

## Boot scene for the 3D Sokoban room.
##
## Loads one level file through the logic layer, builds the visible room and
## places the isometric camera. It owns no puzzle rules: movement, pushing and
## UI arrive in later stories.

const LevelDataScript = preload("res://src/logic/level_data.gd")
const BoardBuilderScript = preload("res://src/game/board_builder.gd")
const CameraRigScript = preload("res://src/game/camera_rig.gd")

const DEFAULT_LEVEL_PATH := "res://assets/data/levels/level-001.json"

## Optional capture aid: an integer 1..3 in this environment variable boots the
## room at that quarter turn, so `capture_command` can screenshot every snap
## state. Unset, the room boots at the default yaw.
const CAPTURE_QUARTER_TURNS_ENV := "STUDIO_CAPTURE_QUARTER_TURNS"

@export_file("*.json") var level_path: String = DEFAULT_LEVEL_PATH

@onready var _board: BoardBuilderScript = $Board as BoardBuilderScript
@onready var _camera_rig: CameraRigScript = $CameraRig as CameraRigScript


func _ready() -> void:
	var level := load_level_file(level_path)
	if level == null:
		return
	_board.build(level)
	_camera_rig.setup(level, _board)
	var turns := capture_quarter_turns()
	if turns != 0:
		_camera_rig.set_quarter_turns(turns)


## Quarter turn requested by the capture aid, or 0 when it is unset.
static func capture_quarter_turns() -> int:
	var raw := OS.get_environment(CAPTURE_QUARTER_TURNS_ENV).strip_edges()
	if not raw.is_valid_int():
		return 0
	return posmod(raw.to_int(), 4)


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
