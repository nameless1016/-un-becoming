class_name BlaireRoute
extends Node2D
## Blaire's way through a room once the player is the ghost. She waits at a stop; when
## the ghost comes close she says what's on her mind there, then walks on to the next
## stop and waits again. She only moves on when the ghost has caught up, so the player
## can look around for as long as they like.
##
## Set it up like Mike's PlayerPath: Marker2D children, in order.
## - A marker with the BlaireStop script is a place where she waits.
## - A plain Marker2D is a corner she walks through on the way.
## - Plain markers after the last stop are her way out: she walks them, then she's gone.
##
## Where she is comes from StoryProgress, so leaving the room (or opening a still) and
## coming back puts her at the stop she's waiting at. When every stop is done she isn't
## in the room any more.

## The route only runs once the story has reached this step (the player is the ghost).
@export var active_from: StringName = StoryProgress.A1_BEDROOM
## How fast she walks, in pixels per second.
@export var walk_speed: float = 45.0

@export_group("Exit Door")
## A door the ghost can't use until Blaire has left: the ghost follows her, not the
## other way around. Empty: no door is closed.
@export var exit_door: Area2D
## Shown (through MetaOS) when the ghost tries that door too early.
@export var door_message: String = "She hasn't left yet."
## How close to the door counts as trying it, in pixels.
@export var door_radius: float = 22.0

var _blaire: BlaireNpc
var _points: Array[Marker2D] = []
## The stop she's waiting at. Null while she talks or walks.
var _waiting_at: BlaireStop
var _door_closed: bool = false
## True from when the pop-up shows until the ghost steps away from the door again.
var _door_warned: bool = false
var _busy: bool = false


func _ready() -> void:
	set_process(false)
	# Deferred, so GhostSwap, SpawnPoints and StillPoints place the player first.
	_begin.call_deferred()


func _begin() -> void:
	if not StoryProgress.reached(active_from):
		return
	for child in get_children():
		if child is Marker2D:
			_points.append(child)
	var stop := _next_stop()
	if stop == null:
		return
	_close_door(true)
	_blaire = BlaireNpc.new()
	_blaire.name = "Blaire"
	get_parent().add_child(_blaire)
	_blaire.global_position = stop.global_position
	_blaire.face(stop.facing)
	_waiting_at = stop
	set_process(true)


func _process(_delta: float) -> void:
	if _busy or Dialogic.current_timeline != null:
		return
	var player := get_tree().get_first_node_in_group(&"player") as Node2D
	if player == null:
		return
	if _waiting_at and player.global_position.distance_to(_blaire.global_position) <= _waiting_at.notice_radius:
		_caught_up(player)
	elif _door_closed:
		_watch_door(player)


## The first stop the story hasn't been to yet, or null when she's done here.
func _next_stop() -> BlaireStop:
	for point in _points:
		var stop := point as BlaireStop
		if stop and not StoryProgress.reached(stop.step):
			return stop
	return null


func _caught_up(player: Node2D) -> void:
	var stop := _waiting_at
	_waiting_at = null
	StoryProgress.advance_to(stop.step)
	SaveManager.save_game()
	await _say(stop.timeline, player)
	# On through the markers after this stop, until the next stop or the end of the list.
	for index in range(_points.find(stop) + 1, _points.size()):
		await _blaire.walk_to(_points[index].global_position, walk_speed)
		var next := _points[index] as BlaireStop
		if next:
			_blaire.face(next.facing)
			_waiting_at = next
			return
	# No stop left: she's out of the room.
	await _blaire.fade_out()
	_blaire.queue_free()
	_close_door(false)
	set_process(false)


func _say(timeline: String, player: Node2D) -> void:
	if timeline.is_empty() or not Dialogic.timeline_exists(timeline):
		return
	_busy = true
	_hold(player, true)
	Dialogic.start(timeline)
	await Dialogic.timeline_ended
	_hold(player, false)
	_busy = false


func _watch_door(player: Node2D) -> void:
	var near := player.global_position.distance_to(exit_door.global_position) <= door_radius
	if not near:
		_door_warned = false
	elif not _door_warned:
		_door_warned = true
		_busy = true
		_hold(player, true)
		# Through MetaOS, the team's pop-up system. An empty title shows as "Info".
		await MetaOS.show_dialog("", door_message, ["OK"])
		_hold(player, false)
		_busy = false


func _close_door(closed: bool) -> void:
	if exit_door == null:
		return
	_door_closed = closed
	exit_door.set_deferred(&"monitoring", not closed)


## Stops the player where they stand while Blaire talks or a pop-up is up.
func _hold(player: Node2D, held: bool) -> void:
	if not is_instance_valid(player):
		return
	var fsm := player.get_node_or_null(^"FSM")
	if fsm:
		fsm.process_mode = Node.PROCESS_MODE_DISABLED if held else Node.PROCESS_MODE_INHERIT
	var body := player as Player
	if held and body:
		body.velocity = Vector2.ZERO
		body.sprite.play("idle_" + body.get_facing_string())
