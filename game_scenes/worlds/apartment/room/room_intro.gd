class_name RoomIntro
extends Node
## The end of the intro, in Blaire's room. Blaire gets up and walks out the door
## by herself, then the ghost appears beside the bed and the player controls the
## ghost from here on. Runs when the dream sends the player here ([member pending]).
##
## Once the intro has been seen, the room starts with the ghost in Blaire's place:
## she's already left for the day.

## Saved when the player takes control of the ghost; the main menu checks it.
const SEEN_FLAG := GhostSwap.SEEN_FLAG

## Set by the dream right before it loads this room.
static var pending: bool = false

## Blaire's way out: a PlayerPath (Mike's scripted walking) whose markers lead from
## the bed to just inside the door. Move the markers in the editor to change it.
@export var exit_path: PlayerPath
## Where Blaire is when she wakes up, beside the bed.
@export var wake_spot: Vector2 = Vector2(300, 166)
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
	blaire.global_position = wake_spot
	_set_points_enabled(false)
	await _wait(1.0)
	# She walks out on her own: PlayerPath drives her Scripted state, no input needed.
	if exit_path:
		exit_path.start()
		await exit_path.finished
	await create_tween().tween_property(blaire, ^"modulate:a", 0.0, 0.6).finished
	# Out of the "player" group, so nothing (camera, points) looks for her any more.
	blaire.remove_from_group(&"player")
	blaire.visible = false
	await _wait(1.5)

	var ghost := GhostSwap.put_in(_room, ghost_spot, blaire)
	ghost.get_node(^"FSM").process_mode = Node.PROCESS_MODE_DISABLED
	await _flicker_in(ghost)
	ghost.get_node(^"FSM").process_mode = Node.PROCESS_MODE_INHERIT
	_set_points_enabled(true)
	SaveManager.set_flag(SEEN_FLAG)
	SaveManager.save_game()


func _swap_in_ghost() -> void:
	var blaire := _room.get_node_or_null(^"PlayerBlaire") as Node2D
	if blaire:
		GhostSwap.put_in(_room, blaire.global_position, blaire)


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
