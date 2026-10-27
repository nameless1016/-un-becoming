extends Node

# Central singleton tracking all collected files and unlocked commands.

signal file_obtained(file: GameFile)
signal file_solved(file: GameFile)
signal command_unlocked(cmd_id: int)

var collected_files: Dictionary = {}

# Unlocked status for terminal commands.
# 1 is Interpret, 2 is Rearrange, 3 is Decode, 4 is Execute, 5 is Intervene, 6 is Close.
var unlocked_commands: Dictionary = {
	1: true,
	2: true,
	3: true,
	4: false,
	5: true,
	6: true
}


# Call this function to unlock a terminal command during the story.
func unlock_terminal_command(cmd_id: int) -> void:
	unlocked_commands[cmd_id] = true
	command_unlocked.emit(cmd_id)


# Returns whether a terminal command is currently unlocked.
func is_command_unlocked(cmd_id: int) -> bool:
	return unlocked_commands.get(cmd_id, false)


# Adds a file to the inventory dictionary and emits a signal.
func obtain_file(file: GameFile) -> bool:
	if not file or collected_files.has(file.file_id):
		return false
	collected_files[file.file_id] = file
	file_obtained.emit(file)
	return true


# Checks if a file exists in the inventory.
func has_file(file_id: String) -> bool:
	return collected_files.has(file_id)


# Returns an array of files matching a specific category.
func get_files_by_category(cat: GameFile.Category) -> Array[GameFile]:
	var result: Array[GameFile] = []
	for file: GameFile in collected_files.values():
		if file.category == cat:
			result.append(file)
	return result


# Marks a file as solved and alerts listening UI elements.
func solve_file(file_id: String) -> void:
	if collected_files.has(file_id):
		var file: GameFile = collected_files[file_id]
		file.is_solved = true
		file_solved.emit(file)
