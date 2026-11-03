class_name LevelSequence
extends RefCounted

## Ordered list of the level files in `assets/data/levels/`, so the scene layer
## knows whether a level has a next one and the victory overlay can disable its
## `Next` button on the last level.
##
## Reading the filesystem is scene-layer work; the logic layer stays pure
## (design/technical-architecture.md).

const LEVEL_DIRECTORY := "res://assets/data/levels"
const LEVEL_EXTENSION := "json"


## Every level file path, sorted by file name so level-002 follows level-001.
static func level_paths(directory: String = LEVEL_DIRECTORY) -> Array[String]:
	var paths: Array[String] = []
	var files := DirAccess.open(directory)
	if files == null:
		push_warning("level_sequence: cannot open the level directory: %s" % directory)
		return paths
	for file_name: String in files.get_files():
		if file_name.get_extension() == LEVEL_EXTENSION:
			paths.append("%s/%s" % [directory, file_name])
	paths.sort()
	return paths


## Index of `path` in `paths`, or -1 when it is not listed.
static func index_of(paths: Array[String], path: String) -> int:
	for index: int in paths.size():
		if paths[index] == path:
			return index
	return -1


static func has_next(paths: Array[String], index: int) -> bool:
	return index >= 0 and index + 1 < paths.size()


## The next level path, or an empty string on the last level.
static func next_path(paths: Array[String], index: int) -> String:
	if not has_next(paths, index):
		return ""
	return paths[index + 1]
