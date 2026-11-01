@tool
extends WorldProp
class_name PropComputer

func _ready() -> void:
	super._ready()
	# always usable, a room scene had it switched off
	if not Engine.is_editor_hint():
		can_interact = true


# using the computer opens the pause menu
func _on_interact(_who: Node2D) -> void:
	# looked up by path so this script still loads if the autoload is missing
	SoundBank.play_sfx("ui_click")
	FileManager.file_system_ui.toggle_filesystem()
