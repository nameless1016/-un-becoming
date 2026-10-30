extends Node

## Manages persistent game state, JSON serialization, and level transition spawns.
##
## Autoloaded as "SaveManager". Tracks session play time, narrative story flags,
## current scene locations, and deferred player placement upon entering scenes.

## Emitted when the game state is successfully written to disk.
signal saved
## Emitted when game data is successfully loaded into memory from disk.
signal loaded

const SAVE_PATH := "user://save.json"

const LIVING_ROOM_SCENE := "res://levels/living_room.tscn"
const LIVING_ROOM_SPAWN := "LivingRoomSpawn"

## Determines which location to prioritize when booting or resuming a session.
enum StartMode {
	ALWAYS_LIVING_ROOM,
	LAST_PLACE,
	CUSTOM
}

var start_mode: StartMode = StartMode.ALWAYS_LIVING_ROOM

var data := SaveData.new()
var pending_spawn: String = ""


func _ready() -> void:
	get_tree().node_added.connect(_on_node_added)


func _process(delta: float) -> void:
	data.play_time += delta


## Sets a specific custom target scene and spawn node for subsequent level boots.
func set_start(scene: String, spawn: String) -> void:
	data.start_scene = scene
	data.start_spawn = spawn
	start_mode = StartMode.CUSTOM


## Resolves the target starting scene and spawn point based on the active StartMode.
func get_start() -> Dictionary:
	match start_mode:
		StartMode.LAST_PLACE:
			if data.scene_path != "":
				return {"scene": data.scene_path, "spawn": data.spawn_name}
		StartMode.CUSTOM:
			if data.start_scene != "":
				return {"scene": data.start_scene, "spawn": data.start_spawn}
	return {"scene": LIVING_ROOM_SCENE, "spawn": LIVING_ROOM_SPAWN}


## Sets a persistent narrative or progress flag.
func set_flag(key: String, value: Variant = true) -> void:
	data.flags[key] = value


## Retrieves a narrative flag value, or returns default if not found.
func get_flag(key: String, default: Variant = false) -> Variant:
	return data.flags.get(key, default)


## Updates data records for the last visited scene and spawn location.
func remember_place(scene: String, spawn: String) -> void:
	data.scene_path = scene
	data.spawn_name = spawn


## Checks whether an existing save file is present on the filesystem.
func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


## Resets save data and transitions to the designated starting scene.
func new_game() -> void:
	var keep_mode := start_mode
	data = SaveData.new()
	start_mode = keep_mode
	_go_to_start()


## Loads the saved game file if available, or falls back to a new game.
func continue_game() -> void:
	if not load_game():
		new_game()
		return
	_go_to_start()


## Serializes player stats, flags, and world state to disk formatted as JSON.
func save_game() -> bool:
	var scene := get_tree().current_scene
	if scene:
		data.scene_path = scene.scene_file_path

	var p := _find_player()
	if p and p.has_method("serialize"):
		data.player = p.serialize()

	var d := data.to_dict()
	d["start_mode"] = start_mode

	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("SaveManager: Couldn't write save file: %s" % error_string(FileAccess.get_open_error()))
		return false

	f.store_string(JSON.stringify(d, "\t"))
	saved.emit()
	return true


## Reads, parses, and repopulates game data from disk.
func load_game() -> bool:
	if not has_save():
		return false

	var content := FileAccess.get_file_as_string(SAVE_PATH)
	var parsed: Variant = JSON.parse_string(content)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("SaveManager: Save file format is corrupt or invalid.")
		return false

	data = SaveData.from_dict(parsed)
	start_mode = int(parsed.get("start_mode", StartMode.ALWAYS_LIVING_ROOM)) as StartMode
	loaded.emit()
	return true


## Deletes the save file from the persistent user storage directory.
func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)


func _go_to_start() -> void:
	var s := get_start()
	pending_spawn = s["spawn"]
	GameManager.load_next_level(s["scene"])


func _find_player() -> PlayerTopDown:
	var root := get_tree().current_scene
	if root == null:
		return null
	return root.find_child("TopDownPlayer", true, false) as PlayerTopDown


func _on_node_added(node: Node) -> void:
	if node is PlayerTopDown and pending_spawn != "":
		_place_player.call_deferred(node)


func _place_player(p: PlayerTopDown) -> void:
	if not is_instance_valid(p):
		return

	var root := get_tree().current_scene
	var spawn := root.find_child(pending_spawn, true, false) as Node2D if root else null
	var target_name := pending_spawn
	pending_spawn = ""

	if spawn != null:
		p.global_position = spawn.global_position
	else:
		push_warning("SaveManager: Could not find spawn point '%s' in current scene." % target_name)
