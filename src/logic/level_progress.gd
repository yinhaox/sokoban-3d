class_name LevelProgress
extends RefCounted

## Which level `Play` should open, per design/ui-flow.md "Main Menu": Continue
## loads the lowest-numbered unlocked, uncompleted level, and the last level when
## every level is complete.
##
## Save data is out of scope for this story, so the caller passes the levels it
## knows and the ones completed in this session. The rule is pure and testable
## headless; the save story replaces the caller, not this class.

const NO_LEVEL := -1


## Index of the first level path that is not in `completed`, or the last level
## when every one is complete. An empty list has no level to open.
static func next_level_index(paths: Array[String], completed: Dictionary) -> int:
	if paths.is_empty():
		return NO_LEVEL
	for index: int in paths.size():
		if not completed.has(paths[index]):
			return index
	return paths.size() - 1
