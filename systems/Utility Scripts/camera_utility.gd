extends Camera2D

## Drag your player node here, or leave empty to auto-find
@export var player: Node2D
@export var transition_duration: float = 0.35

var screen_size: Vector2
var current_grid_pos: Vector2i = Vector2i(0, 0)
var tween: Tween

func _ready() -> void:
	# Dividing by zoom accounts for your 0.25 zoom factor
	screen_size = get_viewport_rect().size / zoom
	
	if player == null:
		player = get_parent().get_node_or_null("TopDownPlayer")
	
	if player != null:
		current_grid_pos = get_player_grid_coord()
		global_position = get_camera_target_pos(current_grid_pos)

func _process(_delta: float) -> void:
	if player == null:
		return
	
	var player_grid = get_player_grid_coord()
	
	if player_grid != current_grid_pos:
		current_grid_pos = player_grid
		slide_to_cell(current_grid_pos)

func get_player_grid_coord() -> Vector2i:
	var gx = floor(player.global_position.x / screen_size.x)
	var gy = floor(player.global_position.y / screen_size.y)
	return Vector2i(int(gx), int(gy))

func get_camera_target_pos(grid: Vector2i) -> Vector2:
	return Vector2(
		(grid.x * screen_size.x) + (screen_size.x * 0.5),
		(grid.y * screen_size.y) + (screen_size.y * 0.5)
	)

func slide_to_cell(grid: Vector2i) -> void:
	var target = get_camera_target_pos(grid)
	
	if tween and tween.is_running():
		tween.kill()
	
	tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "global_position", target, transition_duration)

func snap_to_player() -> void:
	# jump straight to the player's cell, no sliding
	if tween and tween.is_running():
		tween.kill()
	current_grid_pos = get_player_grid_coord()
	global_position = get_camera_target_pos(current_grid_pos)
