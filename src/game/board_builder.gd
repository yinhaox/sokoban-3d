class_name BoardBuilder
extends Node3D

## Builds the visible 3D room of one LevelData from primitive meshes.
##
## Every cell is exactly one world unit and the grid is centred on this node, so
## a cell's world position comes from `cell_to_world()` and nothing else. The
## builder also owns the wall pieces, because the camera rig fades the walls
## that sit between the camera and the player.
##
## Geometry rules come from design/camera-and-presentation.md: BoxMesh,
## CapsuleMesh and TorusMesh only, StandardMaterial3D with a flat albedo,
## roughness 0.9 and metallic 0.0, and no imported texture or mesh.

const LevelDataScript = preload("res://src/logic/level_data.gd")

## One world unit per cell, per design/camera-and-presentation.md `tile_size_m`.
const CELL_SIZE := 1.0
## Flat material values from design/camera-and-presentation.md.
const MATERIAL_ROUGHNESS := 0.9
const MATERIAL_METALLIC := 0.0
## Emissive energy of a filled goal plate, from the palette table.
const GOAL_EMISSION_ENERGY := 0.4
## Small lift that keeps an actor's bottom face off the floor top face.
const ACTOR_LIFT := 0.002
## Small lift that keeps a goal plate's bottom face off the floor top face.
const PLATE_LIFT := 0.001
## CapsuleMesh needs a height of at least two radii.
const CAPSULE_HEIGHT_EPSILON := 0.01
## Height of the darker cap that sits on top of a wall.
const CAP_HEIGHT := 0.02
## Height of the raised cross on a crate's top face.
const CROSS_HEIGHT := 0.02
const CROSS_ARM_LENGTH_RATIO := 0.70
const CROSS_ARM_WIDTH_RATIO := 0.12
const RING_INNER_RADIUS := 0.22
const RING_OUTER_RADIUS := 0.30
const PLATE_SIZE_RATIO := 0.90
## Alpha a faded wall's top cap keeps, so a faded border wall still draws an
## outline instead of disappearing (issue #9).
const OCCLUSION_CAP_ALPHA := 0.55
## How far a crate settles when it comes to rest on a goal plate, so the lit
## plate and the settle are both visible (design/core-rules.md "the crate
## settles").
const CRATE_GOAL_SINK := 0.03

@export var wall_height: float = 1.0
@export var floor_thickness: float = 0.1
@export var crate_size: float = 0.84
@export var player_radius: float = 0.28
@export var player_height: float = 0.55
@export var plate_thickness: float = 0.02

@export_group("Palette")
@export var floor_color: Color = Color("#C9B79C")
@export var wall_side_color: Color = Color("#6B7A8F")
@export var wall_top_color: Color = Color("#55637A")
@export var crate_color: Color = Color("#C98A4B")
@export var crate_on_goal_color: Color = Color("#E0A960")
@export var goal_empty_color: Color = Color("#3F7F6E")
@export var goal_filled_color: Color = Color("#7FD1A8")
@export var player_color: Color = Color("#E2574C")

@export_group("Colorblind palette")
## Palette swapped in when a colorblind mode is on, from design/accessibility.md
## "Palettes". The shape markers below are always built and become visible with
## the mode, so the mode never removes shape information.
@export var colorblind_crate_color: Color = Color("#E69F00")
@export var colorblind_crate_on_goal_color: Color = Color("#F0C060")
@export var colorblind_goal_color: Color = Color("#56B4E9")
@export var colorblind_player_color: Color = Color("#0072B2")
@export var colorblind_marker_color: Color = Color("#111111")
@export var colorblind_marker_size: float = 0.10
@export var colorblind_crate_mark_height: float = 0.26
@export var colorblind_goal_mark_width: float = 0.20
@export var colorblind_player_nub_depth: float = 0.20

## Cell of the player piece, set by `build()`.
var player_cell: Vector2i = Vector2i(-1, -1)

var _columns: int = 0
var _rows: int = 0
var _wall_cells: Array[Vector2i] = []
var _crate_cells: Array[Vector2i] = []
var _crate_nodes: Array[MeshInstance3D] = []
var _player_node: MeshInstance3D
var _colorblind_mode: bool = false
var _colorblind_markers: Array[MeshInstance3D] = []
## Goal cell -> plate node, and the plate's current filled state.
var _goal_cells: Dictionary = {}
var _goal_plates: Dictionary = {}
var _goal_filled: Dictionary = {}

var _floor_material: StandardMaterial3D
var _wall_side_material: StandardMaterial3D
var _wall_top_material: StandardMaterial3D
var _crate_material: StandardMaterial3D
var _crate_on_goal_material: StandardMaterial3D
var _goal_empty_material: StandardMaterial3D
var _goal_filled_material: StandardMaterial3D
var _goal_ring_material: StandardMaterial3D
var _marker_material: StandardMaterial3D
var _player_material: StandardMaterial3D
var _colorblind_mark_material: StandardMaterial3D

## Wall bookkeeping for the occlusion fade: cell -> [side, cap] instances and
## the per-wall transparent material variants.
var _wall_nodes: Dictionary = {}
var _wall_fade_side: Dictionary = {}
var _wall_fade_top: Dictionary = {}
var _wall_tweens: Dictionary = {}
var _faded_walls: Dictionary = {}


## Cell centre in the builder's local space. The grid is centred on the node, so
## cell (0,0) of a 7x7 room is at (-3, 0, -3) and cell (6,6) at (3, 0, 3).
static func cell_to_world(
	cell: Vector2i, columns: int, rows: int, cell_size: float = CELL_SIZE
) -> Vector3:
	return Vector3(
		(float(cell.x) - float(columns - 1) * 0.5) * cell_size,
		0.0,
		(float(cell.y) - float(rows - 1) * 0.5) * cell_size
	)


## Inverse of `cell_to_world()`, rounded to the nearest cell centre.
static func world_to_cell(
	position: Vector3, columns: int, rows: int, cell_size: float = CELL_SIZE
) -> Vector2i:
	return Vector2i(
		roundi(position.x / cell_size + float(columns - 1) * 0.5),
		roundi(position.z / cell_size + float(rows - 1) * 0.5)
	)


## Centroid of the level's walkable cells, in the builder's local space. This is
## the point the camera rig orbits, per design/camera-and-presentation.md.
static func level_centre(level: LevelDataScript, cell_size: float = CELL_SIZE) -> Vector3:
	var total := Vector3.ZERO
	var count := 0
	for row in level.rows:
		for column in level.columns:
			var cell := Vector2i(column, row)
			if level.cell_at(cell) == LevelDataScript.Cell.WALL:
				continue
			total += cell_to_world(cell, level.columns, level.rows, cell_size)
			count += 1
	if count == 0:
		return Vector3.ZERO
	return total / float(count)


## Rebuilds the room for one validated level, replacing every previous child.
func build(level: LevelDataScript) -> void:
	if not level.is_valid():
		push_error("board_builder: refusing to build an invalid level: %s" % level.error_summary())
		return
	clear()
	_columns = level.columns
	_rows = level.rows
	_create_materials()
	_build_floor(level)
	_build_goals(level)
	_build_walls(level)
	_build_crates(level)
	_build_player(level)


## Removes every generated node and resets the wall-fade bookkeeping.
func clear() -> void:
	for tween in _wall_tweens.values():
		(tween as Tween).kill()
	for child in get_children():
		child.free()
	_wall_cells.clear()
	_crate_cells.clear()
	_crate_nodes.clear()
	_goal_cells.clear()
	_goal_plates.clear()
	_goal_filled.clear()
	_player_node = null
	_colorblind_markers.clear()
	_wall_nodes.clear()
	_wall_fade_side.clear()
	_wall_fade_top.clear()
	_wall_tweens.clear()
	_faded_walls.clear()
	player_cell = Vector2i(-1, -1)


func wall_cells() -> Array[Vector2i]:
	var copy: Array[Vector2i] = []
	copy.assign(_wall_cells)
	return copy


func crate_cells() -> Array[Vector2i]:
	var copy: Array[Vector2i] = []
	copy.assign(_crate_cells)
	return copy


func player_node() -> MeshInstance3D:
	return _player_node


## Crate piece by box index, or null when the index has no crate.
func crate_node(index: int) -> MeshInstance3D:
	if index < 0 or index >= _crate_nodes.size():
		return null
	return _crate_nodes[index]


## Turns the colorblind shape markers and palette on or off. The markers exist on
## every board and only their visibility changes, so no rebuild is needed when
## the setting is changed from the pause menu.
func set_colorblind_mode(enabled: bool) -> void:
	_colorblind_mode = enabled
	_apply_palette()
	for marker: MeshInstance3D in _colorblind_markers:
		marker.visible = enabled


func is_colorblind_mode() -> bool:
	return _colorblind_mode


## Number of shape markers the board carries: one per goal, one per crate and one
## on the player.
func colorblind_marker_count() -> int:
	return _colorblind_markers.size()


## True when the board has markers and every one of them is visible.
func colorblind_markers_visible() -> bool:
	if _colorblind_markers.is_empty():
		return false
	for marker: MeshInstance3D in _colorblind_markers:
		if not marker.visible:
			return false
	return true


## World position of the player piece for a cell, matching `_build_player()`.
func player_world_position(cell: Vector2i) -> Vector3:
	var centre := cell_to_world(cell, _columns, _rows)
	centre.y = _player_mesh_height() * 0.5 + ACTOR_LIFT
	return centre


## World position of a crate for a cell. A crate resting on a goal plate settles
## by `CRATE_GOAL_SINK`, which is the visible acknowledgement of a filled plate.
func crate_world_position(cell: Vector2i, on_goal: bool) -> Vector3:
	var centre := cell_to_world(cell, _columns, _rows)
	centre.y = crate_size * 0.5 + ACTOR_LIFT
	return centre - Vector3(0.0, CRATE_GOAL_SINK if on_goal else 0.0, 0.0)


## Whether the goal plate at `cell` is drawn in its filled state.
func is_goal_filled(cell: Vector2i) -> bool:
	return bool(_goal_filled.get(cell, false))


func set_player_cell(cell: Vector2i) -> void:
	player_cell = cell


func set_crate_cell(index: int, cell: Vector2i) -> void:
	if index < 0 or index >= _crate_cells.size():
		return
	_crate_cells[index] = cell


## Swaps a crate's body and top marker to the on-goal palette entry.
func set_crate_on_goal(index: int, on_goal: bool) -> void:
	var crate := crate_node(index)
	if crate == null:
		return
	crate.material_override = _crate_on_goal_material if on_goal else _crate_material
	for child in crate.get_children():
		if child is MeshInstance3D and not str((child as Node).name).begins_with("Cb"):
			(child as MeshInstance3D).material_override = (
				_crate_material if on_goal else _marker_material
			)


## Lights or dims one goal plate. The filled material is the emissive palette
## entry, so a crate landing on a plate changes the plate on screen.
func set_goal_filled(cell: Vector2i, filled: bool) -> void:
	var plate := _goal_plates.get(cell) as MeshInstance3D
	if plate == null:
		return
	plate.material_override = _goal_filled_material if filled else _goal_empty_material
	_goal_filled[cell] = filled


## Re-lights every goal plate from the current box cells.
func refresh_goal_fills(boxes: Array[Vector2i]) -> void:
	for cell: Vector2i in _goal_cells.keys():
		set_goal_filled(cell, boxes.has(cell))


## Lands every actor on the given cells with no tween. Used for undo and restart,
## so a reset never rebuilds the room and never flickers.
func sync_actors(player: Vector2i, boxes: Array[Vector2i]) -> void:
	player_cell = player
	if _player_node != null:
		_player_node.position = player_world_position(player)
	for index: int in _crate_nodes.size():
		if index >= boxes.size():
			break
		var cell: Vector2i = boxes[index]
		_crate_cells[index] = cell
		var on_goal: bool = _goal_cells.has(cell)
		set_crate_on_goal(index, on_goal)
		_crate_nodes[index].position = crate_world_position(cell, on_goal)
	refresh_goal_fills(boxes)


func cell_centre(cell: Vector2i) -> Vector3:
	return cell_to_world(cell, _columns, _rows)


## Axis-aligned bound of the whole room in this node's local space: the outer
## faces of the border walls, from the underside of the floor slab to the top of
## the wall cap. The camera rig frames this box.
func room_bounds() -> AABB:
	var half_width := float(_columns) * CELL_SIZE * 0.5
	var half_depth := float(_rows) * CELL_SIZE * 0.5
	var top := wall_height + CAP_HEIGHT
	return AABB(
		Vector3(-half_width, -floor_thickness, -half_depth),
		Vector3(half_width * 2.0, top + floor_thickness, half_depth * 2.0)
	)


## Alpha of a wall's side faces while it is faded.
static func fade_side_alpha(alpha: float) -> float:
	return clampf(alpha, 0.0, 1.0)


## Alpha of a faded wall's top cap: the same fade as the sides, but never below
## `OCCLUSION_CAP_ALPHA`, so a faded border wall keeps its outline.
static func fade_cap_alpha(alpha: float) -> float:
	return clampf(maxf(alpha, OCCLUSION_CAP_ALPHA), 0.0, 1.0)


## Fades the given wall cells to `alpha` and restores every other wall. The fade
## uses the per-wall transparent material variant, so a faded wall casts no
## shadow and cannot block a target cell. The top cap keeps
## `OCCLUSION_CAP_ALPHA`, so a faded border wall still draws its outline.
func apply_wall_fade(occluded_cells: Array[Vector2i], alpha: float, seconds: float) -> void:
	var wanted := {}
	for cell in occluded_cells:
		wanted[cell] = true
	var target_alpha := clampf(alpha, 0.0, 1.0)
	var duration := maxf(seconds, 0.0)
	for cell in _wall_nodes.keys():
		_fade_wall(cell, wanted.has(cell), target_alpha, duration)


func _fade_wall(cell: Vector2i, should_fade: bool, alpha: float, seconds: float) -> void:
	if _faded_walls.has(cell) == should_fade:
		return
	if should_fade:
		_faded_walls[cell] = true
	else:
		_faded_walls.erase(cell)
	var existing := _wall_tweens.get(cell) as Tween
	if existing != null:
		existing.kill()
	var pieces: Array = _wall_nodes[cell]
	var side: MeshInstance3D = pieces[0]
	var cap: MeshInstance3D = pieces[1]
	var side_material: StandardMaterial3D = _wall_fade_side[cell]
	var top_material: StandardMaterial3D = _wall_fade_top[cell]
	if should_fade:
		side.material_override = side_material
		cap.material_override = top_material
		_set_shadow_casting(side, false)
		_set_shadow_casting(cap, false)
		var side_alpha := fade_side_alpha(alpha)
		var cap_alpha := fade_cap_alpha(alpha)
		var fade := create_tween().set_parallel(true)
		fade.tween_method(
			_set_material_alpha.bind(side_material), side_material.albedo_color.a, side_alpha, seconds
		)
		fade.tween_method(
			_set_material_alpha.bind(top_material), top_material.albedo_color.a, cap_alpha, seconds
		)
		_wall_tweens[cell] = fade
		return
	var restore := create_tween().set_parallel(true)
	restore.tween_method(
		_set_material_alpha.bind(side_material), side_material.albedo_color.a, 1.0, seconds
	)
	restore.tween_method(
		_set_material_alpha.bind(top_material), top_material.albedo_color.a, 1.0, seconds
	)
	restore.chain().tween_callback(_finish_restore.bind(cell))
	_wall_tweens[cell] = restore


func _finish_restore(cell: Vector2i) -> void:
	_wall_tweens.erase(cell)
	if _faded_walls.has(cell):
		return
	var pieces: Array = _wall_nodes[cell]
	var side: MeshInstance3D = pieces[0]
	var cap: MeshInstance3D = pieces[1]
	side.material_override = _wall_side_material
	cap.material_override = _wall_top_material
	_set_shadow_casting(side, true)
	_set_shadow_casting(cap, true)
	var side_material: StandardMaterial3D = _wall_fade_side[cell]
	var top_material: StandardMaterial3D = _wall_fade_top[cell]
	_set_material_alpha(1.0, side_material)
	_set_material_alpha(1.0, top_material)


func _set_material_alpha(value: float, material: StandardMaterial3D) -> void:
	var color := material.albedo_color
	color.a = value
	material.albedo_color = color


func _set_shadow_casting(instance: MeshInstance3D, enabled: bool) -> void:
	instance.cast_shadow = (
		GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if enabled
		else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	)


func _create_materials() -> void:
	_floor_material = _make_material(floor_color)
	_wall_side_material = _make_material(wall_side_color)
	_wall_top_material = _make_material(wall_top_color)
	_crate_material = _make_material(_effective_color(crate_color, colorblind_crate_color))
	_crate_on_goal_material = _make_material(
		_effective_color(crate_on_goal_color, colorblind_crate_on_goal_color)
	)
	_goal_empty_material = _make_material(goal_empty_color)
	_goal_filled_material = _make_emissive_material(
		_effective_color(goal_filled_color, colorblind_goal_color)
	)
	_goal_ring_material = _make_material(_effective_color(goal_filled_color, colorblind_goal_color))
	_marker_material = _make_material(_effective_color(crate_on_goal_color, colorblind_marker_color))
	_player_material = _make_material(_effective_color(player_color, colorblind_player_color))
	_colorblind_mark_material = _make_material(colorblind_marker_color)


## The palette entry for the current colour mode.
func _effective_color(normal: Color, colorblind: Color) -> Color:
	return colorblind if _colorblind_mode else normal


## Re-colours the materials already on the board when the mode is changed while a
## level is open, and does nothing before the first `build()`.
func _apply_palette() -> void:
	if _crate_material == null:
		return
	_crate_material.albedo_color = _effective_color(crate_color, colorblind_crate_color)
	_crate_on_goal_material.albedo_color = _effective_color(
		crate_on_goal_color, colorblind_crate_on_goal_color
	)
	var goal_color := _effective_color(goal_filled_color, colorblind_goal_color)
	_goal_filled_material.albedo_color = goal_color
	_goal_filled_material.emission = goal_color
	_goal_ring_material.albedo_color = goal_color
	_marker_material.albedo_color = _effective_color(crate_on_goal_color, colorblind_marker_color)
	_player_material.albedo_color = _effective_color(player_color, colorblind_player_color)


func _make_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = MATERIAL_ROUGHNESS
	material.metallic = MATERIAL_METALLIC
	return material


func _make_emissive_material(color: Color) -> StandardMaterial3D:
	var material := _make_material(color)
	material.emission_enabled = true
	material.emission = color
	material.emission_energy_multiplier = GOAL_EMISSION_ENERGY
	return material


func _make_transparent_material(color: Color) -> StandardMaterial3D:
	var material := _make_material(color)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material


func _build_floor(level: LevelDataScript) -> void:
	var size := Vector3(CELL_SIZE, floor_thickness, CELL_SIZE)
	for row in level.rows:
		for column in level.columns:
			var cell := Vector2i(column, row)
			if level.cell_at(cell) == LevelDataScript.Cell.WALL:
				continue
			var centre := cell_to_world(cell, _columns, _rows)
			centre.y = -floor_thickness * 0.5
			_add_box(size, centre, _floor_material, "Floor_%d_%d" % [column, row])


func _build_goals(level: LevelDataScript) -> void:
	var size := Vector3(
		CELL_SIZE * PLATE_SIZE_RATIO, plate_thickness, CELL_SIZE * PLATE_SIZE_RATIO
	)
	var plate_top := plate_thickness + PLATE_LIFT
	var ring_radius := (RING_OUTER_RADIUS - RING_INNER_RADIUS) * 0.5
	for cell in level.goals:
		var filled: bool = level.box_starts.has(cell)
		var material := _goal_filled_material if filled else _goal_empty_material
		var centre := cell_to_world(cell, _columns, _rows)
		centre.y = plate_thickness * 0.5 + PLATE_LIFT
		_goal_cells[cell] = true
		_goal_plates[cell] = _add_box(
			size, centre, material, "Goal_%d_%d" % [cell.x, cell.y]
		)
		_goal_filled[cell] = filled
		var ring_centre := cell_to_world(cell, _columns, _rows)
		ring_centre.y = plate_top + ring_radius
		_add_torus(ring_centre, _goal_ring_material, "GoalRing_%d_%d" % [cell.x, cell.y])
		_add_goal_check(cell, plate_top)


## Two angled bars that read as a check mark on an empty plate, so a goal is
## identifiable by shape as well as colour in colorblind mode.
func _add_goal_check(cell: Vector2i, plate_top: float) -> void:
	var arm_size := Vector3(
		colorblind_goal_mark_width * 0.55, 0.012, colorblind_marker_size
	)
	for arm_index in 2:
		var centre := cell_to_world(cell, _columns, _rows)
		centre.y = plate_top + colorblind_marker_size * 0.5
		centre.x += 0.03 * float(1 - arm_index)
		centre.z += 0.04 * float(arm_index) - 0.02
		var arm := _add_box(
			arm_size,
			centre,
			_colorblind_mark_material,
			"CbGoalMark_%d_%d_%d" % [cell.x, cell.y, arm_index]
		)
		arm.rotation.y = PI * 0.25 * (1.0 if arm_index == 0 else -1.0)
		arm.visible = _colorblind_mode
		_colorblind_markers.append(arm)


func _build_walls(level: LevelDataScript) -> void:
	var side_size := Vector3(CELL_SIZE, wall_height, CELL_SIZE)
	var cap_size := Vector3(CELL_SIZE, CAP_HEIGHT, CELL_SIZE)
	for row in level.rows:
		for column in level.columns:
			var cell := Vector2i(column, row)
			if level.cell_at(cell) != LevelDataScript.Cell.WALL:
				continue
			_wall_cells.append(cell)
			var base := cell_to_world(cell, _columns, _rows)
			var side_centre := base
			side_centre.y = wall_height * 0.5
			var cap_centre := base
			cap_centre.y = wall_height + CAP_HEIGHT * 0.5
			var side := _add_box(
				side_size, side_centre, _wall_side_material, "Wall_%d_%d" % [column, row]
			)
			var cap := _add_box(
				cap_size, cap_centre, _wall_top_material, "WallTop_%d_%d" % [column, row]
			)
			_wall_nodes[cell] = [side, cap]
			_wall_fade_side[cell] = _make_transparent_material(wall_side_color)
			_wall_fade_top[cell] = _make_transparent_material(wall_top_color)


func _build_crates(level: LevelDataScript) -> void:
	for index in level.box_starts.size():
		var cell := level.box_starts[index]
		_crate_cells.append(cell)
		var on_goal: bool = level.is_goal(cell)
		var material := _crate_on_goal_material if on_goal else _crate_material
		var crate := _add_box(
			Vector3(crate_size, crate_size, crate_size),
			crate_world_position(cell, on_goal),
			material,
			"Crate_%d" % index
		)
		_crate_nodes.append(crate)
		var marker := _crate_material if on_goal else _marker_material
		_add_crate_cross(crate, marker)
		_add_crate_finial(crate, index)


## A raised post above the crate cross, visible only in colorblind mode, so the
## crate silhouette differs from a bare block at a glance.
func _add_crate_finial(crate: MeshInstance3D, index: int) -> void:
	var size := Vector3(colorblind_marker_size, colorblind_crate_mark_height, colorblind_marker_size)
	var centre := Vector3(
		0.0, crate_size * 0.5 + CROSS_HEIGHT + colorblind_crate_mark_height * 0.5, 0.0
	)
	var finial := _add_box_child(
		crate, size, centre, _colorblind_mark_material, "CbCrateMark_%d" % index
	)
	finial.visible = _colorblind_mode
	_colorblind_markers.append(finial)


func _add_crate_cross(crate: MeshInstance3D, material: StandardMaterial3D) -> void:
	var local_top := crate_size * 0.5 + CROSS_HEIGHT * 0.5 + PLATE_LIFT
	var arm_length := crate_size * CROSS_ARM_LENGTH_RATIO
	var arm_width := crate_size * CROSS_ARM_WIDTH_RATIO
	var arm_size := Vector3(arm_length, CROSS_HEIGHT, arm_width)
	_add_box_child(crate, arm_size, Vector3(0.0, local_top, 0.0), material, "CrossX")
	var arm_z := _add_box_child(
		crate, arm_size, Vector3(0.0, local_top, 0.0), material, "CrossZ"
	)
	arm_z.rotation.y = PI * 0.5


func _build_player(level: LevelDataScript) -> void:
	player_cell = level.player_start
	var capsule_height := _player_mesh_height()
	var mesh := CapsuleMesh.new()
	mesh.radius = player_radius
	mesh.height = capsule_height
	var instance := MeshInstance3D.new()
	instance.name = "Player"
	instance.mesh = mesh
	instance.material_override = _player_material
	instance.position = player_world_position(player_cell)
	add_child(instance)
	_player_node = instance
	var nub := _add_box_child(
		instance,
		Vector3(colorblind_marker_size, colorblind_marker_size, colorblind_player_nub_depth),
		Vector3(0.0, 0.0, player_radius + colorblind_player_nub_depth * 0.5),
		_colorblind_mark_material,
		"CbPlayerMark"
	)
	nub.visible = _colorblind_mode
	_colorblind_markers.append(nub)


## CapsuleMesh needs a height of at least two radii.
func _player_mesh_height() -> float:
	return maxf(player_height, player_radius * 2.0 + CAPSULE_HEIGHT_EPSILON)


func _add_box_child(
	parent: Node3D, size: Vector3, centre: Vector3, material: Material, node_name: String
) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	instance.position = centre
	parent.add_child(instance)
	return instance


func _add_box(
	size: Vector3, centre: Vector3, material: Material, node_name: String
) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	instance.position = centre
	add_child(instance)
	return instance


func _add_torus(centre: Vector3, material: Material, node_name: String) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = RING_INNER_RADIUS
	mesh.outer_radius = RING_OUTER_RADIUS
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.material_override = material
	instance.position = centre
	add_child(instance)
	return instance
