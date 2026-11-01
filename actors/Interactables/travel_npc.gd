extends Npc
class_name TravelNpc

## An Npc that sends the player to another scene, and can pick where they appear.
## Works with the same [signal arg="travel:name"] lines in a timeline as a normal Npc.

@export_group("Travel")
## Scenes by name, as a path or uid text. A timeline line [signal arg="travel:bus"] uses the "bus" entry.
@export var travel_paths: Dictionary[String, String] = {}
## Name of the SpawnPoint to appear at in the next scene.
@export var travel_spawn: String = ""
## If set, talking to this NPC always ends with a trip to this entry of travel_paths.
## Handy when the dialogue is just plain lines with no timeline signals.
@export var auto_travel: String = ""

var pending_path: String = ""


func _on_interact(who: Node2D) -> void:
	if auto_travel != "":
		queue_travel(auto_travel)
	super._on_interact(who)


func queue_travel(target: String) -> void:
	if travel_paths.has(target):
		pending_path = travel_paths[target]
		return
	super.queue_travel(target)


func _on_dialogue_ended() -> void:
	super._on_dialogue_ended()
	if pending_path == "":
		return
	var path := pending_path
	var spawn := travel_spawn
	pending_path = ""
	(func() -> void: SceneDoor.go(path, spawn)).call_deferred()
