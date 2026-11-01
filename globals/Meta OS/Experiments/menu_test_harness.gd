extends Control

## Dedicated Menu and System Integration Test Harness.
## Use this scene to test:
## [Q] - File System Explorer
## [T] - Terminal Window
## [C] - Calendar Window
## [ESC] - Pause Menu
## [1] - Pick up Notebook (Item Dock)
## [2] - Pick up Secret Cipher (The Order Directive)
## [3] - Clear all inventory files
## [4] - Pick up Letter Part 7 and Unlock Decode Command
## [5] - Pick up Mother Profile
## [6] - Pick up Plushie Repair Manual and Unlock Rearrange Command
## [7] - Pick up Letter Part 4

var file_system_ui: FileSystemUI
var pause_menu: PauseMenuUI
var time_banner: TimeBannerUI
var calendar_win: CalendarWindow


func _ready() -> void:
	var main_win: Window = get_window()
	main_win.title = "SYSTEM TEST HARNESS // MENUS"
	main_win.size = Vector2i(960, 640)
	
	var screen_id: int = DisplayServer.get_primary_screen()
	var screen_origin: Vector2i = DisplayServer.screen_get_position(screen_id)
	var screen_size: Vector2i = DisplayServer.screen_get_size(screen_id)
	main_win.position = screen_origin + (screen_size - main_win.size) / 2
	
	get_tree().root.gui_embed_subwindows = false
	
	# Initialize subwindow UI systems.
	file_system_ui = FileSystemUI.new()
	add_child(file_system_ui)
	
	pause_menu = PauseMenuUI.new()
	add_child(pause_menu)
	
	time_banner = TimeBannerUI.new()
	add_child(time_banner)
	
	calendar_win = CalendarWindow.new()
	add_child(calendar_win)
	
	# Connect cross window signals.
	calendar_win.request_open_filesystem.connect(func():
		if calendar_win.visible:
			calendar_win.toggle_calendar()
		if not file_system_ui.is_open:
			file_system_ui.toggle_filesystem()
	)
	
	file_system_ui.request_open_calendar.connect(func():
		if file_system_ui.is_open:
			file_system_ui.toggle_filesystem()
		if not calendar_win.visible:
			calendar_win.toggle_calendar()
	)
	
	_create_test_ui()


func _create_test_ui() -> void:
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color("#0e1117")
	add_child(bg)
	
	var label := Label.new()
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.text = """=== MENU INTEGRATION TEST HARNESS ===

[Q] - Open / Close File System
[T] - Open Terminal (requires a file selected)
[C] - Open Calendar Window
[ESC] - Open Pause Menu

--- FILE PICKUP TESTS ---
[1] - Pick up Notebook (Item Dock)
[2] - Pick up Secret Cipher (The Order Directive)
[3] - Clear all inventory files
[4] - Pick up Letter Part 7 & Unlock Decode
[5] - Pick up Mother Dossier (About)
[6] - Pick up Plushie Manual & Unlock Rearrange
[7] - Pick up Letter Part 4 (Vigenère)"""
	
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Cartograph Mono", "Consolas", "monospace"])
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", 13)
	add_child(label)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.is_echo():
		match event.keycode:
			KEY_Q:
				file_system_ui.toggle_filesystem()
			KEY_T:
				file_system_ui.toggle_terminal()
			KEY_C:
				calendar_win.toggle_calendar()
			KEY_ESCAPE:
				pause_menu.toggle_pause()
			KEY_1:
				_test_pickup_notebook()
			KEY_2:
				_test_pickup_cipher()
			KEY_3:
				_test_clear_inventory()
			KEY_4:
				_test_pickup_letter_pt07()
			KEY_5:
				_test_pickup_about_mother()
			KEY_6:
				_test_pickup_plushie_manual()
			KEY_7:
				_test_pickup_letter_pt04()


func _test_pickup_notebook() -> void:
	FileManager.obtain_file_by_id("item_notebook")
	await MetaOS.show_dialog("Obtained", "notebook.dat", ["CLOSE"], "txt")


func _test_pickup_cipher() -> void:
	FileManager.obtain_file_by_id("cipher_order")
	await MetaOS.show_dialog("Obtained", "the_order_directive.txt", ["CLOSE"], "txt")


func _test_pickup_letter_pt07() -> void:
	FileManager.obtain_file_by_id("cipher_letter_pt07")
	FileManager.unlock_terminal_command(3)
	await MetaOS.show_dialog("Obtained", "letter_pt07.enc", ["CLOSE"], "txt")


func _test_pickup_about_mother() -> void:
	# Obtains the Mother dossier for the About folder.
	FileManager.obtain_file_by_id("about_mother")
	await MetaOS.show_dialog("Obtained", "Mother.info", ["CLOSE"], "txt")


func _test_pickup_plushie_manual() -> void:
	# Obtains the plushie repair cipher.
	FileManager.obtain_file_by_id("cipher_plushie_manual")
	
	# Unlocks command two which represents Rearrange.
	FileManager.unlock_terminal_command(2)
	
	await MetaOS.show_dialog("Obtained", "plushie_repair.enc", ["CLOSE"], "txt")


func _test_pickup_letter_pt04() -> void:
	# Obtains part four of the letter.
	FileManager.obtain_file_by_id("cipher_letter_pt04")
	await MetaOS.show_dialog("Obtained", "letter_pt04.enc", ["CLOSE"], "txt")


func _test_clear_inventory() -> void:
	FileManager.collected_files.clear()
	print("[TestHarness] Cleared inventory buffer.")
