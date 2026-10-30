extends Node

# Central display manager handling fullscreen, borderless, and windowed modes.

enum DisplayMode { FULLSCREEN, BORDERLESS, WINDOWED }

var current_mode: DisplayMode = DisplayMode.WINDOWED


func _ready() -> void:
	# Keep subwindows floating outside the main window.
	get_tree().root.gui_embed_subwindows = false


# Sets the game window display mode for settings menus.
func set_display_mode(mode: DisplayMode) -> void:
	current_mode = mode
	var main_win: Window = get_tree().root.get_window()
	
	match mode:
		DisplayMode.FULLSCREEN:
			main_win.borderless = false
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)
		DisplayMode.BORDERLESS:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
			main_win.borderless = true
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		DisplayMode.WINDOWED:
			force_drop_to_windowed()


# Drops the game out of fullscreen into a centered window on the desktop.
func force_drop_to_windowed(target_size: Vector2i = Vector2i(1020, 680)) -> void:
	var main_win: Window = get_tree().root.get_window()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	main_win.borderless = false
	main_win.size = target_size
	
	var screen_id: int = DisplayServer.get_primary_screen()
	var screen_origin: Vector2i = DisplayServer.screen_get_position(screen_id)
	var screen_size: Vector2i = DisplayServer.screen_get_size(screen_id)
	main_win.position = screen_origin + (screen_size - target_size) / 2
	
	DisplayServer.window_move_to_foreground(DisplayServer.MAIN_WINDOW_ID)
	main_win.grab_focus()
