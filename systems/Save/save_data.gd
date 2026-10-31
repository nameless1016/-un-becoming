class_name SaveData
extends RefCounted

const VERSION := 1

# where the player is right now
var scene_path: String = ""
var spawn_name: String = ""
var player: Dictionary = {}

# where a new load starts, can be changed any time
var start_scene: String = ""
var start_spawn: String = ""

# story stuff, anything goes in here (ex: "met_talker": true)
var flags: Dictionary = {}
var play_time: float = 0.0

func to_dict() -> Dictionary:
	return {
		"version": VERSION,
		"scene_path": scene_path,
		"spawn_name": spawn_name,
		"player": player,
		"start_scene": start_scene,
		"start_spawn": start_spawn,
		"flags": flags,
		"play_time": play_time,
	}

static func from_dict(d: Dictionary) -> SaveData:
	var s := SaveData.new()
	s.scene_path = d.get("scene_path", "")
	s.spawn_name = d.get("spawn_name", "")
	s.player = d.get("player", {})
	s.start_scene = d.get("start_scene", "")
	s.start_spawn = d.get("start_spawn", "")
	s.flags = d.get("flags", {})
	s.play_time = d.get("play_time", 0.0)
	return s
