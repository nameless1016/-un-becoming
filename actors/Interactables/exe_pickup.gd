@tool
extends WorldProp
class_name ExePickup

## A little item you pick up. Interact and it fades out and goes away.

## Fires when the player picks it up, connect to this from the level if you want.
signal collected

func _init() -> void:
	can_interact = true

func _on_interact(who: Node2D) -> void:
	can_interact = false
	collected.emit()
	on_collected(who)
	vanish()

# not made yet, fill this in later
func on_collected(_who: Node2D) -> void:
	print("here supposedly")
	pass

func vanish() -> void:
	var spr := get_node_or_null("Sprite2D") as Sprite2D
	if spr == null:
		queue_free()
		return
	var tween := create_tween()
	tween.tween_property(spr, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)
