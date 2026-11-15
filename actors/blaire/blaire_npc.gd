class_name BlaireNpc
extends Node2D
## Blaire when she isn't the player: once the player is the ghost, this is the Blaire
## they follow around. She has Blaire's sprite and animations (taken from the player
## scene, so new art there shows up here too) and nothing else: no collision and no
## input. BlaireRoute and BlaireSpot create her and move her.

const BLAIRE_SCENE := preload("res://actors/player/player_blaire.tscn")

var facing: Vector2 = Vector2.DOWN

var _sprite: AnimatedSprite2D
var _walk: Tween


func _init() -> void:
	# Borrow the sprite node from the player scene, with its frames and offset.
	var body := BLAIRE_SCENE.instantiate()
	_sprite = body.get_node(^"Sprite") as AnimatedSprite2D
	_sprite.owner = null
	body.remove_child(_sprite)
	body.free()
	add_child(_sprite)


func _ready() -> void:
	# The borrowed sprite starts its own default animation when it enters the tree;
	# this puts back the way she was told to face before that.
	_play("idle")


## Stands still looking in [param direction]. Zero keeps the way she was facing.
func face(direction: Vector2) -> void:
	if direction != Vector2.ZERO:
		facing = direction
	_play("idle")


## Walks in a straight line to [param target] (global) at [param speed] pixels per
## second. Await it. She walks through things, so put the targets around furniture.
func walk_to(target: Vector2, speed: float) -> void:
	var distance := global_position.distance_to(target)
	if distance < 0.5 or speed <= 0.0:
		global_position = target
		return
	facing = target - global_position
	_play("walk")
	if _walk:
		_walk.kill()
	_walk = create_tween()
	_walk.tween_property(self, ^"global_position", target, distance / speed)
	await _walk.finished
	_play("idle")


func fade_out(seconds: float = 0.6) -> void:
	await create_tween().tween_property(self, ^"modulate:a", 0.0, seconds).finished


func _play(kind: String) -> void:
	var side := "down" if facing.y > 0 else "up"
	if absf(facing.x) > absf(facing.y):
		side = "right" if facing.x > 0 else "left"
	_sprite.play("%s_%s" % [kind, side])
