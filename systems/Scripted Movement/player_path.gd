extends Node
class_name PlayerPath

## Put Marker2D nodes under this, in order, and the player walks to each one on
## its own (no keyboard). Marker position = where the feet end up.
## It starts by itself, when the player steps into a trigger area, or when you call start().

signal finished

## Starts when the scene loads. Ignored if there's a trigger area
@export var autostart: bool = true
## An Area2D that starts the walk when the player steps into it
@export var trigger_area: Area2D
## Only lets it run one time, so walking back into the area doesn't redo it
@export var once: bool = true
## Seconds to wait before the player starts moving
@export var start_delay: float = 0.5
## Seconds to stand still at each marker
@export var wait_at_marker: float = 0.0
## Which way the player faces at the end. Zero leaves them facing how they were
@export var end_facing: Vector2 = Vector2.ZERO

var running: bool = false
var has_run: bool = false

func _ready() -> void:
	if trigger_area != null:
		trigger_area.body_entered.connect(_on_trigger_entered)
	elif autostart:
		start.call_deferred()

func _on_trigger_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		start()

func start() -> void:
	if running or (once and has_run):
		return
	running = true
	if start_delay > 0.0:
		await get_tree().create_timer(start_delay).timeout
	var player := get_tree().get_first_node_in_group("player")
	var state := player.get_node_or_null("FSM/Scripted") if player != null else null
	if state == null:
		push_warning("PlayerPath: couldn't find the player or its Scripted state")
		running = false
		return
	var steps: Array = []
	for child in get_children():
		if child is Marker2D:
			steps.append(state.walk_to(child.global_position))
			if wait_at_marker > 0.0:
				steps.append(state.wait(wait_at_marker))
	if end_facing != Vector2.ZERO:
		steps.append(state.face(end_facing))
	state.finished.connect(_on_finished, CONNECT_ONE_SHOT)
	state.play(steps)

func _on_finished() -> void:
	running = false
	has_run = true
	finished.emit()
