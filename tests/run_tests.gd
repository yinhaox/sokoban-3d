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


func _init() -> void:
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
