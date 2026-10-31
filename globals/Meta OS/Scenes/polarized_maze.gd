extends Node2D

# Multi stage perception maze where corridors are formed by connected negative word walls.
# Stage zero represents school alienation, stage one represents the order, stage two represents the fire.
# Walls are hidden in normal view and reveal their words inside the polarized lens.

@onready var player: CharacterBody2D = %Player
@onready var lens_window: Window = %LensWindow
@onready var lens_camera: Camera2D = %LensCamera

var is_dragging_lens: bool = false
var drag_start_mouse_pos: Vector2i = Vector2i.ZERO
var is_shifting_perception: bool = false

var current_stage: int = 0
var window_bounds := Vector2(1020, 680)

var file_system_ui: FileSystemUI
var pause_menu: PauseMenuUI
var time_banner: TimeBannerUI
var calendar_win: CalendarWindow

var glitch_overlay: ColorRect
var glitch_material: ShaderMaterial
var prompt_canvas: CanvasLayer
var prompt_label: Label

var maze_root: Node2D
var boundary_node: Node2D

const MOVE_SPEED: float = 240.0
const WINDOWS_FRAME_OFFSET := Vector2.ZERO

# Theme colors for each perception stage.
const STAGE_COLORS: Array[Color] = [
	Color(0.85, 0.95, 1.0, 1.0),
	Color(0.75, 0.35, 1.0, 1.0),
	Color(1.0, 0.45, 0.15, 1.0)
]


func _ready() -> void:
	# Main window setup with transparent background.
	var main_win: Window = get_window()
	main_win.title = "BLAIRE // PERCEPTION TEST"
	main_win.borderless = true
	main_win.transparent = true
	main_win.size = Vector2i(1020, 680)
	main_win.content_scale_size = Vector2i(1020, 680)
	main_win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	main_win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	
	get_viewport().transparent_bg = true
	get_tree().root.transparent_bg = true
	RenderingServer.set_default_clear_color(Color(0, 0, 0, 0))
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true, DisplayServer.MAIN_WINDOW_ID)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_TRANSPARENT, true, DisplayServer.MAIN_WINDOW_ID)
	
	var screen_id: int = DisplayServer.get_primary_screen()
	var screen_origin: Vector2i = DisplayServer.screen_get_position(screen_id)
	var screen_size: Vector2i = DisplayServer.screen_get_size(screen_id)
	main_win.position = screen_origin + (screen_size - main_win.size) / 2
	
	# Main window only draws layer one, keeping layer two word walls hidden.
	main_win.canvas_cull_mask = 1
	
	# Spawns player at top left.
	player.position = Vector2(95, 100)
	player.visibility_layer = 1
	player.show()
	
	var spr: Sprite2D = player.find_child("Sprite2D", true, false) as Sprite2D
	if spr:
		spr.visibility_layer = 1
		spr.show()
		if spr.texture:
			var tex_size := spr.texture.get_size()
			var factor: float = 36.0 / max(tex_size.x, tex_size.y)
			spr.scale = Vector2(factor, factor)
			
	var col: CollisionShape2D = player.find_child("CollisionShape2D", true, false) as CollisionShape2D
	if col and col.shape is CircleShape2D:
		col.shape.radius = 16.0
	
	# Setup polarized lens window.
	lens_window.world_2d = get_viewport().world_2d
	lens_window.canvas_cull_mask = 3
	lens_window.size = Vector2i(320, 320)
	lens_window.unresizable = true
	lens_window.borderless = true
	lens_window.always_on_top = true
	lens_camera.position_smoothing_enabled = false
	lens_camera.zoom = Vector2.ONE
	lens_window.hide()
	lens_window.window_input.connect(_on_lens_window_input)
	
	_build_glitch_overlay()
	_setup_glitch_prompt_ui()
	_build_window_boundaries(window_bounds)
	
	maze_root = Node2D.new()
	maze_root.name = "PerceptionMazeRoot"
	add_child(maze_root)
	
	# Loads connected hallway walls for stage zero.
	_load_stage(0)
	
	# Initialize external desktop overlays.
	file_system_ui = FileSystemUI.new()
	add_child(file_system_ui)
	
	pause_menu = PauseMenuUI.new()
	add_child(pause_menu)
	
	# Time banner logic is preserved, but not called here.
	
	calendar_win = CalendarWindow.new()
	add_child(calendar_win)
	
	calendar_win.request_open_filesystem.connect(func():
		if calendar_win.visible:
			calendar_win.toggle_calendar()
		if not file_system_ui.is_open:
			file_system_ui.toggle_filesystem()
	)
	
	file_system_ui.request_open_calendar.connect(func():
		if file_system_ui.is_open:
			file_system_ui.toggle_filesystem()
		if not calendar_win.visible:
			calendar_win.toggle_calendar()
	)
	
	
	await get_tree().create_timer(0.4).timeout
	await play_glitched_prompt("[ E   T O   O P E N   L E N S ]", 2.2)


func _build_window_boundaries(bounds: Vector2) -> void:
	boundary_node = Node2D.new()
	boundary_node.name = "WindowBoundaries"
	add_child(boundary_node)
	
	_create_boundary_wall(Vector2(bounds.x / 2.0, -15), Vector2(bounds.x + 50, 30))
	_create_boundary_wall(Vector2(bounds.x / 2.0, bounds.y + 15), Vector2(bounds.x + 50, 30))
	_create_boundary_wall(Vector2(-15, bounds.y / 2.0), Vector2(30, bounds.y + 50))
	_create_boundary_wall(Vector2(bounds.x + 15, bounds.y / 2.0), Vector2(30, bounds.y + 50))


func _create_boundary_wall(center_pos: Vector2, wall_size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.position = center_pos
	body.collision_layer = 1
	body.collision_mask = 1
	
	var col := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = wall_size
	col.shape = rect_shape
	body.add_child(col)
	boundary_node.add_child(body)


# Loads negative word walls matching the perception stage.
func _load_stage(stage_idx: int) -> void:
	current_stage = stage_idx
	
	for child in maze_root.get_children():
		child.queue_free()
		
	match stage_idx:
		0:
			_build_stage_0_school()
		1:
			_build_stage_1_order()
		2:
			_build_stage_2_apartment()


# Stage zero, school alienation hallway.
func _build_stage_0_school() -> void:
	# Spawns player inside the starting hallway.
	player.position = Vector2(100, 100)
	
	# Outer boundary walls.
	_create_word_wall(Vector2(40, 40), Vector2(400, 40), "FAKE FRIENDS", 0)
	_create_word_wall(Vector2(400, 40), Vector2(850, 40), "ALIENATION", 0)
	_create_word_wall(Vector2(850, 40), Vector2(850, 580), "EXCLUDED", 0)
	_create_word_wall(Vector2(650, 580), Vector2(850, 580), "HOPELESS", 0)
	
	# Inner boundary walls.
	_create_word_wall(Vector2(40, 40), Vector2(40, 160), "UNWANTED", 0)
	_create_word_wall(Vector2(40, 160), Vector2(300, 160), "ALONE", 0)
	_create_word_wall(Vector2(300, 160), Vector2(300, 360), "LEFT ON READ", 0)
	_create_word_wall(Vector2(300, 360), Vector2(730, 360), "SILENCE", 0)
	_create_word_wall(Vector2(730, 160), Vector2(730, 360), "OUTCAST", 0)
	_create_word_wall(Vector2(550, 160), Vector2(730, 160), "DISTANCE", 0)
	
	# Lower guiding walls into the trigger.
	_create_word_wall(Vector2(650, 460), Vector2(650, 580), "UNANSWERED", 0)
	_create_word_wall(Vector2(300, 460), Vector2(650, 460), "LAUGHED AT", 0)
	_create_word_wall(Vector2(300, 360), Vector2(300, 460), "LEFT BEHIND", 0)
	
	# Shift trigger placed in the open hallway pocket at the end.
	_create_shift_trigger(Vector2(750, 520), 1)


# Stage one, the order.
func _build_stage_1_order() -> void:
	# Spawns player inside the first hallway corridor.
	player.position = Vector2(120, 100)
	
	# Outer boundary walls.
	_create_word_wall(Vector2(50, 40), Vector2(500, 40), "SURRENDER", 1)
	_create_word_wall(Vector2(500, 40), Vector2(900, 40), "NO ESCAPE", 1)
	_create_word_wall(Vector2(900, 40), Vector2(900, 550), "SEVER CONTACT", 1)
	_create_word_wall(Vector2(200, 550), Vector2(900, 550), "COMPLY", 1)
	
	# Inner divider walls creating winding corridors.
	_create_word_wall(Vector2(50, 40), Vector2(50, 160), "OBEY", 1)
	_create_word_wall(Vector2(50, 160), Vector2(400, 160), "THEY LIED TO YOU", 1)
	_create_word_wall(Vector2(400, 160), Vector2(400, 380), "NOTHING IS REAL", 1)
	_create_word_wall(Vector2(400, 380), Vector2(780, 380), "ANARCHY", 1)
	_create_word_wall(Vector2(780, 160), Vector2(780, 380), "WE ARE YOUR FAMILY", 1)
	_create_word_wall(Vector2(600, 160), Vector2(780, 160), "BLIND FAITH", 1)
	
	# Left chamber walls leading directly to the trigger without gaps.
	_create_word_wall(Vector2(400, 380), Vector2(400, 460), "THE ORDER", 1)
	_create_word_wall(Vector2(200, 460), Vector2(400, 460), "MANDATORY DIRECTIVE", 1)
	_create_word_wall(Vector2(200, 460), Vector2(200, 550), "SURRENDER CONTROL", 1)
	
	# Amber trigger placed safely inside the closed chamber.
	_create_shift_trigger(Vector2(300, 505), 2)


# Stage two, the apartment and arson.
func _build_stage_2_apartment() -> void:
	player.position = Vector2(320, 500)
	
	# Outer perimeter enclosure.
	_create_word_wall(Vector2(100, 60), Vector2(850, 60), "BROKEN HOME", 2)
	_create_word_wall(Vector2(850, 60), Vector2(850, 580), "BURDEN", 2)
	_create_word_wall(Vector2(200, 580), Vector2(850, 580), "ASHES", 2)
	_create_word_wall(Vector2(100, 60), Vector2(100, 440), "COWARD", 2)
	_create_word_wall(Vector2(100, 440), Vector2(200, 440), "TOO LATE", 2)
	_create_word_wall(Vector2(200, 440), Vector2(200, 580), "REGRET", 2)
	
	# Inner maze corridors.
	_create_word_wall(Vector2(220, 180), Vector2(730, 180), "RUNNING AWAY", 2)
	_create_word_wall(Vector2(730, 180), Vector2(730, 440), "LOST YEARS", 2)
	_create_word_wall(Vector2(350, 440), Vector2(730, 440), "BURN DOWN THE HOUSE", 2)
	_create_word_wall(Vector2(350, 280), Vector2(350, 440), "BLAIRE", 2)
	_create_word_wall(Vector2(350, 280), Vector2(600, 280), "POINT OF NO RETURN", 2)
	
	# Final red checkpoint inside the central chamber.
	_create_final_exit_trigger(Vector2(500, 360))


# Creates a physical wall displaying a negative word with seamless corner joints.
func _create_word_wall(from_pt: Vector2, to_pt: Vector2, word: String, stage_idx: int) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 1
	body.visibility_layer = 2
	
	var length: float = from_pt.distance_to(to_pt)
	var angle: float = from_pt.angle_to_point(to_pt)
	var center: Vector2 = (from_pt + to_pt) / 2.0
	var wall_thickness: float = 24.0
	
	var full_len: float = length + wall_thickness
	
	body.position = center
	body.rotation = angle
	
	var col := CollisionShape2D.new()
	var rect_shape := RectangleShape2D.new()
	rect_shape.size = Vector2(full_len, wall_thickness)
	col.shape = rect_shape
	body.add_child(col)
	
	var bg := ColorRect.new()
	bg.size = Vector2(full_len, wall_thickness)
	bg.position = -bg.size / 2.0
	bg.color = Color(0.06, 0.06, 0.08, 1.0)
	bg.visibility_layer = 2
	body.add_child(bg)
	
	var border := Line2D.new()
	border.visibility_layer = 2
	border.width = 2.0
	border.closed = true
	border.joint_mode = Line2D.LINE_JOINT_BEVEL
	border.default_color = STAGE_COLORS[stage_idx]
	
	var half := bg.size / 2.0
	border.points = PackedVector2Array([
		Vector2(-half.x, -half.y),
		Vector2(half.x, -half.y),
		Vector2(half.x, half.y),
		Vector2(-half.x, half.y)
	])
	body.add_child(border)
	
	var lbl := Label.new()
	lbl.visibility_layer = 2
	lbl.text = word
	lbl.size = Vector2(length, wall_thickness)
	lbl.position = -lbl.size / 2.0
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
	
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Cartograph Mono", "TG Frekuent Mono", "Consolas", "monospace"])
	font.font_weight = 600
	lbl.add_theme_font_override("font", font)
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", STAGE_COLORS[stage_idx])
	
	body.add_child(lbl)
	maze_root.add_child(body)


# Creates a checkpoint door icon transitioning to the next perception stage.
func _create_shift_trigger(trigger_pos: Vector2, target_stage: int) -> void:
	var area := Area2D.new()
	area.position = trigger_pos
	area.collision_layer = 1
	area.collision_mask = 1
	
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(40.0, 52.0)
	col.shape = shape
	area.add_child(col)
	
	_attach_door_graphic(area, STAGE_COLORS[target_stage])
	
	area.body_entered.connect(func(body: Node2D):
		if body == player and current_stage != target_stage:
			trigger_perception_shift(target_stage)
	)
	maze_root.add_child(area)


# Final exit door triggering the sequence.
func _create_final_exit_trigger(trigger_pos: Vector2) -> void:
	var area := Area2D.new()
	area.position = trigger_pos
	area.collision_layer = 1
	area.collision_mask = 1
	
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(40.0, 52.0)
	col.shape = shape
	area.add_child(col)
	
	_attach_door_graphic(area, Color("#e52230"))
	
	area.body_entered.connect(func(body: Node2D):
		if body == player and not is_shifting_perception:
			_run_final_sequence()
	)
	maze_root.add_child(area)
	

# Helper that draws a retro one bit door frame, inner panel, and doorknob.
func _attach_door_graphic(parent: Node2D, door_color: Color) -> void:
	var frame := Line2D.new()
	frame.visibility_layer = 2
	frame.width = 2.0
	frame.closed = true
	frame.default_color = door_color
	frame.points = PackedVector2Array([
		Vector2(-18, -26),
		Vector2(18, -26),
		Vector2(18, 26),
		Vector2(-18, 26)
	])
	parent.add_child(frame)
	
	var panel := Line2D.new()
	panel.visibility_layer = 2
	panel.width = 1.5
	panel.closed = true
	panel.default_color = door_color
	panel.points = PackedVector2Array([
		Vector2(-14, -22),
		Vector2(14, -22),
		Vector2(14, 26),
		Vector2(-14, 26)
	])
	parent.add_child(panel)
	
	var knob := Line2D.new()
	knob.visibility_layer = 2
	knob.width = 2.0
	knob.closed = true
	knob.default_color = door_color
	knob.points = PackedVector2Array([
		Vector2(6, 2),
		Vector2(10, 2),
		Vector2(10, 6),
		Vector2(6, 6)
	])
	parent.add_child(knob)


# Shifts perception stage with glitch distortion.
func trigger_perception_shift(new_stage: int) -> void:
	if is_shifting_perception:
		return
	is_shifting_perception = true
	
	is_dragging_lens = false
	lens_window.hide()
	glitch_overlay.show()
	var tween := create_tween()
	
	for i in range(4):
		var power: float = randf_range(0.5, 0.9)
		tween.tween_method(func(val: float): glitch_material.set_shader_parameter("distortion_power", val), 0.0, power, 0.04)
		tween.tween_method(func(val: float): glitch_material.set_shader_parameter("distortion_power", val), power, 0.0, 0.04)
		
	tween.tween_method(func(val: float): glitch_material.set_shader_parameter("white_flash", val), 0.0, 1.0, 0.05)
	
	tween.tween_callback(func():
		_load_stage(new_stage)
	)
	
	tween.tween_method(func(val: float): glitch_material.set_shader_parameter("white_flash", val), 1.0, 0.0, 0.12)
	
	await tween.finished
	glitch_overlay.hide()
	is_shifting_perception = false


# Final sequence triggered by reaching the red door.
func _run_final_sequence() -> void:
	if is_shifting_perception:
		return
	is_shifting_perception = true
	
	is_dragging_lens = false
	lens_window.hide()
	
	# Plays the final glitch distortion.
	await _play_extended_final_glitch()
	
	player.hide()
	maze_root.hide()
	
	# Brief pause after distortion before closing.
	await get_tree().create_timer(0.4).timeout
	get_tree().quit()


# Intense glitch effect with transparent background preservation.
func _play_extended_final_glitch() -> void:
	glitch_overlay.show()
	var tween := create_tween()
	
	for i in range(10):
		var power: float = randf_range(0.6, 1.0)
		tween.tween_method(func(val: float): glitch_material.set_shader_parameter("distortion_power", val), 0.0, power, 0.035)
		tween.tween_method(func(val: float): glitch_material.set_shader_parameter("distortion_power", val), power, 0.0, 0.035)
		
	tween.tween_method(func(val: float): glitch_material.set_shader_parameter("white_flash", val), 0.0, 1.0, 0.15)
	tween.tween_interval(0.2)
	tween.tween_method(func(val: float): glitch_material.set_shader_parameter("white_flash", val), 1.0, 0.0, 0.25)
	
	await tween.finished
	glitch_overlay.hide()


func _build_glitch_overlay() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 125
	add_child(canvas)
	
	glitch_overlay = ColorRect.new()
	glitch_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	glitch_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var shader := Shader.new()
	shader.code = """
		shader_type canvas_item;
		uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
		uniform float distortion_power : hint_range(0.0, 1.0) = 0.0;
		uniform float white_flash : hint_range(0.0, 1.0) = 0.0;

		void fragment() {
			vec2 uv = SCREEN_UV;
			vec2 purple_offset = vec2(distortion_power * 0.04, 0.0);
			vec2 yellow_offset = vec2(-distortion_power * 0.04, 0.0);
			
			vec4 base_col = texture(screen_texture, uv);
			vec4 purple_col = texture(screen_texture, uv + purple_offset);
			vec4 yellow_col = texture(screen_texture, uv + yellow_offset);
			
			vec3 chrom = base_col.rgb;
			chrom.r = purple_col.r * (1.0 + distortion_power * 1.5);
			chrom.b = purple_col.b * (1.0 + distortion_power * 2.0);
			chrom.g = yellow_col.g * (1.0 + distortion_power * 1.2);
			
			vec3 final_rgb = mix(chrom, vec3(1.0), white_flash);
			float alpha = clamp(base_col.a + purple_col.a + yellow_col.a, 0.0, 1.0);
			COLOR = vec4(final_rgb, alpha);
		}
	"""
	glitch_material = ShaderMaterial.new()
	glitch_material.shader = shader
	glitch_material.set_shader_parameter("distortion_power", 0.0)
	glitch_material.set_shader_parameter("white_flash", 0.0)
	glitch_overlay.material = glitch_material
	glitch_overlay.hide()
	canvas.add_child(glitch_overlay)


func _setup_glitch_prompt_ui() -> void:
	prompt_canvas = CanvasLayer.new()
	prompt_canvas.layer = 110
	add_child(prompt_canvas)
	
	prompt_label = Label.new()
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prompt_label.position = Vector2(310, 595)
	prompt_label.size = Vector2(400, 46)
	
	var bg_style := StyleBoxFlat.new()
	bg_style.bg_color = Color(0.0, 0.0, 0.0, 0.72)
	bg_style.border_width_left = 1
	bg_style.border_width_top = 1
	bg_style.border_width_right = 1
	bg_style.border_width_bottom = 1
	bg_style.border_color = Color(0.25, 0.25, 0.3, 0.8)
	bg_style.set_corner_radius_all(6)
	prompt_label.add_theme_stylebox_override("normal", bg_style)
	
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Cartograph Mono", "TG Frekuent Mono", "Cascadia Code", "monospace"])
	font.font_weight = 600
	prompt_label.add_theme_font_override("font", font)
	prompt_label.add_theme_font_size_override("font_size", 16)
	prompt_label.add_theme_color_override("font_color", Color.WHITE)
	
	prompt_canvas.add_child(prompt_label)
	prompt_label.hide()


func play_glitched_prompt(final_text: String, display_hold: float = 2.0) -> void:
	prompt_label.show()
	prompt_label.modulate.a = 1.0
	var glitch_chars := ["█", "░", "■", "0", "1", "X", "#", "&", "?", "/"]
	var current_text := ""
	
	for i in range(final_text.length()):
		var target_char: String = final_text[i]
		
		if target_char != " " and randf() < 0.65:
			prompt_label.text = current_text + glitch_chars.pick_random()
			await get_tree().create_timer(0.025).timeout
			
		current_text += target_char
		prompt_label.text = current_text
		await get_tree().create_timer(0.035).timeout
		
	await get_tree().create_timer(display_hold).timeout
	
	var fade := create_tween()
	fade.tween_property(prompt_label, "modulate:a", 0.0, 0.4)
	await fade.finished
	prompt_label.hide()


func _physics_process(_delta: float) -> void:
	if is_shifting_perception or (file_system_ui and file_system_ui.is_open):
		player.velocity = Vector2.ZERO
		return
		
	var move_input := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_action_pressed("ui_up"): move_input.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_action_pressed("ui_down"): move_input.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_action_pressed("ui_left"): move_input.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_action_pressed("ui_right"): move_input.x += 1.0
		
	player.velocity = move_input.normalized() * MOVE_SPEED
	player.move_and_slide()
	
	player.position.x = clampf(player.position.x, 24.0, window_bounds.x - 24.0)
	player.position.y = clampf(player.position.y, 24.0, window_bounds.y - 24.0)


func _process(_delta: float) -> void:
	if not lens_window.visible:
		return
		
	if is_dragging_lens and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		is_dragging_lens = false
		
	var main_win_pos: Vector2i = DisplayServer.window_get_position(DisplayServer.MAIN_WINDOW_ID)
	var lens_win_pos: Vector2i = lens_window.position
	
	var offset: Vector2 = Vector2(lens_win_pos - main_win_pos) - WINDOWS_FRAME_OFFSET + Vector2(lens_window.size) / 2.0
	lens_camera.global_position = offset


func _on_lens_window_input(event: InputEvent) -> void:
	# Forwards keyboard inputs to the main controls if the lens window is clicked.
	if event is InputEventKey:
		_unhandled_input(event)
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			is_dragging_lens = true
			drag_start_mouse_pos = DisplayServer.mouse_get_position() - lens_window.position
		else:
			is_dragging_lens = false
	elif event is InputEventMouseMotion and is_dragging_lens:
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			is_dragging_lens = false
			return
		lens_window.position = DisplayServer.mouse_get_position() - drag_start_mouse_pos


func _unhandled_input(event: InputEvent) -> void:
	if is_shifting_perception:
		return
		
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_E:
			_toggle_lens_window()
		elif event.keycode == KEY_Q:
			file_system_ui.toggle_filesystem()
		elif event.keycode == KEY_T:
			file_system_ui.toggle_terminal()
		elif event.keycode == KEY_C:
			calendar_win.toggle_calendar()
		elif event.keycode == KEY_ESCAPE:
			pause_menu.toggle_pause()


func _toggle_lens_window() -> void:
	is_dragging_lens = false
	if lens_window.visible:
		lens_window.hide()
	else:
		var main_win_pos: Vector2i = DisplayServer.window_get_position(DisplayServer.MAIN_WINDOW_ID)
		var spawn_pos: Vector2 = Vector2(main_win_pos) + WINDOWS_FRAME_OFFSET + player.position - Vector2(lens_window.size) / 2.0
		lens_window.position = Vector2i(spawn_pos)
		lens_window.show()
		# Keeps keyboard focus on the main game window.
		get_window().grab_focus()
