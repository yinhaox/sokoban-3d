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
## Height of the darker cap that sits on top of a wall. The cap is a flat single
## quad, so this is the lift of the top face above the wall body; kept small so a
## faded wall's top face sits at the top of the body (issue #30).
const CAP_HEIGHT := 0.002
## Small overlap of two adjacent flat caps, so their shared edge never shows as a
## hairline through a faded wall's translucent top (issue #30).
const CAP_OVERLAP := 0.002
## Height of the raised cross on a crate's top face.
const CROSS_HEIGHT := 0.02
const CROSS_ARM_LENGTH_RATIO := 0.70
const CROSS_ARM_WIDTH_RATIO := 0.12
const RING_INNER_RADIUS := 0.22
const RING_OUTER_RADIUS := 0.30
const PLATE_SIZE_RATIO := 0.90
## Highest opacity any part of a faded wall may reach, so a ghosted wall never
## competes with the floor, the crates or the player (issue #30).
const FADE_ALPHA_MAX := 0.25
## Alpha the faded top face keeps. A faded wall keeps its top face at this alpha,
## so it reads as a wall instead of a hollow box with a dark hole inside.
const FADE_CAP_ALPHA := 0.25
## Colours of a faded wall. The top face is much paler than the side body, and
## the side body is paler than the opaque wall, so a ghosted wall reads as a lit
## surface over the floor instead of a dark cavity (issue #30).
const FADE_SIDE_COLOR := Color("#8FA4BF")
const FADE_TOP_COLOR := Color("#DCE6F4")
## How far a crate settles when it comes to rest on a goal plate, so the lit
## plate and the settle are both visible (design/core-rules.md "the crate
## settles").
const CRATE_GOAL_SINK := 0.03
## One faint line per cell edge. The line is the floor tone darkened by
## `GRID_DARKEN_RATIO`, which keeps the value step inside the 8% the story
## allows while staying visible under the flat directional light.
const GRID_LINE_WIDTH := 0.04
const GRID_LINE_HEIGHT := 0.002
const GRID_LIFT := 0.001
const GRID_DARKEN_RATIO := 0.07
const GRID_MAX_DARKEN_RATIO := 0.08
## Thin top-contour bars on the outer boundary of a wall segment, so a continuous
## wall draws one line per boundary run and never a seam between two of its own
## cells (issue #30). They stay crisp while the wall body fades.
const WALL_OUTLINE_WIDTH := 0.035
const WALL_OUTLINE_HEIGHT := 0.008
## Dark plinth around the room. Its top sits just under the floor plane, so it
## fills the void under the border walls and shows as a 0.05-unit rim.
const BASE_THICKNESS := 0.05
const BASE_MARGIN := 0.12
const BASE_TOP_OFFSET := 0.001
## Soft contact shadow: three concentric discs, widest and faintest first. The
## radius multipliers and alpha multipliers keep the falloff soft without a
## texture.
const CONTACT_SHADOW_RADII := [1.22, 1.10, 1.0]
const CONTACT_SHADOW_ALPHAS := [0.35, 0.60, 1.0]
const CONTACT_SHADOW_DISC_HEIGHT := 0.001
const CONTACT_SHADOW_LAYER_LIFT := 0.0002
const CONTACT_SHADOW_LIFT := 0.0015

@export var wall_height: float = 1.0
@export var floor_thickness: float = 0.1
@export var crate_size: float = 0.84
@export var player_radius: float = 0.28
@export var player_height: float = 0.55
@export var plate_thickness: float = 0.02

@export_group("Visual polish")
## Value step between the floor and its grid lines; clamped to the story's 8%.
@export_range(0.0, 0.08, 0.01) var grid_darken_ratio: float = GRID_DARKEN_RATIO
## The grid follows the accessibility reduce-motion setting: it is hidden when
## `set_reduce_motion(true)` is applied. These two are the build-time defaults;
## the runtime setters below can still toggle the groups on a live board.
@export var floor_grid_enabled: bool = true
@export var wall_outline_enabled: bool = true
@export var wall_outline_color: Color = Color("#C6D4E7")
@export var contact_shadow_color: Color = Color("#000000")
@export_range(0.0, 0.4, 0.01) var contact_shadow_alpha: float = 0.18
@export var room_base_color: Color = Color("#1A1F29")
@export_range(0.02, 0.2, 0.01) var room_base_thickness: float = BASE_THICKNESS
@export_range(0.0, 0.3, 0.01) var room_base_margin: float = BASE_MARGIN

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
var _grid_material: StandardMaterial3D
var _wall_outline_material: StandardMaterial3D
var _room_base_material: StandardMaterial3D

## Wall bookkeeping for the occlusion fade: cell -> [side, cap] instances and
## the per-wall transparent material variants.
var _wall_nodes: Dictionary = {}
var _wall_fade_side: Dictionary = {}
var _wall_fade_top: Dictionary = {}
var _wall_tweens: Dictionary = {}
var _faded_walls: Dictionary = {}

## Presentation polish bookkeeping: the generated grid, outline and shadow
## nodes. The visibility flags survive a rebuild so a settings change does not
## need a second build.
var _grid_root: Node3D
var _grid_nodes: Array[MeshInstance3D] = []
var _wall_outlines_root: Node3D
var _wall_outline_nodes: Array[MeshInstance3D] = []
## False when a generated contour bar sits inside a wall segment instead of on its
## boundary. `wall_outline_runs_follow_boundary()` reports it to the regression
## test (issue #30).
var _wall_outline_runs_valid: bool = true
var _contact_shadows: Array[Node3D] = []
var _floor_grid_visible: bool = true
var _wall_outlines_visible: bool = true
var _reduce_motion: bool = false


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
	_build_room_base(level)
	_build_floor(level)
	_build_floor_grid(level)
	_build_goals(level)
	_build_walls(level)
	_build_crates(level)
	_build_player(level)
	_apply_floor_grid_visibility()
	if _wall_outlines_root != null:
		_wall_outlines_root.visible = _wall_outlines_visible and wall_outline_enabled


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
	_grid_root = null
	_grid_nodes.clear()
	_wall_outlines_root = null
	_wall_outline_nodes.clear()
	_wall_outline_runs_valid = true
	_contact_shadows.clear()
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


## Hides the decorative floor grid while the accessibility reduce-motion setting
## is on, per design/accessibility.md "Motion, flashing and timing". The flag is
## kept across a rebuild, so a level change keeps the setting.
func set_reduce_motion(enabled: bool) -> void:
	_reduce_motion = enabled
	_apply_floor_grid_visibility()


func is_reduce_motion() -> bool:
	return _reduce_motion


## Shows or hides the floor grid itself. The grid stays hidden while reduce
## motion is on.
func set_floor_grid_visible(enabled: bool) -> void:
	_floor_grid_visible = enabled
	_apply_floor_grid_visibility()


## Whether the generated grid is on screen right now.
func is_floor_grid_visible() -> bool:
	return _grid_root != null and _grid_root.visible


func grid_line_count() -> int:
	return _grid_nodes.size()


## The floor tone behind the grid line: the same hue and saturation, darkened by
## at most `GRID_MAX_DARKEN_RATIO`, so the value step never exceeds 8%.
static func grid_color_for(floor_tone: Color, darken_ratio: float) -> Color:
	return floor_tone.darkened(clampf(darken_ratio, 0.0, GRID_MAX_DARKEN_RATIO))


## Turns every wall's top border and edge outline on or off. The outlines stay
## opaque while the wall body fades, so a faded wall still reads as a wall.
func set_wall_outlines_enabled(enabled: bool) -> void:
	_wall_outlines_visible = enabled
	if _wall_outlines_root != null:
		_wall_outlines_root.visible = enabled and wall_outline_enabled


func wall_outlines_enabled() -> bool:
	return _wall_outlines_visible


func wall_outline_count() -> int:
	return _wall_outline_nodes.size()


## True when every contour bar sits on an edge between a wall cell and a non-wall
## cell. A bar across the inside of a wall segment reports false, which is the
## internal seam issue #30 removed.
func wall_outline_runs_follow_boundary() -> bool:
	return _wall_outline_runs_valid


## Number of wall cells whose full-cell top face exists. A faded wall keeps this
## face, so it can never show the hollow inside of its box as a dark hole.
func wall_top_face_count() -> int:
	var count := 0
	for cell: Vector2i in _wall_nodes.keys():
		var pieces: Array = _wall_nodes[cell]
		if pieces.size() > 1 and pieces[1] is MeshInstance3D:
			var cap := pieces[1] as MeshInstance3D
			if cap.mesh == null:
				continue
			var cap_bounds := cap.mesh.get_aabb()
			if (
				cap_bounds.size.x >= CELL_SIZE - CAP_OVERLAP
				and cap_bounds.size.z >= CELL_SIZE - CAP_OVERLAP
			):
				count += 1
	return count


## Number of soft contact shadow groups: one per crate, one per goal plate and
## one under the player.
func contact_shadow_count() -> int:
	return _contact_shadows.size()


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
	var shadow := crate.get_node_or_null("ContactShadow") as Node3D
	if shadow != null:
		shadow.position.y = _crate_shadow_local_y(on_goal)


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
## faces of the border walls and the dark base around them, from the underside of
## the base to the top of the wall cap. The camera rig frames this box.
func room_bounds() -> AABB:
	var half_width := float(_columns) * CELL_SIZE * 0.5 + room_base_margin
	var half_depth := float(_rows) * CELL_SIZE * 0.5 + room_base_margin
	var top := wall_height + CAP_HEIGHT
	var bottom := -BASE_TOP_OFFSET - room_base_thickness
	return AABB(
		Vector3(-half_width, bottom, -half_depth),
		Vector3(half_width * 2.0, top - bottom, half_depth * 2.0)
	)


## Alpha of a wall's side faces while it is faded. Clamped to `FADE_ALPHA_MAX`, so
## no part of a faded wall is more opaque than 25% (issue #30).
static func fade_side_alpha(alpha: float) -> float:
	return clampf(alpha, 0.0, FADE_ALPHA_MAX)


## Alpha of a faded wall's top face: never above `FADE_ALPHA_MAX`, and at
## `FADE_CAP_ALPHA` for any fade above zero, so the top face stays readable while
## the side body ghosts away. A zero fade keeps no top face at all.
static func fade_cap_alpha(alpha: float) -> float:
	if alpha <= 0.0:
		return 0.0
	return clampf(maxf(alpha, FADE_CAP_ALPHA), 0.0, FADE_ALPHA_MAX)


## Fades the given wall cells to `alpha` and restores every other wall. The fade
## uses the per-wall transparent material variant, so a faded wall casts no
## shadow and cannot block a target cell. The top face keeps
## `FADE_CAP_ALPHA` in the paler `FADE_TOP_COLOR`, so a faded wall still reads as
## a wall with a complete top instead of a hollow box (issue #30).
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
	_grid_material = _make_material(grid_color_for(floor_color, grid_darken_ratio))
	_wall_outline_material = _make_material(wall_outline_color)
	_room_base_material = _make_material(room_base_color)


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


## A dark plinth around and under the room. Its top sits just below the floor
## plane, so it fills the void under the faded border walls without z-fighting
## the floor slabs.
func _build_room_base(level: LevelDataScript) -> void:
	var size := Vector3(
		float(level.columns) * CELL_SIZE + room_base_margin * 2.0,
		room_base_thickness,
		float(level.rows) * CELL_SIZE + room_base_margin * 2.0
	)
	var centre := Vector3(0.0, -BASE_TOP_OFFSET - room_base_thickness * 0.5, 0.0)
	_add_box(size, centre, _room_base_material, "RoomBase")


## One faint line per shared floor-cell edge. Edges against a wall or the room
## border are left to the wall itself, so the grid never draws over a wall.
func _build_floor_grid(level: LevelDataScript) -> void:
	_grid_root = Node3D.new()
	_grid_root.name = "FloorGrid"
	add_child(_grid_root)
	var east_line := Vector3(GRID_LINE_WIDTH, GRID_LINE_HEIGHT, CELL_SIZE)
	var south_line := Vector3(CELL_SIZE, GRID_LINE_HEIGHT, GRID_LINE_WIDTH)
	for row in level.rows:
		for column in level.columns:
			var cell := Vector2i(column, row)
			if level.cell_at(cell) == LevelDataScript.Cell.WALL:
				continue
			var centre := cell_to_world(cell, _columns, _rows)
			centre.y = GRID_LIFT
			if _is_floor_cell(level, Vector2i(column + 1, row)):
				_add_grid_line(east_line, centre + Vector3(CELL_SIZE * 0.5, 0.0, 0.0))
			if _is_floor_cell(level, Vector2i(column, row + 1)):
				_add_grid_line(south_line, centre + Vector3(0.0, 0.0, CELL_SIZE * 0.5))


func _is_floor_cell(level: LevelDataScript, cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= level.columns or cell.y >= level.rows:
		return false
	return level.cell_at(cell) != LevelDataScript.Cell.WALL


func _add_grid_line(size: Vector3, centre: Vector3) -> void:
	var node_name := "GridLine_%d" % _grid_nodes.size()
	var line := _add_box_to(_grid_root, size, centre, _grid_material, node_name)
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_grid_nodes.append(line)


func _apply_floor_grid_visibility() -> void:
	if _grid_root != null:
		_grid_root.visible = _floor_grid_visible and floor_grid_enabled and not _reduce_motion


## One top-contour bar per merged run of wall-region boundary edges. A continuous
## wall segment therefore draws only its outer boundary and its top-face edge,
## never a line between two of its own cells (issue #30). The bars are built once
## per wall region and are never faded, so a ghosted wall keeps a crisp contour.
func _build_wall_outlines(level: LevelDataScript) -> void:
	_wall_outlines_root = Node3D.new()
	_wall_outlines_root.name = "WallOutlines"
	add_child(_wall_outlines_root)
	var top_y := wall_height + CAP_HEIGHT + WALL_OUTLINE_HEIGHT * 0.5
	for side in [-1, 1]:
		_add_contour_runs(level, true, side, top_y)
		_add_contour_runs(level, false, side, top_y)


## Walks every row (north/south edge) or column (west/east edge) and adds one bar
## per merged run of contiguous boundary cells. `side` is -1 for the low edge of
## the cell and +1 for the high edge.
func _add_contour_runs(
	level: LevelDataScript, along_rows: bool, side: int, top_y: float
) -> void:
	var line_count: int = level.rows if along_rows else level.columns
	var step_count: int = level.columns if along_rows else level.rows
	for line in line_count:
		var run_start := -1
		for step in step_count + 1:
			var on_boundary := false
			if step < step_count:
				var cell: Vector2i = (
					Vector2i(step, line) if along_rows else Vector2i(line, step)
				)
				if level.cell_at(cell) == LevelDataScript.Cell.WALL:
					var neighbour: Vector2i = (
						cell + Vector2i(0, side) if along_rows
						else cell + Vector2i(side, 0)
					)
					on_boundary = not _is_wall_cell(level, neighbour)
			if on_boundary:
				if run_start < 0:
					run_start = step
			elif run_start >= 0:
				_add_contour_bar(
					level, along_rows, side, line, run_start, step - 1, top_y
				)
				run_start = -1


## Adds the bar for one merged run and records whether the run really lies on a
## wall/non-wall boundary, which the regression test reads back.
func _add_contour_bar(
	level: LevelDataScript,
	along_rows: bool,
	side: int,
	line: int,
	start: int,
	end: int,
	top_y: float
) -> void:
	var first := _contour_cell(along_rows, line, start)
	var last := _contour_cell(along_rows, line, end)
	var span := float(end - start + 1) * CELL_SIZE + WALL_OUTLINE_WIDTH
	var centre: Vector3 = (first + last) * 0.5
	centre.y = top_y
	if along_rows:
		centre.z += float(side) * CELL_SIZE * 0.5
		_add_wall_outline_box(Vector3(span, WALL_OUTLINE_HEIGHT, WALL_OUTLINE_WIDTH), centre)
	else:
		centre.x += float(side) * CELL_SIZE * 0.5
		_add_wall_outline_box(Vector3(WALL_OUTLINE_WIDTH, WALL_OUTLINE_HEIGHT, span), centre)
	if not _contour_run_is_boundary(level, along_rows, side, line, start, end):
		_wall_outline_runs_valid = false


## Cell centre of one step of a contour run, in the builder's local space.
func _contour_cell(along_rows: bool, line: int, step: int) -> Vector3:
	var cell: Vector2i = Vector2i(step, line) if along_rows else Vector2i(line, step)
	return cell_to_world(cell, _columns, _rows)


## True when every cell of a run is a wall and its neighbour across the contoured
## edge is not, i.e. the bar lies on the wall segment's outer boundary.
func _contour_run_is_boundary(
	level: LevelDataScript,
	along_rows: bool,
	side: int,
	line: int,
	start: int,
	end: int
) -> bool:
	for step in range(start, end + 1):
		var cell: Vector2i = Vector2i(step, line) if along_rows else Vector2i(line, step)
		if level.cell_at(cell) != LevelDataScript.Cell.WALL:
			return false
		var neighbour: Vector2i = (
			cell + Vector2i(0, side) if along_rows else cell + Vector2i(side, 0)
		)
		if _is_wall_cell(level, neighbour):
			return false
	return true


func _is_wall_cell(level: LevelDataScript, cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= level.columns or cell.y >= level.rows:
		return false
	return level.cell_at(cell) == LevelDataScript.Cell.WALL


func _add_wall_outline_box(size: Vector3, centre: Vector3) -> void:
	var node_name := "WallOutline_%d" % _wall_outline_nodes.size()
	var node := _add_box_to(_wall_outlines_root, size, centre, _wall_outline_material, node_name)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_wall_outline_nodes.append(node)


## Three stacked discs under an actor or plate. The widest layer is faintest, so
## the edge of the shadow falls off softly without a texture.
func _add_contact_shadow(parent: Node3D, local_y: float, radius: float) -> void:
	var container := Node3D.new()
	container.name = "ContactShadow"
	container.position = Vector3(0.0, local_y, 0.0)
	parent.add_child(container)
	for index: int in CONTACT_SHADOW_RADII.size():
		var shadow_radius: float = radius * float(CONTACT_SHADOW_RADII[index])
		var alpha: float = contact_shadow_alpha * float(CONTACT_SHADOW_ALPHAS[index])
		var colour := Color(
			contact_shadow_color.r, contact_shadow_color.g, contact_shadow_color.b, alpha
		)
		var mesh := CylinderMesh.new()
		mesh.top_radius = shadow_radius
		mesh.bottom_radius = shadow_radius
		mesh.height = CONTACT_SHADOW_DISC_HEIGHT
		var layer := MeshInstance3D.new()
		layer.name = "ShadowLayer_%d" % index
		layer.mesh = mesh
		layer.material_override = _make_transparent_material(colour)
		layer.position = Vector3(0.0, CONTACT_SHADOW_LAYER_LIFT * float(index), 0.0)
		layer.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		container.add_child(layer)
	_contact_shadows.append(container)


func _crate_shadow_local_y(on_goal: bool) -> float:
	var sink := CRATE_GOAL_SINK if on_goal else 0.0
	return -crate_size * 0.5 - ACTOR_LIFT + CONTACT_SHADOW_LIFT + sink


func _player_shadow_local_y() -> float:
	return -_player_mesh_height() * 0.5 - ACTOR_LIFT + CONTACT_SHADOW_LIFT


## One floor slab per cell, including the cells under walls. A wall hides its slab
## while it is opaque; while it is faded the sand tone sits behind the translucent
## top and sides, so the ghosted wall shows a lit floor instead of the dark room
## base through the hollow box (issue #30).
func _build_floor(level: LevelDataScript) -> void:
	var size := Vector3(CELL_SIZE, floor_thickness, CELL_SIZE)
	for row in level.rows:
		for column in level.columns:
			var centre := cell_to_world(Vector2i(column, row), _columns, _rows)
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
		_add_contact_shadow(
			_goal_plates[cell] as Node3D,
			-plate_thickness * 0.5 - PLATE_LIFT + CONTACT_SHADOW_LIFT,
			CELL_SIZE * PLATE_SIZE_RATIO * 0.5
		)


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
	for row in level.rows:
		for column in level.columns:
			var cell := Vector2i(column, row)
			if level.cell_at(cell) != LevelDataScript.Cell.WALL:
				continue
			_wall_cells.append(cell)
			var base := cell_to_world(cell, _columns, _rows)
			var side := _add_wall_body(level, cell, base)
			var cap := _add_wall_cap(base, cell)
			_wall_nodes[cell] = [side, cap]
			_wall_fade_side[cell] = _make_transparent_material(FADE_SIDE_COLOR)
			_wall_fade_top[cell] = _make_transparent_material(FADE_TOP_COLOR)
	_build_wall_outlines(level)


## A flat, single-quad top cap. A thin box cap drew its own side face at every
## shared cell edge, which showed through a faded wall's translucent top as a
## seam; a flat quad has no side faces (issue #30). The small overlap closes the
## hairline between two adjacent caps.
func _add_wall_cap(base: Vector3, cell: Vector2i) -> MeshInstance3D:
	var half := CELL_SIZE * 0.5 + CAP_OVERLAP * 0.5
	var y := wall_height + CAP_HEIGHT
	var vertices := PackedVector3Array([
		Vector3(-half, y, half),
		Vector3(half, y, half),
		Vector3(half, y, -half),
		Vector3(-half, y, -half),
	])
	var normals := PackedVector3Array()
	for _index in 4:
		normals.append(Vector3.UP)
	var indices := PackedInt32Array([0, 2, 1, 0, 3, 2])
	var instance := MeshInstance3D.new()
	instance.name = "WallTop_%d_%d" % [cell.x, cell.y]
	instance.mesh = _triangle_mesh(vertices, normals, indices)
	instance.material_override = _wall_top_material
	instance.position = Vector3(base.x, 0.0, base.z)
	add_child(instance)
	return instance


## A wall body that carries only the side faces exposed to a non-wall neighbour.
## Faces shared by two wall cells are omitted, so a faded run never draws a seam
## line through its translucent body (issue #30). The thin top cap closes the top.
func _add_wall_body(level: LevelDataScript, cell: Vector2i, base: Vector3) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = "Wall_%d_%d" % [cell.x, cell.y]
	instance.mesh = _wall_body_mesh(level, cell)
	instance.material_override = _wall_side_material
	instance.position = Vector3(base.x, wall_height * 0.5, base.z)
	add_child(instance)
	return instance


## Generated mesh of a wall body: one quad per exposed side face, no shared faces
## and no top or bottom face (the cap covers the top).
func _wall_body_mesh(level: LevelDataScript, cell: Vector2i) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var half := CELL_SIZE * 0.5
	var bottom := -wall_height * 0.5
	# [neighbour offset, bottom-left corner, bottom-right corner, outward normal].
	var faces: Array = [
		[Vector2i(1, 0), Vector3(half, bottom, half), Vector3(half, bottom, -half), Vector3.RIGHT],
		[Vector2i(-1, 0), Vector3(-half, bottom, -half), Vector3(-half, bottom, half), Vector3.LEFT],
		[Vector2i(0, 1), Vector3(-half, bottom, half), Vector3(half, bottom, half), Vector3.BACK],
		[Vector2i(0, -1), Vector3(half, bottom, -half), Vector3(-half, bottom, -half), Vector3.FORWARD],
	]
	for face: Array in faces:
		var offset: Vector2i = face[0]
		if _is_wall_cell(level, cell + offset):
			continue
		var bottom_left: Vector3 = face[1]
		var bottom_right: Vector3 = face[2]
		var normal: Vector3 = face[3]
		_add_wall_face(vertices, normals, indices, bottom_left, bottom_right, normal)
	return _triangle_mesh(vertices, normals, indices)


## Builds one generated triangle mesh from the given arrays, or an empty mesh when
## there is no face.
func _triangle_mesh(
	vertices: PackedVector3Array, normals: PackedVector3Array, indices: PackedInt32Array
) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	if vertices.is_empty():
		return mesh
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Appends one vertical wall face. `bottom_left` and `bottom_right` are the two
## bottom corners in the order that makes the face visible from outside the wall.
func _add_wall_face(
	vertices: PackedVector3Array,
	normals: PackedVector3Array,
	indices: PackedInt32Array,
	bottom_left: Vector3,
	bottom_right: Vector3,
	normal: Vector3
) -> void:
	var top_left := bottom_left + Vector3(0.0, wall_height, 0.0)
	var top_right := bottom_right + Vector3(0.0, wall_height, 0.0)
	var start := vertices.size()
	for vertex in [bottom_left, bottom_right, top_right, top_left]:
		vertices.append(vertex)
		normals.append(normal)
	for index in [start, start + 1, start + 2, start, start + 2, start + 3]:
		indices.append(index)


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
		_add_contact_shadow(crate, _crate_shadow_local_y(on_goal), crate_size * 0.5)


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
	_add_contact_shadow(instance, _player_shadow_local_y(), player_radius)


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
	return _add_box_to(self, size, centre, material, node_name)


func _add_box_to(
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
