extends Area2D
class_name SceneDoor

## Walk into this to go to another scene. Put a CollisionShape2D on it where the door is.
## Scenes are given as a path or uid text, not a PackedScene, so two rooms can link to each other.

## The scene to go to.
@export_file("*.tscn") var target_scene: String = ""
## Name of the SpawnPoint in that scene to appear at. Empty means the player stays where the scene puts them.
@export var target_spawn: String = ""

## Set right before a scene change, read by the SpawnPoint in the next scene.
static var pending_spawn: String = ""

var going: bool = false


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if going:
		return
	if body.is_in_group("player") or body.name.begins_with("Player"):
		going = true
		go(target_scene, target_spawn)


## Goes to a scene and tells it where to put the player. Other scripts can call this too.
static func go(scene: String, spawn: String = "") -> void:
	if scene == "":
		push_warning("SceneDoor: no target scene set")
		return
	var path := scene
	if path.begins_with("uid://"):
		var id := ResourceUID.text_to_id(path)
		if ResourceUID.has_id(id):
			path = ResourceUID.get_id_path(id)
	pending_spawn = spawn
	GameManager.load_next_level(path)
