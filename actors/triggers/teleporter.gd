extends Area2D
class_name Teleporter

enum TeleportType {
	SAME_SCENE,
	CHANGE_SCENE
}

@export var teleport_type: TeleportType = TeleportType.SAME_SCENE

@export_group("Same Scene Settings")
@export var target_marker: Marker2D
@export var target_position: Vector2 = Vector2.ZERO

@export_group("Change Scene Settings")
@export_file("*.tscn") var target_scene_path: String = ""
@export var target_spawn_name: String = ""

func _ready() -> void:
	# Connect the collision signal
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	# Make sure it's the player entering
	if body is PlayerTopDown or body.name == "PlayerTopDown":
		match teleport_type:
			TeleportType.SAME_SCENE:
				if target_marker != null:
					body.global_position = target_marker.global_position
				else:
					body.global_position = target_position

				var cam = get_viewport().get_camera_2d()
				if cam != null and cam.has_method("snap_to_player"):
					cam.snap_to_player()

			TeleportType.CHANGE_SCENE:
				if target_scene_path != "":
					var transition = get_node_or_null("/root/SceneTransition")
					if transition != null:
						transition.change_scene(target_scene_path, target_spawn_name)
					else:
						get_tree().change_scene_to_file(target_scene_path)
