extends Area2D
class_name Teleporter

## Handles player teleportation across locations or scenes.
##
## Supports moving the player within the current room/map via target markers,
## or transitioning between separate scene files while updating the camera view.

enum TeleportType {
	SAME_SCENE,
	CHANGE_SCENE
}

@export var teleport_type: TeleportType = TeleportType.SAME_SCENE

@export_group("Same Scene Settings")
## Target Marker2D to teleport the player to within the current scene.
@export var target_marker: Marker2D
## Absolute position to teleport the player to if no target marker is provided.
@export var target_position: Vector2 = Vector2.ZERO

@export_group("Change Scene Settings")
## Path to the target scene (.tscn) to load.
@export_file("*.tscn") var target_scene_path: String = ""
## Name of the spawn marker in the target scene to place the player at.
@export var target_spawn_name: String = ""


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body is PlayerTopDown or body.name == "PlayerTopDown":
		match teleport_type:
			TeleportType.SAME_SCENE:
				if target_marker != null:
					body.global_position = target_marker.global_position
				else:
					body.global_position = target_position

				var cam := get_viewport().get_camera_2d()
				if cam != null and cam.has_method("snap_to_player"):
					cam.snap_to_player()

			TeleportType.CHANGE_SCENE:
				if target_scene_path != "":
					var transition := get_node_or_null("/root/SceneTransition")
					if transition != null:
						transition.change_scene(target_scene_path, target_spawn_name)
					else:
						get_tree().change_scene_to_file(target_scene_path)
