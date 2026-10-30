extends Node
## Autoload this as "SaveManager"

signal saved
signal loaded

const SAVE_PATH := "user://save.json"

# change these to your real living room scene and spawn marker
const LIVING_ROOM_SCENE := "res://game_scenes/worlds/apartment/room/room_blaire.tscn"
const LIVING_ROOM_SPAWN := "RoomSpawn"

# ALWAYS_LIVING_ROOM: always start in the living room
# LAST_PLACE: start where they last saved
# CUSTOM: start at whatever set_start() was given
enum StartMode { ALWAYS_LIVING_ROOM, LAST_PLACE, CUSTOM }
var start_mode: StartMode = StartMode.ALWAYS_LIVING_ROOM

var data := SaveData.new()
var pending_spawn: String = ""
# used when the start scene doesn't exist yet (the main menu sets this)
var fallback_scene: String = ""

func _ready() -> void:
	# lets us put the player on a spawn without touching the player scene
	get_tree().node_added.connect(_on_node_added)

func _process(delta: float) -> void:
	data.play_time += delta

# change where the game starts from, can be called by anything (story, settings, etc)
func set_start(scene: String, spawn: String) -> void:
	data.start_scene = scene
	data.start_spawn = spawn
	start_mode = StartMode.CUSTOM

func get_start() -> Dictionary:
	match start_mode:
		StartMode.LAST_PLACE:
			if data.scene_path != "":
				return {"scene": data.scene_path, "spawn": data.spawn_name}
		StartMode.CUSTOM:
			if data.start_scene != "":
				return {"scene": data.start_scene, "spawn": data.start_spawn}
	return {"scene": LIVING_ROOM_SCENE, "spawn": LIVING_ROOM_SPAWN}

# story flags
func set_flag(key: String, value: Variant = true) -> void:
	data.flags[key] = value

func get_flag(key: String, default: Variant = false) -> Variant:
	return data.flags.get(key, default)

# call this when the player goes through a door / teleporter
func remember_place(scene: String, spawn: String) -> void:
	data.scene_path = scene
	data.spawn_name = spawn

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func new_game() -> void:
	var keep_mode := start_mode
	data = SaveData.new()
	start_mode = keep_mode
	_go_to_start()

func continue_game() -> void:
	if not load_game():
		new_game()
		return
	_go_to_start()

func save_game() -> bool:
	var scene := get_tree().current_scene
	if scene:
		data.scene_path = scene.scene_file_path
	var p := _find_player()
	if p:
		data.player = p.serialize()
	var d := data.to_dict()
	d["start_mode"] = start_mode
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_warning("couldn't write save: %s" % error_string(FileAccess.get_open_error()))
		return false
	f.store_string(JSON.stringify(d, "\t"))
	saved.emit()
	return true

func load_game() -> bool:
	if not has_save():
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("save file is broken")
		return false
	data = SaveData.from_dict(parsed)
	start_mode = int(parsed.get("start_mode", StartMode.ALWAYS_LIVING_ROOM)) as StartMode
	loaded.emit()
	return true

func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)

func _go_to_start() -> void:
	var s := get_start()
	var scene: String = s["scene"]
	pending_spawn = s["spawn"]
	if not ResourceLoader.exists(scene) and fallback_scene != "":
		scene = fallback_scene
		pending_spawn = ""
	GameManager.load_next_level(scene)

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
	pending_spawn = ""
	if spawn:
		p.global_position = spawn.global_position
	else:
		push_warning("no spawn named that in this scene")
