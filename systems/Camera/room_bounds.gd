@tool
extends Node2D
class_name RoomBounds

## Defines rectangular spatial boundaries for a room or map sector.
##
## Registers within the 'room_bounds' group to inform cameras and minimap systems 
## of active room limits, and draws a visual debug outline within the 2D editor.

## Size of the room in pixels. The top-left corner corresponds to this node's global position.
@export var size: Vector2 = Vector2(2048, 1280):
	set(value):
		size = value
		queue_redraw()


func _enter_tree() -> void:
	add_to_group("room_bounds")


## Returns the calculated world-space rectangular area of this room.
func get_rect() -> Rect2:
	return Rect2(global_position, size)


func _draw() -> void:
	if Engine.is_editor_hint():
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 0), false, 8.0)
