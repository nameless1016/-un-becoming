extends Node
class_name PlayerPath

## Put Marker2D nodes under this, in order, and the player walks to each one on
## its own (no keyboard) when the scene starts. Marker position = where the feet end up.

signal finished

@export var autostart: bool = true
## Seconds to wait after the scene loads before the player starts moving
@export var start_delay: float = 0.5
## Seconds to stand still at each marker
@export var wait_at_marker: float = 0.0
## Which way the player faces at the end. Zero leaves them facing how they were
@export var end_facing: Vector2 = Vector2.ZERO

func _ready() -> void:
	if autostart:
		start.call_deferred()

func start() -> void:
	if start_delay > 0.0:
		await get_tree().create_timer(start_delay).timeout
	var player := get_tree().get_first_node_in_group("player")
	var state := player.get_node_or_null("FSM/Scripted") if player != null else null
	if state == null:
		push_warning("PlayerPath: couldn't find the player or its Scripted state")
		return
	var steps: Array = []
	for child in get_children():
		if child is Marker2D:
			steps.append(state.walk_to(child.global_position))
			if wait_at_marker > 0.0:
				steps.append(state.wait(wait_at_marker))
	if end_facing != Vector2.ZERO:
		steps.append(state.face(end_facing))
	state.finished.connect(finished.emit, CONNECT_ONE_SHOT)
	state.play(steps)
