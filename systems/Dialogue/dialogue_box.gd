extends CanvasLayer
class_name DialogueBox

signal line_started(line: DialogueLine, index: int)
signal finished

enum PortraitBob { OFF, WHILE_TALKING, ALWAYS }

const BOX_HEIGHT := 130.0
const SIDE_MARGIN := 40.0
const BOTTOM_MARGIN := 14.0
const CHARS_PER_SECOND := 50.0
const FONT_SIZE := 24

var lines: Array[DialogueLine] = []
var title: String = ""
var frames: SpriteFrames
var show_placeholder: bool = false
var pause_world: bool = true
var bob_mode: PortraitBob = PortraitBob.WHILE_TALKING
var bob_height: float = 10.0
var bob_speed: float = 3.0

var bob_amount: float = 0.0
var bob_clock: float = 0.0
var portrait_base: Vector2 = Vector2.ZERO

var index: int = -1
var was_paused: bool = false
var shown: float = 0.0
var typing: bool = false

var root: Control
var box: Panel
var tag_panel: PanelContainer
var tag_label: Label
var text_label: Label
var arrow: Control
var sprite: AnimatedSprite2D
var placeholder: Control

## Opens the box on top of the game. Gives back null if one is already open
static func open(host: Node, new_lines: Array[DialogueLine], speaker: String = "", portrait: SpriteFrames = null, placeholder_portrait: bool = false, pause: bool = true) -> DialogueBox:
	var tree := host.get_tree()
	if new_lines.is_empty() or tree.get_first_node_in_group("dialogue_box") != null:
		return null
	var d := DialogueBox.new()
	d.lines = new_lines
	d.title = speaker
	d.frames = portrait
	d.show_placeholder = placeholder_portrait
	d.pause_world = pause
	tree.current_scene.add_child(d)
	return d

func _ready() -> void:
	layer = 60
	# has to keep running while the game is paused or it would freeze too
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("dialogue_box")

	if pause_world:
		was_paused = get_tree().paused
		get_tree().paused = true

	build_ui()
	get_viewport().size_changed.connect(place_portrait)
	next_line()

func build_ui() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	# the face goes in first so the box covers its feet
	if frames != null:
		sprite = AnimatedSprite2D.new()
		sprite.sprite_frames = frames
		root.add_child(sprite)
	elif show_placeholder:
		placeholder = Control.new()
		placeholder.clip_contents = true
		placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		placeholder.draw.connect(_draw_placeholder)
		root.add_child(placeholder)

	box = Panel.new()
	box.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	box.offset_left = SIDE_MARGIN
	box.offset_right = -SIDE_MARGIN
	box.offset_top = -(BOX_HEIGHT + BOTTOM_MARGIN)
	box.offset_bottom = -BOTTOM_MARGIN
	box.add_theme_stylebox_override("panel", make_box(Color(0.09, 0.09, 0.09, 0.94), Color(0.8, 0.8, 0.8), 3, 6))
	root.add_child(box)

	text_label = Label.new()
	text_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	text_label.offset_left = 30.0
	text_label.offset_top = 28.0
	text_label.offset_right = -56.0
	text_label.offset_bottom = -14.0
	text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text_label.add_theme_font_size_override("font_size", FONT_SIZE)
	text_label.add_theme_color_override("font_color", Color(0.95, 0.95, 0.95))
	box.add_child(text_label)

	arrow = Control.new()
	arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arrow.anchor_left = 1.0
	arrow.anchor_right = 1.0
	arrow.anchor_top = 1.0
	arrow.anchor_bottom = 1.0
	arrow.offset_left = -50.0
	arrow.offset_top = -34.0
	arrow.offset_right = -26.0
	arrow.offset_bottom = -14.0
	arrow.draw.connect(_draw_arrow)
	box.add_child(arrow)

	# name tag sits on the top left corner of the box
	tag_panel = PanelContainer.new()
	var tag_style := make_box(Color(0.85, 0.85, 0.85), Color(0.1, 0.1, 0.1), 3, 4)
	tag_style.content_margin_left = 16.0
	tag_style.content_margin_right = 16.0
	tag_style.content_margin_top = 3.0
	tag_style.content_margin_bottom = 3.0
	tag_panel.add_theme_stylebox_override("panel", tag_style)
	tag_panel.anchor_left = 0.0
	tag_panel.anchor_right = 0.0
	tag_panel.anchor_top = 1.0
	tag_panel.anchor_bottom = 1.0
	tag_panel.offset_left = SIDE_MARGIN + 18.0
	tag_panel.offset_right = SIDE_MARGIN + 18.0
	tag_panel.offset_top = -(BOX_HEIGHT + BOTTOM_MARGIN) - 18.0
	tag_panel.offset_bottom = -(BOX_HEIGHT + BOTTOM_MARGIN) - 18.0
	root.add_child(tag_panel)

	tag_label = Label.new()
	tag_label.add_theme_font_size_override("font_size", 22)
	tag_label.add_theme_color_override("font_color", Color(0.05, 0.05, 0.05))
	tag_panel.add_child(tag_label)

func make_box(bg: Color, border: Color, border_w: int, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	return sb

func next_line() -> void:
	index += 1
	if index >= lines.size():
		close()
		return

	var line := lines[index]
	var who := line.speaker if line.speaker != "" else title
	tag_label.text = who
	tag_panel.visible = who != ""

	text_label.text = line.text
	shown = 0.0
	typing = line.text.length() > 0
	text_label.visible_characters = 0 if typing else -1
	arrow.visible = not typing

	set_expression(line.expression)
	place_portrait()
	line_started.emit(line, index)

func finish_typing() -> void:
	typing = false
	text_label.visible_characters = -1
	arrow.visible = true

func close() -> void:
	if pause_world:
		get_tree().paused = was_paused
	finished.emit()
	queue_free()

func _process(delta: float) -> void:
	if typing:
		shown += CHARS_PER_SECOND * delta
		text_label.visible_characters = int(shown)
		if int(shown) >= lines[index].text.length():
			finish_typing()
	else:
		# the little arrow blinks when it's waiting for you
		arrow.modulate.a = 0.55 + 0.45 * sin(Time.get_ticks_msec() / 1000.0 * 6.0)
	update_bob(delta)

func update_bob(delta: float) -> void:
	if sprite == null and placeholder == null:
		return
	var active := bob_mode == PortraitBob.ALWAYS or (bob_mode == PortraitBob.WHILE_TALKING and typing)
	# eases in and out so it doesn't snap when the text starts or stops
	bob_amount = move_toward(bob_amount, 1.0 if active else 0.0, delta * 6.0)
	if bob_amount <= 0.0:
		bob_clock = 0.0
	else:
		bob_clock += delta * bob_speed
	var y := -absf(sin(bob_clock * PI)) * bob_height * bob_amount
	if sprite != null:
		sprite.position = portrait_base + Vector2(0.0, y)
	elif placeholder != null:
		placeholder.position = portrait_base + Vector2(0.0, y)

func _unhandled_input(event: InputEvent) -> void:
	if not is_advance_event(event):
		return
	get_viewport().set_input_as_handled()
	if typing:
		finish_typing()
	else:
		next_line()

func is_advance_event(event: InputEvent) -> bool:
	# interact key, or space and enter since those are ui_accept
	if event.is_action_pressed("ui_accept"):
		return true
	if InputMap.has_action("interact") and event.is_action_pressed("interact"):
		return true
	return event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E

func set_expression(expr: String) -> void:
	if sprite == null or frames == null:
		return
	var names := frames.get_animation_names()
	if names.is_empty():
		return
	var anim := StringName(expr)
	if expr == "" or not frames.has_animation(anim):
		anim = pick_fallback_animation()
	sprite.play(anim)

func pick_fallback_animation() -> StringName:
	# a fresh SpriteFrames always has an empty "default", so skip animations with no frames in them. "neutral" is the next best guess
	for preferred in [&"default", &"neutral"]:
		if frames.has_animation(preferred) and frames.get_frame_count(preferred) > 0:
			return preferred
	for n in frames.get_animation_names():
		if frames.get_frame_count(n) > 0:
			return StringName(n)
	return &"default"

func place_portrait() -> void:
	if root == null or index < 0 or index >= lines.size():
		return
	var vp := get_viewport().get_visible_rect().size
	var box_top := vp.y - BOTTOM_MARGIN - BOX_HEIGHT
	var on_right := lines[index].side == DialogueLine.FaceSide.RIGHT
	var cx := vp.x * (0.78 if on_right else 0.22)
	var target_h := vp.y * 0.62

	if sprite != null and frames != null and frames.has_animation(sprite.animation):
		var tex := frames.get_frame_texture(sprite.animation, 0)
		if tex != null:
			var s := target_h / float(tex.get_height())
			sprite.scale = Vector2(s, s)
			sprite.centered = false
			sprite.offset = Vector2(-tex.get_width() * 0.5, -tex.get_height())
			sprite.position = Vector2(cx, box_top + 40.0)
			portrait_base = sprite.position

	if placeholder != null:
		placeholder.size = Vector2(target_h * 0.5, target_h)
		placeholder.position = Vector2(cx - placeholder.size.x * 0.5, box_top + 40.0 - target_h)
		portrait_base = placeholder.position
		placeholder.queue_redraw()

func _draw_placeholder() -> void:
	# plain grey stand-in until real faces exist
	var w := placeholder.size.x
	var h := placeholder.size.y
	var edge := Color(0.0, 0.0, 0.0)
	var fill := Color(0.45, 0.45, 0.45)
	placeholder.draw_circle(Vector2(w * 0.5, w * 0.28), w * 0.22 + 4.0, edge)
	placeholder.draw_rect(Rect2(w * 0.16 - 4.0, w * 0.52 - 4.0, w * 0.68 + 8.0, h), edge)
	placeholder.draw_circle(Vector2(w * 0.5, w * 0.28), w * 0.22, fill)
	placeholder.draw_rect(Rect2(w * 0.16, w * 0.52, w * 0.68, h), fill)

func _draw_arrow() -> void:
	var a := arrow.size
	arrow.draw_colored_polygon(PackedVector2Array([Vector2(0.0, 0.0), Vector2(a.x, 0.0), Vector2(a.x * 0.5, a.y)]), Color(0.9, 0.9, 0.9))
