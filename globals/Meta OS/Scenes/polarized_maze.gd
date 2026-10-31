extends Node2D

# Multi stage perception maze with a transparent window.
# Hidden walls are invisible in normal view and glow inside the lens.

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

const STAGE_COLORS: Array[Color] = [
	Color(0.85, 0.95, 1.0, 1.0),
	Color(0.75, 0.35, 1.0, 1.0),
	Color(1.0, 0.45, 0.15, 1.0)
]


func _ready() -> void:
	# Main window setup with desktop transparency.
	var main_win: Window = get_window()
	main_win.title = "BLAIRE // PERCEPTION TEST"
	main_win.borderless = true
	main_win.transparent = true
	main_win.size = Vector2i(1020, 680)
	main_win.content_scale_size = Vector2i(1020, 680)
	main_win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	main_win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	
	# Enables per pixel transparency on the window and viewport.
	get_viewport().transparent_bg = true
	get_tree().root.transparent_bg = true
	RenderingServer.set_default_clear_color(Color(0, 0, 0, 0))
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true, DisplayServer.MAIN_WINDOW_ID)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_TRANSPARENT, true, DisplayServer.MAIN_WINDOW_ID)
	
	var screen_id: int = DisplayServer.get_primary_screen()
	var screen_origin: Vector2i = DisplayServer.screen_get_position(screen_id)
	var screen_size: Vector2i = DisplayServer.screen_get_size(screen_id)
	main_win.position = screen_origin + (screen_size - main_win.size) / 2
	
	# Main window only draws layer one, keeping layer two walls hidden.
	main_win.canvas_cull_mask = 1
	
	# Spawns player at start of the stage zero room.
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
	
	_load_stage(0)
	
	file_system_ui = FileSystemUI.new()
	add_child(file_system_ui)
	
	pause_menu = PauseMenuUI.new()
	add_child(pause_menu)
	
	time_banner = TimeBannerUI.new()
	add_child(time_banner)
	
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
	
	_init_starter_files()
	
	await get_tree().create_timer(0.4).timeout
	await play_glitched_prompt("[ W A S D   T O   M O V E ]", 2.0)
	await play_glitched_prompt("[ E   T O   O P E N   L E N S ]", 2.0)


func _init_starter_files() -> void:
	var f1 := GameFile.new()
	f1.file_id = "entry_letter"
	f1.filename = "a letter to ???.txt"
	f1.category = GameFile.Category.ENTRY
	f1.content = "I saw her standing by the fence.\nShe looked distant.\nWas it something I said?"
	f1.can_interpret = true
	FileManager.obtain_file(f1)
	
	var f2 := GameFile.new()
	f2.file_id = "photo_blaire"
	f2.filename = "small_blaire_teddy.png"
	f2.category = GameFile.Category.PHOTO
	f2.content = "A silhouette of Blaire holding her teddy bear."
	f2.can_intervene = true
	FileManager.obtain_file(f2)
	
	var f3 := GameFile.new()
	f3.file_id = "cipher_order"
	f3.filename = "the_order_directive.txt"
	f3.category = GameFile.Category.SECRET
	f3.cipher_type = GameFile.CipherType.CAESAR
	f3.content = "XLI SVHIV MW EPVIEHC LIVI.\nGLSMGI MW ER MPPYWMSR."
	f3.solved_content = "THE ORDER IS ALREADY HERE.\nCHOICE IS AN ILLUSION."
	f3.ghost_hint_unsolved = "The signal is shifted backward by four letters."
	f3.ghost_hint_solved = "The directive is locked. They are watching."
	f3.can_interpret = true
	f3.can_decode = true
	FileManager.obtain_file(f3)


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


# Stage zero, with the obstructing center rectangle removed.
func _build_stage_0_school() -> void:
	player.position = Vector2(95, 100)
	
	# Outer perimeter wall.
	var outer_wall_points := PackedVector2Array([
		Vector2(40, 40),
		Vector2(160, 40),
		Vector2(160, 60),
		Vector2(220, 60),
		Vector2(220, 40),
		Vector2(370, 40),
		Vector2(370, 160),
		Vector2(440, 160),
		Vector2(440, 40),
		Vector2(560, 40),
		Vector2(560, 200),
		Vector2(740, 200),
		Vector2(740, 160),
		Vector2(920, 160),
		Vector2(920, 460),
		Vector2(660, 460),
		Vector2(660, 340),
		Vector2(580, 340),
		Vector2(580, 580),
		Vector2(380, 580),
		Vector2(380, 460),
		Vector2(150, 460),
		Vector2(150, 340),
		Vector2(40, 340),
		Vector2(40, 40)
	])
	
	# Inner divider block for the right side path.
	var right_block_points := PackedVector2Array([
		Vector2(760, 270),
		Vector2(810, 270),
		Vector2(810, 370),
		Vector2(760, 370),
		Vector2(760, 270)
	])
	
	_build_continuous_wall(outer_wall_points, 0)
	_build_continuous_wall(right_block_points, 0)
	
	# Purple trigger placed inside the open room on the far right.
	_create_shift_trigger(Vector2(865, 230), 1)


# Stage one, matches drawing two, top right spawn to blue trigger on the left.
func _build_stage_1_order() -> void:
	player.position = Vector2(810, 130)
	
	var outer_wall_points := PackedVector2Array([
		Vector2(760, 60),
		Vector2(860, 60),
		Vector2(860, 430),
		Vector2(980, 430),
		Vector2(980, 520),
		Vector2(600, 520),
		Vector2(600, 600),
		Vector2(340, 600),
		Vector2(340, 470),
		Vector2(210, 470),
		Vector2(210, 260),
		Vector2(270, 260),
		Vector2(270, 380),
		Vector2(340, 380),
		Vector2(340, 280),
		Vector2(470, 280),
		Vector2(470, 160),
		Vector2(520, 160),
		Vector2(520, 280),
		Vector2(760, 280),
		Vector2(760, 60)
	])
	
	var center_island_points := PackedVector2Array([
		Vector2(630, 340),
		Vector2(760, 340),
		Vector2(760, 430),
		Vector2(630, 430),
		Vector2(630, 340)
	])
	
	var left_divider_points := PackedVector2Array([
		Vector2(400, 340),
		Vector2(470, 340),
		Vector2(470, 430),
		Vector2(430, 430),
		Vector2(430, 530),
		Vector2(530, 530),
		Vector2(530, 340),
		Vector2(400, 340)
	])
	
	_build_continuous_wall(outer_wall_points, 1)
	_build_continuous_wall(center_island_points, 1)
	_build_continuous_wall(left_divider_points, 1)
	
	_create_shift_trigger(Vector2(240, 320), 2)


# Stage two, matches drawing three, bottom right spawn to center red trigger.
func _build_stage_2_apartment() -> void:
	player.position = Vector2(590, 500)
	
	var outer_wall_points := PackedVector2Array([
		Vector2(540, 440),
		Vector2(640, 440),
		Vector2(640, 560),
		Vector2(350, 560),
		Vector2(350, 620),
		Vector2(260, 620),
		Vector2(260, 540),
		Vector2(60, 540),
		Vector2(60, 130),
		Vector2(340, 130),
		Vector2(340, 50),
		Vector2(650, 50),
		Vector2(650, 360),
		Vector2(400, 360),
		Vector2(400, 290),
		Vector2(580, 290),
		Vector2(580, 130),
		Vector2(400, 130),
		Vector2(400, 220),
		Vector2(140, 220),
		Vector2(140, 480),
		Vector2(180, 480),
		Vector2(180, 360),
		Vector2(240, 360),
		Vector2(240, 480),
		Vector2(400, 480),
		Vector2(400, 440),
		Vector2(540, 440)
	])
	
	_build_continuous_wall(outer_wall_points, 2)
	
	_create_final_exit_trigger(Vector2(430, 330))


func _build_continuous_wall(points: PackedVector2Array, stage_idx: int) -> void:
	if points.size() < 2:
		return
		
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 1
	body.visibility_layer = 2
	
	# Solid visual line with smooth corner joins and no seams.
	var line := Line2D.new()
	line.visibility_layer = 2
	line.width = 16.0
	line.points = points
	line.joint_mode = Line2D.LINE_JOINT_BEVEL
	line.begin_cap_mode = Line2D.LINE_CAP_BOX
	line.end_cap_mode = Line2D.LINE_CAP_BOX
	line.default_color = STAGE_COLORS[stage_idx]
	body.add_child(line)
	
	# Inner dark core.
	var core_line := Line2D.new()
	core_line.visibility_layer = 2
	core_line.width = 12.0
	core_line.points = points
	core_line.joint_mode = Line2D.LINE_JOINT_BEVEL
	core_line.default_color = Color(0.08, 0.08, 0.1, 1.0)
	body.add_child(core_line)
	
	# Generates collision segments along the path.
	for i in range(points.size() - 1):
		var p1: Vector2 = points[i]
		var p2: Vector2 = points[i + 1]
		
		var col := CollisionShape2D.new()
		var seg := SegmentShape2D.new()
		seg.a = p1
		seg.b = p2
		col.shape = seg
		body.add_child(col)
		
	maze_root.add_child(body)


func _create_shift_trigger(trigger_pos: Vector2, target_stage: int) -> void:
	var area := Area2D.new()
	area.position = trigger_pos
	area.collision_layer = 1
	area.collision_mask = 1
	
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 45.0
	col.shape = shape
	area.add_child(col)
	
	var indicator := Line2D.new()
	indicator.visibility_layer = 2
	indicator.width = 2.0
	indicator.closed = true
	indicator.default_color = STAGE_COLORS[target_stage]
	
	for i in range(16):
		var ang: float = (float(i) / 16.0) * TAU
		indicator.add_point(Vector2(cos(ang) * 35.0, sin(ang) * 35.0))
	area.add_child(indicator)
	
	area.body_entered.connect(func(body: Node2D):
		if body == player and current_stage != target_stage:
			trigger_perception_shift(target_stage)
	)
	maze_root.add_child(area)


func _create_final_exit_trigger(trigger_pos: Vector2) -> void:
	var area := Area2D.new()
	area.position = trigger_pos
	area.collision_layer = 1
	area.collision_mask = 1
	
	var col := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = 45.0
	col.shape = shape
	area.add_child(col)
	
	# Draw red circle matching the drawing.
	var red_indicator := Line2D.new()
	red_indicator.visibility_layer = 2
	red_indicator.width = 3.0
	red_indicator.closed = true
	red_indicator.default_color = Color("#e52230")
	
	for i in range(16):
		var ang: float = (float(i) / 16.0) * TAU
		red_indicator.add_point(Vector2(cos(ang) * 28.0, sin(ang) * 28.0))
	area.add_child(red_indicator)
	
	area.body_entered.connect(func(body: Node2D):
		if body == player and not is_shifting_perception:
			_run_final_sequence()
	)
	maze_root.add_child(area)


func trigger_perception_shift(new_stage: int) -> void:
	if is_shifting_perception:
		return
	is_shifting_perception = true
	
	# Resets drag state when closing window.
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


# Final sequence triggered by reaching the red circle.
func _run_final_sequence() -> void:
	if is_shifting_perception:
		return
	is_shifting_perception = true
	
	# Resets drag state when closing window.
	is_dragging_lens = false
	lens_window.hide()
	
	# Plays intense glitch distortion before hiding player.
	await _play_extended_final_glitch()
	
	player.hide()
	maze_root.hide()
	
	# Sequential error dialogue prompts.
	await MetaOS.show_dialog("Info", "[i]Please help me.[/i]", ["YES", "YES"])
	await MetaOS.show_dialog("Blocked", "She didn't come here.", ["OKAY"])
	await MetaOS.show_dialog("Info", "[i]It hurts.[/i]", ["I'M SORRY"])
	
	var no_buttons: Array[String] = []
	await MetaOS.show_dialog("Info", "[color=red][i]Burn down the house, Blaire.[/i][/color]", no_buttons)
	
	get_tree().quit()


# Intense glitch effect with transparent background preservation.
func _play_extended_final_glitch() -> void:
	glitch_overlay.show()
	var tween := create_tween()
	
	# Ten rapid pulses of chromatic aberration.
	for i in range(10):
		var power: float = randf_range(0.6, 1.0)
		tween.tween_method(func(val: float): glitch_material.set_shader_parameter("distortion_power", val), 0.0, power, 0.035)
		tween.tween_method(func(val: float): glitch_material.set_shader_parameter("distortion_power", val), power, 0.0, 0.035)
		
	# Quick flash of white on the lines.
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
			
			// Preserves transparency so empty desktop space does not turn into a black box.
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
	# Positions and sizes centered box.
	prompt_label.position = Vector2(310, 595)
	prompt_label.size = Vector2(400, 46)
	
	# Adds a semi transparent black background and border.
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
		
	# Releases dragging lock if physical mouse button was let go.
	if is_dragging_lens and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		is_dragging_lens = false
		
	var main_win_pos: Vector2i = DisplayServer.window_get_position(DisplayServer.MAIN_WINDOW_ID)
	var lens_win_pos: Vector2i = lens_window.position
	
	# Lens camera tracks relative to the game window.
	var offset: Vector2 = Vector2(lens_win_pos - main_win_pos) - WINDOWS_FRAME_OFFSET + Vector2(lens_window.size) / 2.0
	lens_camera.global_position = offset


func _on_lens_window_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			is_dragging_lens = true
			drag_start_mouse_pos = DisplayServer.mouse_get_position() - lens_window.position
		else:
			is_dragging_lens = false
	elif event is InputEventMouseMotion and is_dragging_lens:
		# Verifies left mouse button is physically held down.
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
	# Resets dragging state every time the window is toggled.
	is_dragging_lens = false
	if lens_window.visible:
		lens_window.hide()
	else:
		var main_win_pos: Vector2i = DisplayServer.window_get_position(DisplayServer.MAIN_WINDOW_ID)
		var spawn_pos: Vector2 = Vector2(main_win_pos) + WINDOWS_FRAME_OFFSET + player.position - Vector2(lens_window.size) / 2.0
		lens_window.position = Vector2i(spawn_pos)
		lens_window.show()
		lens_window.grab_focus()
