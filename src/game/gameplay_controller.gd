class_name GameplayController
extends Node3D

## Drives one playable attempt: forwards direction, undo and restart input into
## `GameSession`, animates the player and crate pieces on the board and reports
## the completion payload that the scene layer shows in the victory overlay.
##
## Rules stay in the logic layer. This node only decides presentation timing and
## input mapping:
## - move 0.13 s and push 0.16 s tiles, bump 0.06 s, from
##   design/core-rules.md `move_seconds`, `push_seconds`, `bump_seconds`;
## - one step per key-down, then repeat after 0.30 s every 0.10 s, from
##   design/input-and-controls.md `move_repeat_*`;
## - `Q`/`E` are not movement keys, so the camera rig keeps them untouched.

signal victory(stats: Dictionary, has_next: bool)

const LevelDataScript = preload("res://src/logic/level_data.gd")
const GameSessionScript = preload("res://src/logic/game_session.gd")
const BoardBuilderScript = preload("res://src/game/board_builder.gd")
const CameraRigScript = preload("res://src/game/camera_rig.gd")

## Returned by `request_move()` when the request was dropped because a tile
## tween is still running; no session call was made.
const MOVE_IGNORED := -1

## design/core-rules.md `win_delay_seconds`.
const WIN_DELAY_SECONDS := 0.4

## Share of `bump_seconds` spent moving out of the blocked cell; the remainder
## brings the piece back.
const BUMP_OUT_RATIO := 0.4

@export var move_seconds: float = 0.13
@export var push_seconds: float = 0.16
@export var bump_seconds: float = 0.06
@export var bump_distance: float = 0.08
@export var win_delay_seconds: float = WIN_DELAY_SECONDS
@export var repeat_delay_seconds: float = 0.30
@export var repeat_interval_seconds: float = 0.10
@export var undo_repeat_interval_seconds: float = 0.08
@export var animation_enabled: bool = true

## The attempt being played. Read-only for callers; the controller is the only
## owner of the session and applies every mutation through its own methods.
var session: GameSessionScript

var _level: LevelDataScript
var _board: BoardBuilderScript
var _camera_rig: CameraRigScript
var _has_next_level: bool = false

var _busy: bool = false
var _tween: Tween
var _elapsed_ms: float = 0.0
var _timer_running: bool = false
var _held_direction: int = -1
var _repeat_elapsed: float = 0.0
var _undo_repeat: bool = false
var _undo_repeat_elapsed: float = 0.0
var _victory_payload: Dictionary = {}
var _victory_scheduled: bool = false


## Starts a fresh attempt on the level already built into `board`. Called again
## for every level change, including the next level of the list.
func setup(
	level: LevelDataScript,
	board: BoardBuilderScript,
	camera_rig: CameraRigScript,
	has_next_level: bool
) -> void:
	_level = level
	_board = board
	_camera_rig = camera_rig
	_has_next_level = has_next_level
	_kill_tween()
	session = GameSessionScript.new(level)
	session.move_committed.connect(_on_move_committed)
	session.move_rejected.connect(_on_move_rejected)
	session.level_completed.connect(_on_level_completed)
	_elapsed_ms = 0.0
	_timer_running = false
	_held_direction = -1
	_repeat_elapsed = 0.0
	_undo_repeat = false
	_undo_repeat_elapsed = 0.0
	_victory_payload.clear()
	_victory_scheduled = false
	_sync_from_session()


## Resolves one direction request. While a tile tween runs the request is
## ignored (issue #11) and `MOVE_IGNORED` is returned; after the win the session
## itself rejects the move with `REJECTED_FINISHED`.
func request_move(direction: int) -> int:
	if session == null or direction < 0:
		return MOVE_IGNORED
	if session.is_won:
		return GameSessionScript.MoveResult.REJECTED_FINISHED
	if _busy:
		return MOVE_IGNORED
	_busy = true
	return session.try_move(direction)


## Undoes one accepted move instantly. A running move tween is cancelled and the
## board lands on the pre-move state, so nothing flickers.
func undo() -> bool:
	if session == null or session.is_won:
		return false
	_kill_tween()
	if not session.undo():
		return false
	_sync_from_session()
	return true


## Restarts the level instantly and resets the attempt counters.
func restart_level() -> void:
	if session == null:
		return
	_kill_tween()
	session.restart()
	_elapsed_ms = 0.0
	_timer_running = false
	_held_direction = -1
	_repeat_elapsed = 0.0
	_undo_repeat = false
	_undo_repeat_elapsed = 0.0
	_victory_payload.clear()
	_victory_scheduled = false
	_sync_from_session()


func elapsed_ms() -> int:
	return int(_elapsed_ms)


func is_busy() -> bool:
	return _busy


## Feeds a comma-separated direction list through the normal move path. Used by
## the capture aid so a screenshot shows a state the game really reached, not a
## hand-placed pose. Returns false when an entry is not a direction or is
## rejected, and reports why.
func apply_move_script(script_text: String) -> bool:
	var tokens := script_text.split(",", false)
	if tokens.is_empty():
		return false
	var applied := true
	for token: String in tokens:
		var direction := direction_for_name(token)
		if direction < 0:
			push_warning("gameplay: capture script entry '%s' is not a direction" % token)
			applied = false
			continue
		var result := request_move(direction)
		if result == MOVE_IGNORED or result >= GameSessionScript.MoveResult.REJECTED_WALL:
			push_warning(
				"gameplay: capture script entry '%s' was rejected (result %d)" % [token, result]
			)
			applied = false
	return applied


## Direction a physical key requests, or MOVE_IGNORED for every other key. The
## camera keys Q/E deliberately do not appear here.
static func direction_for_key(keycode: int) -> int:
	match keycode:
		KEY_UP, KEY_W:
			return GameSessionScript.Direction.UP
		KEY_DOWN, KEY_S:
			return GameSessionScript.Direction.DOWN
		KEY_LEFT, KEY_A:
			return GameSessionScript.Direction.LEFT
		KEY_RIGHT, KEY_D:
			return GameSessionScript.Direction.RIGHT
	return MOVE_IGNORED


## Direction named in a capture script, or MOVE_IGNORED for an unknown word.
static func direction_for_name(direction_name: String) -> int:
	match direction_name.strip_edges().to_lower():
		"up":
			return GameSessionScript.Direction.UP
		"down":
			return GameSessionScript.Direction.DOWN
		"left":
			return GameSessionScript.Direction.LEFT
		"right":
			return GameSessionScript.Direction.RIGHT
	return MOVE_IGNORED


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if key.echo:
		return
	if key.pressed:
		_on_key_pressed(key)
	else:
		_on_key_released(key)


func _process(delta: float) -> void:
	if session == null:
		return
	if _timer_running and not session.is_won:
		_elapsed_ms += delta * 1000.0
	_tick_held_direction(delta)
	_tick_undo_repeat(delta)


func _on_key_pressed(event: InputEventKey) -> void:
	if session == null or session.is_won:
		return
	var keycode := int(event.physical_keycode)
	if keycode == KEY_R:
		restart_level()
		return
	if keycode == KEY_Z:
		_undo_repeat = event.ctrl_pressed
		_undo_repeat_elapsed = 0.0
		undo()
		return
	var direction := direction_for_key(keycode)
	if direction < 0:
		return
	_held_direction = direction
	_repeat_elapsed = 0.0
	request_move(direction)


func _on_key_released(event: InputEventKey) -> void:
	var keycode := int(event.physical_keycode)
	if keycode == KEY_Z:
		_undo_repeat = false
		return
	if direction_for_key(keycode) == _held_direction:
		_held_direction = -1
		_repeat_elapsed = 0.0


## Holding a direction steps once on key-down and then repeats after
## `repeat_delay_seconds`, every `repeat_interval_seconds`, once the previous
## tile tween has finished.
func _tick_held_direction(delta: float) -> void:
	if _held_direction < 0 or session.is_won:
		return
	_repeat_elapsed += delta
	if _busy or _repeat_elapsed < repeat_delay_seconds:
		return
	_repeat_elapsed = maxf(repeat_delay_seconds - repeat_interval_seconds, 0.0)
	request_move(_held_direction)


## Holding Ctrl+Z keeps undoing until the history is empty or the key is
## released; a plain Z undoes exactly one step per press.
func _tick_undo_repeat(delta: float) -> void:
	if not _undo_repeat or _busy or not session.can_undo():
		_undo_repeat_elapsed = 0.0
		return
	_undo_repeat_elapsed += delta
	if _undo_repeat_elapsed < undo_repeat_interval_seconds:
		return
	_undo_repeat_elapsed = 0.0
	undo()


func _on_move_committed(_direction: int, was_push: bool, box_index: int) -> void:
	if session == null:
		return
	if not _timer_running:
		_timer_running = true
	_board.set_player_cell(session.player)
	if was_push and box_index >= 0 and box_index < session.boxes.size():
		var box_cell: Vector2i = session.boxes[box_index]
		_board.set_crate_cell(box_index, box_cell)
		var crate_target := _board.crate_world_position(box_cell, _level.is_goal(box_cell))
		_animate_push(box_index, _board.player_world_position(session.player), crate_target)
		return
	_animate_step(_board.player_world_position(session.player))


func _on_move_rejected(_direction: int, reason: int) -> void:
	if session == null:
		return
	if reason == GameSessionScript.MoveResult.REJECTED_FINISHED:
		_busy = false
		return
	_animate_bump(_direction)


func _on_level_completed(stats: Dictionary) -> void:
	_timer_running = false
	_victory_payload = {
		"moves": int(stats.get("moves", 0)),
		"pushes": int(stats.get("pushes", 0)),
		"elapsed_ms": int(_elapsed_ms),
		"par_moves": int(stats.get("par_moves", 0)),
	}
	if _busy:
		return
	_schedule_victory()


func _animate_step(target: Vector3) -> void:
	var player := _board.player_node()
	if player == null:
		_finish_animation()
		return
	if not _can_animate():
		player.position = target
		_finish_animation()
		return
	_tween = create_tween()
	_tween.tween_property(player, "position", target, move_seconds).set_trans(
		Tween.TRANS_SINE
	).set_ease(Tween.EASE_OUT)
	_tween.finished.connect(_finish_animation)


func _animate_push(box_index: int, player_target: Vector3, crate_target: Vector3) -> void:
	var player := _board.player_node()
	var crate := _board.crate_node(box_index)
	if player == null or crate == null:
		_finish_animation()
		return
	if not _can_animate():
		player.position = player_target
		crate.position = crate_target
		_finish_animation()
		return
	_tween = create_tween().set_parallel(true)
	_tween.tween_property(player, "position", player_target, push_seconds).set_trans(
		Tween.TRANS_SINE
	).set_ease(Tween.EASE_OUT)
	_tween.tween_property(crate, "position", crate_target, push_seconds).set_trans(
		Tween.TRANS_SINE
	).set_ease(Tween.EASE_OUT)
	_tween.finished.connect(_finish_animation)


## Rejected moves nudge the player towards the blocked cell and back, so the
## player sees why nothing happened while the state stays untouched.
func _animate_bump(direction: int) -> void:
	var player := _board.player_node()
	if player == null:
		_finish_animation()
		return
	var offset: Vector2i = GameSessionScript.DIRECTION_OFFSETS[direction]
	var base := _board.player_world_position(session.player)
	var nudge := Vector3(float(offset.x), 0.0, float(offset.y)) * bump_distance
	if not _can_animate():
		player.position = base
		_finish_animation()
		return
	_tween = create_tween()
	_tween.tween_property(
		player, "position", base + nudge, bump_seconds * BUMP_OUT_RATIO
	).set_trans(Tween.TRANS_SINE)
	_tween.tween_property(
		player, "position", base, bump_seconds * (1.0 - BUMP_OUT_RATIO)
	).set_trans(Tween.TRANS_SINE)
	_tween.finished.connect(_finish_animation)


func _finish_animation() -> void:
	_tween = null
	_busy = false
	_refresh_feedback()
	if _camera_rig != null:
		_camera_rig.update_occlusion()
	if not _victory_payload.is_empty():
		_schedule_victory()


func _sync_from_session() -> void:
	_board.sync_actors(session.player, session.boxes)
	_refresh_feedback()
	if _camera_rig != null:
		_camera_rig.update_occlusion()


func _refresh_feedback() -> void:
	_board.refresh_goal_fills(session.boxes)
	for index: int in session.boxes.size():
		_board.set_crate_on_goal(index, _level.is_goal(session.boxes[index]))


func _schedule_victory() -> void:
	if _victory_scheduled or _victory_payload.is_empty():
		return
	_victory_scheduled = true
	if win_delay_seconds > 0.0 and animation_enabled and is_inside_tree():
		var timer: SceneTreeTimer = get_tree().create_timer(win_delay_seconds)
		timer.timeout.connect(_emit_victory)
		return
	_emit_victory()


func _emit_victory() -> void:
	if _victory_payload.is_empty():
		return
	var payload: Dictionary = _victory_payload.duplicate()
	_victory_payload.clear()
	victory.emit(payload, _has_next_level)


func _kill_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = null
	_busy = false


func _can_animate() -> bool:
	return animation_enabled and is_inside_tree()
