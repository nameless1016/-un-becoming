@tool
extends Interactable
class_name Npc

# Dialogue text lines
@export var dialogue_lines: Array[String] = []
@export var dialogue: Array[DialogueLine] = []

@export_group("Dialogue Box")
# Portrait settings
@export var portrait_frames: SpriteFrames
@export var placeholder_portrait: bool = true
@export var pause_world: bool = true

# Bobbing settings
@export var enable_portrait_bob: bool = true
@export var portrait_bob: DialogueBox.PortraitBob = DialogueBox.PortraitBob.WHILE_TALKING
@export var portrait_bob_height: float = 10.0
@export var portrait_bob_speed: float = 3.0

# Called when the player interacts
func _on_interact(_who: Node2D) -> void:
	var box := DialogueBox.open(self, get_lines(), display_name, portrait_frames, placeholder_portrait, pause_world)
	if box != null:
		# Set bobbing values only if enabled
		# Set bobbing values only if enabled
		if enable_portrait_bob:
			box.bob_mode = portrait_bob
			box.bob_height = portrait_bob_height
			box.bob_speed = portrait_bob_speed
		else:
			box.bob_height = 0.0
			box.bob_speed = 0.0
		
		box.line_started.connect(_on_line_started)

# Gets the lines to show in dialogue
func get_lines() -> Array[DialogueLine]:
	if not dialogue.is_empty():
		return dialogue
	var out: Array[DialogueLine] = []
	for text in dialogue_lines:
		out.append(DialogueLine.from_text(text))
	if out.is_empty():
		out.append(DialogueLine.from_text("..."))
	return out

# Runs when a new line starts
func _on_line_started(line: DialogueLine, _i: int) -> void:
	if line.action != "":
		on_dialogue_action(line.action, line.action_args)

# Override this in other scripts for custom events
func on_dialogue_action(_action: String, _args: Dictionary) -> void:
	pass

# Makes the collision circle
func make_solid_shape() -> Shape2D:
	var circle := CircleShape2D.new()
	circle.radius = body_size.x * 0.5
	return circle

# Draws the NPC circle and outline
func draw_body() -> void:
	var r := body_size.x * 0.5
	draw_circle(Vector2.ZERO, r, lit_fill())
	if can_interact:
		draw_arc(Vector2.ZERO, r, 0.0, TAU, 24, outline_color, outline_width)

# Draws the glow around the NPC
func draw_glow(strength: float) -> void:
	var r := body_size.x * 0.5
	for i in 5:
		var a := strength * 0.2 * (1.0 - i / 5.0)
		draw_circle(Vector2.ZERO, r + 6.0 + 8.0 * i, Color(1.0, 1.0, 1.0, a))

# Draws the icon on the minimap
func draw_minimap_icon(canvas: Control, p: Vector2) -> void:
	if can_interact:
		canvas.draw_circle(p, 3.6, Color(0.0, 0.0, 0.0))
		canvas.draw_circle(p, 2.8, Color(0.9, 0.9, 0.9))
		canvas.draw_circle(p, 1.1, Color(0.0, 0.0, 0.0))
	else:
		canvas.draw_circle(p, 2.8, Color(0.38, 0.38, 0.38))
		canvas.draw_circle(p, 1.1, Color(0.12, 0.12, 0.12))
