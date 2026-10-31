extends Node

## Central File Inventory Singleton (FileManager).
## Manages collected files, item dock routing, and terminal command unlocking.

signal file_obtained(file: GameFile)
signal file_solved(file: GameFile)
signal command_unlocked(cmd_id: int)

var collected_files: Dictionary = {}
var database: FileDatabase = preload("res://globals/Meta OS/File System/master_file_database.tres")

# Command IDs: 1=Interpret, 2=Rearrange, 3=Decode, 4=Execute, 5=Intervene
var unlocked_commands: Dictionary = { 1: true, 2: false, 3: false, 4: false, 5: false }


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
