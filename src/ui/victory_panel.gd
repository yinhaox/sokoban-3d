class_name VictoryPanel
extends CanvasLayer

## Result overlay from design/ui-flow.md "Victory": the stars, moves against
## par, pushes, elapsed time and the New best marker, with Retry, Next (hidden /
## disabled on the last level) and Level Select. Keyboard reachable, with Retry
## focused so the safe repeat action is one press away.
##
## The overlay owns no game state. `show_result()` receives the payload from the
## scene layer and the buttons emit intent signals; they never call gameplay
## methods directly (.dsh/rules/ui.md).
##
## Localization is out of scope for this story (issue #11 and #13), so the labels
## carry English literals until the localization story swaps them for `tr()`.

signal retry_requested
signal next_requested
signal level_select_requested

const TITLE_TEXT := "Level Complete"
const RETRY_TEXT := "Retry"
const NEXT_TEXT := "Next"
const LEVEL_SELECT_TEXT := "Level Select"
const MOVES_WITH_PAR_FORMAT := "Moves: %d (par %d)"
const MOVES_FORMAT := "Moves: %d"
const PUSHES_FORMAT := "Pushes: %d"
const TIME_FORMAT := "Time: %s"
const STARS_FORMAT := "%d of 3 stars"
const BUTTON_MIN_SIZE := Vector2(130, UiTheme.MIN_TARGET_PX)
const LEVEL_SELECT_MIN_SIZE := Vector2(160, UiTheme.MIN_TARGET_PX)

var _root: Control
var _title: Label
var _stars: StarRow
var _stars_label: Label
var _moves_label: Label
var _pushes_label: Label
var _time_label: Label
var _retry: Button
var _next: Button
var _level_select: Button
var _bound: bool = false


func _ready() -> void:
	_bind()
	hide_panel()


## Shows the overlay for one completed attempt. `has_next` is false on the last
## level, which disables the `Next` button.
func show_result(result: Dictionary, has_next: bool) -> void:
	_bind()
	if _moves_label == null or _retry == null or _next == null or _level_select == null:
		return
	var moves := int(result.get("moves", 0))
	var par_moves := int(result.get("par_moves", 0))
	var stars := StarRating.stars_for_moves(moves, par_moves)
	_stars.set_stars(stars)
	_stars_label.text = STARS_FORMAT % stars
	if par_moves > 0:
		_moves_label.text = MOVES_WITH_PAR_FORMAT % [moves, par_moves]
	else:
		_moves_label.text = MOVES_FORMAT % moves
	_pushes_label.text = PUSHES_FORMAT % int(result.get("pushes", 0))
	_time_label.text = TIME_FORMAT % format_elapsed_ms(int(result.get("elapsed_ms", 0)))
	_next.disabled = not has_next
	visible = true
	if is_inside_tree():
		_retry.grab_focus()


func hide_panel() -> void:
	_bind()
	visible = false


## How many of the three marks the overlay currently shows, for a headless
## assertion and for the evidence report.
func stars_shown() -> int:
	_bind()
	return _stars.stars if _stars != null else 0


func next_enabled() -> bool:
	_bind()
	return _next != null and not _next.disabled


## `m:ss.t` with a tenth of a second, matching the 100 ms timer precision in
## design/core-rules.md `timer_precision_ms`. Delegates to the shared formatter
## so the HUD and the overlay never disagree.
static func format_elapsed_ms(milliseconds: int) -> String:
	return UiFormat.elapsed_ms(milliseconds)


func _bind() -> void:
	if _bound:
		return
	_bound = true
	_root = get_node_or_null("Root") as Control
	if _root == null:
		push_error("victory_panel: the Root control is missing")
		return
	if _root.theme == null:
		_root.theme = UiTheme.build()
	_title = get_node_or_null("Root/Center/Panel/Content/Title") as Label
	_stars = get_node_or_null("Root/Center/Panel/Content/Stars") as StarRow
	_stars_label = get_node_or_null("Root/Center/Panel/Content/StarsLabel") as Label
	_moves_label = get_node_or_null("Root/Center/Panel/Content/Moves") as Label
	_pushes_label = get_node_or_null("Root/Center/Panel/Content/Pushes") as Label
	_time_label = get_node_or_null("Root/Center/Panel/Content/Time") as Label
	_retry = get_node_or_null("Root/Center/Panel/Content/Buttons/Retry") as Button
	_next = get_node_or_null("Root/Center/Panel/Content/Buttons/Next") as Button
	_level_select = get_node_or_null("Root/Center/Panel/Content/Buttons/LevelSelect") as Button
	if _retry == null or _next == null or _level_select == null:
		push_error("victory_panel: the overlay buttons are missing")
		return
	if _title != null:
		_title.text = TITLE_TEXT
	_retry.text = RETRY_TEXT
	_next.text = NEXT_TEXT
	_level_select.text = LEVEL_SELECT_TEXT
	_retry.custom_minimum_size = BUTTON_MIN_SIZE
	_next.custom_minimum_size = BUTTON_MIN_SIZE
	_level_select.custom_minimum_size = LEVEL_SELECT_MIN_SIZE
	var controls: Array[Control] = [_retry, _next, _level_select]
	UiFocus.wire_horizontal(controls)
	_retry.pressed.connect(_on_retry_pressed)
	_next.pressed.connect(_on_next_pressed)
	_level_select.pressed.connect(_on_level_select_pressed)


func _on_retry_pressed() -> void:
	retry_requested.emit()


func _on_next_pressed() -> void:
	next_requested.emit()


func _on_level_select_pressed() -> void:
	level_select_requested.emit()
