extends Control
class_name MapCanvas

## Draws the whole fake town map in code so no art is needed yet
## Later you can swap this for a real map image (a TextureRect works fine)

const SEED_VALUE := 7
const ROAD := Color(0.76, 0.78, 0.80)
const WATER := Color(0.42, 0.74, 0.88)
const BANK := Color(0.55, 0.80, 0.42)
const FOREST_BASE := Color(0.14, 0.36, 0.18)

## river path, in 0 to 1 screen coordinates
const RIVER = [
	Vector2(0.80, -0.05),
	Vector2(0.78, 0.15),
	Vector2(0.88, 0.35),
	Vector2(0.94, 0.55),
	Vector2(1.04, 0.72),
]

## parks as x, y, width, height in 0 to 1 screen coordinates
const PARKS = [
	Rect2(0.03, 0.28, 0.12, 0.20),
	Rect2(0.46, 0.08, 0.08, 0.12),
]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var s := size
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED_VALUE

	# whole screen starts as road, buildings get drawn on top of it
	draw_rect(Rect2(Vector2.ZERO, s), ROAD)

	var river_pts := PackedVector2Array()
	for p in RIVER:
		river_pts.append(p * s)

	var forest_center := Vector2(0.72, 0.84) * s
	var forest_radius := Vector2(0.36, 0.30) * s

	var park_rects: Array[Rect2] = []
	for r in PARKS:
		park_rects.append(Rect2(r.position * s, r.size * s))

	# city blocks
	var cell := 34.0
	var y := 0.0
	while y < s.y:
		var x := 0.0
		while x < s.x:
			var p := Vector2(x, y) + Vector2(cell, cell) * 0.5
			var skip := in_ellipse(p, forest_center, forest_radius)
			skip = skip or dist_to_line(p, river_pts) < 75.0
			for pr in park_rects:
				if pr.grow(10.0).has_point(p):
					skip = true
			if not skip and rng.randf() < 0.85:
				var w := rng.randf_range(16.0, 26.0)
				var h := rng.randf_range(14.0, 24.0)
				var shade := rng.randf()
				var base := Color(0.55, 0.62, 0.72).lerp(Color(0.78, 0.80, 0.84), shade)
				var rect := Rect2(p - Vector2(w, h) * 0.5, Vector2(w, h))
				# darker rect is the side wall, lighter one on top is the roof
				draw_rect(rect, base.darkened(0.3))
				draw_rect(Rect2(rect.position, Vector2(w, h - 5.0)), base)
			x += cell
		y += cell

	# parks
	for pr in park_rects:
		draw_rect(pr, Color(0.45, 0.72, 0.38))
		for i in 14:
			var tp := pr.position + Vector2(rng.randf() * pr.size.x, rng.randf() * pr.size.y)
			draw_circle(tp, rng.randf_range(8.0, 13.0), Color(0.22, 0.52, 0.26))

	# main avenue
	var avenue := PackedVector2Array([Vector2(0.0, 0.66) * s, Vector2(0.45, 0.52) * s, Vector2(0.80, 0.30) * s])
	draw_polyline(avenue, Color(0.55, 0.57, 0.60), 20.0, true)
	draw_polyline(avenue, Color(0.93, 0.94, 0.95), 14.0, true)

	# river with grassy banks
	draw_polyline(river_pts, BANK, 80.0, true)
	for pt in river_pts:
		draw_circle(pt, 40.0, BANK)
	draw_polyline(river_pts, WATER, 52.0, true)
	for pt in river_pts:
		draw_circle(pt, 26.0, WATER)

	# forest and hill
	draw_colored_polygon(ellipse_points(forest_center, forest_radius, 48), FOREST_BASE)
	for i in 320:
		var a := rng.randf() * TAU
		var d := sqrt(rng.randf())
		var pos := forest_center + Vector2(cos(a), sin(a)) * d * forest_radius
		var tone := rng.randf()
		draw_circle(pos, rng.randf_range(10.0, 18.0), Color(0.16, 0.42, 0.20).lerp(Color(0.28, 0.58, 0.30), tone))

	# lake inside the forest
	var lake := ellipse_points(Vector2(0.88, 0.80) * s, Vector2(0.07, 0.06) * s, 40)
	draw_colored_polygon(lake, WATER)
	var lake_border := lake.duplicate()
	lake_border.append(lake_border[0])
	draw_polyline(lake_border, Color(0.25, 0.55, 0.72), 4.0, true)

	# tower on a little grass platform
	var base_pt := Vector2(0.66, 0.74) * s
	var top := base_pt + Vector2(0, -150)
	var left := base_pt + Vector2(-34, 0)
	var right := base_pt + Vector2(34, 0)
	var iron := Color(0.25, 0.27, 0.30)
	draw_rect(Rect2(base_pt + Vector2(-70, -8), Vector2(140, 26)), Color(0.50, 0.68, 0.32))
	draw_line(left, top, iron, 5.0)
	draw_line(right, top, iron, 5.0)
	for i in range(1, 6):
		var t := i / 6.0
		var t_next := (i + 1) / 6.0
		var pl := left.lerp(top, t)
		var pr2 := right.lerp(top, t)
		draw_line(pl, pr2, iron, 3.0)
		draw_line(pl, right.lerp(top, t_next), iron, 2.0)
	draw_circle(top, 6.0, Color(1.0, 0.7, 0.1))

func in_ellipse(p: Vector2, center: Vector2, radius: Vector2) -> bool:
	var d := (p - center) / radius
	return d.length_squared() < 1.0

func dist_to_line(p: Vector2, pts: PackedVector2Array) -> float:
	var best := INF
	for i in range(pts.size() - 1):
		var q := Geometry2D.get_closest_point_to_segment(p, pts[i], pts[i + 1])
		best = minf(best, p.distance_to(q))
	return best

func ellipse_points(center: Vector2, radius: Vector2, count: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in count:
		var a := TAU * i / count
		pts.append(center + Vector2(cos(a), sin(a)) * radius)
	return pts
