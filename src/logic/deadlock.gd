class_name Deadlock
extends RefCounted

## Corner-deadlock predicate, per design/core-rules.md.
##
## A box is deadlocked when it is not on a goal, at least one of its two
## horizontal neighbours is a wall, and at least one of its two vertical
## neighbours is a wall: the box can never leave that corner again, and no
## push can put it on a plate. Out-of-grid coordinates count as walls.
## Boxes are not walls for this check in 1.0.

const LevelDataScript = preload("res://src/logic/level_data.gd")
const HORIZONTAL_OFFSETS := [Vector2i(-1, 0), Vector2i(1, 0)]
const VERTICAL_OFFSETS := [Vector2i(0, -1), Vector2i(0, 1)]


static func is_corner_deadlock(level: LevelDataScript, box_cell: Vector2i) -> bool:
	if level.is_goal(box_cell):
		return false
	if not _has_wall_neighbour(level, box_cell, HORIZONTAL_OFFSETS):
		return false
	return _has_wall_neighbour(level, box_cell, VERTICAL_OFFSETS)


static func _has_wall_neighbour(
	level: LevelDataScript, box_cell: Vector2i, offsets: Array
) -> bool:
	for offset in offsets:
		if level.is_wall(box_cell + offset):
			return true
	return false
