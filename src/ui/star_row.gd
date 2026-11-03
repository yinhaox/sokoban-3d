class_name StarRow
extends Control

## Three star marks for the victory panel. Shape carries the rating: earned
## stars are filled polygons, missing stars are outlines, so the result does not
## depend on colour alone (design/accessibility.md "shape contract").
##
## The colours come from the UI theme (`StarRow/filled` and `StarRow/empty`), so
## the panel carries no styling of its own.

const STAR_COUNT := 3
const STAR_POINTS := 5
const INNER_RADIUS_RATIO := 0.45
const OUTLINE_WIDTH_PX := 2.0
const START_ANGLE := -PI * 0.5

@export var star_size: float = UiTheme.MIN_TARGET_PX
@export var gap: float = 16.0

var stars: int = 0


func _ready() -> void:
	_apply_minimum_size()
	queue_redraw()


## Sets how many of the three marks are filled. Values outside 0..3 clamp.
func set_stars(count: int) -> void:
	stars = clampi(count, 0, STAR_COUNT)
	_apply_minimum_size()
	queue_redraw()


func _apply_minimum_size() -> void:
	custom_minimum_size = Vector2(
		star_size * float(STAR_COUNT) + gap * float(STAR_COUNT - 1), star_size
	)


func _draw() -> void:
	var filled_color := get_theme_color("filled", "StarRow")
	var empty_color := get_theme_color("empty", "StarRow")
	for index: int in STAR_COUNT:
		var centre := Vector2(star_size * 0.5 + float(index) * (star_size + gap), star_size * 0.5)
		var earned := index < stars
		_draw_star(centre, star_size * 0.5, filled_color if earned else empty_color, earned)


func _draw_star(
	centre: Vector2, radius: float, color: Color, filled: bool
) -> void:
	var points := PackedVector2Array()
	for index: int in STAR_POINTS * 2:
		var angle := START_ANGLE + float(index) * PI / float(STAR_POINTS)
		var point_radius := radius if index % 2 == 0 else radius * INNER_RADIUS_RATIO
		points.append(centre + Vector2(cos(angle), sin(angle)) * point_radius)
	if filled:
		draw_colored_polygon(points, color)
		return
	points.append(points[0])
	draw_polyline(points, color, OUTLINE_WIDTH_PX, true)
