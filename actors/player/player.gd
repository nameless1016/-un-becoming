extends CharacterBody2D
class_name Player

@export_category("PLAYER MOVEMENT")
@export var MAX_SPEED : float = 80
@export var ACCELERATION : float = INF
@export var FRICTION : float = INF

var CUR_DIR : Vector2 = Vector2.DOWN
@onready var sprite: AnimatedSprite2D = %Sprite

func get_facing_string() -> String:
	if abs(CUR_DIR.x) > abs(CUR_DIR.y):
		return "right" if CUR_DIR.x > 0 else "left"
	else:
		return "down" if CUR_DIR.y > 0 else "up"
