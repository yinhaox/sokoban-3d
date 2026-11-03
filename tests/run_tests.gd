extends SceneTree

## Headless regression checks for the project.
##
## Run with:
##   godot --headless --path . -s res://tests/run_tests.gd
##
## Prints one PASS line per successful check and exits 0 only when every
## check passes; any failure exits 1.

const MAIN_SCRIPT = preload("res://src/main.gd")
const MAIN_SCENE_PATH = "res://scenes/main.tscn"
const CAPTURE_SCRIPT_PATH = "res://addons/studio_capture/capture.gd"

const LevelDataClass = preload("res://src/logic/level_data.gd")
const GameSessionClass = preload("res://src/logic/game_session.gd")
const DeadlockClass = preload("res://src/logic/deadlock.gd")
const MoveRecordClass = preload("res://src/logic/move_record.gd")
const BoardBuilderClass = preload("res://src/game/board_builder.gd")
const CameraRigClass = preload("res://src/game/camera_rig.gd")
const GameplayControllerClass = preload("res://src/game/gameplay_controller.gd")
const LevelSequenceClass = preload("res://src/game/level_sequence.gd")
const VictoryPanelClass = preload("res://src/ui/victory_panel.gd")
const InputActionsClass = preload("res://src/input/input_actions.gd")
const ScreenRouterClass = preload("res://src/ui/screen_router.gd")
const LevelProgressClass = preload("res://src/logic/level_progress.gd")
const StarRatingClass = preload("res://src/logic/star_rating.gd")
const UiFormatClass = preload("res://src/ui/ui_format.gd")
const UiThemeClass = preload("res://src/ui/ui_theme.gd")
const MainMenuClass = preload("res://src/ui/main_menu.gd")
const LevelSelectClass = preload("res://src/ui/level_select.gd")
const HudClass = preload("res://src/ui/hud.gd")
const PauseMenuClass = preload("res://src/ui/pause_menu.gd")
const ConfirmModalClass = preload("res://src/ui/confirm_modal.gd")
const StarRowClass = preload("res://src/ui/star_row.gd")
const SaveStoreClass = preload("res://src/logic/save_store.gd")
const SettingsModelClass = preload("res://src/logic/settings_model.gd")
const LocalizationClass = preload("res://src/logic/localization.gd")
const SettingsScreenClass = preload("res://src/ui/settings_screen.gd")

const VICTORY_SCENE_PATH := "res://scenes/ui/victory_panel.tscn"
const HUD_SCENE_PATH := "res://scenes/ui/hud.tscn"
const MAIN_MENU_SCENE_PATH := "res://scenes/ui/main_menu.tscn"
const LEVEL_SELECT_SCENE_PATH := "res://scenes/ui/level_select.tscn"
const PAUSE_MENU_SCENE_PATH := "res://scenes/ui/pause_menu.tscn"
const CONFIRM_SCENE_PATH := "res://scenes/ui/confirm_modal.tscn"
const SETTINGS_SCENE_PATH := "res://scenes/ui/settings_screen.tscn"

const LEVEL_FILES := ["level-001", "level-002", "level-003"]
const LEVEL_DIRECTORY := "res://assets/data/levels/%s.json"

## 7x7 room: player at (2,3), one box at (4,3), one goal at (5,1). A straight
## push right then two pushes up solve it in 6 moves and 3 pushes.
const BASIC_TILES := [
	"#######",
	"#____.#",
	"#_____#",
	"#_@_$_#",
	"#_____#",
	"#_____#",
	"#######",
]

## Player (4,2) faces box (5,2); the cell beyond the box is the right wall.
const WALL_PUSH_TILES := [
	"#######",
	"#_____#",
	"#___@$#",
	"#_____#",
	"#____.#",
	"#_____#",
	"#######",
]

## Two boxes in a row: pushing (4,2) right would need (5,2) to be free.
const BOX_BLOCK_TILES := [
	"#######",
	"#_____#",
	"#__@$$#",
	"#_____#",
	"#_._._#",
	"#_____#",
	"#######",
]

## Player (1,3) pushes box (1,2) up into the (1,1) corner: wall above and left.
const DEADLOCK_TILES := [
	"#######",
	"#_____#",
	"#$____#",
	"#@____#",
	"#____.#",
	"#_____#",
	"#######",
]

## The same corner cell, but it is a goal plate, so it is not a deadlock.
const GOAL_CORNER_TILES := [
	"#######",
	"#.____#",
	"#$____#",
	"#@____#",
	"#_____#",
	"#_____#",
	"#######",
]

## Box (1,3) touches the left wall but no vertical wall: not a corner.
const ONE_WALL_TILES := [
	"#######",
	"#_____#",
	"#_____#",
	"#$@___#",
	"#_____#",
	"#____.#",
	"#######",
]

## Box (3,3) sits in the open, one step from the player.
const OPEN_BOX_TILES := [
	"#######",
	"#_____#",
	"#_____#",
	"#_@$__#",
	"#_____#",
	"#____.#",
	"#######",
]

## Open room, player at (1,1), box (4,5) and goal (5,5), so the player may walk
## a four-cell cycle without touching the box.
const UNDO_TILES := [
	"#######",
	"#@____#",
	"#_____#",
	"#_____#",
	"#_____#",
	"#___$.#",
	"#######",
]

## Two boxes and two goals: (5,2) can reach goal (5,3) first while goal (3,1)
## is still empty, which must not count as a win.
const TWO_GOAL_TILES := [
	"#######",
	"#__.__#",
	"#__$_$#",
	"#____.#",
	"#_@___#",
	"#_____#",
	"#######",
]

var _passed := 0
var _failed := 0

var _rejected_reasons: Array[int] = []
var _deadlock_cells: Array[Vector2i] = []
var _completed_stats: Array[Dictionary] = []
var _victory_events: Array[Dictionary] = []
var _ui_signal_flags: Dictionary = {}


func _init() -> void:
	LocalizationClass.install()
	_test_main_scene()
	_test_project_settings()
	_test_level_data_valid()
	_test_level_data_two_cell_legend()
	_test_level_data_invalid()
	_test_level_data_json_errors()
	_test_move_record()
	_test_game_session_movement()
	_test_game_session_push()
	_test_game_session_blocked_pushes()
	_test_game_session_undo()
	_test_game_session_restart()
	_test_game_session_win()
	_test_game_session_win_needs_every_goal()
	_test_deadlock_predicate()
	_test_deadlock_on_push()
	_test_level_files()
	_test_board_builder()
	_test_camera_rig()
	_test_camera_framing()
	_test_wall_fade_outline()
	_test_gameplay_input_mapping()
	_test_gameplay_controller()
	_test_gameplay_win()
	_test_level_sequence()
	_test_victory_panel()
	_test_input_actions()
	_test_star_rating()
	_test_ui_format()
	_test_screen_router()
	_test_level_progress()
	_test_ui_theme()
	_test_hud()
	_test_level_select()
	_test_main_menu()
	_test_pause_menu()
	_test_confirm_modal()
	_test_star_row()
	_test_gameplay_pause_blocks_input()
	_test_save_settings_i18n()

	if _failed == 0:
		print("PASS: %d checks passed" % _passed)
		quit(0)
		return

	printerr("FAIL: %d of %d checks failed" % [_failed, _passed + _failed])
	quit(1)


func _check(condition: bool, label: String) -> void:
	if condition:
		_passed += 1
		print("PASS: %s" % label)
	else:
		_failed += 1
		printerr("FAIL: %s" % label)


func _test_main_scene() -> void:
	_check(ResourceLoader.exists(MAIN_SCENE_PATH), "scenes/main.tscn exists")

	var packed := load(MAIN_SCENE_PATH) as PackedScene
	if packed == null:
		_check(false, "scenes/main.tscn loads as a PackedScene")
		return
	_check(true, "scenes/main.tscn loads as a PackedScene")

	var root := packed.instantiate()
	if root == null:
		_check(false, "scenes/main.tscn instantiates")
		return
	_check(root is Node3D, "main scene root is a Node3D")
	_check(str(root.name) == "Main", "main scene root is named Main")

	var attached := root.get_script() as Script
	_check(attached != null and attached.resource_path == "res://src/main.gd", "main scene root runs src/main.gd")

	var light := root.get_node_or_null("DirectionalLight3D") as DirectionalLight3D
	_check(light != null, "main scene carries a DirectionalLight3D")
	if light != null:
		_check(light.shadow_enabled, "the directional light casts shadows")
	_check(root.get_node_or_null("WorldEnvironment") is WorldEnvironment, "main scene carries a WorldEnvironment")

	var camera := root.get_node_or_null("CameraRig/Camera3D") as Camera3D
	_check(camera != null, "main scene carries a Camera3D under the camera rig")
	if camera != null:
		_check(camera.projection == Camera3D.PROJECTION_ORTHOGONAL, "the camera uses orthogonal projection")

	var board := root.get_node_or_null("Board")
	_check(board != null and board.get_script() == BoardBuilderClass, "main scene carries the board builder")

	var gameplay := root.get_node_or_null("Gameplay")
	_check(
		gameplay != null and gameplay.get_script() == GameplayControllerClass,
		"main scene carries the gameplay controller"
	)
	_check(
		root.get_node_or_null("VictoryPanel") is CanvasLayer,
		"main scene carries the victory overlay"
	)
	for screen_name: String in ["HUD", "MainMenu", "LevelSelect", "PauseMenu", "ConfirmModal"]:
		_check(
			root.get_node_or_null(screen_name) is CanvasLayer,
			"main scene carries the %s screen" % screen_name
		)
	_check(
		root.get_node_or_null("SettingsPanel") is CanvasLayer,
		"main scene carries the settings placeholder"
	)
	_check(root.get_node_or_null("CreditsPanel") is CanvasLayer, "main scene carries the credits screen")
	root.free()

	var level := MAIN_SCRIPT.load_level_file("res://assets/data/levels/level-001.json")
	_check(level != null and level.is_valid(), "the boot level path loads level-001")
	if level != null:
		_check(level.id == "level-001", "the boot level is level-001")


func _test_project_settings() -> void:
	_check(ProjectSettings.get_setting("application/config/name", "") == "Game Studio", "project name is Game Studio")
	_check(ProjectSettings.get_setting("application/run/main_scene", "") == MAIN_SCENE_PATH, "main scene is registered in project.godot")
	_check(ProjectSettings.get_setting("autoload/StudioCapture", "") == "*" + CAPTURE_SCRIPT_PATH, "StudioCapture autoload points at the capture addon")
	_check(int(ProjectSettings.get_setting("display/window/size/viewport_width", 0)) == 1152, "viewport width is 1152")
	_check(int(ProjectSettings.get_setting("display/window/size/viewport_height", 0)) == 648, "viewport height is 648")


func _test_level_data_valid() -> void:
	var level := _make_level(BASIC_TILES)
	_check(level.is_valid(), "a valid level fixture loads without errors")
	_check(level.id == "level-900", "a level keeps its id field")
	_check(level.columns == 7 and level.rows == 7, "a level keeps its columns and rows")
	_check(level.par_moves == 20 and level.par_pushes == 5, "a level keeps its par values")
	_check(level.player_start == Vector2i(2, 3), "the player start comes from the '@' tile")
	_check(level.box_starts.size() == 1, "the box start count comes from the '$' tile")
	_check(
		level.box_starts.size() == 1 and level.box_starts[0] == Vector2i(4, 3),
		"the box start cell comes from the '$' tile"
	)
	_check(level.goals.size() == 1 and level.goals[0] == Vector2i(5, 1), "the goal cell comes from the '.' tile")
	_check(level.cell_at(Vector2i(0, 0)) == LevelDataClass.Cell.WALL, "cell_at reports a wall")
	_check(level.cell_at(Vector2i(2, 3)) == LevelDataClass.Cell.FLOOR, "cell_at reports a floor cell")
	_check(level.cell_at(Vector2i(5, 1)) == LevelDataClass.Cell.GOAL, "cell_at reports a goal cell")
	_check(
		level.cell_at(Vector2i(-1, 0)) == LevelDataClass.Cell.VOID,
		"cell_at reports VOID for a coordinate outside the grid"
	)
	_check(level.is_wall(Vector2i(-1, 3)), "is_wall treats an out-of-grid coordinate as a wall")
	_check(level.is_wall(Vector2i(7, 3)), "is_wall treats a coordinate past the right edge as a wall")
	_check(level.is_goal(Vector2i(5, 1)) and not level.is_goal(Vector2i(2, 3)), "is_goal reports only goal cells")
	_check(level.initial_boxes().size() == 1, "initial_boxes returns a copy of the starting boxes")
	_check(level.initial_boxes()[0] == Vector2i(4, 3), "initial_boxes returns the starting box cell")
	_check(_make_level(BASIC_TILES, {"notes": ""}).is_valid(), "an empty optional notes field is accepted")


func _test_level_data_two_cell_legend() -> void:
	var box_on_goal := _make_level(
		["#######", "#__*__#", "#__$__#", "#__.__#", "#__@__#", "#_____#", "#######"]
	)
	_check(box_on_goal.is_valid(), "a level with a '* box-on-goal tile validates")
	_check(box_on_goal.box_starts.has(Vector2i(3, 1)), "a '*' tile is a box start")
	_check(box_on_goal.goals.has(Vector2i(3, 1)), "a '*' tile is also a goal")

	var player_on_goal := _make_level(
		["#######", "#__+__#", "#__$__#", "#__.__#", "#__$__#", "#_____#", "#######"]
	)
	_check(player_on_goal.is_valid(), "a level with a '+' player-on-goal tile validates")
	_check(player_on_goal.player_start == Vector2i(3, 1), "a '+' tile is the player start")
	_check(player_on_goal.goals.has(Vector2i(3, 1)), "a '+' tile is also a goal")


func _test_level_data_invalid() -> void:
	var short_row := LevelDataClass.from_dictionary(
		_level_dictionary(
			["#######", "#____.#", "#####", "#_@_$_#", "#_____#", "#_____#", "#######"]
		)
	)
	_check(not short_row.is_valid(), "a tile row of the wrong length is rejected")
	_check(short_row.error_summary().contains("tiles[2]"), "a short tile row error names the row index")
	_check(
		short_row.cell_at(Vector2i(1, 1)) == LevelDataClass.Cell.VOID,
		"cell_at on an invalid level returns VOID instead of crashing"
	)

	var wrong_columns := LevelDataClass.from_dictionary(
		_level_dictionary(BASIC_TILES, {"columns": 4})
	)
	_check(not wrong_columns.is_valid(), "columns outside 5..15 is rejected")
	_check(wrong_columns.error_summary().contains("columns: 4"), "a column range error names the value")

	var wrong_rows := LevelDataClass.from_dictionary(_level_dictionary(BASIC_TILES, {"rows": 20}))
	_check(not wrong_rows.is_valid(), "rows outside 5..15 is rejected")
	_check(wrong_rows.error_summary().contains("rows: 20"), "a row range error names the value")

	var no_player := LevelDataClass.from_dictionary(
		_level_dictionary(
			["#######", "#____.#", "#_____#", "#___$_#", "#_____#", "#_____#", "#######"]
		)
	)
	_check(not no_player.is_valid(), "a level with no player is rejected")
	_check(no_player.error_summary().contains("player"), "a missing-player error names the player")

	var two_players := LevelDataClass.from_dictionary(
		_level_dictionary(
			["#######", "#____.#", "#_____#", "#_@@$_#", "#_____#", "#_____#", "#######"]
		)
	)
	_check(not two_players.is_valid(), "a level with two players is rejected")

	var extra_goal := LevelDataClass.from_dictionary(
		_level_dictionary(
			["#######", "#____.#", "#_____#", "#_@_$_#", "#_____#", "#____.#", "#######"]
		)
	)
	_check(not extra_goal.is_valid(), "a goal count that differs from the box count is rejected")
	_check(extra_goal.error_summary().contains("goals"), "a goal-count error names the goals")

	var bad_character := LevelDataClass.from_dictionary(
		_level_dictionary(
			["#######", "#____.#", "#_____#", "#_@_x_#", "#_____#", "#_____#", "#######"]
		)
	)
	_check(not bad_character.is_valid(), "an unknown cell character is rejected")
	_check(bad_character.error_summary().contains("unknown cell character"), "an unknown-character error names the character")

	var open_border := LevelDataClass.from_dictionary(
		_level_dictionary(
			["###_###", "#____.#", "#_____#", "#_@_$_#", "#_____#", "#_____#", "#######"]
		)
	)
	_check(not open_border.is_valid(), "a border that is not all walls is rejected")
	_check(open_border.error_summary().contains("border"), "a border error names the border")

	var solved := LevelDataClass.from_dictionary(
		_level_dictionary(
			["#######", "#_____#", "#_____#", "#___*_#", "#_@___#", "#_____#", "#######"]
		)
	)
	_check(not solved.is_valid(), "a level that starts already solved is rejected")
	_check(solved.error_summary().contains("already solved"), "a solved-start error says so")

	var bad_id := LevelDataClass.from_dictionary(_level_dictionary(BASIC_TILES, {"id": "level-01"}))
	_check(not bad_id.is_valid(), "an id outside level-NNN is rejected")
	_check(bad_id.error_summary().contains("id"), "an id error names the id field")

	var bad_stem := LevelDataClass.from_dictionary(_level_dictionary(BASIC_TILES), "level-902")
	_check(not bad_stem.is_valid(), "an id that differs from the file stem is rejected")
	_check(bad_stem.error_summary().contains("file stem"), "a file-stem error names the file stem")

	var missing_field := _level_dictionary(BASIC_TILES)
	missing_field.erase("par_moves")
	var missing := LevelDataClass.from_dictionary(missing_field)
	_check(not missing.is_valid(), "a missing required field is rejected")
	_check(missing.error_summary().contains("par_moves"), "a missing-field error names the field")

	var wrong_type := LevelDataClass.from_dictionary(_level_dictionary(BASIC_TILES, {"columns": "7"}))
	_check(not wrong_type.is_valid(), "a field with the wrong type is rejected")
	_check(wrong_type.error_summary().contains("expected an integer"), "a wrong-type error says the expected type")

	var wrong_tiles := LevelDataClass.from_dictionary(_level_dictionary(BASIC_TILES, {"tiles": "#######"}))
	_check(not wrong_tiles.is_valid(), "a tiles field that is not an array is rejected")
	_check(wrong_tiles.error_summary().contains("tiles"), "a tiles-type error names the tiles field")

	var bad_par := LevelDataClass.from_dictionary(
		_level_dictionary(BASIC_TILES, {"par_moves": 3, "par_pushes": 5})
	)
	_check(not bad_par.is_valid(), "par_pushes greater than par_moves is rejected")
	_check(bad_par.error_summary().contains("par_pushes"), "a par error names par_pushes")

	var long_notes := LevelDataClass.from_dictionary(
		_level_dictionary(BASIC_TILES, {"notes": "x".repeat(201)})
	)
	_check(not long_notes.is_valid(), "notes longer than 200 characters is rejected")

	var unknown_field := _make_level(BASIC_TILES, {"extra_field": 1})
	_check(unknown_field.is_valid(), "an unknown field only warns and is ignored")


func _test_level_data_json_errors() -> void:
	var broken := LevelDataClass.from_json_text("{ \"id\": ")
	_check(not broken.is_valid(), "malformed JSON is rejected instead of crashing")
	_check(broken.error_summary().contains("invalid JSON"), "a malformed-JSON error says the JSON is invalid")

	var not_object := LevelDataClass.from_json_text("[]")
	_check(not not_object.is_valid(), "a JSON array at the top level is rejected")
	_check(not_object.error_summary().contains("object"), "a top-level type error names the expected object")

	var valid := LevelDataClass.from_json_text(
		"{\"id\":\"level-900\",\"name\":\"Fixture\",\"name_key\":\"level_900_name\","
		+ "\"author\":\"Test\",\"difficulty\":1,\"par_moves\":6,\"par_pushes\":3,"
		+ "\"columns\":7,\"rows\":7,\"tiles\":[\"#######\",\"#____.#\",\"#_____#\","
		+ "\"#_@_$_#\",\"#_____#\",\"#_____#\",\"#######\"]}",
		"level-900"
	)
	_check(valid.is_valid(), "a JSON level fixture parses")
	_check(valid.player_start == Vector2i(2, 3), "a JSON level fixture reads the player start")


func _test_move_record() -> void:
	var boxes: Array[Vector2i] = [Vector2i(4, 3)]
	var record := MoveRecordClass.new(
		GameSessionClass.Direction.RIGHT, true, 0, Vector2i(2, 3), boxes, 2, 1
	)
	_check(record.direction == GameSessionClass.Direction.RIGHT, "a move record keeps the direction")
	_check(record.was_push, "a move record keeps the push flag")
	_check(record.box_index == 0, "a move record keeps the box index")
	_check(record.player_before == Vector2i(2, 3), "a move record keeps the previous player cell")
	_check(record.moves_before == 2 and record.pushes_before == 1, "a move record keeps the previous counters")
	_check(record.boxes_before.size() == 1 and record.boxes_before[0] == Vector2i(4, 3), "a move record keeps the previous box cells")


func _test_game_session_movement() -> void:
	var level := _make_level(BASIC_TILES)
	var session := GameSessionClass.new(level)
	_check(session.player == Vector2i(2, 3), "a session starts the player on the start cell")
	_check(session.boxes.size() == 1 and session.boxes[0] == Vector2i(4, 3), "a session starts the boxes on their start cells")
	_check(session.moves == 0 and session.pushes == 0, "a session starts with zero counters")
	_check(not session.can_undo(), "a session starts with an empty undo history")

	var result := session.try_move(GameSessionClass.Direction.LEFT)
	_check(result == GameSessionClass.MoveResult.MOVED, "stepping into floor returns MOVED")
	_check(session.player == Vector2i(1, 3), "an accepted step moves the player one cell")
	_check(session.moves == 1 and session.pushes == 0, "a step counts one move and no push")
	_check(session.can_undo() and session.undo_depth() == 1, "a step adds one undo entry")

	var blocked := GameSessionClass.new(level)
	blocked.try_move(GameSessionClass.Direction.UP)
	blocked.try_move(GameSessionClass.Direction.UP)
	blocked.try_move(GameSessionClass.Direction.UP)
	var player_before := blocked.player
	var moves_before := blocked.moves
	var depth_before := blocked.undo_depth()
	_rejected_reasons.clear()
	blocked.move_rejected.connect(_on_move_rejected)
	var rejected := blocked.try_move(GameSessionClass.Direction.UP)
	_check(rejected == GameSessionClass.MoveResult.REJECTED_WALL, "a move into a wall returns REJECTED_WALL")
	_check(blocked.player == player_before, "a rejected wall move does not move the player")
	_check(blocked.moves == moves_before and blocked.pushes == 0, "a rejected wall move does not change counters")
	_check(blocked.undo_depth() == depth_before, "a rejected move adds no undo entry")
	_check(_rejected_reasons.has(GameSessionClass.MoveResult.REJECTED_WALL), "a rejected move emits move_rejected with the reason")


func _test_game_session_push() -> void:
	var session := GameSessionClass.new(_make_level(BASIC_TILES))
	_completed_stats.clear()
	session.level_completed.connect(_on_level_completed)
	session.try_move(GameSessionClass.Direction.RIGHT)
	var result := session.try_move(GameSessionClass.Direction.RIGHT)
	_check(result == GameSessionClass.MoveResult.PUSHED, "pushing a box into free floor returns PUSHED")
	_check(session.player == Vector2i(4, 3), "a push moves the player into the box's old cell")
	_check(session.boxes[0] == Vector2i(5, 3), "a push moves the box one cell further")
	_check(session.moves == 2 and session.pushes == 1, "a push counts one move and one push")
	_check(session.undo_depth() == 2, "a push adds one undo entry")
	_check(not session.is_won, "moving a box onto floor does not win the level")


func _test_game_session_blocked_pushes() -> void:
	var wall_session := GameSessionClass.new(_make_level(WALL_PUSH_TILES))
	var player_before := wall_session.player
	var box_before := wall_session.boxes[0]
	var result := wall_session.try_move(GameSessionClass.Direction.RIGHT)
	_check(result == GameSessionClass.MoveResult.REJECTED_BOX, "pushing a box into a wall returns REJECTED_BOX")
	_check(wall_session.player == player_before, "a blocked push does not move the player")
	_check(wall_session.boxes[0] == box_before, "a blocked push does not move the box")
	_check(wall_session.moves == 0 and wall_session.pushes == 0, "a blocked push changes no counter")
	_check(not wall_session.can_undo(), "a blocked push adds no undo entry")

	var box_session := GameSessionClass.new(_make_level(BOX_BLOCK_TILES))
	var second_player := box_session.player
	var boxes_before := _copy_cells(box_session.boxes)
	var second_result := box_session.try_move(GameSessionClass.Direction.RIGHT)
	_check(second_result == GameSessionClass.MoveResult.REJECTED_BOX, "pushing a box into another box returns REJECTED_BOX")
	_check(box_session.player == second_player, "a box-on-box rejection leaves the player in place")
	_check(_cells_equal(box_session.boxes, boxes_before), "a box-on-box rejection leaves every box in place")
	_check(box_session.moves == 0 and box_session.pushes == 0, "a box-on-box rejection changes no counter")


func _test_game_session_undo() -> void:
	var level := _make_level(UNDO_TILES)
	var session := GameSessionClass.new(level)
	for index in 100:
		session.try_move(_cycle_direction(index))
	_check(session.moves == 100, "one hundred accepted moves are counted")
	_check(session.undo_depth() == 100, "at least one hundred moves stay reachable by undo")
	_check(session.player == Vector2i(1, 1), "the walk cycle ends where it started")
	var undone := 0
	for index in 100:
		if session.undo():
			undone += 1
	_check(undone == 100, "undo rewinds one hundred accepted moves")
	_check(session.moves == 0 and session.pushes == 0, "undo restores the counters")
	_check(session.player == Vector2i(1, 1), "undo restores the player position")
	_check(not session.can_undo(), "undo empties the history")
	_check(not session.undo(), "undo on an empty history does nothing")

	var pruned := GameSessionClass.new(level)
	for index in 101:
		pruned.try_move(_cycle_direction(index))
	_check(pruned.undo_depth() == 100, "the undo history is capped at undo_limit moves")
	for index in 100:
		pruned.undo()
	_check(pruned.moves == 1, "the oldest undo entry is discarded at the cap")
	_check(pruned.player == Vector2i(2, 1), "the discarded entry leaves the state after the first move")

	var pushed := GameSessionClass.new(_make_level(BASIC_TILES))
	pushed.try_move(GameSessionClass.Direction.RIGHT)
	pushed.try_move(GameSessionClass.Direction.RIGHT)
	_check(pushed.undo(), "undo accepts a push entry")
	_check(pushed.player == Vector2i(3, 3), "undo of a push restores the previous player cell")
	_check(pushed.boxes[0] == Vector2i(4, 3), "undo of a push restores the previous box cell")
	_check(pushed.moves == 1 and pushed.pushes == 0, "undo of a push restores the counters before the push")


func _test_game_session_restart() -> void:
	var level := _make_level(BASIC_TILES)
	var session := GameSessionClass.new(level)
	session.try_move(GameSessionClass.Direction.RIGHT)
	session.try_move(GameSessionClass.Direction.RIGHT)
	_check(session.moves == 2 and session.pushes == 1, "the restart fixture has moved and pushed")
	_check(session.attempts == 0, "a new session has zero attempts")
	session.restart()
	_check(session.player == level.player_start, "restart restores the player start")
	_check(session.boxes[0] == level.box_starts[0], "restart restores the box start cells")
	_check(session.moves == 0 and session.pushes == 0, "restart resets the counters")
	_check(not session.can_undo(), "restart empties the undo history")
	_check(not session.is_won, "restart clears the win state")
	_check(session.attempts == 1, "restart counts the attempt")


func _test_game_session_win() -> void:
	var session := GameSessionClass.new(_make_level(BASIC_TILES))
	_completed_stats.clear()
	session.level_completed.connect(_on_level_completed)
	var solution: Array[int] = [
		GameSessionClass.Direction.RIGHT,
		GameSessionClass.Direction.RIGHT,
		GameSessionClass.Direction.DOWN,
		GameSessionClass.Direction.RIGHT,
		GameSessionClass.Direction.UP,
	]
	for direction in solution:
		session.try_move(direction)
	_check(not session.is_won, "a box that is not on the last goal does not win")
	_check(_completed_stats.is_empty(), "no completion signal fires before every goal is filled")
	session.try_move(GameSessionClass.Direction.UP)
	_check(session.is_won, "pushing the last box onto its goal wins the level")
	_check(_completed_stats.size() == 1, "winning emits level_completed once")
	_check(_completed_stats[0].get("moves", -1) == 6, "the completion stats carry the move count")
	_check(_completed_stats[0].get("pushes", -1) == 3, "the completion stats carry the push count")
	var moves_after_win := session.moves
	var rejected := session.try_move(GameSessionClass.Direction.LEFT)
	_check(rejected == GameSessionClass.MoveResult.REJECTED_FINISHED, "a move after the win is rejected")
	_check(session.moves == moves_after_win, "a move after the win changes no counter")


func _test_game_session_win_needs_every_goal() -> void:
	var session := GameSessionClass.new(_make_level(TWO_GOAL_TILES))
	_completed_stats.clear()
	session.level_completed.connect(_on_level_completed)
	_walk(
		session,
		[
			GameSessionClass.Direction.RIGHT,
			GameSessionClass.Direction.RIGHT,
			GameSessionClass.Direction.UP,
			GameSessionClass.Direction.UP,
			GameSessionClass.Direction.UP,
			GameSessionClass.Direction.RIGHT,
			GameSessionClass.Direction.DOWN,
		]
	)
	_check(session.boxes[1] == Vector2i(5, 3), "the first box reaches its goal")
	_check(not session.is_won, "a box on one goal does not win while another goal is empty")
	_check(_completed_stats.is_empty(), "no completion signal fires while a goal is empty")
	_walk(
		session,
		[
			GameSessionClass.Direction.LEFT,
			GameSessionClass.Direction.DOWN,
			GameSessionClass.Direction.LEFT,
			GameSessionClass.Direction.UP,
		]
	)
	_check(session.is_won, "filling the last empty goal wins the level")
	_check(_completed_stats.size() == 1, "the two-goal win emits level_completed once")
	_check(_completed_stats[0].get("moves", -1) == 11, "the two-goal win counts eleven moves")
	_check(_completed_stats[0].get("pushes", -1) == 2, "the two-goal win counts two pushes")


func _test_deadlock_predicate() -> void:
	var deadlock_level := _make_level(DEADLOCK_TILES)
	_check(DeadlockClass.is_corner_deadlock(deadlock_level, Vector2i(1, 1)), "a box in a non-goal corner is deadlocked")
	_check(not DeadlockClass.is_corner_deadlock(deadlock_level, Vector2i(1, 2)), "a box against one wall only is not deadlocked")

	var goal_corner := _make_level(GOAL_CORNER_TILES)
	_check(not DeadlockClass.is_corner_deadlock(goal_corner, Vector2i(1, 1)), "a box in a corner goal is not deadlocked")

	var one_wall := _make_level(ONE_WALL_TILES)
	_check(not DeadlockClass.is_corner_deadlock(one_wall, Vector2i(1, 3)), "a box with one wall and one open axis is not deadlocked")

	var open_box := _make_level(OPEN_BOX_TILES)
	_check(not DeadlockClass.is_corner_deadlock(open_box, Vector2i(3, 3)), "a box in the open is not deadlocked")


func _test_deadlock_on_push() -> void:
	var session := GameSessionClass.new(_make_level(DEADLOCK_TILES))
	_deadlock_cells.clear()
	session.deadlock_detected.connect(_on_deadlock_detected)
	session.try_move(GameSessionClass.Direction.UP)
	_check(session.boxes[0] == Vector2i(1, 1), "the box is pushed into the corner")
	_check(session.last_deadlock_cell == Vector2i(1, 1), "a deadlocked push records the box cell")
	_check(_deadlock_cells.size() == 1, "a deadlocked push emits deadlock_detected once")

	var winning := GameSessionClass.new(_make_level(BASIC_TILES))
	_deadlock_cells.clear()
	winning.deadlock_detected.connect(_on_deadlock_detected)
	_walk(
		winning,
		[
			GameSessionClass.Direction.RIGHT,
			GameSessionClass.Direction.RIGHT,
			GameSessionClass.Direction.DOWN,
			GameSessionClass.Direction.RIGHT,
			GameSessionClass.Direction.UP,
			GameSessionClass.Direction.UP,
		]
	)
	_check(_deadlock_cells.is_empty(), "a box pushed onto a goal emits no deadlock warning")


func _test_level_files() -> void:
	for file_stem in LEVEL_FILES:
		var path := LEVEL_DIRECTORY % file_stem
		_check(FileAccess.file_exists(path), "level file exists: %s" % path)
		var text := _read_level_text(file_stem)
		if text.is_empty():
			_check(false, "level file is readable: %s" % path)
			continue
		var level := LevelDataClass.from_json_text(text, file_stem)
		_check(level.is_valid(), "level file validates: %s (%s)" % [file_stem, level.error_summary()])
		_check(level.id == file_stem, "level id matches its file stem: %s" % file_stem)
		_check(level.box_starts.size() == level.goals.size(), "level boxes match goals: %s" % file_stem)

	var first := LevelDataClass.from_json_text(_read_level_text("level-001"), "level-001")
	_check(first.par_moves == 6 and first.par_pushes == 3, "level 001 carries the par values from its file")
	var session := GameSessionClass.new(first)
	_walk(
		session,
		[
			GameSessionClass.Direction.RIGHT,
			GameSessionClass.Direction.RIGHT,
			GameSessionClass.Direction.DOWN,
			GameSessionClass.Direction.RIGHT,
			GameSessionClass.Direction.UP,
			GameSessionClass.Direction.UP,
		]
	)
	_check(session.is_won, "level 001 is solvable from its file")
	_check(session.moves == first.par_moves, "level 001 is solved within its par moves")
	_check(session.pushes == first.par_pushes, "level 001 is solved within its par pushes")


func _test_board_builder() -> void:
	_check(
		BoardBuilderClass.cell_to_world(Vector2i(0, 0), 7, 7) == Vector3(-3.0, 0.0, -3.0),
		"cell (0,0) of a 7x7 room is at (-3,0,-3)"
	)
	_check(
		BoardBuilderClass.cell_to_world(Vector2i(6, 6), 7, 7) == Vector3(3.0, 0.0, 3.0),
		"cell (6,6) of a 7x7 room is at (3,0,3)"
	)
	var centred := BoardBuilderClass.cell_to_world(Vector2i(7, 7), 15, 15)
	_check(centred == Vector3.ZERO, "the centre cell of a 15x15 room is at the origin")
	var step := BoardBuilderClass.cell_to_world(Vector2i(3, 4), 7, 7) - BoardBuilderClass.cell_to_world(
		Vector2i(2, 4), 7, 7
	)
	_check(step == Vector3(1.0, 0.0, 0.0), "one cell is exactly one world unit")
	var neighbour := BoardBuilderClass.cell_to_world(Vector2i(3, 4), 7, 7)
	_check(BoardBuilderClass.world_to_cell(neighbour, 7, 7) == Vector2i(3, 4), "world_to_cell inverts cell_to_world")

	var level := _make_level(BASIC_TILES)
	_check(BoardBuilderClass.level_centre(level) == Vector3.ZERO, "level_centre centres a rectangular room")

	var board := BoardBuilderClass.new()
	board.build(level)
	_check(board.player_cell == level.player_start, "the board places the player on the player start")
	var player := board.get_node_or_null("Player") as MeshInstance3D
	_check(player != null, "the board builds a player piece")
	if player != null:
		var expected := BoardBuilderClass.cell_to_world(level.player_start, 7, 7)
		_check(
			is_equal_approx(player.position.x, expected.x) and is_equal_approx(player.position.z, expected.z),
			"the player piece sits on its cell"
		)
		_check(player.position.y > 0.0, "the player capsule is above the floor")
	var crate := board.get_node_or_null("Crate_0") as MeshInstance3D
	_check(crate != null, "the board builds a crate for every crate start")
	if crate != null:
		var expected := BoardBuilderClass.cell_to_world(level.box_starts[0], 7, 7)
		_check(
			is_equal_approx(crate.position.x, expected.x) and is_equal_approx(crate.position.z, expected.z),
			"the crate sits on its cell"
		)
		_check(
			crate.position.y - board.crate_size * 0.5 > 0.0,
			"the crate bottom face is above the floor top face"
		)
	var goal := board.get_node_or_null("Goal_5_1") as MeshInstance3D
	_check(goal != null, "the board builds a goal plate for every goal")
	if goal != null:
		_check(
			goal.position.y - board.plate_thickness * 0.5 > 0.0,
			"the goal plate bottom face is above the floor top face"
		)
	_check(board.get_node_or_null("Wall_0_0") != null, "the board builds walls from the wall cells")
	_check(board.get_node_or_null("WallTop_0_0") != null, "each wall carries a darker top cap")
	_check(board.wall_cells().size() == 24, "a 7x7 room has 24 wall cells")
	board.free()


func _test_camera_rig() -> void:
	_check(CameraRigClass.snap_yaw_degrees(45.0, 0) == 45.0, "quarter turn 0 keeps the default yaw")
	_check(CameraRigClass.snap_yaw_degrees(45.0, 1) == 135.0, "one quarter turn adds 90 degrees")
	_check(CameraRigClass.snap_yaw_degrees(45.0, 4) == 45.0, "four quarter turns return to the default yaw")
	_check(CameraRigClass.snap_yaw_degrees(45.0, -1) == 315.0, "a negative quarter turn wraps to 315 degrees")

	_check(CameraRigClass.clamp_pitch_degrees(20.0) == 30.0, "a pitch below 30 degrees is clamped")
	_check(CameraRigClass.clamp_pitch_degrees(40.0) == 40.0, "the default pitch is inside its limits")
	_check(CameraRigClass.clamp_pitch_degrees(70.0) == 55.0, "a pitch above 55 degrees is clamped")

	_check(
		is_equal_approx(CameraRigClass.apply_zoom_step(1.0, 1, 0.1, 0.6, 1.8), 1.1),
		"a zoom step moves the multiplier by one step"
	)
	_check(CameraRigClass.apply_zoom_step(0.6, -1, 0.1, 0.6, 1.8) == 0.6, "zoom stops at the lower bound")
	_check(CameraRigClass.apply_zoom_step(1.8, 1, 0.1, 0.6, 1.8) == 1.8, "zoom stops at the upper bound")

	var small: Array[Vector3] = [
		Vector3(-3.5, 0.0, -3.5),
		Vector3(3.5, 0.0, 3.5),
		Vector3(-3.5, 1.0, 3.5),
		Vector3(3.5, 1.0, -3.5),
	]
	var aspect := 1152.0 / 648.0
	var fitted := CameraRigClass.fit_orthogonal_size(small, 45.0, 40.0, aspect, 0.8, 6.0, 18.0)
	_check(fitted > 6.0 and fitted < 18.0, "the 7x7 room fits inside the camera size bounds")
	var huge: Array[Vector3] = [Vector3(-50.0, 0.0, -50.0), Vector3(50.0, 0.0, 50.0)]
	_check(
		is_equal_approx(CameraRigClass.fit_orthogonal_size(huge, 45.0, 40.0, aspect, 0.8, 6.0, 18.0), 18.0),
		"a large room clamps at the maximum camera size"
	)
	var tiny: Array[Vector3] = [Vector3(-0.1, 0.0, -0.1), Vector3(0.1, 0.0, 0.1)]
	_check(
		is_equal_approx(CameraRigClass.fit_orthogonal_size(tiny, 45.0, 40.0, aspect, 0.8, 6.0, 18.0), 6.0),
		"a tiny room clamps at the minimum camera size"
	)

	var cells := CameraRigClass.cells_on_segment(Vector3(0.0, 0.0, 0.0), Vector3(0.0, 0.0, 6.0), 1.0, 7, 7)
	_check(cells.has(Vector2i(3, 3)), "the column walk crosses the middle cell")
	_check(cells.has(Vector2i(3, 6)), "the column walk crosses the last row")

	var wall_cells: Array[Vector2i] = []
	for column in 7:
		wall_cells.append(Vector2i(column, 0))
		wall_cells.append(Vector2i(column, 6))
	for row in range(1, 6):
		wall_cells.append(Vector2i(0, row))
		wall_cells.append(Vector2i(6, row))
	var targets: Array[Vector3] = [BoardBuilderClass.cell_to_world(Vector2i(2, 3), 7, 7)]
	var camera_ground := Vector3(14.14, 0.0, 14.14)
	var occluded := CameraRigClass.occluded_wall_cells(camera_ground, targets, wall_cells, 1.0, 7, 7)
	_check(not occluded.is_empty(), "a near wall between the camera and the player is marked for fade")
	var near_side := false
	for cell in occluded:
		if cell.x == 6 or cell.y == 6:
			near_side = true
		_check(wall_cells.has(cell), "every faded cell is a wall cell")
	_check(near_side, "the faded walls are on the camera side of the room")
	_check(not occluded.has(Vector2i(0, 0)), "a wall behind the player is not faded")
	var no_targets: Array[Vector3] = []
	_check(
		CameraRigClass.occluded_wall_cells(camera_ground, no_targets, wall_cells, 1.0, 7, 7).is_empty(),
		"no targets means no faded walls"
	)


func _test_camera_framing() -> void:
	var aspect := 1152.0 / 648.0
	var camera_distance := 20.0
	var base_camera := Vector3(
		0.0, sin(deg_to_rad(40.0)) * camera_distance, cos(deg_to_rad(40.0)) * camera_distance
	)
	var sizes := [[7, 7], [9, 7], [15, 15]]
	for yaw in [45.0, 135.0, 225.0, 315.0]:
		for room in sizes:
			var label := "%dx%d room at yaw %d" % [room[0], room[1], int(yaw)]
			var corners := _room_corners(room[0], room[1], 1.0)
			var framing := CameraRigClass.frame_room(
				corners, yaw, 40.0, aspect, 0.8, 6.0, 18.0, base_camera
			)
			var size: float = framing["size"]
			var camera_local: Vector3 = framing["camera_local"]
			var min_view := Vector2(INF, INF)
			var max_view := Vector2(-INF, -INF)
			var every_corner_in_front := true
			for corner in corners:
				var view := CameraRigClass.view_point(corner, camera_local, yaw, 40.0)
				min_view = Vector2(minf(min_view.x, view.x), minf(min_view.y, view.y))
				max_view = Vector2(maxf(max_view.x, view.x), maxf(max_view.y, view.y))
				if CameraRigClass.view_depth(corner, camera_local, yaw, 40.0) <= 0.0:
					every_corner_in_front = false
			var horizontal := max_view.x - min_view.x
			var vertical := max_view.y - min_view.y
			var centre := (min_view + max_view) * 0.5
			_check(centre.length() < 0.01, "%s: the projected room is centred in the view" % label)
			_check(
				vertical <= size + 0.001,
				"%s: the whole room height fits the orthographic size" % label
			)
			_check(
				horizontal <= size * aspect + 0.001,
				"%s: the whole room width fits the orthographic size" % label
			)
			_check(every_corner_in_front, "%s: every room corner is in front of the camera" % label)
			_check(
				maxf(vertical, horizontal / aspect) >= size * 0.8 - 0.002,
				"%s: the room fills its fill ratio of the view" % label
			)

	# A non-square room must not be framed with a square room's size.
	var wide: float = CameraRigClass.frame_room(
		_room_corners(9, 7, 1.0), 45.0, 40.0, aspect, 0.8, 6.0, 18.0, base_camera
	)["size"]
	var square: float = CameraRigClass.frame_room(
		_room_corners(7, 7, 1.0), 45.0, 40.0, aspect, 0.8, 6.0, 18.0, base_camera
	)["size"]
	_check(wide > square, "a 9x7 room is framed larger than a 7x7 room")


func _room_corners(columns: int, rows: int, wall_height: float) -> Array[Vector3]:
	var half_width := float(columns) * BoardBuilderClass.CELL_SIZE * 0.5
	var half_depth := float(rows) * BoardBuilderClass.CELL_SIZE * 0.5
	var corners: Array[Vector3] = []
	for x in [-half_width, half_width]:
		for y in [0.0, wall_height]:
			for z in [-half_depth, half_depth]:
				corners.append(Vector3(x, y, z))
	return corners


func _test_wall_fade_outline() -> void:
	var faded_side := BoardBuilderClass.fade_side_alpha(0.22)
	var faded_cap := BoardBuilderClass.fade_cap_alpha(0.22)
	_check(faded_side > 0.0, "a faded wall keeps some alpha instead of vanishing")
	_check(faded_side < 0.5, "a faded wall stays semi-transparent")
	_check(faded_cap > faded_side, "a faded wall's top cap stays more opaque than its sides")
	_check(
		faded_cap >= 0.3 and faded_cap < 1.0,
		"a faded border wall keeps a visible outline in its top cap"
	)
	_check(BoardBuilderClass.fade_cap_alpha(1.0) == 1.0, "an opaque wall keeps an opaque cap")
	_check(BoardBuilderClass.fade_cap_alpha(0.0) > 0.0, "even a full fade keeps the wall outline")

	var level := _make_level(BASIC_TILES)
	var board := BoardBuilderClass.new()
	board.build(level)
	var bounds := board.room_bounds()
	_check(
		is_equal_approx(bounds.position.x, -3.5) and is_equal_approx(bounds.position.z, -3.5),
		"the room bounds start at the outer face of the border walls"
	)
	_check(
		is_equal_approx(bounds.size.x, 7.0) and is_equal_approx(bounds.size.z, 7.0),
		"the room bounds cover the whole 7x7 footprint"
	)
	_check(
		is_equal_approx(bounds.position.y, -board.floor_thickness),
		"the room bounds include the floor slab"
	)
	_check(
		is_equal_approx(bounds.end.y, board.wall_height + BoardBuilderClass.CAP_HEIGHT),
		"the room bounds reach the top of the wall cap"
	)
	board.free()


func _test_gameplay_input_mapping() -> void:
	_check(
		GameplayControllerClass.direction_for_action(InputActionsClass.MOVE_UP)
		== GameSessionClass.Direction.UP,
		"the move_up action requests an up move"
	)
	_check(
		GameplayControllerClass.direction_for_action(InputActionsClass.MOVE_DOWN)
		== GameSessionClass.Direction.DOWN,
		"the move_down action requests a down move"
	)
	_check(
		GameplayControllerClass.direction_for_action(InputActionsClass.MOVE_LEFT)
		== GameSessionClass.Direction.LEFT,
		"the move_left action requests a left move"
	)
	_check(
		GameplayControllerClass.direction_for_action(InputActionsClass.MOVE_RIGHT)
		== GameSessionClass.Direction.RIGHT,
		"the move_right action requests a right move"
	)
	_check(
		GameplayControllerClass.direction_for_action(InputActionsClass.CAMERA_ROTATE_LEFT)
		== GameplayControllerClass.MOVE_IGNORED,
		"a camera action requests no move"
	)
	_check(
		GameplayControllerClass.direction_for_action(InputActionsClass.PAUSE)
		== GameplayControllerClass.MOVE_IGNORED,
		"the pause action requests no move"
	)
	_check(
		GameplayControllerClass.direction_for_name(" right ") == GameSessionClass.Direction.RIGHT,
		"a capture script direction name maps to a move"
	)
	_check(
		GameplayControllerClass.direction_for_name("jump") == GameplayControllerClass.MOVE_IGNORED,
		"an unknown capture direction is ignored"
	)


func _test_gameplay_controller() -> void:
	var level := _make_level(BASIC_TILES)
	var pair := _make_controller(level)
	var controller: GameplayControllerClass = pair[0]
	var board: BoardBuilderClass = pair[1]

	_check(
		controller.request_move(GameSessionClass.Direction.RIGHT)
		== GameSessionClass.MoveResult.MOVED,
		"a step through the controller returns MOVED"
	)
	_check(controller.session.player == Vector2i(3, 3), "the controller moves the session player")
	_check(
		controller.request_move(GameSessionClass.Direction.RIGHT)
		== GameSessionClass.MoveResult.PUSHED,
		"a push through the controller returns PUSHED"
	)
	_check(controller.session.boxes[0] == Vector2i(5, 3), "the controller moves the session box")
	_check(
		controller.session.moves == 2 and controller.session.pushes == 1,
		"the controller counts the moves and pushes"
	)
	_check(controller.undo(), "undo after a push is accepted")
	_check(
		controller.session.player == Vector2i(3, 3)
		and controller.session.boxes[0] == Vector2i(4, 3),
		"undo of a push restores the player and the box cell"
	)
	_check(
		controller.session.moves == 1 and controller.session.pushes == 0,
		"undo of a push restores the counters"
	)
	_check(controller.undo(), "a second undo is accepted")
	_check(
		controller.session.player == Vector2i(2, 3) and controller.session.moves == 0,
		"undo returns the player to the start cell"
	)
	_check(not controller.undo(), "undo on an empty history does nothing")
	controller.free()
	board.free()

	var restart_pair := _make_controller(level)
	var restart_controller: GameplayControllerClass = restart_pair[0]
	restart_controller.request_move(GameSessionClass.Direction.RIGHT)
	restart_controller.request_move(GameSessionClass.Direction.RIGHT)
	_check(
		restart_controller.session.moves == 2 and restart_controller.session.pushes == 1,
		"the restart fixture has moved and pushed"
	)
	restart_controller.restart_level()
	_check(
		restart_controller.session.moves == 0 and restart_controller.session.pushes == 0,
		"restart resets the counters"
	)
	_check(
		restart_controller.session.player == level.player_start,
		"restart restores the player start cell"
	)
	_check(
		restart_controller.session.boxes[0] == level.box_starts[0],
		"restart restores the box start cell"
	)
	_check(restart_controller.elapsed_ms() == 0, "restart resets the elapsed time")
	_check(restart_controller.session.attempts == 1, "restart counts the attempt")

	restart_controller._busy = true
	var moves_before: int = restart_controller.session.moves
	_check(
		restart_controller.request_move(GameSessionClass.Direction.RIGHT)
		== GameplayControllerClass.MOVE_IGNORED,
		"a move request during a tile tween is ignored"
	)
	_check(
		restart_controller.session.moves == moves_before,
		"an ignored request changes no counter"
	)
	restart_controller._busy = false
	restart_controller._held_direction = GameSessionClass.Direction.RIGHT
	restart_controller._repeat_elapsed = 0.0
	restart_controller._process(0.31)
	_check(
		restart_controller.session.moves == 1,
		"holding a direction moves after the repeat delay"
	)
	restart_controller._process(0.20)
	_check(
		restart_controller.session.moves == 2,
		"holding a direction keeps moving"
	)
	restart_controller.free()
	restart_pair[1].free()

	var blocked_pair := _make_controller(level)
	var blocked_controller: GameplayControllerClass = blocked_pair[0]
	blocked_controller.request_move(GameSessionClass.Direction.LEFT)
	var blocked_moves: int = blocked_controller.session.moves
	_check(
		blocked_controller.request_move(GameSessionClass.Direction.LEFT)
		== GameSessionClass.MoveResult.REJECTED_WALL,
		"a move into a wall returns REJECTED_WALL"
	)
	_check(
		blocked_controller.session.moves == blocked_moves
		and blocked_controller.session.player == Vector2i(1, 3),
		"a blocked move leaves the state and the counters unchanged"
	)
	_check(not blocked_controller.is_busy(), "the bump feedback ends and clears the busy state")
	blocked_controller.free()
	blocked_pair[1].free()


func _test_gameplay_win() -> void:
	var level := _make_level(BASIC_TILES)
	var pair := _make_controller(level)
	var controller: GameplayControllerClass = pair[0]
	var board: BoardBuilderClass = pair[1]
	_victory_events.clear()
	controller.victory.connect(_on_controller_victory)
	_check(not board.is_goal_filled(Vector2i(5, 1)), "the goal plate starts empty")
	_walk_controller(
		controller,
		[
			GameSessionClass.Direction.RIGHT,
			GameSessionClass.Direction.RIGHT,
			GameSessionClass.Direction.DOWN,
			GameSessionClass.Direction.RIGHT,
			GameSessionClass.Direction.UP,
			GameSessionClass.Direction.UP,
		]
	)
	_check(controller.session.is_won, "the controller completes the level")
	_check(_victory_events.size() == 1, "the controller reports one completion")
	if _victory_events.size() == 1:
		var event: Dictionary = _victory_events[0]
		var stats: Dictionary = event["stats"]
		_check(int(stats.get("moves", -1)) == 6, "the completion payload carries the move count")
		_check(int(stats.get("pushes", -1)) == 3, "the completion payload carries the push count")
		_check(int(stats.get("elapsed_ms", -1)) >= 0, "the completion payload carries the elapsed time")
		_check(not bool(event["has_next"]), "the completion payload knows the last level")
	_check(board.is_goal_filled(Vector2i(5, 1)), "the goal plate lights when a crate lands on it")
	_check(board.crate_cells()[0] == Vector2i(5, 1), "the board tracks the finished crate cell")
	_check(
		board.crate_node(0) != null
		and board.crate_node(0).position.y
		< board.crate_world_position(Vector2i(5, 1), false).y,
		"a crate on a goal settles below the plate height"
	)
	var moves_after_win: int = controller.session.moves
	_check(
		controller.request_move(GameSessionClass.Direction.LEFT)
		== GameSessionClass.MoveResult.REJECTED_FINISHED,
		"a move after the win is rejected"
	)
	_check(
		controller.session.moves == moves_after_win,
		"a rejected move after the win changes no counter"
	)
	_check(not controller.undo(), "undo is closed after the win")
	controller.free()
	pair[1].free()


func _test_level_sequence() -> void:
	var paths := LevelSequenceClass.level_paths()
	_check(paths.size() == LEVEL_FILES.size(), "the level directory lists every level file")
	if paths.size() < 2:
		return
	_check(paths[0].ends_with("level-001.json"), "the level list starts at level-001")
	_check(paths[paths.size() - 1].ends_with("level-003.json"), "the level list ends at level-003")
	_check(LevelSequenceClass.has_next(paths, 0), "level-001 has a next level")
	_check(
		not LevelSequenceClass.has_next(paths, paths.size() - 1),
		"the last level has no next level"
	)
	_check(LevelSequenceClass.next_path(paths, 0) == paths[1], "next_path returns the following level")
	_check(LevelSequenceClass.index_of(paths, paths[1]) == 1, "index_of finds a level path")
	_check(
		MAIN_SCRIPT.resolve_level_argument("1", paths) == paths[0],
		"a numeric level argument selects by position"
	)
	_check(
		MAIN_SCRIPT.resolve_level_argument("level-002", paths) == paths[1],
		"a level id selects that level"
	)
	_check(
		MAIN_SCRIPT.resolve_level_argument("missing", paths) == "",
		"an unknown level argument selects nothing"
	)


func _test_victory_panel() -> void:
	_check(ResourceLoader.exists(VICTORY_SCENE_PATH), "the victory overlay scene exists")
	var packed := load(VICTORY_SCENE_PATH) as PackedScene
	_check(packed != null, "the victory overlay scene loads")
	if packed == null:
		return
	var panel := packed.instantiate()
	_check(panel is CanvasLayer, "the victory overlay is a canvas layer")
	_check(str(panel.name) == "VictoryPanel", "the victory overlay root is named VictoryPanel")
	var retry := panel.get_node_or_null("Root/Center/Panel/Content/Buttons/Retry") as Button
	var next := panel.get_node_or_null("Root/Center/Panel/Content/Buttons/Next") as Button
	var level_select := panel.get_node_or_null("Root/Center/Panel/Content/Buttons/LevelSelect") as Button
	var moves_label := panel.get_node_or_null("Root/Center/Panel/Content/Moves") as Label
	var time_label := panel.get_node_or_null("Root/Center/Panel/Content/Time") as Label
	_check(
		retry != null and next != null and level_select != null,
		"the victory overlay carries Retry, Next and Level Select"
	)
	_check(
		moves_label != null and time_label != null,
		"the victory overlay carries its stat labels"
	)
	if retry == null or next == null or level_select == null or moves_label == null or time_label == null:
		panel.free()
		return
	panel.show_result({"moves": 6, "pushes": 3, "elapsed_ms": 12600, "par_moves": 6}, false)
	_check(panel.visible, "show_result shows the overlay")
	_check(moves_label.text.contains("6") and moves_label.text.contains("par 6"), "the overlay shows moves against par")
	_check(time_label.text.contains("0:12.6"), "the overlay shows the elapsed time")
	_check(panel.stars_shown() == 3, "a par run shows three stars")
	_check(panel.next_enabled() == false, "Next is disabled on the last level")
	_check(not retry.disabled, "Retry stays enabled on the last level")
	_check(not level_select.disabled, "Level Select stays enabled on the last level")
	panel.show_result({"moves": 8, "pushes": 3, "elapsed_ms": 0, "par_moves": 6}, true)
	_check(panel.stars_shown() == 2, "a run inside the 1.25 par bound shows two stars")
	_check(panel.next_enabled(), "Next is enabled when another level follows")
	panel.show_result({"moves": 60, "pushes": 3, "elapsed_ms": 0, "par_moves": 6}, false)
	_check(panel.stars_shown() == 1, "a slow run shows one star")
	panel.hide_panel()
	_check(not panel.visible, "hide_panel hides the overlay")
	panel.free()
	_check(VictoryPanelClass.format_elapsed_ms(0) == "0:00.0", "zero milliseconds format as 0:00.0")
	_check(
		VictoryPanelClass.format_elapsed_ms(12600) == "0:12.6",
		"the time format keeps a tenth of a second"
	)
	_check(
		VictoryPanelClass.format_elapsed_ms(90000) == "1:30.0",
		"the time format rolls over to minutes"
	)


func _test_input_actions() -> void:
	InputActionsClass.register_defaults()
	for action: String in InputActionsClass.GAMEPLAY_ACTIONS:
		_check(InputMap.has_action(action), "the InputMap registers %s" % action)
	_check(InputMap.has_action(InputActionsClass.UI_BACK), "the InputMap registers ui_back")
	_check(InputActionsClass.DIRECTION_ACTIONS.size() == 4, "there are exactly four direction actions")

	var move_events := InputMap.action_get_events(InputActionsClass.MOVE_UP)
	_check(move_events.size() == 4, "move_up carries its four default bindings")
	_check(_has_key_event(move_events, KEY_W), "move_up binds W")
	_check(_has_key_event(move_events, KEY_UP), "move_up binds the up arrow")
	_check(_has_joy_button_event(move_events, JOY_BUTTON_DPAD_UP), "move_up binds the d-pad up")

	var undo_events := InputMap.action_get_events(InputActionsClass.UNDO)
	_check(undo_events.size() == 3, "undo carries three bindings")
	_check(_has_ctrl_key_event(undo_events, KEY_Z), "undo binds Ctrl+Z")
	_check(_has_joy_button_event(undo_events, JOY_BUTTON_Y), "undo binds the gamepad Y button")

	var pause_events := InputMap.action_get_events(InputActionsClass.PAUSE)
	_check(_has_key_event(pause_events, KEY_ESCAPE), "pause binds Escape")
	_check(_has_joy_button_event(pause_events, JOY_BUTTON_START), "pause binds gamepad Start")

	var zoom_in_events := InputMap.action_get_events(InputActionsClass.CAMERA_ZOOM_IN)
	_check(
		_has_mouse_wheel_event(zoom_in_events, MOUSE_BUTTON_WHEEL_UP),
		"camera_zoom_in binds the mouse wheel up"
	)
	_check(
		_has_mouse_wheel_event(
			InputMap.action_get_events(InputActionsClass.CAMERA_ZOOM_OUT), MOUSE_BUTTON_WHEEL_DOWN
		),
		"camera_zoom_out binds the mouse wheel down"
	)
	var rotate_events := InputMap.action_get_events(InputActionsClass.CAMERA_ROTATE_LEFT)
	_check(
		_has_joy_button_event(rotate_events, JOY_BUTTON_LEFT_SHOULDER),
		"camera_rotate_left binds the left shoulder button"
	)
	var before := InputMap.action_get_events(InputActionsClass.MOVE_UP).size()
	InputActionsClass.register_defaults()
	_check(
		InputMap.action_get_events(InputActionsClass.MOVE_UP).size() == before,
		"register_defaults is idempotent"
	)
	_check(
		InputActionsClass.default_events("not_an_action").is_empty(),
		"an unknown action has no default binding"
	)


func _test_star_rating() -> void:
	_check(StarRatingClass.stars_for_moves(6, 6) == 3, "a par run earns three stars")
	_check(StarRatingClass.stars_for_moves(5, 6) == 3, "a run under par earns three stars")
	_check(StarRatingClass.stars_for_moves(7, 6) == 2, "a run inside the 1.25 par bound earns two stars")
	_check(StarRatingClass.stars_for_moves(8, 6) == 2, "the two-star bound is inclusive")
	_check(StarRatingClass.stars_for_moves(9, 6) == 1, "a run past the bound earns one star")
	_check(StarRatingClass.star_2_bound(6) == 8, "the two-star bound for par 6 is 8 moves")
	_check(StarRatingClass.star_2_bound(24) == 30, "the two-star bound for par 24 is 30 moves")
	_check(
		StarRatingClass.stars_for_moves(0, 0) == 3,
		"a zero-move completion against par 0 clamps to three stars"
	)


func _test_ui_format() -> void:
	_check(UiFormatClass.elapsed_ms(0) == "0:00.0", "zero time formats as 0:00.0")
	_check(UiFormatClass.elapsed_ms(999) == "0:00.9", "sub-second time keeps a tenth")
	_check(UiFormatClass.elapsed_ms(12600) == "0:12.6", "12.6 seconds format as 0:12.6")
	_check(UiFormatClass.elapsed_ms(90000) == "1:30.0", "90 seconds format as 1:30.0")
	_check(UiFormatClass.elapsed_ms(3600000) == "1:00:00.0", "an hour rolls into h:mm:ss.t")
	_check(
		UiFormatClass.elapsed_ms(360000000) == "99:59:59.9",
		"the displayed timer clamps at 99 hours"
	)


func _test_screen_router() -> void:
	var router := ScreenRouterClass.new()
	var transitions: Array = []
	router.screen_changed.connect(
		func(from_screen: int, to_screen: int) -> void:
			transitions.append([from_screen, to_screen])
	)
	_check(router.screen == ScreenRouterClass.Screen.MAIN_MENU, "the router boots on the main menu")
	_check(not router.pause_game(), "a pause request outside gameplay is refused")
	_check(router.screen == ScreenRouterClass.Screen.MAIN_MENU, "a refused transition keeps the screen")

	_check(router.show_level_select(), "the main menu opens the level select")
	_check(router.screen == ScreenRouterClass.Screen.LEVEL_SELECT, "the level select is the current screen")
	_check(router.back(), "back leaves the level select")
	_check(router.screen == ScreenRouterClass.Screen.MAIN_MENU, "back returns to the main menu")

	_check(router.start_gameplay(), "the main menu can start gameplay")
	_check(router.accepts_gameplay_input(), "gameplay accepts gameplay input")
	_check(router.shows_room(), "gameplay shows the room")
	_check(router.pause_game(), "gameplay opens the pause menu")
	_check(router.screen == ScreenRouterClass.Screen.PAUSE, "the pause menu is the current screen")
	_check(not router.accepts_gameplay_input(), "pause stops gameplay input")
	_check(router.show_settings(), "pause opens the settings placeholder")
	_check(router.back(), "back leaves settings")
	_check(router.screen == ScreenRouterClass.Screen.PAUSE, "settings returns to pause")
	_check(router.resume_game(), "pause resumes gameplay")
	_check(router.screen == ScreenRouterClass.Screen.GAMEPLAY, "resume returns to gameplay")

	_check(router.show_victory(), "gameplay can open the victory panel")
	_check(not router.pause_game(), "a pause request on the victory panel is refused")
	_check(router.show_level_select(), "victory opens the level select")
	_check(router.back(), "back leaves the level select from victory")
	_check(router.screen == ScreenRouterClass.Screen.MAIN_MENU, "victory level select returns to the menu")
	_check(router.show_credits(), "the main menu opens credits")
	_check(router.back(), "back leaves credits")
	_check(router.screen == ScreenRouterClass.Screen.MAIN_MENU, "credits returns to the main menu")
	_check(transitions.size() >= 10, "every accepted transition emits screen_changed")
	_check(
		ScreenRouterClass.screen_name(ScreenRouterClass.Screen.PAUSE) == "pause",
		"the router names the pause screen"
	)


func _test_level_progress() -> void:
	var paths: Array[String] = ["level-001", "level-002", "level-003"]
	_check(
		LevelProgressClass.next_level_index(paths, {}) == 0,
		"Play opens the first level when nothing is complete"
	)
	_check(
		LevelProgressClass.next_level_index(paths, {"level-001": true}) == 1,
		"Play opens the first unfinished level"
	)
	_check(
		LevelProgressClass.next_level_index(
			paths, {"level-001": true, "level-002": true, "level-003": true}
		) == 2,
		"Play opens the last level when every level is complete"
	)
	var empty: Array[String] = []
	_check(
		LevelProgressClass.next_level_index(empty, {}) == LevelProgressClass.NO_LEVEL,
		"Play has no level when the list is empty"
	)


func _test_ui_theme() -> void:
	var theme := UiThemeClass.build()
	_check(theme.default_font_size >= 16, "the theme body font is at least 16 px")
	_check(theme.get_font_size("font_size", "Button") >= 16, "the button font is at least 16 px")
	_check(theme.get_font_size("font_size", "TitleLabel") >= 16, "the title font is at least 16 px")
	var focus := theme.get_stylebox("focus", "Button") as StyleBoxFlat
	_check(focus != null, "the theme carries a button focus stylebox")
	if focus != null:
		_check(focus.border_width_top >= 2, "the focus ring is at least 2 px wide")
		_check(focus.border_color == UiThemeClass.FOCUS, "the focus ring uses the palette focus colour")
	_check(
		theme.get_stylebox("panel", "HudStrip") != null,
		"the theme styles the HUD strip"
	)
	_check(
		theme.get_stylebox("panel", "ScreenBackground") != null,
		"the theme styles a screen background"
	)


func _test_hud() -> void:
	var packed := load(HUD_SCENE_PATH) as PackedScene
	_check(packed != null, "the HUD scene loads")
	if packed == null:
		return
	var hud := packed.instantiate()
	_check(hud is CanvasLayer, "the HUD is a canvas layer")
	hud.set_level(1, "First Push")
	var level_label := hud.get_node_or_null("Strip/Margin/Row/LevelLabel") as Label
	var moves_label := hud.get_node_or_null("Strip/Margin/Row/MovesLabel") as Label
	var pushes_label := hud.get_node_or_null("Strip/Margin/Row/PushesLabel") as Label
	var goals_label := hud.get_node_or_null("Strip/Margin/Row/GoalsLabel") as Label
	var time_label := hud.get_node_or_null("Strip/Margin/Row/TimeLabel") as Label
	var undo := hud.get_node_or_null("Strip/Margin/Row/Undo") as Button
	var restart := hud.get_node_or_null("Strip/Margin/Row/Restart") as Button
	var pause := hud.get_node_or_null("Strip/Margin/Row/Pause") as Button
	_check(
		level_label != null and moves_label != null and pushes_label != null,
		"the HUD carries its labels"
	)
	_check(undo != null and restart != null and pause != null, "the HUD carries its three buttons")
	if moves_label == null or undo == null or restart == null or pause == null:
		hud.free()
		return
	_check(level_label.text.contains("First Push"), "the HUD names the level")
	hud.set_attempt_stats(
		{
			"moves": 7,
			"pushes": 3,
			"goals_filled": 1,
			"goals_total": 2,
			"can_undo": true,
			"elapsed_ms": 12600,
		}
	)
	_check(moves_label.text == "Moves: 7", "the HUD shows the move count")
	_check(pushes_label.text == "Pushes: 3", "the HUD shows the push count")
	_check(goals_label.text == "Goals: 1/2", "the HUD shows the goal counter")
	_check(time_label.text == "Time: 0:12.6", "the HUD shows the elapsed time")
	_check(not undo.disabled, "Undo is enabled while history exists")
	hud.set_attempt_stats({"moves": 0, "pushes": 0, "goals_filled": 0, "goals_total": 2, "can_undo": false})
	_check(undo.disabled, "Undo is disabled with an empty history")
	_ui_signal_flags.clear()
	hud.undo_requested.connect(_on_test_undo_requested)
	hud.restart_requested.connect(_on_test_restart_requested)
	hud.pause_requested.connect(_on_test_pause_requested)
	undo.pressed.emit()
	restart.pressed.emit()
	pause.pressed.emit()
	_check(bool(_ui_signal_flags.get("undo", false)), "the HUD Undo button emits undo_requested")
	_check(bool(_ui_signal_flags.get("restart", false)), "the HUD Restart button emits restart_requested")
	_check(bool(_ui_signal_flags.get("pause", false)), "the HUD Pause button emits pause_requested")
	hud.free()


func _test_level_select() -> void:
	var packed := load(LEVEL_SELECT_SCENE_PATH) as PackedScene
	_check(packed != null, "the level select scene loads")
	if packed == null:
		return
	var screen := packed.instantiate()
	_check(screen is CanvasLayer, "the level select is a canvas layer")
	var levels: Array[Dictionary] = [
		{"index": 0, "name": "First Push", "par_moves": 6, "difficulty": 1, "completed": false},
		{"index": 1, "name": "Turn the Corner", "par_moves": 14, "difficulty": 1, "completed": true},
		{"index": 2, "name": "Two of a Kind", "par_moves": 24, "difficulty": 2, "completed": false},
	]
	screen.show_levels(levels)
	_check(screen.card_count() == 3, "the level select builds one card per level")
	var fewer_levels: Array[Dictionary] = [
		{"index": 0, "name": "First Push", "par_moves": 6, "difficulty": 1, "completed": false},
		{"index": 1, "name": "Turn the Corner", "par_moves": 14, "difficulty": 1, "completed": false},
	]
	screen.show_levels(fewer_levels)
	_check(screen.card_count() == 2, "rebuilding the level select replaces the old cards")
	_check(LevelSelectClass.difficulty_label(1) == "Beginner", "difficulty 1-2 reads Beginner")
	_check(LevelSelectClass.difficulty_label(6) == "Medium", "difficulty 5-6 reads Medium")
	_check(LevelSelectClass.difficulty_label(10) == "Expert", "difficulty 9-10 reads Expert")
	_check(LevelSelectClass.difficulty_label(42) == "Expert", "an out-of-range difficulty clamps")
	_ui_signal_flags.clear()
	screen.level_selected.connect(_on_test_level_selected)
	screen.back_requested.connect(_on_test_back_requested)
	var grid := screen.get_node_or_null("Root/Content/Margin/Layout/Grid") as GridContainer
	if grid != null and grid.get_child_count() > 0:
		var card := grid.get_child(0) as Button
		card.pressed.emit()
	_check(bool(_ui_signal_flags.get("level_selected", false)), "a card emits level_selected")
	_check(
		int(_ui_signal_flags.get("selected_index", -1)) == 0,
		"the level card reports its list index"
	)
	var back := screen.get_node_or_null("Root/Content/Margin/Layout/Back") as Button
	if back != null:
		back.pressed.emit()
	_check(bool(_ui_signal_flags.get("back", false)), "the level select back button emits back_requested")
	screen.free()


func _test_main_menu() -> void:
	var packed := load(MAIN_MENU_SCENE_PATH) as PackedScene
	_check(packed != null, "the main menu scene loads")
	if packed == null:
		return
	var menu := packed.instantiate()
	_check(menu is CanvasLayer, "the main menu is a canvas layer")
	var texts: Array = menu.button_texts()
	_check(texts.size() == 5, "the main menu has five buttons")
	if texts.size() == 5:
		_check(texts[0] == "Play", "the first main menu button is Play")
		_check(texts[1] == "Level Select", "the second main menu button is Level Select")
		_check(texts[4] == "Quit", "the last main menu button is Quit")
	var version := menu.get_node_or_null("Root/Version") as Label
	menu.set_version("1.0")
	_check(version != null and version.visible and version.text == "v1.0", "the version label shows v<version>")
	menu.set_version("")
	_check(version != null and not version.visible, "the version label hides without a project version")
	_ui_signal_flags.clear()
	menu.play_requested.connect(_on_test_play_requested)
	var play := menu.get_node_or_null("Root/Content/Margin/Layout/Buttons/Play") as Button
	if play != null:
		play.pressed.emit()
	_check(bool(_ui_signal_flags.get("play", false)), "the Play button emits play_requested")
	menu.free()


func _test_pause_menu() -> void:
	var packed := load(PAUSE_MENU_SCENE_PATH) as PackedScene
	_check(packed != null, "the pause menu scene loads")
	if packed == null:
		return
	var menu := packed.instantiate()
	_check(menu is CanvasLayer, "the pause menu is a canvas layer")
	var texts: Array = menu.button_texts()
	_check(texts.size() == 4, "the pause menu has four buttons")
	if texts.size() == 4:
		_check(texts[0] == "Resume", "the first pause button is Resume")
		_check(texts[1] == "Restart", "the second pause button is Restart")
		_check(texts[3] == "Main Menu", "the last pause button is Main Menu")
	_ui_signal_flags.clear()
	menu.resume_requested.connect(_on_test_resume_requested)
	menu.main_menu_requested.connect(_on_test_main_menu_requested)
	var resume := menu.get_node_or_null("Root/Center/Panel/Content/Resume") as Button
	if resume != null:
		resume.pressed.emit()
	var main_menu := menu.get_node_or_null("Root/Center/Panel/Content/MainMenu") as Button
	if main_menu != null:
		main_menu.pressed.emit()
	_check(bool(_ui_signal_flags.get("resume", false)), "Resume emits resume_requested")
	_check(bool(_ui_signal_flags.get("main_menu", false)), "Main Menu emits main_menu_requested")
	menu.free()


func _test_confirm_modal() -> void:
	var packed := load(CONFIRM_SCENE_PATH) as PackedScene
	_check(packed != null, "the confirm modal scene loads")
	if packed == null:
		return
	var modal := packed.instantiate()
	_check(modal is CanvasLayer, "the confirm modal is a canvas layer")
	_ui_signal_flags.clear()
	modal.confirmed.connect(_on_test_confirmed)
	modal.cancelled.connect(_on_test_cancelled)
	modal.ask("Discard this attempt?")
	var question := modal.get_node_or_null("Root/Center/Panel/Content/Question") as Label
	_check(modal.is_open(), "ask opens the confirm modal")
	_check(question != null and question.text == "Discard this attempt?", "the modal shows the question")
	modal.cancel()
	_check(not modal.is_open(), "cancel closes the modal")
	_check(bool(_ui_signal_flags.get("cancelled", false)), "cancel emits cancelled")
	modal.ask("Leave the level?")
	modal.confirm()
	_check(not modal.is_open(), "confirm closes the modal")
	_check(bool(_ui_signal_flags.get("confirmed", false)), "confirm emits confirmed")
	modal.free()


func _test_star_row() -> void:
	var row := StarRowClass.new()
	_check(row != null, "a star row can be created")
	if row == null:
		return
	row.set_stars(2)
	_check(row.stars == 2, "the star row keeps two filled stars")
	_check(row.custom_minimum_size.x > 0.0, "the star row reserves room for three marks")
	row.set_stars(9)
	_check(row.stars == 3, "the star row clamps above three")
	row.set_stars(-4)
	_check(row.stars == 0, "the star row clamps below zero")
	row.free()


func _test_gameplay_pause_blocks_input() -> void:
	var pair := _make_controller(_make_level(BASIC_TILES))
	var controller: GameplayControllerClass = pair[0]
	var board: BoardBuilderClass = pair[1]
	_check(
		controller.request_move(GameSessionClass.Direction.RIGHT) == GameSessionClass.MoveResult.MOVED,
		"the pause fixture takes one move"
	)
	controller.set_paused(true)
	_check(controller.is_paused(), "the controller reports the paused state")
	var moves_before := controller.session.moves
	_check(
		controller.request_move(GameSessionClass.Direction.RIGHT) == GameplayControllerClass.MOVE_IGNORED,
		"a move request while paused is ignored"
	)
	_check(controller.session.moves == moves_before, "a paused move changes no counter")
	_check(not controller.undo(), "undo while paused is refused")
	var elapsed_before := controller.elapsed_ms()
	controller._process(1.0)
	_check(controller.elapsed_ms() == elapsed_before, "the timer does not advance while paused")
	controller.set_paused(false)
	_check(
		controller.request_move(GameSessionClass.Direction.RIGHT) == GameSessionClass.MoveResult.PUSHED,
		"unpausing lets the next move through"
	)
	controller.free()
	board.free()


func _has_key_event(events: Array[InputEvent], keycode: int) -> bool:
	for event: InputEvent in events:
		var key := event as InputEventKey
		if key != null and key.physical_keycode == keycode and not key.ctrl_pressed:
			return true
	return false


func _has_ctrl_key_event(events: Array[InputEvent], keycode: int) -> bool:
	for event: InputEvent in events:
		var key := event as InputEventKey
		if key != null and key.physical_keycode == keycode and key.ctrl_pressed:
			return true
	return false


func _has_joy_button_event(events: Array[InputEvent], button_index: int) -> bool:
	for event: InputEvent in events:
		var button := event as InputEventJoypadButton
		if button != null and button.button_index == button_index:
			return true
	return false


func _has_mouse_wheel_event(events: Array[InputEvent], button_index: int) -> bool:
	for event: InputEvent in events:
		var button := event as InputEventMouseButton
		if button != null and button.button_index == button_index:
			return true
	return false


func _make_controller(level: LevelDataClass) -> Array:
	var board := BoardBuilderClass.new()
	board.build(level)
	var controller := GameplayControllerClass.new()
	controller.animation_enabled = false
	controller.setup(level, board, null, false)
	return [controller, board]


func _walk_controller(controller: GameplayControllerClass, directions: Array[int]) -> void:
	for direction in directions:
		controller.request_move(direction)


func _on_controller_victory(stats: Dictionary, has_next: bool) -> void:
	_victory_events.append({"stats": stats, "has_next": has_next})


func _level_dictionary(tiles: Array, overrides: Dictionary = {}) -> Dictionary:
	var data := {
		"id": "level-900",
		"name": "Test Room",
		"name_key": "level_900_name",
		"author": "Test Author",
		"difficulty": 1,
		"par_moves": 20,
		"par_pushes": 5,
		"columns": (tiles[0] as String).length(),
		"rows": tiles.size(),
		"tiles": tiles,
	}
	for key in overrides:
		data[key] = overrides[key]
	return data


func _make_level(tiles: Array, overrides: Dictionary = {}) -> LevelDataClass:
	return LevelDataClass.from_dictionary(_level_dictionary(tiles, overrides))


func _read_level_text(file_stem: String) -> String:
	var path := LEVEL_DIRECTORY % file_stem
	if not FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text


func _walk(session: GameSessionClass, directions: Array[int]) -> void:
	for direction in directions:
		session.try_move(direction)


func _cycle_direction(index: int) -> int:
	if index % 4 == 0:
		return GameSessionClass.Direction.RIGHT
	if index % 4 == 1:
		return GameSessionClass.Direction.DOWN
	if index % 4 == 2:
		return GameSessionClass.Direction.LEFT
	return GameSessionClass.Direction.UP


func _copy_cells(cells: Array[Vector2i]) -> Array[Vector2i]:
	var copy: Array[Vector2i] = []
	copy.assign(cells)
	return copy


func _cells_equal(left: Array[Vector2i], right: Array[Vector2i]) -> bool:
	if left.size() != right.size():
		return false
	for index in left.size():
		if left[index] != right[index]:
			return false
	return true


func _on_move_rejected(_direction: int, reason: int) -> void:
	_rejected_reasons.append(reason)


func _on_deadlock_detected(box_cell: Vector2i) -> void:
	_deadlock_cells.append(box_cell)


func _on_level_completed(stats: Dictionary) -> void:
	_completed_stats.append(stats)


func _on_test_undo_requested() -> void:
	_ui_signal_flags["undo"] = true


func _on_test_restart_requested() -> void:
	_ui_signal_flags["restart"] = true


func _on_test_pause_requested() -> void:
	_ui_signal_flags["pause"] = true


func _on_test_play_requested() -> void:
	_ui_signal_flags["play"] = true


func _on_test_resume_requested() -> void:
	_ui_signal_flags["resume"] = true


func _on_test_main_menu_requested() -> void:
	_ui_signal_flags["main_menu"] = true


func _on_test_back_requested() -> void:
	_ui_signal_flags["back"] = true


func _on_test_level_selected(index: int) -> void:
	_ui_signal_flags["level_selected"] = true
	_ui_signal_flags["selected_index"] = index


func _on_test_confirmed() -> void:
	_ui_signal_flags["confirmed"] = true


func _on_test_cancelled() -> void:
	_ui_signal_flags["cancelled"] = true


func _test_save_settings_i18n() -> void:
	_test_save_round_trip()
	_test_save_corrupt_recovery()
	_test_save_newer_version()
	_test_save_migration()
	_test_save_unlock_and_records()
	_test_settings_clamping()
	_test_localization_tables()
	_test_level_select_progress_cards()
	_test_settings_screen()
	_test_colorblind_and_reduce_motion()


func _test_save_round_trip() -> void:
	var path := "user://test-save-roundtrip.json"
	_clean_save_test_files(path)
	var store := SaveStoreClass.new()
	store.configure(path)
	var summary := store.load_profile()
	_check(summary["status"] == SaveStoreClass.STATUS_NEW, "a missing profile loads as a new profile")
	_check(int(store.data().get("version", 0)) == SaveStoreClass.CURRENT_VERSION, "a new profile carries the current version")
	_check(store.ensure_unlocked("level-001"), "the store unlocks the first level")
	_check(store.is_unlocked("level-001"), "the first level reads as unlocked")
	_check(not store.is_unlocked("level-002"), "the second level starts locked")
	_check(is_equal_approx(float(store.set_setting("master_volume", 0.4)), 0.4), "set_setting returns the stored value")
	_check(store.save_now(), "the store writes its profile atomically")
	_check(FileAccess.file_exists(path), "the profile exists after a write")
	_check(not FileAccess.file_exists(path + ".tmp"), "an atomic write leaves no temp file behind")
	_check(not FileAccess.file_exists(path + ".bak"), "the first write creates no backup to rotate")
	store.set_setting("sfx_volume", 0.7)
	_check(store.save_now(), "a second write succeeds")
	_check(FileAccess.file_exists(path + ".bak"), "a second write keeps the previous profile as .bak")
	var reloaded := SaveStoreClass.new()
	reloaded.configure(path)
	var second := reloaded.load_profile()
	_check(second["status"] == SaveStoreClass.STATUS_OK, "an intact profile reloads as OK")
	_check(is_equal_approx(float(reloaded.settings().get("master_volume", 0.0)), 0.4), "the settings round-trip through the file")
	_check(is_equal_approx(float(reloaded.settings().get("sfx_volume", 0.0)), 0.7), "a later setting change round-trips too")
	_check(reloaded.is_unlocked("level-001"), "the unlock round-trips through the file")
	DirAccess.remove_absolute(path)
	var adopted := SaveStoreClass.new()
	adopted.configure(path)
	var third := adopted.load_profile()
	_check(third["status"] == SaveStoreClass.STATUS_RECOVERED, "a missing profile adopts the readable backup")
	_check(adopted.is_unlocked("level-001"), "the adopted backup keeps the unlock")
	store.free()
	reloaded.free()
	adopted.free()
	_clean_save_test_files(path)
	var future_path := "user://test-save-unknown.json"
	_clean_save_test_files(future_path)
	_write_test_text(
		future_path,
		JSON.stringify(
			{
				"version": 1,
				"unlocked": ["level-001"],
				"levels": {},
				"settings": {},
				"stats": {"total_moves": 7},
				"future_field": {"kept": true},
			}
		)
	)
	var future_store := SaveStoreClass.new()
	future_store.configure(future_path)
	future_store.load_profile()
	_check(future_store.data().has("future_field"), "an unknown top-level key is preserved")
	_check(
		int((future_store.data().get("stats", {}) as Dictionary).get("total_moves", 0)) == 7,
		"lifetime stats are preserved"
	)
	future_store.save_now()
	var rewritten: Variant = JSON.parse_string(_read_test_text(future_path))
	_check(
		rewritten is Dictionary
		and ((rewritten as Dictionary).get("future_field", {}) as Dictionary).get("kept", false),
		"the unknown key is written back after a round trip"
	)
	future_store.free()
	_clean_save_test_files(future_path)


func _test_save_corrupt_recovery() -> void:
	var path := "user://test-save-corrupt.json"
	_clean_save_test_files(path)
	_write_test_text(path, "{ this is not json")
	var store := SaveStoreClass.new()
	store.configure(path)
	var summary := store.load_profile()
	_check(summary["status"] == SaveStoreClass.STATUS_CORRUPT, "a damaged profile reports the corrupt status")
	_check(str(summary["notice_key"]) == SaveStoreClass.NOTICE_CORRUPT, "a damaged profile asks for the corrupt notice")
	_check(store.last_backup_path != "" and FileAccess.file_exists(store.last_backup_path), "a damaged profile is backed up")
	_check(
		store.last_backup_path.get_file().begins_with("test-save-corrupt.corrupt-"),
		"the backup name follows save.corrupt-<ts>.json"
	)
	_check(_read_test_text(store.last_backup_path) == "{ this is not json", "the backup keeps the damaged bytes")
	_check(int(store.data().get("version", 0)) == SaveStoreClass.CURRENT_VERSION, "a damaged profile falls back to defaults")
	_check(is_equal_approx(float(store.settings().get("master_volume", 0.0)), 0.8), "the fallback settings are the defaults")
	var reloaded := SaveStoreClass.new()
	reloaded.configure(path)
	_check(reloaded.load_profile()["status"] == SaveStoreClass.STATUS_OK, "the fresh profile left after corruption loads cleanly")
	store.free()
	reloaded.free()
	_clean_save_test_files(path)


func _test_save_newer_version() -> void:
	var path := "user://test-save-newer.json"
	_clean_save_test_files(path)
	var newer := {
		"version": SaveStoreClass.CURRENT_VERSION + 1,
		"unlocked": ["level-002"],
		"levels": {},
		"settings": {"master_volume": 0.1},
	}
	_write_test_text(path, JSON.stringify(newer))
	var store := SaveStoreClass.new()
	store.configure(path)
	var summary := store.load_profile()
	_check(summary["status"] == SaveStoreClass.STATUS_NEWER, "a newer profile reports the newer status")
	_check(bool(summary["read_only"]), "a newer profile makes the store read-only")
	_check(str(summary["notice_key"]) == SaveStoreClass.NOTICE_NEWER, "a newer profile asks for the newer notice")
	_check(store.last_backup_path != "" and FileAccess.file_exists(store.last_backup_path), "a newer profile is copied aside")
	_check(not store.is_unlocked("level-002"), "a newer profile's data is not adopted into the fresh one")
	var before := _read_test_text(path)
	_check(not store.save_now(), "a read-only store refuses to write")
	_check(_read_test_text(path) == before, "a refused write leaves the newer file untouched")
	store.free()
	_clean_save_test_files(path)


func _test_save_migration() -> void:
	var path := "user://test-save-migration.json"
	_clean_save_test_files(path)
	var legacy := {
		"version": 0,
		"completed": ["level-001"],
		"settings": {"master_volume": 0.5, "sfx_volume": 0.25},
	}
	_write_test_text(path, JSON.stringify(legacy))
	var store := SaveStoreClass.new()
	store.configure(path)
	var summary := store.load_profile()
	_check(summary["status"] == SaveStoreClass.STATUS_MIGRATED, "an older profile reports the migrated status")
	_check(int(store.data().get("version", 0)) == SaveStoreClass.CURRENT_VERSION, "migration reaches the current version")
	_check(is_equal_approx(float(store.settings().get("master_volume", 0.0)), 0.5), "migration keeps a valid stored setting")
	_check(is_equal_approx(float(store.settings().get("sfx_volume", 0.0)), 0.25), "migration keeps a second stored setting")
	_check(is_equal_approx(float(store.settings().get("camera_sensitivity", 0.0)), 1.0), "migration fills a missing setting with its default")
	var written: Variant = JSON.parse_string(_read_test_text(path))
	_check(written is Dictionary and int((written as Dictionary).get("version", 0)) == SaveStoreClass.CURRENT_VERSION, "the migrated profile is written back")
	store.free()
	_clean_save_test_files(path)


func _test_save_unlock_and_records() -> void:
	var path := "user://test-save-records.json"
	_clean_save_test_files(path)
	var store := SaveStoreClass.new()
	store.configure(path)
	store.load_profile()
	store.ensure_unlocked("level-001")
	var ids: Array[String] = ["level-001", "level-002", "level-003"]
	_check(store.next_unfinished(ids) == "level-001", "Play starts on the first unlocked level")
	var first := store.complete_level(
		"level-001", ids, {"moves": 10, "pushes": 4, "elapsed_ms": 20000, "stars": 2}
	)
	_check(bool(first.get("new_best", false)), "the first completion sets a best record")
	_check(str(first.get("unlocked", "")) == "level-002", "completing a level unlocks the next one")
	_check(store.is_unlocked("level-002"), "the next level is unlocked")
	_check(not store.is_unlocked("level-003"), "the level after that stays locked")
	_check(store.next_unfinished(ids) == "level-002", "Play moves to the next unfinished level")
	var record := store.record_for("level-001")
	_check(bool(record.get("completed", false)), "a completed level records completion")
	_check(int(record.get("stars", 0)) == 2 and int(record.get("best_moves", 0)) == 10, "the record keeps stars and best moves")
	_check(int(record.get("best_pushes", 0)) == 4 and int(record.get("best_time_ms", 0)) == 20000, "the record keeps the pushes and time of the best run")
	store.complete_level(
		"level-001", ids, {"moves": 12, "pushes": 6, "elapsed_ms": 30000, "stars": 1}
	)
	record = store.record_for("level-001")
	_check(int(record.get("best_moves", 0)) == 10 and int(record.get("best_pushes", 0)) == 4, "a worse run does not replace the best moves")
	_check(int(record.get("stars", 0)) == 2, "a lower star count does not replace the best stars")
	store.complete_level(
		"level-001", ids, {"moves": 8, "pushes": 3, "elapsed_ms": 15000, "stars": 3}
	)
	record = store.record_for("level-001")
	_check(int(record.get("best_moves", 0)) == 8 and int(record.get("best_time_ms", 0)) == 15000, "a better run replaces the best record")
	_check(int(record.get("stars", 0)) == 3, "a higher star count replaces the best stars")
	store.complete_level(
		"level-001", ids, {"moves": 8, "pushes": 3, "elapsed_ms": 12000, "stars": 2}
	)
	_check(int(store.record_for("level-001").get("best_time_ms", 0)) == 12000, "an equal-move faster run improves the time")
	_check(int(store.record_for("level-001").get("stars", 0)) == 3, "an equal-move run keeps the higher star count")
	store.complete_level("level-002", ids, {"moves": 14, "pushes": 6, "elapsed_ms": 1000, "stars": 3})
	_check(store.is_unlocked("level-003"), "completing the second level unlocks the third")
	store.complete_level("level-003", ids, {"moves": 20, "pushes": 8, "elapsed_ms": 1000, "stars": 3})
	_check(store.next_unfinished(ids) == "level-003", "Play opens the last level when every level is complete")
	_check(store.complete_level("", ids, {}).is_empty(), "a completion without a level id is ignored")
	store.save_now()
	var reloaded := SaveStoreClass.new()
	reloaded.configure(path)
	reloaded.load_profile()
	_check(int(reloaded.record_for("level-001").get("best_moves", 0)) == 8, "the merged record round-trips through the file")
	_check(reloaded.is_unlocked("level-003"), "the unlock chain round-trips through the file")
	store.free()
	reloaded.free()
	_clean_save_test_files(path)


func _test_settings_clamping() -> void:
	_check(is_equal_approx(float(SettingsModelClass.clamp_value("master_volume", 5.0)), 1.0), "a volume above the range clamps to 1.0")
	_check(is_equal_approx(float(SettingsModelClass.clamp_value("master_volume", -3.0)), 0.0), "a volume below the range clamps to 0.0")
	_check(is_equal_approx(float(SettingsModelClass.clamp_value("camera_sensitivity", 9.0)), 2.0), "camera sensitivity clamps at its maximum")
	_check(is_equal_approx(float(SettingsModelClass.clamp_value("camera_sensitivity", 0.1)), 0.5), "camera sensitivity clamps at its minimum")
	_check(str(SettingsModelClass.clamp_value("language", "fr")) == "en", "an unsupported language falls back to English")
	_check(str(SettingsModelClass.clamp_value("colorblind_mode", "rainbow")) == "off", "an unsupported colorblind mode falls back to off")
	_check(SettingsModelClass.clamp_value("reduce_motion", "yes") == false, "a non-bool reduce-motion value falls back to false")
	var sanitized := SettingsModelClass.sanitize(
		{"master_volume": "loud", "sfx_volume": 0.25, "fullscreen": true}
	)
	_check(is_equal_approx(float(sanitized.get("master_volume", 0.0)), 0.8), "sanitize replaces a wrong-type value with its default")
	_check(is_equal_approx(float(sanitized.get("sfx_volume", 0.0)), 0.25), "sanitize keeps a valid value")
	_check(SettingsModelClass.sanitize({}).size() == SettingsModelClass.SETTINGS_KEYS.size(), "sanitize returns every settings key")
	_check(SettingsModelClass.volume_to_db(0.5) < 0.0, "a half volume maps to a negative dB value")
	_check(SettingsModelClass.volume_to_db(1.0) == 0.0, "full volume maps to 0 dB")
	_check(
		SettingsModelClass.window_mode_for(true) == DisplayServer.WINDOW_MODE_FULLSCREEN,
		"the fullscreen setting maps to the fullscreen window mode"
	)
	_check(
		SettingsModelClass.window_mode_for(false) == DisplayServer.WINDOW_MODE_WINDOWED,
		"the windowed setting maps to the windowed mode"
	)


func _test_localization_tables() -> void:
	LocalizationClass.install()
	var en := LocalizationClass.load_dictionary("en")
	var zh := LocalizationClass.load_dictionary("zh")
	_check(en.size() >= LocalizationClass.REQUIRED_KEYS.size(), "the English table carries every required key")
	var missing := ""
	for key: String in LocalizationClass.REQUIRED_KEYS:
		if not en.has(key):
			missing = "en:" + key
		elif not zh.has(key):
			missing = "zh:" + key
	_check(missing == "", "both locale tables cover every required key (%s)" % missing)
	var partial := LocalizationClass.build_translation("zh", {"ui_menu_title": "标题"}, en)
	_check(str(partial.get_message("ui_menu_title")) == "标题", "a translated key reads from its own locale")
	_check(
		str(partial.get_message("ui_menu_play")) == str(en.get("ui_menu_play", "")),
		"a key missing from zh falls back to English"
	)
	var packed := load(MAIN_MENU_SCENE_PATH) as PackedScene
	_check(packed != null, "the main menu scene loads for the locale check")
	if packed == null:
		return
	var menu := packed.instantiate()
	LocalizationClass.set_locale("zh")
	menu.refresh_texts()
	var zh_texts: Array = menu.button_texts()
	_check(zh_texts[0] == zh.get("ui_menu_play", ""), "switching to zh updates the menu without a restart")
	LocalizationClass.set_locale("en")
	menu.refresh_texts()
	_check(menu.button_texts()[0] == "Play", "switching back to en updates the menu in place")
	menu.free()


func _test_level_select_progress_cards() -> void:
	var packed := load(LEVEL_SELECT_SCENE_PATH) as PackedScene
	_check(packed != null, "the level select scene loads for the progress check")
	if packed == null:
		return
	var screen := packed.instantiate()
	var entries: Array[Dictionary] = [
		{
			"index": 0,
			"name": "First Push",
			"par_moves": 6,
			"difficulty": 1,
			"completed": true,
			"unlocked": true,
			"stars": 2,
			"best_moves": 8,
			"best_time_ms": 12600,
		},
		{
			"index": 1,
			"name": "Turn the Corner",
			"par_moves": 14,
			"difficulty": 1,
			"completed": false,
			"unlocked": false,
			"stars": 0,
			"best_moves": 0,
			"best_time_ms": 0,
		},
	]
	screen.show_levels(entries)
	var grid := screen.get_node_or_null("Root/Content/Margin/Layout/Grid") as GridContainer
	_check(grid != null and grid.get_child_count() == 2, "the level select builds a card per entry")
	if grid == null or grid.get_child_count() != 2:
		screen.free()
		return
	var first := grid.get_child(0) as Button
	var second := grid.get_child(1) as Button
	var first_texts: Array[String] = []
	for label: Node in first.find_children("*", "Label", true, false):
		first_texts.append((label as Label).text)
	_check(first_texts.has("Stars: 2/3"), "a completed card shows its star count")
	_check(
		first_texts.has("Best: 8 moves · 0:12.6"),
		"a completed card shows its best moves and time"
	)
	_check(second.disabled, "a locked card is disabled")
	var second_texts: Array[String] = []
	for label: Node in second.find_children("*", "Label", true, false):
		second_texts.append((label as Label).text)
	_check(second_texts.has("Locked"), "a locked card says it is locked")
	_check(not second_texts.has("Turn the Corner"), "a locked card hides the level name")
	screen.free()


func _test_settings_screen() -> void:
	_check(ResourceLoader.exists(SETTINGS_SCENE_PATH), "the real settings screen scene exists")
	var packed := load(SETTINGS_SCENE_PATH) as PackedScene
	_check(packed != null, "the settings screen scene loads")
	if packed == null:
		return
	var screen := packed.instantiate()
	_check(screen is CanvasLayer, "the settings screen is a canvas layer")
	var values := SettingsModelClass.defaults()
	values["language"] = "zh"
	values["master_volume"] = 0.5
	screen.bind_values(values)
	LocalizationClass.set_locale("en")
	screen.refresh_texts()
	var title := screen.get_node_or_null("Root/Content/Margin/Layout/Title") as Label
	var rows := "Root/Content/Margin/Layout/Scroll/Rows"
	var slider := screen.get_node_or_null(rows + "/MasterRow/Slider") as HSlider
	var language_option := screen.get_node_or_null(rows + "/LanguageRow/Option") as OptionButton
	var colorblind_option := screen.get_node_or_null(rows + "/ColorblindRow/Option") as OptionButton
	var reduce_check := screen.get_node_or_null(rows + "/ReduceMotion") as CheckButton
	var fullscreen_check := screen.get_node_or_null(rows + "/Fullscreen") as CheckButton
	_check(
		title != null and slider != null and language_option != null and colorblind_option != null,
		"the settings screen carries its labels and controls"
	)
	if slider == null or language_option == null or title == null:
		screen.free()
		return
	_check(title.text == "Settings", "the settings title is translated")
	_check(is_equal_approx(slider.value, 50.0), "bind_values shows the stored master volume")
	_check(language_option.selected == 1, "bind_values shows the stored language")
	_check(screen.get_node_or_null(rows + "/ReduceMotion") is CheckButton, "the settings screen carries the reduce-motion toggle")
	_check(screen.get_node_or_null(rows + "/Fullscreen") is CheckButton, "the settings screen carries the fullscreen toggle")
	_check(reduce_check != null and fullscreen_check != null, "both toggles load")
	var emitted: Array = []
	screen.setting_changed.connect(
		func(key: String, value: Variant) -> void: emitted.append([key, value])
	)
	slider.value = 25.0
	slider.value_changed.emit(25.0)
	_check(emitted.size() == 1 and str(emitted[0][0]) == "master_volume", "moving a slider emits its setting key")
	_check(emitted.size() == 1 and is_equal_approx(float(emitted[0][1]), 0.25), "the volume slider emits a 0..1 value")
	language_option.item_selected.emit(0)
	_check(
		emitted.size() == 2 and str(emitted[1][0]) == "language" and str(emitted[1][1]) == "en",
		"choosing a language emits the language setting"
	)
	colorblind_option.item_selected.emit(1)
	_check(
		emitted.size() == 3 and str(emitted[2][1]) == "deuteranopia",
		"choosing a colorblind mode emits the mode setting"
	)
	if reduce_check != null:
		reduce_check.toggled.emit(true)
	_check(
		emitted.size() == 4 and str(emitted[3][0]) == "reduce_motion",
		"toggling reduce motion emits its setting"
	)
	if fullscreen_check != null:
		fullscreen_check.toggled.emit(true)
	_check(
		emitted.size() == 5 and str(emitted[4][0]) == "fullscreen",
		"toggling fullscreen emits its setting"
	)
	LocalizationClass.set_locale("zh")
	screen.refresh_texts()
	_check(title.text == "设置", "the settings title re-translates after a language switch")
	_check(
		(screen.get_node_or_null(rows + "/MasterRow/Label") as Label).text == "主音量",
		"a settings row re-translates after a language switch"
	)
	LocalizationClass.set_locale("en")
	screen.refresh_texts()
	screen.free()


func _test_colorblind_and_reduce_motion() -> void:
	var board := BoardBuilderClass.new()
	board.build(_make_level(BASIC_TILES))
	_check(board.colorblind_marker_count() >= 4, "the board builds colorblind shape markers")
	_check(not board.colorblind_markers_visible(), "the shape markers stay hidden while colorblind mode is off")
	board.set_colorblind_mode(true)
	_check(board.is_colorblind_mode(), "the board reports colorblind mode")
	_check(board.colorblind_markers_visible(), "every shape marker becomes visible in colorblind mode")
	_check(
		board.get_node_or_null("CbGoalMark_5_1_0") != null
		and (board.get_node_or_null("Crate_0") as Node).get_node_or_null("CbCrateMark_0") != null
		and (board.get_node_or_null("Player") as Node).get_node_or_null("CbPlayerMark") != null,
		"the goal, the crate and the player each carry a shape marker"
	)
	board.set_colorblind_mode(false)
	_check(not board.colorblind_markers_visible(), "turning the mode off hides the markers again")
	board.free()
	_check(is_equal_approx(CameraRigClass.tween_seconds(0.28, 1.0, false), 0.28), "camera sensitivity 1 keeps the base tween time")
	_check(is_equal_approx(CameraRigClass.tween_seconds(0.28, 2.0, false), 0.14), "camera sensitivity 2 halves the tween time")
	_check(CameraRigClass.tween_seconds(0.28, 1.0, true) == 0.0, "reduce motion makes a camera tween instant")
	var pair := _make_controller(_make_level(BASIC_TILES))
	var controller: GameplayControllerClass = pair[0]
	controller.animation_enabled = true
	controller.reduce_motion = false
	_check(controller.motion_enabled(), "a fresh controller allows animation")
	controller.reduce_motion = true
	_check(not controller.motion_enabled(), "reduce motion disables tile animation")
	controller.free()
	pair[1].free()


func _clean_save_test_files(path: String) -> void:
	for suffix: String in ["", ".tmp", ".bak"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(path + suffix)
	var prefix := path.get_base_dir() + "/" + path.get_file().get_basename()
	for file_name: String in DirAccess.get_files_at(path.get_base_dir()):
		if file_name.begins_with(prefix.get_file() + ".corrupt-"):
			DirAccess.remove_absolute(path.get_base_dir() + "/" + file_name)
		elif file_name.begins_with(prefix.get_file() + ".newer-"):
			DirAccess.remove_absolute(path.get_base_dir() + "/" + file_name)


func _write_test_text(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(text)
	file.close()


func _read_test_text(path: String) -> String:
	if not FileAccess.file_exists(path):
		return ""
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	var text := file.get_as_text()
	file.close()
	return text
