class_name LevelData
extends RefCounted

## One parsed, validated level, per design/level-format.md.
##
## Pure data: no file IO and no scene access. `from_json_text()` and
## `from_dictionary()` are called with file contents or test fixtures. They
## never raise on bad input: every failure is appended to `errors` as one
## sentence naming the field, and `is_valid()` is false so a caller can reject
## the level whole instead of half-loading it.

enum Cell { WALL, FLOOR, GOAL, VOID }

const MIN_COLUMNS := 5
const MAX_COLUMNS := 15
const MIN_ROWS := 5
const MAX_ROWS := 15
const MIN_BOXES := 1
const MAX_BOXES := 8
const MIN_DIFFICULTY := 1
const MAX_DIFFICULTY := 10
const MIN_PAR_MOVES := 1
const MAX_PAR_MOVES := 500
const MIN_PAR_PUSHES := 1
const MAX_NAME_CHARACTERS := 48
const MAX_AUTHOR_CHARACTERS := 64
const MAX_NOTES_CHARACTERS := 200
const ID_PREFIX := "level-"
const ID_LENGTH := 9
const DEFAULT_SCHEMA_VERSION := 1

## One character per cell, per design/level-format.md. `*` and `+` are a box
## and a player that start on a goal plate, so they also count as goals.
const LEGEND := {
	"#": Cell.WALL,
	"_": Cell.FLOOR,
	".": Cell.GOAL,
	"$": Cell.FLOOR,
	"*": Cell.GOAL,
	"@": Cell.FLOOR,
	"+": Cell.GOAL,
}

const BOX_CHARACTERS := ["$", "*"]
const PLAYER_CHARACTERS := ["@", "+"]
const GOAL_CHARACTERS := [".", "*", "+"]

const KNOWN_FIELDS := [
	"id",
	"name",
	"name_key",
	"author",
	"difficulty",
	"par_moves",
	"par_pushes",
	"columns",
	"rows",
	"tiles",
	"notes",
	"schema_version",
]

var id: String = ""
var name: String = ""
var name_key: String = ""
var author: String = ""
var difficulty: int = 0
var par_moves: int = 0
var par_pushes: int = 0
var columns: int = 0
var rows: int = 0
var tiles: Array[String] = []
var notes: String = ""
var schema_version: int = DEFAULT_SCHEMA_VERSION

var player_start: Vector2i = Vector2i(-1, -1)
var box_starts: Array[Vector2i] = []
var goals: Array[Vector2i] = []

## One sentence per validation failure; empty means the level is valid.
var errors: Array[String] = []

var _cells: Array[int] = []


## Parses level file text. `file_stem` is the file name without extension, so
## the loader can enforce `id` == file stem; leave it empty in fixtures.
static func from_json_text(text: String, file_stem: String = "") -> LevelData:
	var level := LevelData.new()
	var parser := JSON.new()
	if parser.parse(text) != OK:
		level._add_error(
			"file: invalid JSON at line %d: %s"
			% [parser.get_error_line(), parser.get_error_message()]
		)
		return level
	if not (parser.data is Dictionary):
		level._add_error("file: the top-level JSON value must be an object")
		return level
	level._parse(parser.data as Dictionary, file_stem)
	return level


## Parses an already-decoded level dictionary, for fixtures and the catalog.
static func from_dictionary(data: Dictionary, file_stem: String = "") -> LevelData:
	var level := LevelData.new()
	level._parse(data, file_stem)
	return level


func is_valid() -> bool:
	return errors.is_empty()


func error_summary() -> String:
	return "\n".join(errors)


## Cells copy of the starting boxes, so a session can reset without aliasing.
func initial_boxes() -> Array[Vector2i]:
	var copy: Array[Vector2i] = []
	copy.assign(box_starts)
	return copy


func is_inside(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.x < columns and cell.y >= 0 and cell.y < rows


## Cell type, with Cell.VOID for any coordinate outside the grid or a grid that
## could not be built because the file was invalid.
func cell_at(cell: Vector2i) -> int:
	if not is_inside(cell) or _cells.size() != columns * rows:
		return Cell.VOID
	return _cells[cell.y * columns + cell.x]


## Walls and out-of-grid coordinates are both unwalkable.
func is_wall(cell: Vector2i) -> bool:
	return not is_inside(cell) or cell_at(cell) == Cell.WALL


func is_goal(cell: Vector2i) -> bool:
	return is_inside(cell) and cell_at(cell) == Cell.GOAL


func _parse(data: Dictionary, file_stem: String) -> void:
	_warn_unknown_fields(data)
	id = _required_text(data, "id")
	name = _required_text(data, "name", MAX_NAME_CHARACTERS)
	name_key = _required_text(data, "name_key")
	author = _required_text(data, "author", MAX_AUTHOR_CHARACTERS)
	difficulty = _required_int(data, "difficulty")
	par_moves = _required_int(data, "par_moves")
	par_pushes = _required_int(data, "par_pushes")
	columns = _required_int(data, "columns")
	rows = _required_int(data, "rows")
	notes = _optional_text(data, "notes", MAX_NOTES_CHARACTERS)
	schema_version = _optional_int(data, "schema_version", DEFAULT_SCHEMA_VERSION)
	_validate_metadata(file_stem)
	_read_tiles(data)


func _validate_metadata(file_stem: String) -> void:
	if not id.is_empty():
		if not _is_level_id(id):
			_add_error("id: '%s' does not match the pattern level-NNN" % id)
		elif not file_stem.is_empty() and id != file_stem:
			_add_error("id: '%s' does not match the file stem '%s'" % [id, file_stem])
	if columns < MIN_COLUMNS or columns > MAX_COLUMNS:
		_add_error(
			"columns: %d is outside the allowed range %d..%d"
			% [columns, MIN_COLUMNS, MAX_COLUMNS]
		)
	if rows < MIN_ROWS or rows > MAX_ROWS:
		_add_error("rows: %d is outside the allowed range %d..%d" % [rows, MIN_ROWS, MAX_ROWS])
	if difficulty < MIN_DIFFICULTY or difficulty > MAX_DIFFICULTY:
		_add_error(
			"difficulty: %d is outside the allowed range %d..%d"
			% [difficulty, MIN_DIFFICULTY, MAX_DIFFICULTY]
		)
	if par_moves < MIN_PAR_MOVES or par_moves > MAX_PAR_MOVES:
		_add_error(
			"par_moves: %d is outside the allowed range %d..%d"
			% [par_moves, MIN_PAR_MOVES, MAX_PAR_MOVES]
		)
	if par_moves >= MIN_PAR_MOVES and (par_pushes < MIN_PAR_PUSHES or par_pushes > par_moves):
		_add_error(
			"par_pushes: %d must be between 1 and par_moves (%d)" % [par_pushes, par_moves]
		)


func _read_tiles(data: Dictionary) -> void:
	var raw: Variant = data.get("tiles")
	if not (raw is Array):
		_add_error("tiles: missing required array of strings")
		return
	var raw_tiles: Array = raw
	if raw_tiles.size() != rows:
		_add_error("tiles: expected %d rows, got %d" % [rows, raw_tiles.size()])
	var shape_ok: bool = (
		rows >= MIN_ROWS
		and rows <= MAX_ROWS
		and columns >= MIN_COLUMNS
		and columns <= MAX_COLUMNS
		and raw_tiles.size() == rows
	)
	var cells: Array[int] = []
	var counts := {"players": 0, "boxes": 0, "goals": 0}
	for row_index in raw_tiles.size():
		if not _read_tile_row(raw_tiles[row_index], row_index, cells, counts):
			shape_ok = false
	if shape_ok and cells.size() == columns * rows:
		_cells = cells
	_validate_entities(counts["players"], counts["boxes"], counts["goals"])
	_validate_border()
	_validate_not_solved()


## Reads one tile row, appending known cells and counting entities. Returns
## false when the row is not a string, has the wrong length or a bad character.
func _read_tile_row(
	value: Variant, row_index: int, cells: Array[int], counts: Dictionary
) -> bool:
	if not (value is String):
		_add_error("tiles[%d]: expected a string" % row_index)
		return false
	var row_text: String = value
	tiles.append(row_text)
	var row_ok := true
	if row_text.length() != columns:
		_add_error(
			"tiles[%d]: expected %d characters, got %d" % [row_index, columns, row_text.length()]
		)
		row_ok = false
	for column_index in row_text.length():
		var character := row_text[column_index]
		if not LEGEND.has(character):
			_add_error(
				"tiles[%d]: unknown cell character '%s' at column %d"
				% [row_index, character, column_index]
			)
			row_ok = false
			continue
		cells.append(LEGEND[character])
		_count_entity(character, Vector2i(column_index, row_index), counts)
	return row_ok


func _count_entity(character: String, position: Vector2i, counts: Dictionary) -> void:
	if character in PLAYER_CHARACTERS:
		counts["players"] += 1
		player_start = position
	if character in BOX_CHARACTERS:
		counts["boxes"] += 1
		box_starts.append(position)
	if character in GOAL_CHARACTERS:
		counts["goals"] += 1
		goals.append(position)


func _validate_entities(player_count: int, box_count: int, goal_count: int) -> void:
	if player_count != 1:
		_add_error("player: expected exactly one '@' or '+', found %d" % player_count)
	if box_count < MIN_BOXES or box_count > MAX_BOXES:
		_add_error("boxes: expected %d..%d, found %d" % [MIN_BOXES, MAX_BOXES, box_count])
	if box_count != goal_count:
		_add_error("goals: expected %d (one per box), found %d" % [box_count, goal_count])


func _validate_border() -> void:
	if _cells.is_empty():
		return
	for column_index in columns:
		_check_border_cell(Vector2i(column_index, 0), "top")
		_check_border_cell(Vector2i(column_index, rows - 1), "bottom")
	for row_index in range(1, rows - 1):
		_check_border_cell(Vector2i(0, row_index), "left")
		_check_border_cell(Vector2i(columns - 1, row_index), "right")


func _check_border_cell(cell: Vector2i, edge: String) -> void:
	if not is_wall(cell):
		_add_error(
			"tiles[%d]: the %s border must be a wall at column %d"
			% [cell.y, edge, cell.x]
		)


func _validate_not_solved() -> void:
	if _cells.is_empty() or box_starts.is_empty():
		return
	for box_cell in box_starts:
		if not is_goal(box_cell):
			return
	_add_error("boxes: the level is already solved at start")


func _is_level_id(value: String) -> bool:
	if value.length() != ID_LENGTH or not value.begins_with(ID_PREFIX):
		return false
	return value.substr(ID_PREFIX.length(), ID_LENGTH - ID_PREFIX.length()).is_valid_int()


func _warn_unknown_fields(data: Dictionary) -> void:
	for key in data:
		if not KNOWN_FIELDS.has(key):
			push_warning("level '%s': unknown field '%s' is ignored" % [str(data.get("id", "?")), key])


func _required_text(data: Dictionary, key: String, max_characters: int = 0) -> String:
	if not data.has(key):
		_add_error("field '%s': missing required string" % key)
		return ""
	return _read_text(data[key], key, max_characters)


func _optional_text(data: Dictionary, key: String, max_characters: int) -> String:
	if not data.has(key):
		return ""
	var value: Variant = data[key]
	if not (value is String):
		_add_error("field '%s': expected a string, got %s" % [key, type_string(typeof(value))])
		return ""
	var text: String = value
	if text.length() > max_characters:
		_add_error(
			"field '%s': %d characters exceeds the %d limit"
			% [key, text.length(), max_characters]
		)
	return text


func _read_text(value: Variant, key: String, max_characters: int) -> String:
	if not (value is String):
		_add_error("field '%s': expected a string, got %s" % [key, type_string(typeof(value))])
		return ""
	var text: String = value
	if text.is_empty():
		_add_error("field '%s': must not be empty" % key)
	elif max_characters > 0 and text.length() > max_characters:
		_add_error(
			"field '%s': %d characters exceeds the %d limit"
			% [key, text.length(), max_characters]
		)
	return text


func _required_int(data: Dictionary, key: String) -> int:
	if not data.has(key):
		_add_error("field '%s': missing required integer" % key)
		return 0
	return _read_int(data[key], key)


func _optional_int(data: Dictionary, key: String, fallback: int) -> int:
	if not data.has(key):
		return fallback
	return _read_int(data[key], key)


func _read_int(value: Variant, key: String) -> int:
	if value is int:
		return value
	if value is float and float(value) == floorf(float(value)):
		return int(value)
	_add_error("field '%s': expected an integer, got %s" % [key, type_string(typeof(value))])
	return 0


func _add_error(message: String) -> void:
	errors.append(message)
