@tool
extends WorldObject
class_name WorldProp

## A room prop with its own sprite. It isn't drawn as a grey box, the sprite is
## the visual. Put the solid part in the Solid > CollisionShape2D child.

func _init() -> void:
	# props are small, so the defaults for the big world don't fit
	interact_radius = 24.0
	can_interact = false
	# the Solid child blocks the player, no need for the auto blocker
	solid = false

func get_sprite_rect() -> Rect2:
	var spr := get_node_or_null("Sprite2D") as Sprite2D
	if spr == null or spr.texture == null:
		return Rect2(-body_size * 0.5, body_size)
	var size := spr.texture.get_size() / Vector2(spr.hframes, spr.vframes)
	return Rect2(spr.position - size * 0.5, size)

# the sprite is already the body
func draw_body() -> void:
	pass

func draw_glow(strength: float) -> void:
	var r := get_sprite_rect()
	for i in 5:
		var grow := Vector2(1.0, 1.0) + Vector2(1.5, 1.5) * i
		var a := strength * 0.2 * (1.0 - i / 5.0)
		draw_rect(Rect2(r.position - grow, r.size + grow * 2.0), Color(1.0, 1.0, 1.0, a))

func draw_prompt() -> void:
	if not player_near or not can_interact:
		return
	var c := Vector2(0.0, get_sprite_rect().position.y - 8.0)
	draw_circle(c, 5.0, Color(0.0, 0.0, 0.0))
	draw_circle(c, 4.2, Color(0.9, 0.9, 0.9))
	draw_string(ThemeDB.fallback_font, c + Vector2(-5.0, 3.0), prompt_text, HORIZONTAL_ALIGNMENT_CENTER, 10.0, 8, Color(0.0, 0.0, 0.0))

# the player here isn't PlayerTopDown, so go by the "player" group or a name starting with Player
func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.name.begins_with("Player"):
		player = body
		player_near = true
		queue_redraw()

# on the minimap, show the footprint of the furniture instead of a little diamond
func draw_minimap_icon(canvas: Control, p: Vector2) -> void:
	var cs := get_node_or_null("Solid/CollisionShape2D") as CollisionShape2D
	var mm := canvas.get_parent().get_parent() as Minimap
	if cs == null or mm == null:
		super.draw_minimap_icon(canvas, p)
		return
	var size := Vector2(6.0, 6.0)
	if cs.shape is RectangleShape2D:
		size = (cs.shape as RectangleShape2D).size
	elif cs.shape is CircleShape2D:
		var d := (cs.shape as CircleShape2D).radius * 2.0
		size = Vector2(d, d)
	elif cs.shape is CapsuleShape2D:
		var c := cs.shape as CapsuleShape2D
		size = Vector2(c.radius * 2.0, c.height)
	var center := p + (cs.global_position - global_position) * mm.scale_f
	var rect := Rect2(center - size * mm.scale_f * 0.5, size * mm.scale_f)
	if can_interact:
		canvas.draw_rect(rect, Color(0.9, 0.9, 0.9))
		canvas.draw_rect(rect, Color(0.0, 0.0, 0.0), false, 1.5)
	else:
		canvas.draw_rect(rect, Color(0.4, 0.4, 0.4))
