class_name RoomIntro
extends Node
## The end of the intro, in Blaire's room. Blaire gets up and walks out the door
## by herself, then the ghost appears beside the bed and the player controls the
## ghost from here on. Runs when the dream sends the player here ([member pending]).
##
## Once the intro has been seen, the room starts with the ghost in Blaire's place:
## she's already left for the day.

const GHOST_SCENE := preload("res://actors/player/ghost/player_ghost.tscn")
## Saved when the player takes control of the ghost; the main menu checks it.
const SEEN_FLAG := "intro_seen"
const WALK_SPEED := 45.0

## Set by the dream right before it loads this room.
static var pending: bool = false

## Blaire's way out, from below the bed to the door.
@export var exit_path: Array[Vector2] = [Vector2(330, 182), Vector2(358, 192)]
## Where the ghost appears, beside the bed.
@export var ghost_spot: Vector2 = Vector2(318, 162)

@onready var _room: Node = get_parent()


func _ready() -> void:
	if pending:
		pending = false
		_play_intro.call_deferred()
	elif SaveManager.get_flag(SEEN_FLAG):
		# Deferred, so a StillPoint can first put the player back where they were.
		_swap_in_ghost.call_deferred()


func _play_intro() -> void:
	var blaire := _room.get_node(^"PlayerBlaire") as Player
	_set_points_enabled(false)
	# She moves on her own: no input, no state machine.
	blaire.get_node(^"FSM").process_mode = Node.PROCESS_MODE_DISABLED
	await _wait(1.0)
	for target in exit_path:
		await _walk(blaire, target)
	blaire.sprite.play(&"idle_right")
	await create_tween().tween_property(blaire, ^"modulate:a", 0.0, 0.6).finished
	# Out of the "player" group, so nothing (camera, points) looks for her any more.
	blaire.remove_from_group(&"player")
	blaire.visible = false
	await _wait(1.5)

	var ghost := _spawn_ghost(ghost_spot, blaire)
	ghost.get_node(^"FSM").process_mode = Node.PROCESS_MODE_DISABLED
	await _flicker_in(ghost)
	ghost.get_node(^"FSM").process_mode = Node.PROCESS_MODE_INHERIT
	_set_points_enabled(true)
	SaveManager.set_flag(SEEN_FLAG)
	SaveManager.save_game()


func _swap_in_ghost() -> void:
	var blaire := _room.get_node_or_null(^"PlayerBlaire") as Node2D
	if blaire:
		_spawn_ghost(blaire.global_position, blaire)


## Adds the ghost, points the camera at it and removes [param replacing].
func _spawn_ghost(at: Vector2, replacing: Node) -> Node2D:
	var ghost := GHOST_SCENE.instantiate() as Node2D
	ghost.global_position = at
	_room.add_child(ghost)
	var camera := _room.get_node_or_null(^"WorldCameraComponent")
	if camera and &"player" in camera:
		camera.set(&"player", ghost)
	replacing.queue_free()
	return ghost


func _walk(body: Player, target: Vector2) -> void:
	var step := target - body.global_position
	body.CUR_DIR = Vector2(signf(step.x), 0) if absf(step.x) > absf(step.y) else Vector2(0, signf(step.y))
	body.sprite.play(StringName("walk_" + body.get_facing_string()))
	await create_tween().tween_property(body, ^"global_position", target, step.length() / WALK_SPEED).finished


## Fades in unsteadily, like something that isn't quite here.
func _flicker_in(ghost: Node2D) -> void:
	ghost.modulate.a = 0.0
	var tween := create_tween()
	for alpha in [0.5, 0.0, 0.7, 0.2, 0.9, 0.5, 1.0]:
		tween.tween_property(ghost, ^"modulate:a", alpha, 0.12)
	await tween.finished


func _set_points_enabled(enabled: bool) -> void:
	var points := _room.get_node_or_null(^"PointsOfInterest")
	if points == null:
		return
	for point in points.get_children():
		if &"can_interact" in point:
			point.set(&"can_interact", enabled)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
