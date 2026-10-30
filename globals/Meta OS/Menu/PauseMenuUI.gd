class_name PauseMenuUI
extends Window

# Fullscreen desktop pause menu with sliding date badge and gradual blur transitions.

var is_paused: bool = false
var system_font: SystemFont
var content_font: SystemFont

var background_rect: TextureRect
var blur_material: ShaderMaterial
var menu_container: VBoxContainer
var resume_btn: Button
var settings_btn: Button
var exit_btn: Button

# Scaled up date badge and time slot components.
var date_badge: HBoxContainer
var weekday_lbl: Label
var day_lbl: Label
var slot_lbl: Label

var current_focus_idx: int = 0
var buttons: Array[Button] = []
var active_transition: Tween

var quit_dialog: PanelContainer
var quit_dialog_open: bool = false


func _init() -> void:
	borderless = true
	always_on_top = true
	unresizable = true
	transient = false
	exclusive = false
	title = "PAUSE"
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	_setup_fonts()
	_build_ui()


func _ready() -> void:
	hide()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_ESCAPE:
			if quit_dialog_open:
				_close_quit_dialog()
			else:
				toggle_pause()
			get_viewport().set_input_as_handled()
		elif is_paused and not quit_dialog_open:
			if event.keycode == KEY_UP or event.keycode == KEY_W:
				_change_selection(-1)
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_DOWN or event.keycode == KEY_S:
				_change_selection(1)
				get_viewport().set_input_as_handled()
			elif event.keycode == KEY_ENTER or event.keycode == KEY_SPACE:
				buttons[current_focus_idx].pressed.emit()
				get_viewport().set_input_as_handled()


func toggle_pause() -> void:
	if is_paused:
		_animate_close()
	else:
		is_paused = true
		get_tree().paused = true
		_close_quit_dialog()
		_capture_desktop()
		_update_badge()
		show()
		grab_focus()
		DisplayServer.window_move_to_foreground(get_window_id())
		_animate_open()


func _capture_desktop() -> void:
	var screen_id: int = DisplayServer.get_primary_screen()
	var screen_origin: Vector2i = DisplayServer.screen_get_position(screen_id)
	var screen_size: Vector2i = DisplayServer.screen_get_size(screen_id)
	
	size = screen_size
	position = screen_origin
	
	menu_container.position.y = int(float(screen_size.y) * 0.52)
	quit_dialog.position = (Vector2(screen_size) - quit_dialog.size) / 2.0
	
	var desktop_img: Image = DisplayServer.screen_get_image(screen_id)
	if desktop_img and not desktop_img.is_empty():
		background_rect.texture = ImageTexture.create_from_image(desktop_img)


# Gradual blur in, with date badge and menu sliding in from the left.
func _animate_open() -> void:
	if active_transition and active_transition.is_valid():
		active_transition.kill()
		
	# Start both elements off screen on the left.
	menu_container.position.x = -350.0
	menu_container.modulate.a = 0.0
	
	date_badge.position.x = -400.0
	date_badge.modulate.a = 0.0
	
	blur_material.set_shader_parameter("blur_amount", 0.0)
	blur_material.set_shader_parameter("dim_amount", 1.0)
	
	active_transition = create_tween().set_parallel(true)
	active_transition.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	
	# Background blur.
	active_transition.tween_method(func(val: float): blur_material.set_shader_parameter("blur_amount", val), 0.0, 4.2, 0.35)
	active_transition.tween_method(func(val: float): blur_material.set_shader_parameter("dim_amount", val), 1.0, 0.36, 0.35)
	
	# Menu options slide from the left.
	active_transition.tween_property(menu_container, "position:x", 80.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	active_transition.tween_property(menu_container, "modulate:a", 1.0, 0.25)
	
	# Date badge slides from the left into the top left corner.
	active_transition.tween_property(date_badge, "position:x", 45.0, 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	active_transition.tween_property(date_badge, "modulate:a", 1.0, 0.28)
	
	current_focus_idx = 0
	_update_selection_visuals()


# Gradual unblur, with date badge and menu sliding out to the left.
func _animate_close() -> void:
	if active_transition and active_transition.is_valid():
		active_transition.kill()
		
	active_transition = create_tween().set_parallel(true)
	active_transition.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	
	# Smoothly dissolves the blur and dim.
	active_transition.tween_method(func(val: float): blur_material.set_shader_parameter("blur_amount", val), 4.2, 0.0, 0.25)
	active_transition.tween_method(func(val: float): blur_material.set_shader_parameter("dim_amount", val), 0.36, 1.0, 0.25)
	
	# Menu options slide out to the left.
	active_transition.tween_property(menu_container, "position:x", -350.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	active_transition.tween_property(menu_container, "modulate:a", 0.0, 0.2)
	
	# Date badge slides out to the left.
	active_transition.tween_property(date_badge, "position:x", -400.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	active_transition.tween_property(date_badge, "modulate:a", 0.0, 0.18)
	
	await active_transition.finished
	is_paused = false
	get_tree().paused = false
	hide()
	DisplayServer.window_move_to_foreground(DisplayServer.MAIN_WINDOW_ID)
	get_tree().root.get_window().grab_focus()


func _change_selection(direction: int) -> void:
	current_focus_idx = posmod(current_focus_idx + direction, buttons.size())
	_update_selection_visuals()


func _update_selection_visuals() -> void:
	for i in range(buttons.size()):
		var b := buttons[i]
		var raw_name: String = b.get_meta("label_name", "")
		if i == current_focus_idx:
			b.text = "> " + raw_name
			b.add_theme_color_override("font_color", Color.WHITE)
		else:
			b.text = "  " + raw_name
			b.add_theme_color_override("font_color", Color("#777777"))


func _update_badge() -> void:
	weekday_lbl.text = TimeManager.get_weekday_name()
	day_lbl.text = "%02d" % TimeManager.current_day
	slot_lbl.text = TimeManager.get_slot_symbol() + "  " + TimeManager.get_slot_name()


func _open_quit_dialog() -> void:
	quit_dialog_open = true
	quit_dialog.show()


func _close_quit_dialog() -> void:
	quit_dialog_open = false
	quit_dialog.hide()


func _setup_fonts() -> void:
	system_font = SystemFont.new()
	system_font.font_names = PackedStringArray(["Cartograph Mono", "Cartograph CF", "TG Frekuent Mono", "Consolas", "monospace"])
	system_font.font_weight = 550
	system_font.hinting = TextServer.HINTING_NORMAL
	system_font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	
	content_font = SystemFont.new()
	content_font.font_names = PackedStringArray(["Jost", "Futura", "Inter", "Segoe UI", "sans-serif"])
	content_font.font_weight = 400
	content_font.font_italic = true


func _build_ui() -> void:
	background_rect = TextureRect.new()
	background_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	background_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background_rect.stretch_mode = TextureRect.STRETCH_SCALE
	background_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var shader := Shader.new()
	shader.code = """
		shader_type canvas_item;
		uniform float blur_amount : hint_range(0.0, 10.0) = 4.0;
		uniform float dim_amount : hint_range(0.0, 1.0) = 0.36;
		void fragment() {
			vec2 size = vec2(textureSize(TEXTURE, 0));
			vec2 pixel = vec2(1.0) / size;
			vec4 sum = vec4(0.0);
			sum += texture(TEXTURE, UV + vec2(-pixel.x * blur_amount, -pixel.y * blur_amount)) * 0.09;
			sum += texture(TEXTURE, UV + vec2(0.0, -pixel.y * blur_amount)) * 0.12;
			sum += texture(TEXTURE, UV + vec2(pixel.x * blur_amount, -pixel.y * blur_amount)) * 0.09;
			sum += texture(TEXTURE, UV + vec2(-pixel.x * blur_amount, 0.0)) * 0.12;
			sum += texture(TEXTURE, UV) * 0.16;
			sum += texture(TEXTURE, UV + vec2(pixel.x * blur_amount, 0.0)) * 0.12;
			sum += texture(TEXTURE, UV + vec2(-pixel.x * blur_amount, pixel.y * blur_amount)) * 0.09;
			sum += texture(TEXTURE, UV + vec2(0.0, pixel.y * blur_amount)) * 0.12;
			sum += texture(TEXTURE, UV + vec2(pixel.x * blur_amount, pixel.y * blur_amount)) * 0.09;
			sum.rgb *= dim_amount;
			COLOR = sum;
		}
	"""
	blur_material = ShaderMaterial.new()
	blur_material.shader = shader
	background_rect.material = blur_material
	add_child(background_rect)
	
	# Scaled up date badge with time slot name.
	date_badge = HBoxContainer.new()
	date_badge.position = Vector2(45, 40)
	date_badge.add_theme_constant_override("separation", 22)
	add_child(date_badge)
	
	var badge_card := VBoxContainer.new()
	badge_card.add_theme_constant_override("separation", 0)
	date_badge.add_child(badge_card)
	
	# Scaled up weekday box.
	var top_box := PanelContainer.new()
	top_box.custom_minimum_size = Vector2(104, 38)
	var white_style := StyleBoxFlat.new()
	white_style.bg_color = Color("#555555")
	top_box.add_theme_stylebox_override("panel", white_style)
	badge_card.add_child(top_box)
	
	weekday_lbl = Label.new()
	weekday_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	weekday_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	weekday_lbl.add_theme_font_override("font", system_font)
	weekday_lbl.add_theme_font_size_override("font_size", 18)
	weekday_lbl.add_theme_color_override("font_color", Color.WHITE)
	top_box.add_child(weekday_lbl)
	
	# Scaled up day number box.
	var bot_box := PanelContainer.new()
	bot_box.custom_minimum_size = Vector2(104, 68)
	var black_style := StyleBoxFlat.new()
	black_style.bg_color = Color("#151515")
	bot_box.add_theme_stylebox_override("panel", black_style)
	badge_card.add_child(bot_box)
	
	day_lbl = Label.new()
	day_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	day_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	day_lbl.add_theme_font_override("font", system_font)
	day_lbl.add_theme_font_size_override("font_size", 42)
	day_lbl.add_theme_color_override("font_color", Color.WHITE)
	bot_box.add_child(day_lbl)
	
	# Scaled up slot indicator.
	slot_lbl = Label.new()
	slot_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	slot_lbl.add_theme_font_override("font", system_font)
	slot_lbl.add_theme_font_size_override("font_size", 28)
	slot_lbl.add_theme_color_override("font_color", Color("#dddddd"))
	date_badge.add_child(slot_lbl)
	
	# Menu options on the lower-left.
	menu_container = VBoxContainer.new()
	menu_container.position = Vector2(80, 500)
	menu_container.add_theme_constant_override("separation", 20)
	add_child(menu_container)
	
	resume_btn = _create_menu_button("Resume", 38)
	resume_btn.pressed.connect(toggle_pause)
	menu_container.add_child(resume_btn)
	buttons.append(resume_btn)
	
	settings_btn = _create_menu_button("Settings", 38)
	menu_container.add_child(settings_btn)
	buttons.append(settings_btn)
	
	exit_btn = _create_menu_button("Exit", 38)
	exit_btn.pressed.connect(_open_quit_dialog)
	menu_container.add_child(exit_btn)
	buttons.append(exit_btn)
	
	_build_quit_dialog()


func _create_menu_button(btn_name: String, font_sz: int) -> Button:
	var btn := Button.new()
	btn.set_meta("label_name", btn_name)
	btn.text = "  " + btn_name
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.flat = true
	btn.add_theme_font_override("font", system_font)
	btn.add_theme_font_size_override("font_size", font_sz)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	
	btn.mouse_entered.connect(func():
		current_focus_idx = buttons.find(btn)
		_update_selection_visuals()
	)
	return btn


func _build_quit_dialog() -> void:
	quit_dialog = PanelContainer.new()
	quit_dialog.custom_minimum_size = Vector2(420, 200)
	quit_dialog.size = Vector2(420, 200)
	quit_dialog.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var out_style := StyleBoxFlat.new()
	out_style.bg_color = Color.BLACK
	out_style.border_width_left = 2
	out_style.border_width_top = 2
	out_style.border_width_right = 2
	out_style.border_width_bottom = 2
	out_style.border_color = Color.WHITE
	quit_dialog.add_theme_stylebox_override("panel", out_style)
	add_child(quit_dialog)
	
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 0)
	quit_dialog.add_child(layout)
	
	# Title bar.
	var t_bar := PanelContainer.new()
	var t_bar_style := StyleBoxFlat.new()
	t_bar_style.bg_color = Color.BLACK
	t_bar_style.border_width_bottom = 2
	t_bar_style.border_color = Color.WHITE
	t_bar.add_theme_stylebox_override("panel", t_bar_style)
	layout.add_child(t_bar)
	
	var t_margin := MarginContainer.new()
	t_margin.add_theme_constant_override("margin_left", 8)
	t_margin.add_theme_constant_override("margin_right", 6)
	t_margin.add_theme_constant_override("margin_top", 4)
	t_margin.add_theme_constant_override("margin_bottom", 4)
	t_bar.add_child(t_margin)
	
	var t_row := HBoxContainer.new()
	t_margin.add_child(t_row)
	
	var t_lbl := Label.new()
	t_lbl.text = "Exit"
	t_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t_lbl.add_theme_font_override("font", system_font)
	t_lbl.add_theme_font_size_override("font_size", 13)
	t_row.add_child(t_lbl)
	
	var q_close_btn := Button.new()
	q_close_btn.text = "X"
	q_close_btn.custom_minimum_size = Vector2(18, 18)
	_apply_square_btn_style(q_close_btn, Color.WHITE)
	q_close_btn.pressed.connect(_close_quit_dialog)
	t_row.add_child(q_close_btn)
	
	# Message body.
	var body_margin := MarginContainer.new()
	body_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_margin.add_theme_constant_override("margin_top", 24)
	layout.add_child(body_margin)
	
	var msg_lbl := Label.new()
	msg_lbl.text = "Don't leave me..."
	msg_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_lbl.add_theme_font_override("font", content_font)
	msg_lbl.add_theme_font_size_override("font_size", 16)
	msg_lbl.add_theme_color_override("font_color", Color.WHITE)
	body_margin.add_child(msg_lbl)
	
	# Buttons with red YES and white NO.
	var btn_margin := MarginContainer.new()
	btn_margin.add_theme_constant_override("margin_bottom", 16)
	layout.add_child(btn_margin)
	
	var btn_row := HBoxContainer.new()
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn_row.add_theme_constant_override("separation", 24)
	btn_margin.add_child(btn_row)
	
	var yes_btn := Button.new()
	yes_btn.text = "YES"
	yes_btn.custom_minimum_size = Vector2(80, 28)
	_apply_square_btn_style(yes_btn, Color("#ff4444"))
	yes_btn.pressed.connect(func(): get_tree().quit())
	btn_row.add_child(yes_btn)
	
	var no_btn := Button.new()
	no_btn.text = "NO"
	no_btn.custom_minimum_size = Vector2(80, 28)
	_apply_square_btn_style(no_btn, Color.WHITE)
	no_btn.pressed.connect(_close_quit_dialog)
	btn_row.add_child(no_btn)
	
	quit_dialog.hide()


func _apply_square_btn_style(btn: Button, text_color: Color) -> void:
	btn.add_theme_font_override("font", system_font)
	btn.add_theme_font_size_override("font_size", 12)
	
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color.BLACK
	normal.border_width_left = 2
	normal.border_width_top = 2
	normal.border_width_right = 2
	normal.border_width_bottom = 2
	normal.border_color = Color.WHITE
	
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color.WHITE
	hover.border_width_left = 2
	hover.border_width_top = 2
	hover.border_width_right = 2
	hover.border_width_bottom = 2
	hover.border_color = Color.WHITE
	
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	
	btn.add_theme_color_override("font_color", text_color)
	btn.add_theme_color_override("font_hover_color", Color.BLACK)
	btn.add_theme_color_override("font_pressed_color", Color.BLACK)
