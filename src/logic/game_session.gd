class_name GameSession
extends RefCounted

## One attempt at one level: move resolution, push, undo, restart, deadlock and
## the win condition, per design/core-rules.md.
##
## The session is pure state: it never reads Input, never touches a node and
## returns a typed result from `try_move()`. A rejected move emits
## `move_rejected` and leaves every position and counter untouched.

signal move_committed(direction: int, was_push: bool, box_index: int)
signal move_rejected(direction: int, reason: int)
signal undo_performed(moves_left: int)
signal deadlock_detected(box_cell: Vector2i)
signal level_completed(stats: Dictionary)

const LevelDataScript = preload("res://src/logic/level_data.gd")
const MoveRecordScript = preload("res://src/logic/move_record.gd")
const DeadlockScript = preload("res://src/logic/deadlock.gd")

enum Direction { UP, DOWN, LEFT, RIGHT }

enum MoveResult { MOVED, PUSHED, REJECTED_WALL, REJECTED_BOX, REJECTED_FINISHED }

## design/core-rules.md proposes an undo cap of 50 (range 10..100); issue #3
## requires at least 100 reachable steps, so the session defaults to the
## documented maximum and a caller may configure any other positive cap.
const DEFAULT_UNDO_LIMIT := 100
const MIN_UNDO_LIMIT := 1

const DIRECTION_OFFSETS := [
	Vector2i(0, -1),
	Vector2i(0, 1),
	Vector2i(-1, 0),
	Vector2i(1, 0),
]

var level: LevelDataScript
var undo_limit: int
var player: Vector2i = Vector2i.ZERO
var boxes: Array[Vector2i] = []
var moves: int = 0
var pushes: int = 0
var attempts: int = 0
var is_won: bool = false
var last_deadlock_cell: Vector2i = Vector2i(-1, -1)

var _history: Array[MoveRecordScript] = []


func _init(level_data: LevelDataScript, undo_limit_value: int = DEFAULT_UNDO_LIMIT) -> void:
	assert(level_data != null and level_data.is_valid(), "GameSession needs a valid level")
	level = level_data
	undo_limit = maxi(undo_limit_value, MIN_UNDO_LIMIT)
	_reset_board()


## Resolves one move request. The first matching case wins:
## 1. wall or outside the grid: rejected, no state change;
## 2. walkable with no box: the player steps;
## 3. a box and a walkable, empty cell beyond it: the box and player move;
## 4. a box with a wall or another box beyond it: rejected, no state change.
func try_move(direction: int) -> int:
	if is_won:
		return _reject(direction, MoveResult.REJECTED_FINISHED)
	if direction < 0 or direction >= DIRECTION_OFFSETS.size():
		return _reject(direction, MoveResult.REJECTED_WALL)
	var offset: Vector2i = DIRECTION_OFFSETS[direction]
	var target: Vector2i = player + offset
	if level.is_wall(target):
		return _reject(direction, MoveResult.REJECTED_WALL)
	var box_index: int = _box_index_at(target)
	if box_index == -1:
		_commit_step(direction, target)
		return MoveResult.MOVED
	var beyond: Vector2i = target + offset
	if level.is_wall(beyond) or _box_index_at(beyond) != -1:
		return _reject(direction, MoveResult.REJECTED_BOX)
	_commit_push(direction, box_index, target, beyond)
	return MoveResult.PUSHED


func undo() -> bool:
	if _history.is_empty():
		return false
	var record: MoveRecordScript = _history.pop_back()
	player = record.player_before
	boxes.assign(record.boxes_before)
	moves = record.moves_before
	pushes = record.pushes_before
	is_won = _all_goals_filled()
	last_deadlock_cell = Vector2i(-1, -1)
	undo_performed.emit(_history.size())
	return true


func restart() -> void:
	_reset_board()
	attempts += 1


func can_undo() -> bool:
	return not _history.is_empty()


func undo_depth() -> int:
	return _history.size()


## Goals that currently hold a box, for the HUD's `filled/total` counter.
func filled_goal_count() -> int:
	var filled := 0
	for goal_cell: Vector2i in level.goals:
		if _box_index_at(goal_cell) != -1:
			filled += 1
	return filled


func goal_count() -> int:
	return level.goals.size()


func _reset_board() -> void:
	player = level.player_start
	boxes = level.initial_boxes()
	moves = 0
	pushes = 0
	is_won = false
	last_deadlock_cell = Vector2i(-1, -1)
	_history.clear()


func _commit_step(direction: int, target: Vector2i) -> void:
	_record_history(direction, false, -1)
	player = target
	moves += 1
	move_committed.emit(direction, false, -1)


func _commit_push(
	direction: int, box_index: int, target: Vector2i, beyond: Vector2i
) -> void:
	_record_history(direction, true, box_index)
	player = target
	boxes[box_index] = beyond
	moves += 1
	pushes += 1
	move_committed.emit(direction, true, box_index)
	_check_deadlock(beyond)
	_check_win()


func _reject(direction: int, reason: int) -> int:
	move_rejected.emit(direction, reason)
	return reason


func _record_history(direction: int, was_push: bool, box_index: int) -> void:
	var record := MoveRecordScript.new(
		direction, was_push, box_index, player, _copy_boxes(), moves, pushes
	)
	_history.append(record)
	while _history.size() > undo_limit:
		_history.pop_front()


func _copy_boxes() -> Array[Vector2i]:
	var copy: Array[Vector2i] = []
	copy.assign(boxes)
	return copy


func _box_index_at(cell: Vector2i) -> int:
	for index in boxes.size():
		if boxes[index] == cell:
			return index
	return -1


func _check_deadlock(box_cell: Vector2i) -> void:
	if not DeadlockScript.is_corner_deadlock(level, box_cell):
		return
	last_deadlock_cell = box_cell
	deadlock_detected.emit(box_cell)


func _check_win() -> void:
	if not _all_goals_filled():
		return
	is_won = true
	level_completed.emit(_completion_stats())


func _all_goals_filled() -> bool:
	if level.goals.is_empty():
		return false
	return filled_goal_count() == goal_count()


func _completion_stats() -> Dictionary:
	return {
		"moves": moves,
		"pushes": pushes,
		"par_moves": level.par_moves,
		"par_pushes": level.par_pushes,
	}
