class_name SaveStore
extends Node

## The versioned profile at `user://save.json`, per issue #16 and
## design/settings-and-save.md "Save file".
##
## One file holds the schema version, the unlocked level ids, a per-level record
## of best moves/pushes/time/stars and the settings. Writes are atomic: the data
## goes to `<path>.tmp`, the previous file rotates to `<path>.bak`, and the temp
## file is renamed into place, so a kill during a write leaves one readable file.
##
## A file that fails JSON, size or shape checks is copied to
## `<name>.corrupt-<unix>.json`, the game continues with a fresh profile and the
## backup path is reported. A file from a newer schema version is copied to
## `<name>.newer-<unix>.json`, the store becomes read-only and a fresh profile is
## used in memory; the newer file is never overwritten.

signal settings_changed(key: String, value: Variant)
signal profile_changed
signal save_failed

const CURRENT_VERSION := 1
const DEFAULT_PATH := "user://save.json"
const SAVE_DEBOUNCE_SECONDS := 0.5
const SAVE_MAX_BYTES := 65536
const TEMP_SUFFIX := ".tmp"
const BACKUP_SUFFIX := ".bak"
const CORRUPT_TAG := ".corrupt-"
const NEWER_TAG := ".newer-"
const JSON_INDENT := "  "

## Status values `load_profile()` reports.
const STATUS_OK := "ok"
const STATUS_NEW := "new"
const STATUS_RECOVERED := "recovered"
const STATUS_MIGRATED := "migrated"
const STATUS_CORRUPT := "corrupt"
const STATUS_NEWER := "newer"

const NOTICE_CORRUPT := "ui_notice_corrupt"
const NOTICE_NEWER := "ui_notice_newer"
const NOTICE_SAVE_FAILED := "ui_notice_save_failed"

const FIRST_LEVEL_ID := "level-001"

var path: String = DEFAULT_PATH
var status: String = STATUS_NEW
var notice_key: String = ""
var notice_arg: String = ""
var read_only: bool = false
var last_backup_path: String = ""

var _data: Dictionary = {}
var _debounce_timer: SceneTreeTimer
var _save_generation: int = 0


## Points the store at another file, for a test or a capture run.
func configure(new_path: String) -> void:
	path = new_path if not new_path.strip_edges().is_empty() else DEFAULT_PATH


## Reads and validates the profile. Always leaves `data()` usable: a new, a
## damaged or a newer file starts from defaults and reports why.
func load_profile() -> Dictionary:
	_reset()
	var source_path := _readable_path()
	if source_path.is_empty():
		_data = _fresh_data()
		status = STATUS_NEW
		if source_path != path:
			push_warning("save: no profile at %s; starting fresh" % path)
		return load_summary()
	var text := _read_text(source_path)
	if text.is_empty() and not FileAccess.file_exists(source_path):
		_data = _fresh_data()
		status = STATUS_NEW
		return load_summary()
	var json := JSON.new()
	if json.parse(text) != OK:
		return _recover_corrupt(source_path, "invalid JSON at line %d" % json.get_error_line())
	var parsed: Variant = json.data
	if not (parsed is Dictionary):
		return _recover_corrupt(source_path, "not a JSON object")
	if not _version_is_readable(parsed as Dictionary):
		return _recover_corrupt(source_path, "version is missing or not a number")
	var version := int((parsed as Dictionary).get("version", 0))
	if version > CURRENT_VERSION:
		return _recover_newer(source_path, version)
	if version < CURRENT_VERSION:
		var migrated := _migrate(version, parsed as Dictionary)
		if migrated.is_empty():
			return _recover_corrupt(source_path, "no migration path from version %d" % version)
		_data = _normalize(migrated)
		status = STATUS_MIGRATED
		save_now()
		return load_summary()
	_data = _normalize(parsed as Dictionary)
	status = STATUS_RECOVERED if source_path != path else STATUS_OK
	if source_path != path:
		push_warning("save: adopted the readable profile from %s" % source_path)
		save_now()
	return load_summary()


## The whole profile dictionary. Callers treat it as read-only; use the methods
## below to change it, so a change is validated and saved.
func data() -> Dictionary:
	return _data


func load_summary() -> Dictionary:
	return {
		"status": status,
		"notice_key": notice_key,
		"notice_arg": notice_arg,
		"read_only": read_only,
	}


func settings() -> Dictionary:
	return (_data.get("settings", SettingsModel.defaults()) as Dictionary).duplicate(true)


## Applies one setting through the model's clamping and persists it after the
## debounce. Returns the value that was actually stored.
func set_setting(key: String, value: Variant) -> Variant:
	if not SettingsModel.SETTINGS_KEYS.has(key):
		push_warning("save: unknown setting '%s'" % key)
		return null
	var clamped: Variant = SettingsModel.clamp_value(key, value)
	var current := settings()
	current[key] = clamped
	_data["settings"] = current
	settings_changed.emit(key, clamped)
	request_save()
	return clamped


func is_unlocked(level_id: String) -> bool:
	var unlocked: Array = _data.get("unlocked", [])
	return unlocked.has(level_id)


## Makes a level id selectable, keeping the first level reachable on a fresh
## profile or after a level rename.
func ensure_unlocked(level_id: String) -> bool:
	if level_id.is_empty() or is_unlocked(level_id):
		return false
	var unlocked: Array = _data.get("unlocked", [])
	unlocked.append(level_id)
	_data["unlocked"] = unlocked
	request_save()
	return true


func is_completed(level_id: String) -> bool:
	return bool(record_for(level_id).get("completed", false))


## Best record for one level id, or an empty dictionary when it was never played.
func record_for(level_id: String) -> Dictionary:
	var levels: Dictionary = _data.get("levels", {})
	var record: Variant = levels.get(level_id, {})
	return (record as Dictionary).duplicate(true) if record is Dictionary else {}


## The level id `Play` should open: the lowest unlocked, uncompleted level in
## `ordered_ids`, else the last level. `ordered_ids` is the build's level list.
func next_unfinished(ordered_ids: Array[String]) -> String:
	if ordered_ids.is_empty():
		return ""
	for level_id: String in ordered_ids:
		if is_unlocked(level_id) and not is_completed(level_id):
			return level_id
	return ordered_ids[ordered_ids.size() - 1]


## Records one completion, merging records instead of replacing them: best moves
## (with the pushes and time of that run) only improve, and stars only rise.
## Unlocks the following level id in `ordered_ids`. Returns what changed.
func complete_level(level_id: String, ordered_ids: Array[String], result: Dictionary) -> Dictionary:
	if level_id.is_empty():
		return {}
	ensure_unlocked(level_id)
	var old := record_for(level_id)
	var moves := maxi(int(result.get("moves", 0)), 0)
	var pushes := maxi(int(result.get("pushes", 0)), 0)
	var elapsed_ms := maxi(int(result.get("elapsed_ms", 0)), 0)
	var stars := clampi(int(result.get("stars", 0)), 0, 3)
	var has_best := old.has("best_moves")
	var better := (
		not has_best
		or moves < int(old.get("best_moves", moves))
		or (moves == int(old.get("best_moves", moves)) and elapsed_ms < int(old.get("best_time_ms", elapsed_ms)))
	)
	var record := old
	record["completed"] = true
	record["stars"] = maxi(int(old.get("stars", 0)), stars)
	if better:
		record["best_moves"] = moves
		record["best_pushes"] = pushes
		record["best_time_ms"] = elapsed_ms
	var levels: Dictionary = _data.get("levels", {})
	levels[level_id] = record
	_data["levels"] = levels
	var unlocked_id := _unlock_next(level_id, ordered_ids)
	request_save()
	return {"record": record.duplicate(true), "new_best": better, "unlocked": unlocked_id}


## Writes the profile immediately, atomically. Returns false and reports when the
## write failed or the store is read-only.
func save_now() -> bool:
	if read_only:
		push_warning("save: profile is from a newer version; refusing to overwrite %s" % path)
		save_failed.emit()
		return false
	var base_dir := path.get_base_dir()
	if not base_dir.is_empty() and not DirAccess.dir_exists_absolute(base_dir):
		DirAccess.make_dir_recursive_absolute(base_dir)
	var temp_path := path + TEMP_SUFFIX
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		push_warning("save: cannot write %s" % temp_path)
		save_failed.emit()
		return false
	file.store_string(JSON.stringify(_data, JSON_INDENT, false, true))
	file.flush()
	file.close()
	if not _rotate_into_place(temp_path):
		push_warning("save: cannot move %s into place" % temp_path)
		save_failed.emit()
		return false
	status = STATUS_OK if status == STATUS_NEW else status
	profile_changed.emit()
	return true


## Cancels a pending debounced write and writes now. Called on level completion
## and on application quit.
func flush() -> bool:
	_save_generation += 1
	return save_now()


## Schedules one write after the debounce, keeping only the newest request.
func request_save() -> void:
	if read_only:
		return
	_save_generation += 1
	if not is_inside_tree() or get_tree() == null:
		return
	var generation := _save_generation
	_debounce_timer = get_tree().create_timer(SAVE_DEBOUNCE_SECONDS)
	_debounce_timer.timeout.connect(_on_debounce_timeout.bind(generation))


## Removes the profile, its temp file and its backup, for a capture run that must
## boot on a fresh profile. Never touches the corrupt/newer backups.
func erase_profile_files() -> void:
	for candidate: String in [path, path + TEMP_SUFFIX, path + BACKUP_SUFFIX]:
		if FileAccess.file_exists(candidate):
			DirAccess.remove_absolute(candidate)


func _on_debounce_timeout(generation: int) -> void:
	if generation == _save_generation:
		save_now()


func _reset() -> void:
	_data = _fresh_data()
	status = STATUS_NEW
	notice_key = ""
	notice_arg = ""
	read_only = false
	last_backup_path = ""


func _fresh_data() -> Dictionary:
	return {
		"version": CURRENT_VERSION,
		"unlocked": [],
		"levels": {},
		"settings": SettingsModel.defaults(),
		"stats": {"total_moves": 0, "total_plays": 0},
	}


## The profile path when it exists, else the newest readable sibling of the
## profile (backup first, then temp), per design/settings-and-save.md.
func _readable_path() -> String:
	if FileAccess.file_exists(path):
		return path
	for candidate: String in [path + BACKUP_SUFFIX, path + TEMP_SUFFIX]:
		if FileAccess.file_exists(candidate):
			return candidate
	return ""


func _read_text(source_path: String) -> String:
	var file := FileAccess.open(source_path, FileAccess.READ)
	if file == null:
		push_warning("save: cannot read %s" % source_path)
		return ""
	if file.get_length() > SAVE_MAX_BYTES:
		file.close()
		push_warning("save: %s is larger than %d bytes" % [source_path, SAVE_MAX_BYTES])
		return ""
	var text := file.get_as_text()
	file.close()
	return text


func _version_is_readable(parsed: Dictionary) -> bool:
	if not parsed.has("version"):
		return true
	var version: Variant = parsed["version"]
	return version is int or version is float


## Chain of schema migrations. Each step takes the previous dictionary and
## returns the next version; `load_profile()` runs every step up to
## `CURRENT_VERSION`. A missing step is reported as corruption, never guessed.
func _migrate(version: int, parsed: Dictionary) -> Dictionary:
	var current := parsed.duplicate(true)
	var step_version := version
	while step_version < CURRENT_VERSION:
		match step_version:
			0:
				current = _migrate_v0_to_v1(current)
			_:
				push_warning("save: no migration from version %d" % step_version)
				return {}
		step_version += 1
	current["version"] = CURRENT_VERSION
	return current


## Version 0 is a pre-schema profile: it may carry partial keys. Fill every
## missing section so v1 validation can run on it.
static func _migrate_v0_to_v1(legacy: Dictionary) -> Dictionary:
	var migrated := legacy.duplicate(true)
	migrated["version"] = 1
	if not (migrated.get("levels") is Dictionary):
		migrated["levels"] = {}
	if not (migrated.get("unlocked") is Array):
		migrated["unlocked"] = []
	if not (migrated.get("settings") is Dictionary):
		migrated["settings"] = {}
	if not (migrated.get("stats") is Dictionary):
		migrated["stats"] = {}
	return migrated


## Validates and fills one profile dictionary. Missing sections take their
## default; a wrong type is replaced with the default and logged.
func _normalize(parsed: Dictionary) -> Dictionary:
	var result := _fresh_data()
	var unlocked: Variant = parsed.get("unlocked")
	if unlocked is Array:
		var ids: Array = []
		for value: Variant in unlocked:
			if value is String and not ids.has(value):
				ids.append(value)
		result["unlocked"] = ids
	elif unlocked != null:
		push_warning("save: unlocked is not an array; starting with no unlock")
	var levels: Variant = parsed.get("levels")
	if levels is Dictionary:
		var records := {}
		for level_id: Variant in (levels as Dictionary).keys():
			var record: Variant = (levels as Dictionary)[level_id]
			if record is Dictionary:
				records[str(level_id)] = _normalize_record(record as Dictionary)
		result["levels"] = records
	elif levels != null:
		push_warning("save: levels is not an object; dropping its records")
	var settings: Variant = parsed.get("settings")
	if settings is Dictionary:
		result["settings"] = SettingsModel.sanitize(settings as Dictionary)
	elif settings != null:
		push_warning("save: settings is not an object; using defaults")
	return result


func _normalize_record(record: Dictionary) -> Dictionary:
	var normalized := record.duplicate(true)
	normalized["completed"] = bool(record.get("completed", false))
	normalized["stars"] = clampi(int(record.get("stars", 0)), 0, 3)
	normalized["best_moves"] = maxi(int(record.get("best_moves", 0)), 0)
	normalized["best_pushes"] = maxi(int(record.get("best_pushes", 0)), 0)
	normalized["best_time_ms"] = maxi(int(record.get("best_time_ms", 0)), 0)
	return normalized


func _unlock_next(level_id: String, ordered_ids: Array[String]) -> String:
	var index := ordered_ids.find(level_id)
	if index < 0 or index + 1 >= ordered_ids.size():
		return ""
	var next_id := ordered_ids[index + 1]
	if is_unlocked(next_id):
		return ""
	ensure_unlocked(next_id)
	return next_id


func _rotation_path(tag: String, _source_path: String) -> String:
	var stamp := int(Time.get_unix_time_from_system())
	var base := path.get_basename() + tag + str(stamp)
	var candidate := base + ".json"
	var counter := 1
	while FileAccess.file_exists(candidate):
		candidate = base + "-" + str(counter) + ".json"
		counter += 1
	return candidate


func _recover_corrupt(source_path: String, reason: String) -> Dictionary:
	push_warning("save: %s is corrupt (%s); backing it up" % [source_path, reason])
	last_backup_path = _rotation_path(CORRUPT_TAG, source_path)
	var copied := DirAccess.copy_absolute(source_path, last_backup_path) == OK
	if not copied:
		push_warning("save: could not back up %s" % source_path)
	_data = _fresh_data()
	status = STATUS_CORRUPT
	notice_key = NOTICE_CORRUPT
	notice_arg = last_backup_path.get_file()
	save_now()
	return load_summary()


func _recover_newer(source_path: String, version: int) -> Dictionary:
	push_warning("save: profile version %d is newer than %d; starting fresh" % [version, CURRENT_VERSION])
	last_backup_path = _rotation_path(NEWER_TAG, source_path)
	var copied := DirAccess.copy_absolute(source_path, last_backup_path) == OK
	if not copied:
		push_warning("save: could not copy the newer profile")
	_data = _fresh_data()
	status = STATUS_NEWER
	read_only = true
	notice_key = NOTICE_NEWER
	notice_arg = last_backup_path.get_file()
	return load_summary()


## Temp -> current with the previous current kept as `.bak`. On a failed final
## rename the previous file is put back, so one readable profile always remains.
func _rotate_into_place(temp_path: String) -> bool:
	var backup_path := path + BACKUP_SUFFIX
	if FileAccess.file_exists(backup_path):
		DirAccess.remove_absolute(backup_path)
	if FileAccess.file_exists(path):
		if DirAccess.rename_absolute(path, backup_path) != OK:
			return false
	if DirAccess.rename_absolute(temp_path, path) == OK:
		return true
	if not FileAccess.file_exists(path) and FileAccess.file_exists(backup_path):
		DirAccess.rename_absolute(backup_path, path)
	return false
