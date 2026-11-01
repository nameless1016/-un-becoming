extends Node
## Makes the ghost hover: bobs its sprite gently up and down.
## Uses ghost_sheet.png, drawn in the same layout as Blaire's sheet.

@export var height: float = 1.5
@export var period: float = 2.4

var _sprite: Node2D
var _base_y: float
var _time: float = 0.0


func _ready() -> void:
	_sprite = get_parent().get_node(^"Sprite") as Node2D
	_base_y = _sprite.position.y


func _process(delta: float) -> void:
	_time += delta
	_sprite.position.y = _base_y + sin(_time * TAU / period) * height
