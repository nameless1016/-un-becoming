extends Interactable
class_name Npc

## Represents an interactable NPC in the world.
##
## Manages dialogue triggering through Dialogic timelines or simple text lines,
## handles dialogue event signals, and draws the NPC's in-game body and minimap icon.

@export_group("Dialogue")
## File name of a Dialogic timeline (e.g., "a1_bus_driver"). No path or extension needed.
@export var timeline_name: String = ""
## Direct reference to a Dialogic timeline (.dtl). Overrides timeline_name if set.
@export var timeline: DialogicTimeline
## Fallback lines used to generate a temporary timeline when no timeline is assigned.
@export var dialogue_lines: Array[String] = []
## Dialogic character (.dch) used for name tags and portraits when using dialogue_lines.
@export var character: DialogicCharacter
## Whether to pause the game world while the dialogue is open.
@export var pause_world: bool = true


func _on_interact(_who: Node2D) -> void:
	start_dialogue(get_timeline(), pause_world)


## Resolves the timeline to play in order of priority: explicit resource, timeline name, or generated lines.
func get_timeline() -> DialogicTimeline:
	if timeline != null:
		return timeline
	var named := find_timeline(timeline_name)
	if named != null:
		return named
	var speaker := display_name
	if character != null and character.get_identifier() != "":
		speaker = character.get_identifier()
	var lines: Array[String] = dialogue_lines
	return build_text_timeline(lines, speaker)


func _on_dialogue_signal(argument: Variant) -> void:
	if argument is Dictionary:
		on_dialogue_action(str(argument.get("action", "")), argument)
	else:
		on_dialogue_action(str(argument), {})


## Virtual method to override in subclasses for handling custom timeline signal events.
func on_dialogue_action(_action: String, _args: Dictionary) -> void:
	pass


func make_solid_shape() -> Shape2D:
	var circle := CircleShape2D.new()
	circle.radius = body_size.x * 0.5
	return circle


func draw_body() -> void:
	var r := body_size.x * 0.5
	draw_circle(Vector2.ZERO, r, lit_fill())
	if can_interact:
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 24, outline_color, outline_width)


func draw_glow(_strength: float) -> void:
	pass


func draw_minimap_icon(canvas: Control, p: Vector2) -> void:
	if can_interact:
		canvas.draw_circle(p, 3.6, Color(0.0, 0.0, 0.0))
		canvas.draw_circle(p, 2.8, Color(0.9, 0.9, 0.9))
		canvas.draw_circle(p, 1.1, Color(0.0, 0.0, 0.0))
	else:
		canvas.draw_circle(p, 2.8, Color(0.38, 0.38, 0.38))
		canvas.draw_circle(p, 1.1, Color(0.12, 0.12, 0.12))
