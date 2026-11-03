class_name LevelSelect
extends CanvasLayer

## Level cards for the level files that exist, per design/ui-flow.md "Level
## Select". Every selectable card is a button, so a level can be chosen with the
## keyboard or a gamepad.
##
## A card shows the number, the level name and its par when unlocked; a locked
## card shows only its number and a `Locked` label and cannot be focused. A
## completed card shows its stars and best record. Labels come from `tr()`;
## `refresh_texts()` rebuilds the grid after a language switch.

signal level_selected(index: int)
signal back_requested

const TITLE_KEY := "ui_level_select_title"
const BACK_KEY := "ui_common_back"
const CARD_NUMBER_KEY := "ui_level_card_number"
const PAR_KEY := "ui_level_par"
const BEST_KEY := "ui_level_best"
const STARS_KEY := "ui_level_stars"
const LOCKED_KEY := "ui_common_locked"
const COMPLETED_KEY := "ui_common_completed"
const DIFFICULTY_KEYS := {
	1: "ui_difficulty_beginner",
	2: "ui_difficulty_beginner",
	3: "ui_difficulty_easy",
	4: "ui_difficulty_easy",
	5: "ui_difficulty_medium",
	6: "ui_difficulty_medium",
	7: "ui_difficulty_hard",
	8: "ui_difficulty_hard",
	9: "ui_difficulty_expert",
	10: "ui_difficulty_expert",
}
const CARD_MIN_SIZE := Vector2(220, 190)
const CARD_COLUMNS := 4

const StarRowScript = preload("res://src/ui/star_row.gd")

var _title: Label
var _grid: GridContainer
var _back: Button
var _cards: Array[Control] = []
var _entries: Array[Dictionary] = []
var _bound: bool = false


func _ready() -> void:
	_bind()


## Rebuilds the grid from the level list. Each entry carries `index`, `name`,
## `par_moves`, `difficulty`, `completed`, `unlocked`, `stars`, `best_moves` and
## `best_time_ms`; the save fields default to an unlocked, never-played level so
## an older caller still works.
func show_levels(levels: Array[Dictionary]) -> void:
	_bind()
	_entries = levels.duplicate(true)
	_render_cards()


func focus_default() -> void:
	_bind()
	if not is_inside_tree():
		return
	for card: Control in _cards:
		var button := card as Button
		if button != null and not button.disabled:
			button.grab_focus()
			return
	if _back != null:
		_back.grab_focus()


## Card count, for a headless assertion on the built grid.
func card_count() -> int:
	_bind()
	return _cards.size()


## Difficulty label for a level's 1-10 difficulty value, from
## design/level-progression.md "Stars and records".
static func difficulty_label(difficulty: int) -> String:
	Localization.install()
	var key := str(DIFFICULTY_KEYS.get(clampi(difficulty, 1, 10), "ui_difficulty_beginner"))
	return TranslationServer.translate(key)


func refresh_texts() -> void:
	_bind()
	if not _bound:
		return
	_title.text = tr(TITLE_KEY)
	_back.text = tr(BACK_KEY)
	_render_cards()


func _render_cards() -> void:
	if _grid == null:
		return
	_clear_cards()
	for entry: Dictionary in _entries:
		var card := _make_card(entry)
		_grid.add_child(card)
		_cards.append(card)
	_wire_cards()
	if is_inside_tree() and not _cards.is_empty():
		for card: Control in _cards:
			var button := card as Button
			if button != null and not button.disabled:
				button.grab_focus()
				return


func _clear_cards() -> void:
	for card: Control in _cards:
		if is_instance_valid(card):
			card.free()
	_cards.clear()


func _make_card(entry: Dictionary) -> Button:
	var index := int(entry.get("index", 0))
	var unlocked := bool(entry.get("unlocked", true))
	var button := Button.new()
	button.custom_minimum_size = CARD_MIN_SIZE
	button.focus_mode = Control.FOCUS_ALL if unlocked else Control.FOCUS_NONE
	button.disabled = not unlocked
	var margin := MarginContainer.new()
	margin.theme_type_variation = &"CardMargin"
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(margin)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)
	column.add_child(_card_label(tr(CARD_NUMBER_KEY) % (index + 1), &"HeadingLabel"))
	if not unlocked:
		column.add_child(_card_label(tr(LOCKED_KEY), &"MutedLabel"))
		return button
	column.add_child(_card_label(str(entry.get("name", "")), &"Label"))
	var par_label := tr(PAR_KEY) % [
		int(entry.get("par_moves", 0)), difficulty_label(int(entry.get("difficulty", 1)))
	]
	column.add_child(_card_label(par_label, &"MutedLabel"))
	var stars := clampi(int(entry.get("stars", 0)), 0, 3)
	var star_row := StarRowScript.new()
	star_row.stars = stars
	star_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	star_row.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	column.add_child(star_row)
	column.add_child(_card_label(tr(STARS_KEY) % stars, &"MutedLabel"))
	var best_moves := int(entry.get("best_moves", 0))
	if best_moves > 0:
		column.add_child(
			_card_label(
				tr(BEST_KEY) % [best_moves, UiFormat.elapsed_ms(int(entry.get("best_time_ms", 0)))],
				&"MutedLabel"
			)
		)
	elif bool(entry.get("completed", false)):
		column.add_child(_card_label(tr(COMPLETED_KEY), &"MutedLabel"))
	button.pressed.connect(_on_card_pressed.bind(index))
	return button


func _card_label(text: String, variation: StringName) -> Label:
	var label := Label.new()
	label.text = text
	label.theme_type_variation = variation
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## Row-major focus order over the enabled cards: left/right inside a row, up/down
## between rows, and the last row leads to the Back button. A locked card is
## skipped because it cannot take focus.
func _wire_cards() -> void:
	if _back == null:
		return
	var focusable: Array[Control] = []
	for card: Control in _cards:
		var button := card as Button
		if button != null and not button.disabled:
			focusable.append(card)
	if focusable.is_empty():
		_back.focus_neighbor_top = _back.get_path_to(_back)
		_back.focus_neighbor_bottom = _back.get_path_to(_back)
		_back.focus_neighbor_left = _back.get_path_to(_back)
		_back.focus_neighbor_right = _back.get_path_to(_back)
		return
	for index: int in focusable.size():
		var card: Control = focusable[index]
		var column := index % CARD_COLUMNS
		var left_index := index - 1 if column > 0 else index
		var right_index := index + 1 if column < CARD_COLUMNS - 1 and index + 1 < focusable.size() else index
		var up_index := index - CARD_COLUMNS if index - CARD_COLUMNS >= 0 else index
		card.focus_neighbor_left = card.get_path_to(focusable[left_index])
		card.focus_neighbor_right = card.get_path_to(focusable[right_index])
		card.focus_neighbor_top = card.get_path_to(focusable[up_index])
		var down_control: Control = (
			focusable[index + CARD_COLUMNS] if index + CARD_COLUMNS < focusable.size() else _back
		)
		card.focus_neighbor_bottom = card.get_path_to(down_control)
	_back.focus_neighbor_top = _back.get_path_to(focusable[focusable.size() - 1])
	_back.focus_neighbor_bottom = _back.get_path_to(_back)
	_back.focus_neighbor_left = _back.get_path_to(_back)
	_back.focus_neighbor_right = _back.get_path_to(_back)


func _bind() -> void:
	Localization.install()
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
	_back.custom_minimum_size = Vector2(200, UiTheme.MIN_TARGET_PX)
	_grid.columns = CARD_COLUMNS
	_back.pressed.connect(_on_back_pressed)
	refresh_texts()


func _on_card_pressed(index: int) -> void:
	level_selected.emit(index)


func _on_back_pressed() -> void:
	back_requested.emit()
