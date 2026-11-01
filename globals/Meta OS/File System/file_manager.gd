extends Node

## Central File Inventory Singleton (FileManager).
## Manages collected files, item dock routing, and terminal command unlocking.

signal file_obtained(file: GameFile)
signal file_solved(file: GameFile)
signal command_unlocked(cmd_id: int)

var collected_files: Dictionary = {}
var database: FileDatabase = preload("res://globals/Meta OS/File System/master_file_database.tres")

# Command IDs: 1=Interpret, 2=Rearrange, 3=Decode, 4=Execute, 5=Intervene
var unlocked_commands: Dictionary = { 1: true, 2: false, 3: false, 4: true, 5: false }



var file_system_ui: FileSystemUI
var pause_menu: PauseMenuUI
var calendar_win: CalendarWindow
var allow_keybinds: bool = false


func _ready() -> void:
	file_hard()
	file_system_ui = FileSystemUI.new()
	add_child(file_system_ui)

	pause_menu = PauseMenuUI.new()
	add_child(pause_menu)

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


func _unhandled_input(event: InputEvent) -> void:
	if not allow_keybinds: return
	if event is InputEventKey and event.pressed and not event.is_echo():
		match event.keycode:
			KEY_Q:
				SoundBank.play_sfx("ui_click")
				file_system_ui.toggle_filesystem()
			KEY_T:
				SoundBank.play_sfx("ui_click")
				file_system_ui.toggle_terminal()
			KEY_C:
				SoundBank.play_sfx("ui_click")
				calendar_win.toggle_calendar()
			KEY_ESCAPE:
				SoundBank.play_sfx("ui_click")
				pause_menu.toggle_pause()


# THIS IS FOR SUBMISSION TO GAME JAM, HARDCODING SOME FILES SO PEOPLE CAN READ STUFF ON THEIR OWN
# func name idea is by JJ
func file_hard() -> void:
	obtain_file_by_id("item_hairpin")
	obtain_file_by_id("item_notebook")
	obtain_file_by_id("about_myself")
	obtain_file_by_id("about_blaire")
	obtain_file_by_id("about_the_order")
	obtain_file_by_id("about_apartment")
	obtain_file_by_id("about_ghost_machine")
	obtain_file_by_id("cipher_photo_piece_03")
	obtain_file_by_id("cipher_photo_piece_04")
	obtain_file_by_id("cipher_letter_pt06")
	obtain_file_by_id("cipher_letter_pt07")


## Unlocks a terminal command as the story progresses
func unlock_terminal_command(cmd_id: int) -> void:
	unlocked_commands[cmd_id] = true
	command_unlocked.emit(cmd_id)


func is_command_unlocked(cmd_id: int) -> bool:
	return unlocked_commands.get(cmd_id, false)


## Searches the database .tres by file_id and adds it to collected files
func obtain_file_by_id(fid: String) -> void:
	if collected_files.has(fid):
		return

	if not database:
		push_error("[FileManager] Database resource is missing!")
		return

	for f in database.all_files:
		if f and f.file_id == fid:
			collected_files[fid] = f
			file_obtained.emit(f)
			print("[FileManager] Obtained: ", f.filename)
			return

	push_warning("[FileManager] File ID not found in database: " + fid)


## Returns all files that belong in the right-side item dock
func get_item_dock_files() -> Array[GameFile]:
	var result: Array[GameFile] = []
	for file: GameFile in collected_files.values():
		if file.destination == GameFile.Destination.ITEM_DOCK or file.category == GameFile.Category.ITEM:
			result.append(file)
	return result


## Returns files for folder categories (Entry, About, Photo, Executable, Secret)
func get_files_by_category(cat: GameFile.Category) -> Array[GameFile]:
	var result: Array[GameFile] = []
	for file: GameFile in collected_files.values():
		if file.category == cat:
			result.append(file)
	return result


## Marks an encrypted file as solved
func solve_file(file_id: String) -> void:
	if collected_files.has(file_id):
		var file: GameFile = collected_files[file_id]
		file.is_solved = true
		file_solved.emit(file)
		print("[FileManager] Solved: ", file.filename)


## Resets all inventory and relocks ciphers when a time loop resets
func reset_progress() -> void:
	for file in collected_files.values():
		if file is GameFile:
			file.is_solved = false

	collected_files.clear()

	# Relock commands back to starting state (Command 1 unlocked, others locked)
	unlocked_commands = { 1: true, 2: false, 3: false, 4: false, 5: false }
	print("[FileManager] Progress reset for new time loop.")
