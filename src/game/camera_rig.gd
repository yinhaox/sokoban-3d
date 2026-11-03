class_name CameraRig
extends Node3D

## Isometric camera rig for the 3D room, per design/camera-and-presentation.md.
##
## The rig orbits the level centre on a fixed pitch and frames the room's
## bounding box, so the whole floor and all four border walls are centred in the
## viewport at any level size. The `camera_rotate_left` / `camera_rotate_right`
## actions snap the yaw by a quarter turn, the `camera_zoom_in` /
## `camera_zoom_out` actions (bound to `=`/`-` and the mouse wheel) change the
## orthographic zoom inside its bounds, and `update_occlusion()` fades the walls
## between the camera and the player, a crate or a goal plate. The camera never
## free-orbits and the pitch is not player-adjustable in 1.0.

const LevelDataScript = preload("res://src/logic/level_data.gd")
const BoardBuilderScript = preload("res://src/game/board_builder.gd")
const InputActionsScript = preload("res://src/input/input_actions.gd")

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
## Settings range for camera sensitivity, from design/settings-and-save.md.
const SENSITIVITY_MIN := 0.5
const SENSITIVITY_MAX := 2.0

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
@export var occlusion_alpha: float = 0.22
@export var occlusion_seconds: float = 0.12
@export var camera_distance: float = 20.0

## Settings hooks: `sensitivity` divides the rotation/zoom tween time (2.0 is
## twice as fast) and `reduce_motion` makes every camera move and wall fade
## instant, per design/accessibility.md "Motion, flashing and timing". The same
## accessibility switch also hides the decorative floor grid on the board.
@export var sensitivity: float = 1.0
@export var reduce_motion: bool = false:
	set(value):
		reduce_motion = value
		if _board != null:
			_board.set_reduce_motion(value)

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
	_board.set_reduce_motion(reduce_motion)
	_quarter_turns = 0
	_zoom = 1.0
	position = BoardBuilderScript.level_centre(level)
	rotation = Vector3(0.0, deg_to_rad(_current_yaw()), 0.0)
	_camera.rotation = Vector3(-deg_to_rad(clamp_pitch_degrees(pitch_degrees)), 0.0, 0.0)
	_apply_framing(_current_yaw(), false)
	_camera.current = true
	update_occlusion()


## Selects one of the four snap states without animating. The capture path uses
## it to screenshot every quarter turn; a normal boot leaves the state at 0.
func set_quarter_turns(turns: int) -> void:
	if _level == null or _board == null:
		return
	_quarter_turns = posmod(turns, 4)
	_zoom = 1.0
	rotation = Vector3(0.0, deg_to_rad(_current_yaw()), 0.0)
	_apply_framing(_current_yaw(), false)
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
	_board.apply_wall_fade(
		occluded, occlusion_alpha, 0.0 if reduce_motion else occlusion_seconds
	)


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
	var duration := tween_seconds(zoom_seconds, sensitivity, reduce_motion)
	if duration <= 0.0:
		_camera.size = _fitted_size * _zoom
		update_occlusion()
		return
	_zoom_tween = create_tween()
	_zoom_tween.tween_property(_camera, "size", _fitted_size * _zoom, duration)
	_zoom_tween.finished.connect(update_occlusion)


## Duration of one camera tween after the sensitivity setting and reduced motion
## are applied. Zero means the move happens in the same frame.
static func tween_seconds(base_seconds: float, sensitivity_value: float, reduce: bool) -> float:
	if reduce:
		return 0.0
	return base_seconds / clampf(sensitivity_value, SENSITIVITY_MIN, SENSITIVITY_MAX)


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
	var framing := frame_room(
		corners,
		yaw_degrees,
		pitch_degrees,
		aspect,
		fill_ratio_value,
		size_minimum,
		size_maximum,
		Vector3.ZERO
	)
	return framing["size"]


## View-plane coordinates of `point` for a camera at `camera_local`. `point` uses
## the room's world axes and `camera_local` is the camera position inside the
## rig, so the rig yaw is applied here. X runs along the camera's right axis and
## Y along its up axis.
static func view_point(
	point: Vector3, camera_local: Vector3, yaw_degrees: float, pitch_degrees: float
) -> Vector2:
	var pitch := deg_to_rad(clamp_pitch_degrees(pitch_degrees))
	var offset := point.rotated(Vector3.UP, -deg_to_rad(yaw_degrees)) - camera_local
	return Vector2(offset.x, offset.y * cos(pitch) - offset.z * sin(pitch))


## Distance of `point` in front of the camera along the view direction. A
## positive value means the camera's placement covers the point instead of
## leaving it behind the near plane.
static func view_depth(
	point: Vector3, camera_local: Vector3, yaw_degrees: float, pitch_degrees: float
) -> float:
	var pitch := deg_to_rad(clamp_pitch_degrees(pitch_degrees))
	var offset := point.rotated(Vector3.UP, -deg_to_rad(yaw_degrees)) - camera_local
	return -offset.y * sin(pitch) - offset.z * cos(pitch)


## Camera position inside the rig that brings a view-plane offset to the middle
## of the viewport. Inverse of `view_point()` for a camera-local offset.
static func view_offset_to_camera_local(view_offset: Vector2, pitch_degrees: float) -> Vector3:
	var pitch := deg_to_rad(clamp_pitch_degrees(pitch_degrees))
	return Vector3(view_offset.x, view_offset.y * cos(pitch), -view_offset.y * sin(pitch))


## Frames the room's bounding box in the orthographic view. Returns
## `{"size": float, "camera_local": Vector3}`: the projection size and the
## camera position inside the rig that centre the projected room in the viewport
## and leave `fill_ratio_value` of the limiting axis as margin.
static func frame_room(
	room_corners: Array[Vector3],
	yaw_degrees: float,
	pitch_degrees: float,
	aspect: float,
	fill_ratio_value: float,
	size_minimum: float,
	size_maximum: float,
	base_camera_local: Vector3
) -> Dictionary:
	if room_corners.is_empty():
		return {"size": size_minimum, "camera_local": base_camera_local}
	var min_view := Vector2(INF, INF)
	var max_view := Vector2(-INF, -INF)
	for corner: Vector3 in room_corners:
		var view := view_point(corner, base_camera_local, yaw_degrees, pitch_degrees)
		min_view = Vector2(minf(min_view.x, view.x), minf(min_view.y, view.y))
		max_view = Vector2(maxf(max_view.x, view.x), maxf(max_view.y, view.y))
	var safe_aspect := maxf(aspect, MIN_ASPECT)
	var horizontal_span := max_view.x - min_view.x
	var vertical_span := max_view.y - min_view.y
	var fitted := maxf(vertical_span, horizontal_span / safe_aspect) / maxf(fill_ratio_value, MIN_ASPECT)
	var view_centre := (min_view + max_view) * 0.5
	return {
		"size": clampf(fitted, size_minimum, size_maximum),
		"camera_local": base_camera_local + view_offset_to_camera_local(
			view_centre, pitch_degrees
		),
	}


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
	if event.is_action_pressed(InputActionsScript.CAMERA_ROTATE_LEFT):
		rotate_quarter(-1)
	elif event.is_action_pressed(InputActionsScript.CAMERA_ROTATE_RIGHT):
		rotate_quarter(1)
	elif event.is_action_pressed(InputActionsScript.CAMERA_ZOOM_IN):
		zoom_by(-1)
	elif event.is_action_pressed(InputActionsScript.CAMERA_ZOOM_OUT):
		zoom_by(1)


func _start_rotation(direction: int) -> void:
	_queued_turn = 0
	_quarter_turns += signi(direction)
	_zoom = 1.0
	if _zoom_tween != null and _zoom_tween.is_valid():
		_zoom_tween.kill()
	var target_yaw := _current_yaw()
	var camera_local := _apply_framing(target_yaw, true)
	var duration := tween_seconds(rotate_seconds, sensitivity, reduce_motion)
	if duration <= 0.0:
		rotation.y = deg_to_rad(target_yaw)
		_camera.position = camera_local
		_on_rotation_finished()
		return
	_rotate_tween = create_tween()
	_rotate_tween.tween_property(
		self, "rotation:y", deg_to_rad(target_yaw), duration
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_rotate_tween.parallel().tween_property(
		_camera, "position", camera_local, duration
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


## Places the camera so the room's bounding box is centred in the viewport and
## fills `fill_ratio` of the limiting axis. Returns the camera position inside
## the rig so a rotation can tween towards it.
func _apply_framing(target_yaw: float, animate: bool) -> Vector3:
	var framing := frame_room(
		_room_corners(),
		target_yaw,
		pitch_degrees,
		_viewport_aspect(),
		fill_ratio,
		size_min,
		size_max,
		_camera_local_offset()
	)
	_fitted_size = framing["size"]
	var camera_local: Vector3 = framing["camera_local"]
	_camera.size = _fitted_size
	if not animate:
		_camera.position = camera_local
	return camera_local


## The eight corners of the room's bounding box, relative to the rig position.
func _room_corners() -> Array[Vector3]:
	var bounds := _board.room_bounds()
	var corners: Array[Vector3] = []
	for x: float in [bounds.position.x, bounds.end.x]:
		for y: float in [bounds.position.y, bounds.end.y]:
			for z: float in [bounds.position.z, bounds.end.z]:
				corners.append(Vector3(x, y, z) - position)
	return corners


func _viewport_aspect() -> float:
	var viewport_size := get_viewport().get_visible_rect().size
	return viewport_size.x / maxf(viewport_size.y, 1.0)
