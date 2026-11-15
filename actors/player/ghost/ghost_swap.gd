class_name GhostSwap
extends Node
## Once the intro has been played the player is the ghost, and Blaire has left
## for the day. Add this node to a room where the player starts as PlayerBlaire:
## it puts the ghost in her place (after any SpawnPoint has placed her).

const GHOST_SCENE := preload("res://actors/player/ghost/player_ghost.tscn")


## The room's PlayerPaths (scripted walks) were made for Blaire, like her walk to her
## seat on the bus. With this on they don't run for the ghost.
@export var stop_player_paths: bool = true


func _ready() -> void:
	if StoryProgress.reached(StoryProgress.A1_BEDROOM):
		if stop_player_paths:
			_stop_paths()
		# Deferred, so SpawnPoints and StillPoints place Blaire first.
		_swap.call_deferred()


## Marks every PlayerPath in the room as already walked, so none of them starts.
func _stop_paths() -> void:
	for node in get_parent().find_children("*", "", true, false):
		var path := node as PlayerPath
		if path:
			path.once = true
			path.has_run = true


func _swap() -> void:
	var blaire := get_parent().get_node_or_null(^"PlayerBlaire") as Node2D
	if blaire:
		put_in(get_parent(), blaire.global_position, blaire)


## Adds the ghost to [param room] at [param at], points the room's camera at it
## and removes [param replacing].
static func put_in(room: Node, at: Vector2, replacing: Node) -> Node2D:
	var ghost := GHOST_SCENE.instantiate() as Node2D
	ghost.global_position = at
	room.add_child(ghost)
	for camera in room.find_children("*", "Camera2D", true, false):
		# Mike's follow camera uses "player", the template's world camera "target".
		if &"player" in camera:
			camera.set(&"player", ghost)
		if &"target" in camera:
			camera.set(&"target", ghost)
	replacing.queue_free()
	return ghost
