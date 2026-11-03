class_name VictoryPanel
extends CanvasLayer

## Centred result overlay shown after the last crate lands, per issue #11 and
## design/ui-flow.md "Victory": the moves, the pushes and the elapsed time plus
## a `Retry` and a `Next` button.
##
## The overlay owns no game state. `show_result()` receives the payload from the
## scene layer and the buttons emit intent signals; they never call gameplay
## methods directly (.dsh/rules/ui.md).
##
## Localization is out of scope for this story (issue #11), so the labels carry
## English literals until the localization story swaps them for `tr()` keys.

signal retry_requested
signal next_requested

## Overlay labels, created by the scene and filled by `show_result()`.
const TITLE_TEXT := "Level Complete"
const RETRY_TEXT := "Retry"
const NEXT_TEXT := "Next"

const MILLISECONDS_PER_SECOND := 1000
const MILLISECONDS_PER_TENTH := 100
const SECONDS_PER_MINUTE := 60

var _title: Label
var _moves_label: Label
var _pushes_label: Label
var _time_label: Label
var _retry: Button
var _next: Button
var _bound: bool = false


func _ready() -> void:
	_bind()
	hide_panel()


## Shows the overlay for one completed attempt. `has_next` is false on the last
## level, which disables the `Next` button.
func show_result(result: Dictionary, has_next: bool) -> void:
	_bind()
	if _moves_label == null or _pushes_label == null or _time_label == null:
		return
	if _retry == null or _next == null:
		return
	_moves_label.text = "Moves: %d" % int(result.get("moves", 0))
	_pushes_label.text = "Pushes: %d" % int(result.get("pushes", 0))
	_time_label.text = "Time: %s" % format_elapsed_ms(int(result.get("elapsed_ms", 0)))
	_next.disabled = not has_next
	visible = true
	if is_inside_tree():
		_retry.grab_focus()


func hide_panel() -> void:
	_bind()
	visible = false


## `m:ss.t` with a tenth of a second, matching the 100 ms timer precision in
## design/core-rules.md `timer_precision_ms`.
static func format_elapsed_ms(milliseconds: int) -> String:
	var safe_ms: int = maxi(milliseconds, 0)
	var total_seconds: int = safe_ms / MILLISECONDS_PER_SECOND
	var minutes: int = total_seconds / SECONDS_PER_MINUTE
	var seconds: int = total_seconds % SECONDS_PER_MINUTE
	var tenths: int = (safe_ms % MILLISECONDS_PER_SECOND) / MILLISECONDS_PER_TENTH
	return "%d:%02d.%d" % [minutes, seconds, tenths]


## Resolves the scene nodes once, whether or not the overlay is inside the tree
## yet, so a headless test can exercise the labels without a window.
func _bind() -> void:
	if _bound:
		return
	_bound = true
	_title = get_node_or_null("Center/Panel/Margin/Content/Title") as Label
	_moves_label = get_node_or_null("Center/Panel/Margin/Content/Moves") as Label
	_pushes_label = get_node_or_null("Center/Panel/Margin/Content/Pushes") as Label
	_time_label = get_node_or_null("Center/Panel/Margin/Content/Time") as Label
	_retry = get_node_or_null("Center/Panel/Margin/Content/Buttons/Retry") as Button
	_next = get_node_or_null("Center/Panel/Margin/Content/Buttons/Next") as Button
	if _retry == null or _next == null:
		push_error("victory_panel: the overlay buttons are missing")
		return
	_retry.text = RETRY_TEXT
	_next.text = NEXT_TEXT
	if _title != null:
		_title.text = TITLE_TEXT
	if _moves_label != null:
		_moves_label.text = "Moves: 0"
	if _pushes_label != null:
		_pushes_label.text = "Pushes: 0"
	if _time_label != null:
		_time_label.text = "Time: 0:00.0"
	_retry.pressed.connect(_on_retry_pressed)
	_next.pressed.connect(_on_next_pressed)
	_retry.focus_neighbor_right = _retry.get_path_to(_next)
	_next.focus_neighbor_left = _next.get_path_to(_retry)


func _on_retry_pressed() -> void:
	retry_requested.emit()


func _on_next_pressed() -> void:
	next_requested.emit()
