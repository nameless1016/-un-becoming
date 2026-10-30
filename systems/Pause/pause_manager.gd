extends Node
## Autoload this as "PauseManager"

var menu: PauseMenuUI

func _ready() -> void:
	# keeps working while the game is paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	menu = PauseMenuUI.new()
	add_child(menu)

func _unhandled_input(event: InputEvent) -> void:
	# the menu closes itself with esc, this only opens it
	if event.is_action_pressed("ui_cancel") and not menu.visible:
		menu.toggle_pause()
		get_viewport().set_input_as_handled()
