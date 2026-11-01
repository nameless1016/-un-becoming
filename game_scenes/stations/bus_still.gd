extends PointAndClickScene
## The bus still opens on the empty bus, then the passengers fade in, as if the
## ghost is only now noticing them. Their hotspots unlock once they're there.

const ARRIVE_LOCK := &"passengers_arriving"

@export var empty_hold: float = 1.0
@export var fade_time: float = 1.8

@onready var _empty_bus: CanvasItem = $EmptyBus


func _ready() -> void:
	super()
	lock_input(ARRIVE_LOCK)
	var tween := create_tween()
	tween.tween_interval(empty_hold)
	tween.tween_property(_empty_bus, ^"modulate:a", 0.0, fade_time).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func() -> void:
		_empty_bus.visible = false
		unlock_input(ARRIVE_LOCK))
