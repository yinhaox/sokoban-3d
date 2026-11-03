class_name MoveRecord
extends RefCounted

## One accepted move and the state it replaced, per
## design/technical-architecture.md. A value object: GameSession builds it
## before mutating the board and undo restores every field from it.

var direction: int = 0
var was_push: bool = false
var box_index: int = -1
var player_before: Vector2i = Vector2i.ZERO
var boxes_before: Array[Vector2i] = []
var moves_before: int = 0
var pushes_before: int = 0


func _init(
	move_direction: int,
	move_was_push: bool,
	moved_box_index: int,
	player_cell: Vector2i,
	box_cells: Array[Vector2i],
	move_count: int,
	push_count: int
) -> void:
	direction = move_direction
	was_push = move_was_push
	box_index = moved_box_index
	player_before = player_cell
	boxes_before = box_cells
	moves_before = move_count
	pushes_before = push_count
