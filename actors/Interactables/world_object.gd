@tool
extends Interactable
class_name WorldObject

@export_multiline var examine_text: String = ""
@export var dialogue: Array[DialogueLine] = []
@export var pause_world: bool = true

func _on_interact(_who: Node2D) -> void:
	var lines: Array[DialogueLine] = dialogue
	if lines.is_empty():
		var text := examine_text if examine_text != "" else "..."
		lines = [DialogueLine.from_text(text)]
	DialogueBox.open(self, lines, display_name, null, false, pause_world)
