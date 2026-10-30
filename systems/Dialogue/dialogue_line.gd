extends Resource
class_name DialogueLine

enum FaceSide { LEFT, RIGHT }

@export_multiline var text: String = ""
## Overrides the name tag for just this line. Empty uses the usual name
@export var speaker: String = ""
## Name of an animation in the portrait's SpriteFrames, like "neutral" or "angry". Empty uses the default one
@export var expression: String = ""
## Which side the face shows up on
@export var side: FaceSide = FaceSide.LEFT
## For later: something to run when this line shows up, like "walk_to_door". The NPC decides what it means
@export var action: String = ""
@export var action_args: Dictionary = {}

static func from_text(t: String) -> DialogueLine:
	var line := DialogueLine.new()
	line.text = t
	return line
