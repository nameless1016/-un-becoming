class_name GhostSwap
extends Node
## Once the intro has been played the player is the ghost, and Blaire has left
## for the day. Add this node to a room where the player starts as PlayerBlaire:
## it puts the ghost in her place (after any SpawnPoint has placed her).

const GHOST_SCENE := preload("res://actors/player/ghost/player_ghost.tscn")
## Saved when the intro ends, when the player takes control of the ghost.
const SEEN_FLAG := "intro_seen"


func _ready() -> void:
	if SaveManager.get_flag(SEEN_FLAG):
		# Deferred, so SpawnPoints and StillPoints place Blaire first.
		_swap.call_deferred()


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
