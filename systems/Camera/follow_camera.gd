extends Camera2D
class_name FollowCamera

## Drag your player node here, or leave empty to auto-find
@export var player: Node2D
## Group the player is in, used when no player is dragged in
@export var player_group: StringName = &"player"

var current_room: RoomBounds

func _ready() -> void:
	# update in physics so it matches the player and doesn't jitter
	process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	
	# always center on the player, in case something else set the anchor or offset
	anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER
	offset = Vector2.ZERO
	
	if player == null:
		player = get_tree().get_first_node_in_group(player_group) as Node2D
	
	snap_to_player()

func _physics_process(_delta: float) -> void:
	if player == null:
		# the player might not be in the tree yet, keep looking
		player = get_tree().get_first_node_in_group(player_group) as Node2D
		if player == null:
			return
		snap_to_player()
	
	global_position = player.global_position
	
	# if the player walked into a different room, switch the limits
	var room = find_room()
	if room != null and room != current_room:
		set_room(room)

func find_room() -> RoomBounds:
	for node in get_tree().get_nodes_in_group("room_bounds"):
		var room = node as RoomBounds
		if room != null and room.get_rect().has_point(player.global_position):
			return room
	return null

func set_room(room: RoomBounds) -> void:
	current_room = room
	var rect = room.get_rect()
	var view = get_viewport_rect().size / zoom
	
	# if the room is smaller than the screen, pad the limits so the room stays centered
	var pad_x = maxf(0.0, view.x - rect.size.x) * 0.5
	var pad_y = maxf(0.0, view.y - rect.size.y) * 0.5
	
	limit_left = int(rect.position.x - pad_x)
	limit_right = int(rect.end.x + pad_x)
	limit_top = int(rect.position.y - pad_y)
	limit_bottom = int(rect.end.y + pad_y)

func snap_to_player() -> void:
	# jump straight to the player, no sliding
	if player == null:
		return
	global_position = player.global_position
	var room = find_room()
	if room != null:
		set_room(room)
	force_update_scroll()
	reset_smoothing()
