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
	_test_main_helpers()
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


func _test_main_helpers() -> void:
	_check(MAIN_SCRIPT.title_text() == "Game Studio", "main.title_text() returns the studio title")
	_check(MAIN_SCRIPT.status_text(0) == "Game Studio (0 frames)", "main.status_text(0) formats zero frames")
	_check(MAIN_SCRIPT.status_text(7) == "Game Studio (7 frames)", "main.status_text(7) formats seven frames")
	_check(MAIN_SCRIPT.status_text(-3) == "Game Studio (0 frames)", "main.status_text() clamps negative frames")


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
	_check(root is Node2D, "main scene root is a Node2D")
	_check(str(root.name) == "Main", "main scene root is named Main")

	var attached := root.get_script() as Script
	_check(attached != null and attached.resource_path == "res://src/main.gd", "main scene root runs src/main.gd")

	var label := root.get_node_or_null("Title") as Label
	_check(label != null, "main scene has a Title label")
	if label != null:
		_check(label.text == "Game Studio", "Title label reads Game Studio")
	root.free()


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
