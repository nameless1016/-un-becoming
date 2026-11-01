@tool
extends WorldProp
class_name PropComputer

# using the computer opens the pause menu
func _on_interact(_who: Node2D) -> void:
	PauseManager.open()
