class_name CameraRig
extends Node3D

## Isometric camera rig for the 3D room, per design/camera-and-presentation.md.
##
## The rig orbits the level centre on a fixed pitch. `Q` and `E` snap the yaw by
## a quarter turn, the mouse wheel changes the orthographic zoom inside its
## bounds, and `update_occlusion()` fades the walls between the camera and the
## player, a crate or a goal plate. The camera never free-orbits and the pitch is
## not player-adjustable in 1.0.

const LevelDataScript = preload("res://src/logic/level_data.gd")
const BoardBuilderScript = preload("res://src/game/board_builder.gd")

## design/camera-and-presentation.md allows a 30..55 degree pitch; 1.0 fixes 40.
const PITCH_MIN_DEGREES := 30.0
const PITCH_MAX_DEGREES := 55.0
const QUARTER_TURN_DEGREES := 90.0
## Sample spacing of the occlusion walk, as a fraction of one cell.
const OCCLUSION_SAMPLE_RATIO := 0.1
const OCCLUSION_MAX_SAMPLES := 4096
const MIN_SAMPLE_STEP := 0.001
## Inset of the sampled cell corners, as a fraction of one cell.
const CELL_FOOTPRINT_INSET_RATIO := 0.45
const MIN_ASPECT := 0.01

@export var base_yaw_degrees: float = 45.0
@export var pitch_degrees: float = 40.0
@export var rotate_seconds: float = 0.28
@export var zoom_seconds: float = 0.15
@export var zoom_min: float = 0.6
@export var zoom_max: float = 1.8
@export var zoom_step: float = 0.1
@export var fill_ratio: float = 0.8
@export var size_min: float = 6.0
@export var size_max: float = 18.0
@export var occlusion_alpha: float = 0.12
@export var occlusion_seconds: float = 0.12
@export var camera_distance: float = 20.0

var _level: LevelDataScript
var _board: BoardBuilderScript
var _quarter_turns: int = 0
var _zoom: float = 1.0
var _fitted_size: float = size_min
var _queued_turn: int = 0
var _rotate_tween: Tween
var _zoom_tween: Tween

@onready var _camera: Camera3D = $Camera3D as Camera3D


## Places the rig over the level and frames the room. Called once by the boot
## scene after the board has been built.
func setup(level: LevelDataScript, board: BoardBuilderScript) -> void:
	_level = level
	_board = board
	_quarter_turns = 0
	_zoom = 1.0
	position = BoardBuilderScript.level_centre(level)
	rotation = Vector3(0.0, deg_to_rad(_current_yaw()), 0.0)
	_fitted_size = _fit_size(_current_yaw())
	_camera.position = _camera_local_offset()
	_camera.rotation = Vector3(-deg_to_rad(clamp_pitch_degrees(pitch_degrees)), 0.0, 0.0)
	_camera.size = _fitted_size
	_camera.current = true
	update_occlusion()


## Fades every wall between the camera and the player or a crate, and restores
## the walls that no longer occlude. Recompute on load, rotation and zoom; it is
## not polled every frame.
func update_occlusion() -> void:
	if _level == null or _board == null:
		return
	var camera_ground := position + _offset_direction(_current_yaw()) * camera_distance
	var occluded := occluded_wall_cells(
		camera_ground,
		_occlusion_targets(),
		_board.wall_cells(),
		BoardBuilderScript.CELL_SIZE,
		_level.columns,
		_level.rows
	)
	_board.apply_wall_fade(occluded, occlusion_alpha, occlusion_seconds)


## Points that must stay visible: the centre and four inset corners of the
## player's cell, every crate's cell and every goal plate's cell, so a wall that
## clips any part of one of those footprints fades.
func _occlusion_targets() -> Array[Vector3]:
	var cells: Array[Vector2i] = [_board.player_cell]
	cells.append_array(_board.crate_cells())
	cells.append_array(_level.goals)
	var inset := BoardBuilderScript.CELL_SIZE * CELL_FOOTPRINT_INSET_RATIO
	var corners: Array[Vector2] = [
		Vector2(-inset, -inset),
		Vector2(inset, -inset),
		Vector2(-inset, inset),
		Vector2(inset, inset),
	]
	var points: Array[Vector3] = []
	for cell in cells:
		var centre := _board.cell_centre(cell)
		points.append(centre)
		for corner in corners:
			points.append(centre + Vector3(corner.x, 0.0, corner.y))
	return points


## Starts one quarter turn, or queues at most one further turn while the
## current rotation tween runs. A third request is dropped.
func rotate_quarter(direction: int) -> void:
	if direction == 0:
		return
	if _rotate_tween != null and _rotate_tween.is_running():
		if _queued_turn == 0:
			_queued_turn = signi(direction)
		return
	_start_rotation(direction)


## Moves the zoom multiplier by one step, clamped to the configured bounds.
func zoom_by(direction: int) -> void:
	if _level == null or direction == 0:
		return
	var target := apply_zoom_step(_zoom, direction, zoom_step, zoom_min, zoom_max)
	if is_equal_approx(target, _zoom):
		return
	_zoom = target
	if _zoom_tween != null and _zoom_tween.is_valid():
		_zoom_tween.kill()
	_zoom_tween = create_tween()
	_zoom_tween.tween_property(_camera, "size", _fitted_size * _zoom, zoom_seconds)
	_zoom_tween.finished.connect(update_occlusion)


## Absolute yaw of a quarter-turn state, wrapped into 0..360 degrees.
static func snap_yaw_degrees(base_degrees: float, quarter_turns: int) -> float:
	return fposmod(base_degrees + QUARTER_TURN_DEGREES * float(quarter_turns), 360.0)


## The pitch is fixed in 1.0; this clamps any value to the documented range.
static func clamp_pitch_degrees(degrees: float) -> float:
	return clampf(degrees, PITCH_MIN_DEGREES, PITCH_MAX_DEGREES)


## One zoom step as a multiplier of the fitted size, clamped to its bounds.
static func apply_zoom_step(
	current: float, direction: int, step: float, minimum: float, maximum: float
) -> float:
	return clampf(current + step * float(direction), minimum, maximum)


## Orthographic size that makes the room's projected bounds fill `fill_ratio` of
## the shorter viewport axis, then clamped to size_minimum..size_maximum.
static func fit_orthogonal_size(
	corners: Array[Vector3],
	yaw_degrees: float,
	pitch_degrees: float,
	aspect: float,
	fill_ratio_value: float,
	size_minimum: float,
	size_maximum: float
) -> float:
	if corners.is_empty():
		return size_minimum
	var yaw := deg_to_rad(yaw_degrees)
	var pitch := deg_to_rad(clamp_pitch_degrees(pitch_degrees))
	var offset := Vector3(sin(yaw), 0.0, cos(yaw))
	var forward := Vector3(
		-cos(pitch) * offset.x, -sin(pitch), -cos(pitch) * offset.z
	)
	var right := Vector3(cos(yaw), 0.0, -sin(yaw))
	var up := right.cross(forward)
	var min_right := INF
	var max_right := -INF
	var min_up := INF
	var max_up := -INF
	for corner in corners:
		var projected_right := corner.dot(right)
		var projected_up := corner.dot(up)
		min_right = minf(min_right, projected_right)
		max_right = maxf(max_right, projected_right)
		min_up = minf(min_up, projected_up)
		max_up = maxf(max_up, projected_up)
	var safe_aspect := maxf(aspect, MIN_ASPECT)
	var vertical_span := max_up - min_up
	var horizontal_span := max_right - min_right
	var fitted := maxf(vertical_span, horizontal_span / safe_aspect) / maxf(fill_ratio_value, MIN_ASPECT)
	return clampf(fitted, size_minimum, size_maximum)


## Grid cells crossed by the XZ projection of the segment from `from` to `to`,
## inside the grid only. A wall cell in this list sits between the camera and
## the target's footprint.
static func cells_on_segment(
	from: Vector3, to: Vector3, cell_size: float, columns: int, rows: int
) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	var seen := {}
	var step := maxf(cell_size * OCCLUSION_SAMPLE_RATIO, MIN_SAMPLE_STEP)
	var samples := clampi(int(ceil(from.distance_to(to) / step)) + 1, 2, OCCLUSION_MAX_SAMPLES)
	for index in samples:
		var point := from.lerp(to, float(index) / float(samples - 1))
		var cell := BoardBuilderScript.world_to_cell(point, columns, rows, cell_size)
		if cell.x < 0 or cell.y < 0 or cell.x >= columns or cell.y >= rows:
			continue
		if seen.has(cell):
			continue
		seen[cell] = true
		cells.append(cell)
	return cells


## Walls from `wall_cells` whose footprint lies between the camera ground
## position and any target point. Each wall appears once.
static func occluded_wall_cells(
	camera_ground: Vector3,
	targets: Array[Vector3],
	wall_cells: Array[Vector2i],
	cell_size: float,
	columns: int,
	rows: int
) -> Array[Vector2i]:
	var walls := {}
	for cell in wall_cells:
		walls[cell] = true
	var result: Array[Vector2i] = []
	var seen := {}
	for target in targets:
		for cell in cells_on_segment(camera_ground, target, cell_size, columns, rows):
			if not walls.has(cell) or seen.has(cell):
				continue
			seen[cell] = true
			result.append(cell)
	return result


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		_handle_key(event as InputEventKey)
	elif event is InputEventMouseButton:
		_handle_mouse_button(event as InputEventMouseButton)


func _handle_key(event: InputEventKey) -> void:
	if not event.pressed or event.echo:
		return
	if event.physical_keycode == KEY_Q:
		rotate_quarter(-1)
	elif event.physical_keycode == KEY_E:
		rotate_quarter(1)


func _handle_mouse_button(event: InputEventMouseButton) -> void:
	if not event.pressed:
		return
	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		zoom_by(-1)
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		zoom_by(1)


func _start_rotation(direction: int) -> void:
	_queued_turn = 0
	_quarter_turns += signi(direction)
	_zoom = 1.0
	if _zoom_tween != null and _zoom_tween.is_valid():
		_zoom_tween.kill()
	var target_yaw := _current_yaw()
	_fitted_size = _fit_size(target_yaw)
	_camera.size = _fitted_size
	_rotate_tween = create_tween()
	_rotate_tween.tween_property(
		self, "rotation:y", deg_to_rad(target_yaw), rotate_seconds
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_rotate_tween.finished.connect(_on_rotation_finished)


func _on_rotation_finished() -> void:
	_rotate_tween = null
	update_occlusion()
	if _queued_turn != 0:
		var queued := _queued_turn
		_queued_turn = 0
		_start_rotation(queued)


func _current_yaw() -> float:
	return base_yaw_degrees + QUARTER_TURN_DEGREES * float(_quarter_turns)


func _camera_local_offset() -> Vector3:
	var pitch := deg_to_rad(clamp_pitch_degrees(pitch_degrees))
	return Vector3(0.0, sin(pitch) * camera_distance, cos(pitch) * camera_distance)


func _offset_direction(yaw_degrees: float) -> Vector3:
	var yaw := deg_to_rad(yaw_degrees)
	return Vector3(sin(yaw), 0.0, cos(yaw))


func _fit_size(target_yaw: float) -> float:
	var half_width := float(_level.columns) * BoardBuilderScript.CELL_SIZE * 0.5
	var half_depth := float(_level.rows) * BoardBuilderScript.CELL_SIZE * 0.5
	var corners: Array[Vector3] = []
	for x in [-half_width, half_width]:
		for y in [0.0, _board.wall_height]:
			for z in [-half_depth, half_depth]:
				corners.append(Vector3(x, y, z))
	var viewport_size := get_viewport().get_visible_rect().size
	var aspect := viewport_size.x / maxf(viewport_size.y, 1.0)
	return fit_orthogonal_size(
		corners,
		target_yaw,
		clamp_pitch_degrees(pitch_degrees),
		aspect,
		fill_ratio,
		size_min,
		size_max
	)
