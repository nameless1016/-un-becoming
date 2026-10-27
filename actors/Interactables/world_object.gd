@tool
extends Interactable
class_name WorldObject

## Represents an interactable world prop or object (e.g., signs, crates, examine points).
##
## Triggers Dialogic timelines or simple text examination descriptions when interacted with,
## while sharing base interaction, collision, and minimap functionality.

@export_group("Dialogue")
## File name of a Dialogic timeline (e.g., "a1_fridge"). No path or extension needed.
@export var timeline_name: String = ""
## Direct reference to a Dialogic timeline (.dtl). Overrides timeline_name if set.
@export var timeline: DialogicTimeline
## Quick text prompt shown when no timeline is provided.
@export_multiline var examine_text: String = ""
## Whether to pause the game world during interaction.
@export var pause_world: bool = true


func _on_interact(_who: Node2D) -> void:
	var tl := timeline
	if tl == null:
		tl = find_timeline(timeline_name)
	if tl == null:
		var text := examine_text if examine_text != "" else "..."
		tl = build_text_timeline([text], display_name)
	start_dialogue(tl, pause_world)
