@tool
extends WorldProp
class_name PropTelevision

func _ready() -> void:
	super._ready()
	# always usable, a room scene had it switched off
	if not Engine.is_editor_hint():
		can_interact = true


# using the computer opens the pause menu
func _on_interact(_who: Node2D) -> void:
	# looked up by path so this script still loads if the autoload is missing
	var pause_manager := get_node_or_null("/root/PauseManager")
	if pause_manager == null:
		push_warning("PauseManager isn't set up as an autoload")
		return
	pause_manager.open()
