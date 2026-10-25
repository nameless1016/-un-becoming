@tool
extends Area2D
class_name Interactable

signal interacted(who: Node2D)

## Off means it's just standing there and the player can't use it
@export var can_interact: bool = true:
	set(value):
		can_interact = value
		if not value:
			glow_amount = 0.0
		queue_redraw()
		# glow only runs on things you can use, so wake up or stop the per-frame work
		if is_inside_tree() and not Engine.is_editor_hint():
			set_process(needs_process())
## Whether it shows on the minimap. The minimap has its own switch too
@export var show_on_minimap: bool = true
@export var display_name: String = ""
## How close the player has to be to use it, measured from the middle
@export var interact_radius: float = 130.0
## Blocks the player from walking through it
@export var solid: bool = true
## The letter on the little prompt bubble
@export var prompt_text: String = "E"

@export_group("Look")
@export var body_size: Vector2 = Vector2(96, 96):
	set(value):
		body_size = value
		queue_redraw()
@export var fill_color: Color = Color(0.55, 0.55, 0.55):
	set(value):
		fill_color = value
		queue_redraw()
@export var outline_color: Color = Color(0.0, 0.0, 0.0):
	set(value):
		outline_color = value
		queue_redraw()
@export var outline_width: float = 4.0:
	set(value):
		outline_width = value
		queue_redraw()

@export_group("Hint")
## Glows now and then so the player notices it. Only matters if can_interact is on
@export var glow_enabled: bool = true
## Seconds of calm between glows
@export var glow_interval: float = 4.0
## How long one glow lasts, in seconds
@export var glow_time: float = 1.0

@export_group("Idle Motion")
## How far it moves up and down in the world, in pixels. 0 keeps it still
@export var bob_height: float = 0.0
## Full up and down trips per second
@export var bob_speed: float = 1.0

var player: Node2D
var player_near: bool = false
var bubble_text: String = ""
var bubble_left: float = 0.0
var anim_time: float = 0.0
var glow_offset: float = 0.0
var glow_amount: float = 0.0
var last_glow: float = 0.0

func _ready() -> void:
	set_process(false)
	queue_redraw()
	# in the editor we only want the drawing, none of the game stuff
	if Engine.is_editor_hint():
		return

	add_to_group("interactables")

	# so a bunch of them in one room don't all glow at the same moment
	glow_offset = randf() * (glow_interval + glow_time)

	# nothing else should detect this, it only looks for the player
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

func needs_process() -> bool:
	return bob_height > 0.0 or bubble_left > 0.0 or (glow_enabled and can_interact and EntitySettings.show_glow_hint)

func build_blocker() -> void:
	# same layer as the tilemap walls so the player bumps into it
	var blocker := StaticBody2D.new()
	blocker.collision_layer = 2
	blocker.collision_mask = 0
	var cs := CollisionShape2D.new()
	cs.shape = make_solid_shape()
	blocker.add_child(cs)
	add_child(blocker)

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
	if not is_interact_event(event):
		return
	# if a few things are in range, only the closest one reacts
	if not is_closest_in_range():
		return
	interact(player)
	get_viewport().set_input_as_handled()

func is_interact_event(event: InputEvent) -> bool:
	# uses an "interact" action if you made one, otherwise plain E
	if InputMap.has_action("interact"):
		return event.is_action_pressed("interact")
	return event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E

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

func interact(who: Node2D) -> void:
	if not can_interact:
		return
	interacted.emit(who)
	_on_interact(who)

## NPCs and objects fill this in
func _on_interact(_who: Node2D) -> void:
	pass

func speak(text: String, seconds: float = 2.5) -> void:
	bubble_text = text
	bubble_left = seconds
	set_process(true)
	queue_redraw()

func get_glow() -> float:
	# 0 most of the time, then rises and falls once every glow_interval or so
	# it stays off while the player is close, the prompt takes over then
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
	# only redraw when something on screen is actually changing
	if bob_height > 0.0 or glow_amount > 0.0 or last_glow > 0.0 or bubble_was_up != (bubble_text != ""):
		queue_redraw()
	last_glow = glow_amount
	# nothing left to animate, so stop running every frame
	if not needs_process():
		set_process(false)

func _draw() -> void:
	draw_shadow()
	# only the body bobs, the prompt and bubble stay put
	draw_set_transform(Vector2(0.0, sin(anim_time * TAU * bob_speed) * bob_height))
	if glow_amount > 0.0:
		draw_glow(glow_amount)
	draw_body()
	draw_set_transform(Vector2.ZERO)
	draw_prompt()
	draw_bubble()

func draw_shadow() -> void:
	# a flat shadow underneath so the bounce reads as a hop and not floating
	if bob_height <= 0.0:
		return
	draw_set_transform(Vector2(0.0, body_size.y * 0.5), 0.0, Vector2(1.0, 0.3))
	draw_circle(Vector2.ZERO, body_size.x * 0.45, Color(0.0, 0.0, 0.0, 0.35))
	draw_set_transform(Vector2.ZERO)

## The fill gets a bit brighter while it glows
func lit_fill() -> Color:
	return fill_color.lerp(Color(1.0, 1.0, 1.0), 0.35 * glow_amount)

## Soft white halo, a few see-through layers stacked behind the body
func draw_glow(strength: float) -> void:
	var half := body_size * 0.5
	for i in 5:
		var grow := Vector2(6.0, 6.0) + Vector2(8.0, 8.0) * i
		var a := strength * 0.2 * (1.0 - i / 5.0)
		draw_rect(Rect2(-half - grow, body_size + grow * 2.0), Color(1.0, 1.0, 1.0, a))

func draw_body() -> void:
	var r := Rect2(-body_size * 0.5, body_size)
	draw_rect(r, lit_fill())
	# thin outline only on the ones you can actually use
	if can_interact:
		draw_rect(r, outline_color, false, outline_width)

func draw_prompt() -> void:
	if not player_near or not can_interact or bubble_text != "":
		return
	var c := Vector2(0.0, -body_size.y * 0.5 - 40.0)
	draw_circle(c, 22.0, Color(0.0, 0.0, 0.0))
	draw_circle(c, 19.0, Color(0.9, 0.9, 0.9))
	var font := ThemeDB.fallback_font
	draw_string(font, c + Vector2(-20.0, 10.0), prompt_text, HORIZONTAL_ALIGNMENT_CENTER, 40.0, 30, Color(0.0, 0.0, 0.0))

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

## The minimap calls this to draw this thing as a tiny icon
func draw_minimap_icon(canvas: Control, p: Vector2) -> void:
	var r := 3.2
	if can_interact:
		canvas.draw_colored_polygon(diamond(p, r + 1.0), Color(0.0, 0.0, 0.0))
		canvas.draw_colored_polygon(diamond(p, r), Color(0.9, 0.9, 0.9))
	else:
		canvas.draw_colored_polygon(diamond(p, r), Color(0.38, 0.38, 0.38))

func diamond(p: Vector2, r: float) -> PackedVector2Array:
	return PackedVector2Array([p + Vector2(0.0, -r), p + Vector2(r, 0.0), p + Vector2(0.0, r), p + Vector2(-r, 0.0)])
