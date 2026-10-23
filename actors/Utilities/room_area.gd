extends Area2D
class_name RoomArea

## Reference to the camera in the scene (drag your Camera2D here or let it auto-find)
@export var camera: Camera2D

## Duration of the slide transition in seconds
@export var transition_duration: float = 0.4

@onready var collision_shape: CollisionShape2D = $CollisionShape2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if camera == null:
		camera = get_viewport().get_camera_2d()

func _on_body_entered(body: Node2D) -> void:
	# Check if the colliding node is the player
	if body is PlayerTopDown or body.name == "PlayerTopDown":
		transition_to_this_room()

func transition_to_this_room() -> void:
	if camera == null:
		return
	
	# The center of this RoomArea defines where the camera should center
	var target_pos = global_position
	
	# Create a smooth transition tween
	var tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(camera, "global_position", target_pos, transition_duration)
