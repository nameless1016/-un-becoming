@tool
extends Node2D
class_name RoomBounds

## Size of the room in pixels. The top left corner is wherever this node sits
@export var size: Vector2 = Vector2(2048, 1280):
	set(value):
		size = value
		queue_redraw()

func _enter_tree() -> void:
	# done here and not in _ready so the camera can already find it
	add_to_group("room_bounds")

func get_rect() -> Rect2:
	return Rect2(global_position, size)

func _draw() -> void:
	if Engine.is_editor_hint():
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 0), false, 8.0)
