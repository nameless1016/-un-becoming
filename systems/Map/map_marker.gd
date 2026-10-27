extends Control
class_name MapMarker

## The orange "you are here" bubble with a little train in it

var bob: float = 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(84, 100)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_delta: float) -> void:
	# small up and down bounce so it feels alive
	bob = sin(Time.get_ticks_msec() / 1000.0 * 4.0) * 4.0
	queue_redraw()

func _draw() -> void:
	var c := Vector2(size.x * 0.5, 40.0 + bob)

	# tail pointing down at the place name
	draw_colored_polygon(PackedVector2Array([c + Vector2(-16, 28), c + Vector2(16, 28), c + Vector2(0, 56)]), Color(1.0, 0.55, 0.05))

	draw_circle(c, 38.0, Color(1.0, 0.55, 0.05))
	draw_circle(c, 33.0, Color(1.0, 0.85, 0.2))
	draw_circle(c, 29.0, Color(0.97, 0.97, 1.0))

	# the train: body, roof stripe, windows, wheels
	draw_rect(Rect2(c + Vector2(-20, -14), Vector2(40, 26)), Color(0.2, 0.4, 0.85))
	draw_rect(Rect2(c + Vector2(-20, -14), Vector2(40, 6)), Color(0.85, 0.9, 1.0))
	for i in 3:
		draw_rect(Rect2(c + Vector2(-16 + i * 12, -5), Vector2(9, 8)), Color(0.9, 0.95, 1.0))
	draw_circle(c + Vector2(-11, 14), 4.0, Color(0.15, 0.15, 0.2))
	draw_circle(c + Vector2(11, 14), 4.0, Color(0.15, 0.15, 0.2))
