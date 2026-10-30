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

@export_group("Travel")
## Scenes this NPC can send the player to, keyed by the name used in a timeline signal.
## A timeline line like [signal arg="travel:school"] loads the scene stored under "school".
@export var travel_scenes: Dictionary[String, PackedScene] = {}

## Scene waiting to load once the current dialogue has finished.
var pending_scene: PackedScene

@export_group("Sprite Hint")
## Color of the 1 pixel outline that blinks around the sprite of an interactable NPC.
@export var hint_color: Color = Color(1.0, 1.0, 1.0, 1.0)

## Draws a 1 texel outline around the opaque pixels of a sprite, switched by "strength".
const OUTLINE_SHADER_CODE := """
shader_type canvas_item;
uniform vec4 outline_color : source_color = vec4(1.0);
uniform float strength = 0.0;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	if (strength > 0.0 && c.a < 0.1) {
		vec2 px = TEXTURE_PIXEL_SIZE;
		float a = texture(TEXTURE, UV + vec2(px.x, 0.0)).a;
		a = max(a, texture(TEXTURE, UV - vec2(px.x, 0.0)).a);
		a = max(a, texture(TEXTURE, UV + vec2(0.0, px.y)).a);
		a = max(a, texture(TEXTURE, UV - vec2(0.0, px.y)).a);
		if (a > 0.1) {
			c = vec4(outline_color.rgb, outline_color.a);
		}
	}
	COLOR = c;
}
"""

static var outline_shader: Shader

var outline_mat: ShaderMaterial


func _ready() -> void:
	super._ready()
	if Engine.is_editor_hint():
		return
	setup_outline()


## Gives the NPC's sprite the outline material used for the blinking interact hint.
func setup_outline() -> void:
	for child in get_children():
		if not (child is Sprite2D or child is AnimatedSprite2D):
			continue
		var sprite := child as CanvasItem
		if sprite.material != null:
			return
		if outline_shader == null:
			outline_shader = Shader.new()
			outline_shader.code = OUTLINE_SHADER_CODE
		outline_mat = ShaderMaterial.new()
		outline_mat.shader = outline_shader
		outline_mat.set_shader_parameter("outline_color", hint_color)
		sprite.material = outline_mat
		return


## Outline is on while the base class glow pulse is active, off otherwise.
func update_outline() -> void:
	if outline_mat != null:
		var on := can_interact and glow_amount > 0.0
		outline_mat.set_shader_parameter("strength", 1.0 if on else 0.0)


func _process(delta: float) -> void:
	super._process(delta)
	update_outline()


func _draw() -> void:
	super._draw()
	update_outline()


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
func on_dialogue_action(action: String, args: Dictionary) -> void:
	print("[Npc] %s got dialogue signal: '%s'" % [name, action])
	# "travel:school" or {"action": "travel", "target": "school"}
	if action.begins_with("travel:"):
		queue_travel(action.trim_prefix("travel:").strip_edges())
	elif action == "travel":
		queue_travel(str(args.get("target", "")).strip_edges())


## Remembers the scene for a travel target. It loads when the dialogue ends.
func queue_travel(target: String) -> void:
	var scene: PackedScene = travel_scenes.get(target)
	if scene == null:
		#push_warning("%s: no travel scene set for '%s' (keys: %s)" % [name, target, travel_scenes.keys()])
		return
	#print("[Npc] %s queued travel to '%s' (%s)" % [name, target, scene.resource_path])
	pending_scene = scene


func _on_dialogue_ended() -> void:
	super._on_dialogue_ended()
	#print("[Npc] %s dialogue ended, pending scene: %s" % [name, pending_scene])
	if pending_scene == null:
		return
	var scene := pending_scene
	pending_scene = null
	get_tree().change_scene_to_packed.call_deferred(scene)


func make_solid_shape() -> Shape2D:
	var circle := CircleShape2D.new()
	circle.radius = body_size.x * 0.5
	return circle


## True when the NPC has its own sprite child, so the placeholder circle is not needed.
func has_sprite() -> bool:
	for child in get_children():
		if child is Sprite2D or child is AnimatedSprite2D:
			return true
	return false


func draw_body() -> void:
	# NPCs with a sprite use it as their body, so draw no placeholder or ring
	if has_sprite():
		return
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
