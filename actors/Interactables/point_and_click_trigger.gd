@tool
extends Interactable
class_name PointAndClickTrigger

## The point and click scene that opens when the player interacts
@export_file("*.tscn") var station_scene: String = ""

func _on_interact(_who: Node2D) -> void:
	if station_scene == "":
		push_warning("%s has no station_scene set" % name)
		return
	# same level change the point and click scene uses to leave
	GameManager.load_next_level(station_scene)
