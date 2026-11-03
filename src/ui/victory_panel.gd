class_name VictoryPanel
extends CanvasLayer

## Result overlay from design/ui-flow.md "Victory": the stars, moves against
## par, pushes, elapsed time and the New best marker, with Retry, Next (disabled
## on the last level) and Level Select. Keyboard reachable, with Retry focused so
## the safe repeat action is one press away.
##
## The overlay owns no game state. `show_result()` receives the payload from the
## scene layer and the buttons emit intent signals; they never call gameplay
## methods directly (.dsh/rules/ui.md). Labels come from `tr()`;
## `refresh_texts()` re-renders the last result after a language switch.

signal retry_requested
signal next_requested
signal level_select_requested

const TITLE_KEY := "ui_victory_title"
const RETRY_KEY := "ui_victory_retry"
const NEXT_KEY := "ui_victory_next"
const LEVEL_SELECT_KEY := "ui_victory_level_select"
const MOVES_WITH_PAR_KEY := "ui_victory_moves_par"
const MOVES_KEY := "ui_victory_moves"
const PUSHES_KEY := "ui_victory_pushes"
const TIME_KEY := "ui_victory_time"
const STARS_KEY := "ui_victory_stars"
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
var _last_result: Dictionary = {}
var _last_has_next: bool = false
var _shown: bool = false
var _bound: bool = false


func _ready() -> void:
	_bind()
	hide_panel()


## Shows the overlay for one completed attempt. `has_next` is false on the last
## level, which disables the `Next` button.
func show_result(result: Dictionary, has_next: bool) -> void:
	_bind()
	_last_result = result.duplicate(true)
	_last_has_next = has_next
	_shown = true
	_render_result()
	visible = true
	if is_inside_tree():
		_retry.grab_focus()


func hide_panel() -> void:
	_bind()
	_shown = false
	visible = false


## How many of the three marks the overlay currently shows, for a headless
## assertion and for the evidence report.
func stars_shown() -> int:
	_bind()
	return _stars.stars if _stars != null else 0


func next_enabled() -> bool:
	_bind()
	return _next != null and not _next.disabled


## Re-reads every label from the active locale and re-renders the last result.
func refresh_texts() -> void:
	_bind()
	if not _bound:
		return
	_title.text = tr(TITLE_KEY)
	_retry.text = tr(RETRY_KEY)
	_next.text = tr(NEXT_KEY)
	_level_select.text = tr(LEVEL_SELECT_KEY)
	if _shown:
		_render_result()


## `m:ss.t` with a tenth of a second, matching the 100 ms timer precision in
## design/core-rules.md `timer_precision_ms`. Delegates to the shared formatter
## so the HUD and the overlay never disagree.
static func format_elapsed_ms(milliseconds: int) -> String:
	return UiFormat.elapsed_ms(milliseconds)


func _render_result() -> void:
	if _moves_label == null or _retry == null or _next == null or _level_select == null:
		return
	var moves := int(_last_result.get("moves", 0))
	var par_moves := int(_last_result.get("par_moves", 0))
	var stars := StarRating.stars_for_moves(moves, par_moves)
	_stars.set_stars(stars)
	_stars_label.text = tr(STARS_KEY) % stars
	if par_moves > 0:
		_moves_label.text = tr(MOVES_WITH_PAR_KEY) % [moves, par_moves]
	else:
		_moves_label.text = tr(MOVES_KEY) % moves
	_pushes_label.text = tr(PUSHES_KEY) % int(_last_result.get("pushes", 0))
	_time_label.text = tr(TIME_KEY) % format_elapsed_ms(int(_last_result.get("elapsed_ms", 0)))
	_next.disabled = not _last_has_next


func _bind() -> void:
	Localization.install()
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
	_retry.custom_minimum_size = BUTTON_MIN_SIZE
	_next.custom_minimum_size = BUTTON_MIN_SIZE
	_level_select.custom_minimum_size = LEVEL_SELECT_MIN_SIZE
	var controls: Array[Control] = [_retry, _next, _level_select]
	UiFocus.wire_horizontal(controls)
	_retry.pressed.connect(_on_retry_pressed)
	_next.pressed.connect(_on_next_pressed)
	_level_select.pressed.connect(_on_level_select_pressed)
	refresh_texts()


func _on_retry_pressed() -> void:
	retry_requested.emit()


func _on_next_pressed() -> void:
	next_requested.emit()


func _on_level_select_pressed() -> void:
	level_select_requested.emit()
