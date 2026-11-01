extends Marker2D
class_name SpawnPoint

## Where the player appears when a SceneDoor sends them here.
## Give it the same name as the door's target_spawn.

@export var spawn_name: String = ""


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	if spawn_name != "" and spawn_name == SceneDoor.pending_spawn:
		SceneDoor.pending_spawn = ""
		place_player.call_deferred()


func place_player() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		push_warning("SpawnPoint: no node in the 'player' group")
		return
	player.global_position = global_position
	# so the camera doesn't slide over from where the player used to be
	await get_tree().process_frame
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return
	if cam.has_method("snap_to_player"):
		cam.call("snap_to_player")
	else:
		cam.reset_smoothing()
