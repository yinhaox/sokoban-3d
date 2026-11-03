class_name Hud
extends CanvasLayer

## The in-level strip from design/ui-flow.md "Gameplay HUD": level name, moves,
## pushes, goal completion `x/y`, elapsed time, then Undo, Restart and Pause.
##
## The HUD owns no game state. The scene layer feeds it `attempt_changed`
## payloads from the gameplay controller and calls `set_elapsed_ms()` each frame
## while the timer runs; the buttons emit intent signals and never touch the
## session (.dsh/rules/ui.md).
##
## Labels reserve a fixed width and only rewrite their text, so a counter
## going from 9 to 10 does not reflow the strip and the numbers do not flicker.

signal undo_requested
signal restart_requested
signal pause_requested

const TEXT_MOVES := "Moves: %d"
const TEXT_PUSHES := "Pushes: %d"
const TEXT_GOALS := "Goals: %d/%d"
const TEXT_TIME := "Time: %s"
const TEXT_UNDO := "Undo"
const TEXT_RESTART := "Restart"
const TEXT_PAUSE := "Pause"
const TEXT_LEVEL := "Level %d: %s"

var _level_label: Label
var _moves_label: Label
var _pushes_label: Label
var _goals_label: Label
var _time_label: Label
var _undo: Button
var _restart: Button
var _pause: Button
var _bound: bool = false


func _ready() -> void:
	_bind()
	set_attempt_stats({})


## Names the level in the strip, e.g. `Level 1: First Push`.
func set_level(level_number: int, level_name: String) -> void:
	_bind()
	if _level_label == null:
		return
	_level_label.text = TEXT_LEVEL % [level_number, level_name]


## Rewrites the counters from one gameplay payload. Missing keys read as zero,
## so the strip is valid before the first level is loaded.
func set_attempt_stats(stats: Dictionary) -> void:
	_bind()
	if _moves_label == null:
		return
	_moves_label.text = TEXT_MOVES % int(stats.get("moves", 0))
	_pushes_label.text = TEXT_PUSHES % int(stats.get("pushes", 0))
	_goals_label.text = TEXT_GOALS % [
		int(stats.get("goals_filled", 0)), int(stats.get("goals_total", 0))
	]
	_undo.disabled = not bool(stats.get("can_undo", false))
	set_elapsed_ms(int(stats.get("elapsed_ms", 0)))


func set_elapsed_ms(milliseconds: int) -> void:
	_bind()
	if _time_label == null:
		return
	_time_label.text = TEXT_TIME % UiFormat.elapsed_ms(milliseconds)


func _bind() -> void:
	if _bound:
		return
	_bound = true
	_level_label = get_node_or_null("Strip/Margin/Row/LevelLabel") as Label
	_moves_label = get_node_or_null("Strip/Margin/Row/MovesLabel") as Label
	_pushes_label = get_node_or_null("Strip/Margin/Row/PushesLabel") as Label
	_goals_label = get_node_or_null("Strip/Margin/Row/GoalsLabel") as Label
	_time_label = get_node_or_null("Strip/Margin/Row/TimeLabel") as Label
	_undo = get_node_or_null("Strip/Margin/Row/Undo") as Button
	_restart = get_node_or_null("Strip/Margin/Row/Restart") as Button
	_pause = get_node_or_null("Strip/Margin/Row/Pause") as Button
	if _moves_label == null or _undo == null:
		push_error("hud: the HUD strip is missing its labels or buttons")
		return
	_undo.text = TEXT_UNDO
	_restart.text = TEXT_RESTART
	_pause.text = TEXT_PAUSE
	_undo.pressed.connect(_on_undo_pressed)
	_restart.pressed.connect(_on_restart_pressed)
	_pause.pressed.connect(_on_pause_pressed)
	var actions: Array[Control] = [_undo, _restart, _pause]
	for index: int in actions.size():
		var control := actions[index]
		var previous := actions[posmod(index - 1, actions.size())]
		var next := actions[(index + 1) % actions.size()]
		control.focus_neighbor_left = control.get_path_to(previous)
		control.focus_neighbor_right = control.get_path_to(next)


func _on_undo_pressed() -> void:
	undo_requested.emit()


func _on_restart_pressed() -> void:
	restart_requested.emit()


func _on_pause_pressed() -> void:
	pause_requested.emit()
