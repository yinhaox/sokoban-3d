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
## Every label is read through `tr()`; `refresh_texts()` re-renders the last
## payload after a language switch.

signal undo_requested
signal restart_requested
signal pause_requested

const MOVES_KEY := "ui_hud_moves"
const PUSHES_KEY := "ui_hud_pushes"
const GOALS_KEY := "ui_hud_goals"
const TIME_KEY := "ui_hud_time"
const LEVEL_KEY := "ui_hud_level"
const UNDO_KEY := "ui_hud_undo"
const RESTART_KEY := "ui_hud_restart"
const PAUSE_KEY := "ui_hud_pause"

var _level_label: Label
var _moves_label: Label
var _pushes_label: Label
var _goals_label: Label
var _time_label: Label
var _undo: Button
var _restart: Button
var _pause: Button
var _level_number: int = 0
var _level_name: String = ""
var _stats: Dictionary = {}
var _elapsed_ms: int = 0
var _bound: bool = false


func _ready() -> void:
	_bind()
	_render_stats()


## Names the level in the strip, e.g. `Level 1: First Push`.
func set_level(level_number: int, level_name: String) -> void:
	_bind()
	_level_number = level_number
	_level_name = level_name
	_render_level()


## Rewrites the counters from one gameplay payload. Missing keys read as zero,
## so the strip is valid before the first level is loaded.
func set_attempt_stats(stats: Dictionary) -> void:
	_bind()
	_stats = stats.duplicate()
	_render_stats()


func set_elapsed_ms(milliseconds: int) -> void:
	_bind()
	_elapsed_ms = milliseconds
	_render_time()


## Re-reads every label from the active locale and re-renders the last payload.
func refresh_texts() -> void:
	_bind()
	if not _bound:
		return
	_undo.text = tr(UNDO_KEY)
	_restart.text = tr(RESTART_KEY)
	_pause.text = tr(PAUSE_KEY)
	_render_level()
	_render_stats()


func _render_level() -> void:
	if _level_label == null:
		return
	_level_label.text = tr(LEVEL_KEY) % [_level_number, _level_name]


func _render_stats() -> void:
	if _moves_label == null:
		return
	_moves_label.text = tr(MOVES_KEY) % int(_stats.get("moves", 0))
	_pushes_label.text = tr(PUSHES_KEY) % int(_stats.get("pushes", 0))
	_goals_label.text = tr(GOALS_KEY) % [
		int(_stats.get("goals_filled", 0)), int(_stats.get("goals_total", 0))
	]
	_undo.disabled = not bool(_stats.get("can_undo", false))
	set_elapsed_ms(int(_stats.get("elapsed_ms", _elapsed_ms)))


func _render_time() -> void:
	if _time_label == null:
		return
	_time_label.text = tr(TIME_KEY) % UiFormat.elapsed_ms(_elapsed_ms)


func _bind() -> void:
	Localization.install()
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
	refresh_texts()
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
