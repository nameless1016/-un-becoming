extends CanvasLayer

## How long each half of the fade takes, in seconds
@export var fade_time: float = 0.3

var rect: ColorRect
var busy: bool = false

func _ready() -> void:
	layer = 100
	# keeps running while the game is paused, otherwise the fade would freeze
	process_mode = Node.PROCESS_MODE_ALWAYS

	rect = ColorRect.new()
	rect.color = Color.BLACK
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.modulate.a = 0.0
	add_child(rect)

func change_scene(path: String, spawn_name: String = "") -> void:
	if busy:
		return
	busy = true

	# freeze everything so the player can't walk around during the fade
	get_tree().paused = true
	await fade_to(1.0)

	get_tree().change_scene_to_file(path)
	# the swap happens at the end of the frame, so wait a couple frames for the new scene
	await get_tree().process_frame
	await get_tree().process_frame

	place_player(spawn_name)
	get_tree().paused = false

	await fade_to(0.0)
	busy = false

func fade_to(alpha: float) -> void:
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(rect, "modulate:a", alpha, fade_time)
	await tween.finished

func place_player(spawn_name: String) -> void:
	# empty name means leave the player wherever the new scene put them
	if spawn_name == "":
		return

	var scene = get_tree().current_scene
	if scene == null:
		return

	var player = scene.get_node_or_null("TopDownPlayer")
	var spawn = scene.get_node_or_null("Spawns/" + spawn_name)
	if player == null or spawn == null:
		push_warning("SceneTransition: couldn't find TopDownPlayer or Spawns/" + spawn_name)
		return

	player.global_position = spawn.global_position

	var cam = get_viewport().get_camera_2d()
	if cam != null and cam.has_method("snap_to_player"):
		cam.snap_to_player()
