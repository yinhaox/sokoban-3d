class_name LevelSelect
extends CanvasLayer

## Level cards for the level files that exist, per design/ui-flow.md "Level
## Select". Every card is a button, so a level can be chosen with the keyboard
## or a gamepad; a card shows the number, the level name and its par, plus a
## completed marker for the levels finished in this session.
##
## Save data and locking are out of scope for this story: every listed level is
## selectable, as issue #13 allows for this shell.
##
## Localization is out of scope for this story, so labels are English literals in
## this script until the localization story swaps them for `tr()` keys.

signal level_selected(index: int)
signal back_requested

const TITLE_TEXT := "Select a Level"
const BACK_TEXT := "Back"
const CARD_TEXT := "Level %02d"
const PAR_TEXT := "Par %d · %s"
const COMPLETED_TEXT := "Completed"
const CARD_MIN_SIZE := Vector2(220, 140)
const CARD_COLUMNS := 4
const DIFFICULTY_LABELS := {
	1: "Beginner",
	2: "Beginner",
	3: "Easy",
	4: "Easy",
	5: "Medium",
	6: "Medium",
	7: "Hard",
	8: "Hard",
	9: "Expert",
	10: "Expert",
}

var _title: Label
var _grid: GridContainer
var _back: Button
var _cards: Array[Control] = []
var _bound: bool = false


func _ready() -> void:
	_bind()


## Rebuilds the grid from the level list. Each entry carries `index`, `name`,
## `par_moves`, `difficulty` and `completed`.
func show_levels(levels: Array[Dictionary]) -> void:
	_bind()
	if _grid == null:
		return
	_clear_cards()
	for entry: Dictionary in levels:
		var index := int(entry.get("index", 0))
		var card := _make_card(entry)
		card.pressed.connect(_on_card_pressed.bind(index))
		_grid.add_child(card)
		_cards.append(card)
	_wire_cards()
	if is_inside_tree() and not _cards.is_empty():
		_cards[0].grab_focus()


func focus_default() -> void:
	_bind()
	if is_inside_tree() and not _cards.is_empty():
		_cards[0].grab_focus()
	elif is_inside_tree() and _back != null:
		_back.grab_focus()


## Card count, for a headless assertion on the built grid.
func card_count() -> int:
	_bind()
	return _cards.size()


## Difficulty label for a level's 1-10 difficulty value, from
## design/level-progression.md "Stars and records".
static func difficulty_label(difficulty: int) -> String:
	return str(DIFFICULTY_LABELS.get(clampi(difficulty, 1, 10), "Beginner"))


func _clear_cards() -> void:
	for card: Control in _cards:
		if is_instance_valid(card):
			card.free()
	_cards.clear()


func _make_card(entry: Dictionary) -> Button:
	var index := int(entry.get("index", 0))
	var button := Button.new()
	button.custom_minimum_size = CARD_MIN_SIZE
	button.focus_mode = Control.FOCUS_ALL
	var margin := MarginContainer.new()
	margin.theme_type_variation = &"CardMargin"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(margin)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)
	column.add_child(_card_label(CARD_TEXT % (index + 1), &"HeadingLabel"))
	column.add_child(_card_label(str(entry.get("name", "")), &"Label"))
	var par_label := PAR_TEXT % [
		int(entry.get("par_moves", 0)), difficulty_label(int(entry.get("difficulty", 1)))
	]
	column.add_child(_card_label(par_label, &"MutedLabel"))
	if bool(entry.get("completed", false)):
		column.add_child(_card_label(COMPLETED_TEXT, &"MutedLabel"))
	return button


func _card_label(text: String, variation: StringName) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## Row-major focus order over the grid: left/right inside a row, up/down between
## rows, and the last row leads to the Back button.
func _wire_cards() -> void:
	if _cards.is_empty() or _back == null:
		return
	for index: int in _cards.size():
		var card: Control = _cards[index]
		var column := index % CARD_COLUMNS
		var left_index := index - 1 if column > 0 else index
		var right_index := index + 1 if column < CARD_COLUMNS - 1 and index + 1 < _cards.size() else index
		var up_index := index - CARD_COLUMNS if index - CARD_COLUMNS >= 0 else index
		card.focus_neighbor_left = card.get_path_to(_cards[left_index])
		card.focus_neighbor_right = card.get_path_to(_cards[right_index])
		card.focus_neighbor_top = card.get_path_to(_cards[up_index])
		var down_control: Control = _cards[index + CARD_COLUMNS] if index + CARD_COLUMNS < _cards.size() else _back
		card.focus_neighbor_bottom = card.get_path_to(down_control)
	_back.focus_neighbor_top = _back.get_path_to(_cards[_cards.size() - 1])
	_back.focus_neighbor_bottom = _back.get_path_to(_back)
	_back.focus_neighbor_left = _back.get_path_to(_back)
	_back.focus_neighbor_right = _back.get_path_to(_back)


func _bind() -> void:
	if _bound:
		return
	_bound = true
	var root := get_node_or_null("Root") as Control
	if root == null:
		push_error("level_select: the Root control is missing")
		return
	if root.theme == null:
		root.theme = UiTheme.build()
	_title = get_node_or_null("Root/Content/Margin/Layout/Title") as Label
	_grid = get_node_or_null("Root/Content/Margin/Layout/Grid") as GridContainer
	_back = get_node_or_null("Root/Content/Margin/Layout/Back") as Button
	if _title == null or _grid == null or _back == null:
		push_error("level_select: the title, grid or back button is missing")
		return
	_title.text = TITLE_TEXT
	_back.text = BACK_TEXT
	_back.custom_minimum_size = Vector2(200, UiTheme.MIN_TARGET_PX)
	_grid.columns = CARD_COLUMNS
	_back.pressed.connect(_on_back_pressed)


func _on_card_pressed(index: int) -> void:
	level_selected.emit(index)


func _on_back_pressed() -> void:
	back_requested.emit()
