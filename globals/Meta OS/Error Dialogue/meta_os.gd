extends Node

# Autoload singleton managing dialog spawning and player punishment.

# Update this path if the scene file is moved.
var window_scene: PackedScene = preload("res://globals/Meta OS/Error Dialogue/native_error_window.tscn")


func _ready() -> void:
	get_tree().root.gui_embed_subwindows = false


# Spawns a dialogue box and pauses execution until a choice is selected.
func show_dialog(title: String, message: String, buttons: Array[String], icon: Variant = null) -> String:
	while true:
		var win: NativeErrorWindow = window_scene.instantiate() as NativeErrorWindow
		add_child(win)
		win.setup(title, message, buttons, true, icon)
		
		var action: String = await win.closed
		
		# If the player pressed the X button, verify whether to punish or exit.
		if action == "__CLOSE_X__":
			if buttons.is_empty():
				return action
				
			var punish_win: NativeErrorWindow = window_scene.instantiate() as NativeErrorWindow
			add_child(punish_win)
			punish_win.setup("", "Clicking away doesn't do you any favors.", ["OK"], false)
			await punish_win.closed
		else:
			return action
			
	return ""


# Spawns an inescapable error popup.
func show_critical_error(title: String, message: String) -> void:
	var fatal_win: NativeErrorWindow = window_scene.instantiate() as NativeErrorWindow
	add_child(fatal_win)
	fatal_win.setup(title, message, ["OK"], false)
	await fatal_win.closed
