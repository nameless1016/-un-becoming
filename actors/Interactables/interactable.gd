@tool
extends Area2D
class_name Interactable

## Base class for all interactable entities, props, and NPCs in the game world.
##
## Provides proximity detection, collision blocking, custom CanvasItem rendering
## (bodies, prompts, speech bubbles, glow hints), minimap representation,
## and integration with Dialogic timelines and pauses.

signal interacted(who: Node2D)
## Fired when this entity starts a Dialogic conversation.
signal dialogue_started
## Fired when this entity finishes a Dialogic conversation.
signal dialogue_finished

## When disabled, interaction prompts, glow hints, and input processing are stopped.
@export var can_interact: bool = true:
	set(value):
		can_interact = value
		if not value:
			glow_amount = 0.0
		queue_redraw()
		if is_inside_tree() and not Engine.is_editor_hint():
			set_process(needs_process())

## Whether this entity draws a marker on the active minimap.
@export var show_on_minimap: bool = true
## Display name used as a fallback speaker tag in dialogues.
@export var display_name: String = ""
## Proximity radius required for the player to trigger an interaction.
@export var interact_radius: float = 130.0
## When true, spawns a static physics body to block player movement.
@export var solid: bool = true
## Text glyph displayed inside the floating interaction prompt.
@export var prompt_text: String = "E"

@export_group("Look")
## Visual dimensions of the rendered body rect.
@export var body_size: Vector2 = Vector2(96, 96):
	set(value):
		body_size = value
		queue_redraw()
## Primary fill color of the entity body.
@export var fill_color: Color = Color(0.55, 0.55, 0.55):
	set(value):
		fill_color = value
		queue_redraw()
## Border outline color drawn when interactable.
@export var outline_color: Color = Color(0.0, 0.0, 0.0):
	set(value):
		outline_color = value
		queue_redraw()
## Thickness of the border outline.
@export var outline_width: float = 4.0:
	set(value):
		outline_width = value
		queue_redraw()

@export_group("Hint")
## Enables intermittent pulsing glow to highlight interactable objects.
@export var glow_enabled: bool = true
## Delay in seconds between pulse glow cycles.
@export var glow_interval: float = 4.0
## Duration in seconds of a single glow cycle.
@export var glow_time: float = 1.0

@export_group("Idle Motion")
## Amplitude of vertical bobbing in pixels.
@export var bob_height: float = 0.0
## Frequency of the bobbing motion in cycles per second.
@export var bob_speed: float = 1.0

var player: Node2D
var player_near: bool = false
var bubble_text: String = ""
var bubble_left: float = 0.0
var anim_time: float = 0.0
var glow_offset: float = 0.0
var glow_amount: float = 0.0
var last_glow: float = 0.0

var in_dialogue: bool = false
var paused_by_dialogue: bool = false
var was_paused: bool = false

static var dialogic_input_patched: bool = false
const DIALOGUE_STYLE := "res://dialogue/style/unbecoming_640_style.tres"


func _ready() -> void:
	set_process(false)
	queue_redraw()
	if Engine.is_editor_hint():
		return

	add_to_group("interactables")
	glow_offset = randf() * (glow_interval + glow_time)
	collision_layer = 0

	var detect := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = interact_radius
	detect.shape = circle
	add_child(detect)

	if solid:
		build_blocker()

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	set_process(needs_process())


## Evaluates whether the node requires active per-frame _process calls.
func needs_process() -> bool:
	return bob_height > 0.0 or bubble_left > 0.0 or (glow_enabled and can_interact and EntitySettings.show_glow_hint)


## Generates a child StaticBody2D to prevent the player from walking through this entity.
func build_blocker() -> void:
	var blocker := StaticBody2D.new()
	blocker.collision_layer = 2
	blocker.collision_mask = 0
	var cs := CollisionShape2D.new()
	cs.shape = make_solid_shape()
	blocker.add_child(cs)
	add_child(blocker)


## Constructs the collision boundary shape for blocking movement. Overridable by subclasses.
func make_solid_shape() -> Shape2D:
	var rect := RectangleShape2D.new()
	rect.size = body_size
	return rect


func _on_body_entered(body: Node2D) -> void:
	if body is PlayerTopDown or body.name == "PlayerTopDown":
		player = body
		player_near = true
		queue_redraw()


func _on_body_exited(body: Node2D) -> void:
	if body == player:
		player_near = false
		queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not can_interact or not player_near:
		return
	if is_dialogue_running():
		return
	if not is_interact_event(event):
		return
	if not is_closest_in_range():
		return
	interact(player)
	get_viewport().set_input_as_handled()


## Checks whether an input event corresponds to the interact action or default key.
func is_interact_event(event: InputEvent) -> bool:
	if InputMap.has_action("interact"):
		return event.is_action_pressed("interact")
	return event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E


## Verifies if this node is the closest active interactable to the player.
func is_closest_in_range() -> bool:
	var mine := player.global_position.distance_to(global_position)
	for node in get_tree().get_nodes_in_group("interactables"):
		var other := node as Interactable
		if other == null or other == self:
			continue
		if not other.can_interact or not other.player_near:
			continue
		if other.player.global_position.distance_to(other.global_position) < mine:
			return false
	return true


## Triggers the interaction sequence for this node.
func interact(who: Node2D) -> void:
	if not can_interact or is_dialogue_running():
		return
	interacted.emit(who)
	_on_interact(who)


## Virtual interaction hook to be implemented by child classes.
func _on_interact(_who: Node2D) -> void:
	pass

#region Dialogic

## Returns true if a conversation is actively running on this node or globally.
func is_dialogue_running() -> bool:
	return in_dialogue or Dialogic.current_timeline != null


## Launches a Dialogic timeline and handles world pause management.
func start_dialogue(timeline: DialogicTimeline, pause: bool = true) -> bool:
	if is_dialogue_running():
		return false
	if timeline == null or timeline.events.is_empty():
		push_warning("%s: no dialogue to play" % name)
		return false

	patch_dialogic_input()
	use_fallback_style()
	in_dialogue = true

	Dialogic.process_mode = Node.PROCESS_MODE_ALWAYS
	paused_by_dialogue = pause
	if pause:
		was_paused = get_tree().paused
		get_tree().paused = true

	Dialogic.signal_event.connect(_on_dialogic_signal)
	Dialogic.timeline_ended.connect(_on_dialogue_ended, CONNECT_ONE_SHOT)

	var layout := Dialogic.start(timeline)
	if layout != null:
		layout.process_mode = Node.PROCESS_MODE_ALWAYS
	dialogue_started.emit()
	return true


## Locates a Dialogic timeline resource by file name.
func find_timeline(timeline_name: String) -> DialogicTimeline:
	var wanted := timeline_name.strip_edges()
	if wanted == "":
		return null
	var found := DialogicResourceUtil.get_timeline_resource(wanted)
	if found == null:
		push_warning("%s: no Dialogic timeline called '%s'" % [name, wanted])
	return found


## Dynamically compiles raw text strings into an ad-hoc Dialogic timeline resource.
func build_text_timeline(lines: Array[String], speaker: String = "") -> DialogicTimeline:
	var who := speaker.strip_edges().replace('"', "'")
	var prefix := ('"%s": ' % who) if who != "" else "_: "
	var out := PackedStringArray()
	for line in lines:
		var body := line.strip_edges().replace("\n", "\\\n")
		if body != "":
			out.append(prefix + body)
	if out.is_empty():
		out.append(prefix + "...")
	var timeline := DialogicTimeline.new()
	timeline.from_text("\n".join(out))
	return timeline


func _on_dialogue_ended() -> void:
	if Dialogic.signal_event.is_connected(_on_dialogic_signal):
		Dialogic.signal_event.disconnect(_on_dialogic_signal)
	if paused_by_dialogue:
		get_tree().paused = was_paused
	paused_by_dialogue = false
	in_dialogue = false
	dialogue_finished.emit()


func _on_dialogic_signal(argument: Variant) -> void:
	_on_dialogue_signal(argument)


## Virtual callback receiving [signal arg="..."] calls from Dialogic timelines.
func _on_dialogue_signal(_argument: Variant) -> void:
	pass


func _exit_tree() -> void:
	if in_dialogue and paused_by_dialogue and get_tree() != null:
		get_tree().paused = was_paused


## Applies project fallback styling when no default style is specified in project settings.
static func use_fallback_style() -> void:
	if str(ProjectSettings.get_setting("dialogic/layout/default_style", "")) != "":
		return
	if ResourceLoader.exists(DIALOGUE_STYLE):
		ProjectSettings.set_setting("dialogic/layout/default_style", DIALOGUE_STYLE)


## Ensures the interaction key/action is bound to Dialogic's progress input action.
static func patch_dialogic_input() -> void:
	if dialogic_input_patched:
		return
	dialogic_input_patched = true
	var action := str(ProjectSettings.get_setting("dialogic/text/input_action", "dialogic_default_action"))
	if not InputMap.has_action(action):
		return
	var keys: Array[InputEvent] = []
	var e := InputEventKey.new()
	e.keycode = KEY_E
	keys.append(e)
	if InputMap.has_action("interact"):
		keys.append_array(InputMap.action_get_events("interact"))
	for ev in keys:
		if not InputMap.action_has_event(action, ev):
			InputMap.action_add_event(action, ev)

#endregion


## Displays a temporary floating dialogue bubble above the entity.
func speak(text: String, seconds: float = 2.5) -> void:
	bubble_text = text
	bubble_left = seconds
	set_process(true)
	queue_redraw()


## Calculates current glow intensity factor based on time and distance conditions.
func get_glow() -> float:
	if not glow_enabled or not can_interact or player_near or not EntitySettings.show_glow_hint:
		return 0.0
	var t := fmod(anim_time + glow_offset, glow_interval + glow_time)
	if t >= glow_time:
		return 0.0
	return sin(PI * t / glow_time)


func _process(delta: float) -> void:
	anim_time += delta
	var bubble_was_up := bubble_text != ""
	if bubble_left > 0.0:
		bubble_left -= delta
		if bubble_left <= 0.0:
			bubble_text = ""
	glow_amount = get_glow()
	if bob_height > 0.0 or glow_amount > 0.0 or last_glow > 0.0 or bubble_was_up != (bubble_text != ""):
		queue_redraw()
	last_glow = glow_amount
	if not needs_process():
		set_process(false)


func _draw() -> void:
	draw_shadow()
	draw_set_transform(Vector2(0.0, sin(anim_time * TAU * bob_speed) * bob_height))
	if glow_amount > 0.0:
		draw_glow(glow_amount)
	draw_body()
	draw_set_transform(Vector2.ZERO)
	draw_prompt()
	draw_bubble()


## Renders the drop shadow beneath the entity body during bobbing movement.
func draw_shadow() -> void:
	if bob_height <= 0.0:
		return
	draw_set_transform(Vector2(0.0, body_size.y * 0.5), 0.0, Vector2(1.0, 0.3))
	draw_circle(Vector2.ZERO, body_size.x * 0.45, Color(0.0, 0.0, 0.0, 0.35))
	draw_set_transform(Vector2.ZERO)


## Computes the body fill color blended with current glow intensity.
func lit_fill() -> Color:
	return fill_color.lerp(Color(1.0, 1.0, 1.0), 0.35 * glow_amount)


## Draws layered rectangular halos surrounding the entity body.
func draw_glow(strength: float) -> void:
	var half := body_size * 0.5
	for i in 5:
		var grow := Vector2(6.0, 6.0) + Vector2(8.0, 8.0) * i
		var a := strength * 0.2 * (1.0 - i / 5.0)
		draw_rect(Rect2(-half - grow, body_size + grow * 2.0), Color(1.0, 1.0, 1.0, a))


## Draws the primary visual rectangle and optional interactable border.
func draw_body() -> void:
	var r := Rect2(-body_size * 0.5, body_size)
	draw_rect(r, lit_fill())
	if can_interact:
		draw_rect(r, outline_color, false, outline_width)


## Draws the floating interaction prompt circle and key glyph.
func draw_prompt() -> void:
	if not player_near or not can_interact or bubble_text != "":
		return
	var c := Vector2(0.0, -body_size.y * 0.5 - 40.0)
	draw_circle(c, 22.0, Color(0.0, 0.0, 0.0))
	draw_circle(c, 19.0, Color(0.9, 0.9, 0.9))
	var font := ThemeDB.fallback_font
	draw_string(font, c + Vector2(-20.0, 10.0), prompt_text, HORIZONTAL_ALIGNMENT_CENTER, 40.0, 30, Color(0.0, 0.0, 0.0))


## Draws the speech bubble container and wrapped text.
func draw_bubble() -> void:
	if bubble_text == "":
		return
	var font := ThemeDB.fallback_font
	var font_size := 28
	var text_size := font.get_string_size(bubble_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var pad := Vector2(16.0, 10.0)
	var box_size := text_size + pad * 2.0
	var top_left := Vector2(-box_size.x * 0.5, -body_size.y * 0.5 - 30.0 - box_size.y)
	var box := Rect2(top_left, box_size)
	draw_rect(box, Color(0.08, 0.08, 0.08))
	draw_rect(box, Color(0.85, 0.85, 0.85), false, 3.0)
	draw_string(font, top_left + pad + Vector2(0.0, font.get_ascent(font_size)), bubble_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.95, 0.95, 0.95))


## Draws this entity's diamond icon marker onto the minimap canvas.
func draw_minimap_icon(canvas: Control, p: Vector2) -> void:
	var r := 3.2
	if can_interact:
		canvas.draw_colored_polygon(diamond(p, r + 1.0), Color(0.0, 0.0, 0.0))
		canvas.draw_colored_polygon(diamond(p, r), Color(0.9, 0.9, 0.9))
	else:
		canvas.draw_colored_polygon(diamond(p, r), Color(0.38, 0.38, 0.38))


## Generates diamond polygon vertices around a center point for minimap drawing.
func diamond(p: Vector2, r: float) -> PackedVector2Array:
	return PackedVector2Array([p + Vector2(0.0, -r), p + Vector2(r, 0.0), p + Vector2(0.0, r), p + Vector2(-r, 0.0)])
