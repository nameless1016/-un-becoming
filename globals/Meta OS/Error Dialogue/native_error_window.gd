class_name NativeErrorWindow
extends Control

# Narrative error dialogue popup.

signal closed(action: String)

@export var custom_font: Font

var allow_close: bool = true
var body_font: SystemFont
var italic_font: SystemFont
var bold_font: SystemFont
var is_shaking: bool = false

var is_dragging: bool = false
var drag_offset: Vector2 = Vector2.ZERO

# Default landscape dimensions.
const BASE_WIDTH: float = 660.0
const BASE_HEIGHT: float = 220.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	_setup_system_fonts()
	_ensure_canvas_layer_priority()
	_apply_satantech_theme()
	
	var x_btn := _get_close_button()
	if x_btn and not x_btn.pressed.is_connected(_on_close_clicked):
		x_btn.pressed.connect(_on_close_clicked)
		
	var title_bar := _get_title_bar()
	if title_bar and not title_bar.gui_input.is_connected(_on_title_bar_gui_input):
		title_bar.mouse_filter = Control.MOUSE_FILTER_STOP
		title_bar.gui_input.connect(_on_title_bar_gui_input)


# Ensures the popup appears on layer 128 so other scenes cannot block clicks.
func _ensure_canvas_layer_priority() -> void:
	var canvas := find_child("PopupCanvasLayer", false, false) as CanvasLayer
	if not canvas:
		canvas = CanvasLayer.new()
		canvas.name = "PopupCanvasLayer"
		canvas.layer = 128
		add_child(canvas)
		
	var outer := _get_outer_frame()
	if outer and outer.get_parent() != canvas:
		outer.reparent(canvas)


# Configures dialogue text, buttons, tags, and dimensions.
func setup(p_title: String, p_message: String, buttons: Array, p_allow_close: bool = true, p_icon: Variant = null) -> void:
	allow_close = p_allow_close
	
	var is_italic: bool = false
	if "[i]" in p_message:
		is_italic = true
		p_message = p_message.replace("[i]", "").replace("[/i]", "")
		
	var force_red: bool = false
	if "[color=red]" in p_message or "[color=#ff4444]" in p_message or "[color=red]" in p_title:
		force_red = true
		p_message = p_message.replace("[color=red]", "").replace("[color=#ff4444]", "").replace("[/color]", "")
		p_title = p_title.replace("[color=red]", "").replace("[color=#ff4444]", "").replace("[/color]", "")
	
	var has_icon: bool = (p_icon != null)

	# Dynamic size calculation based on text length.
	var raw_lines := p_message.split("\n")
	var max_line_len: int = 0
	for line in raw_lines:
		max_line_len = max(max_line_len, line.length())
		
	var text_w: float = max_line_len * 8.5
	if has_icon:
		text_w += 28.0 + 12.0
		
	var btn_row_w: float = 0.0
	for b in buttons:
		btn_row_w += str(b).length() * 8.5 + 36.0
	if buttons.size() > 1:
		btn_row_w += (buttons.size() - 1) * 18.0
		
	var needed_w: float = max(text_w, btn_row_w) + 64.0
	var win_w: float = clampf(needed_w, 350.0, 680.0)
	
	var line_count: int = raw_lines.size()
	if text_w > (win_w - 60.0):
		line_count += int(text_w / (win_w - 60.0))
		
	var win_h: float = 28.0 + (line_count * 22.0) + 24.0
	if not buttons.is_empty():
		win_h += 30.0 + 16.0
		win_h = max(win_h, 150.0)
	else:
		win_h = max(win_h, 136.0)
		
	# Even numbers prevent subpixel font blur.
	win_w = round(win_w / 2.0) * 2.0
	win_h = round(win_h / 2.0) * 2.0
		
	_apply_frame_geometry(win_w, win_h)
	_apply_frame_geometry.call_deferred(win_w, win_h)
		
	var is_critical: bool = (
		force_red
		or not p_allow_close 
		or "CRITICAL" in p_title 
		or "FATAL" in p_title 
		or "Burn" in p_message 
		or "0x" in p_title
	)
	var text_color: Color = Color("#ff4444") if is_critical else Color.WHITE
	
	var clean_title: String = p_title if p_title != "" else "Info"
	var bar := _get_title_bar()
	if bar:
		bar.visible = true
		bar.custom_minimum_size = Vector2(0, 26)
		
	var title_lbl := _get_title_label()
	if title_lbl:
		title_lbl.text = clean_title
		title_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
		title_lbl.add_theme_font_override("font", custom_font if custom_font else bold_font)
		title_lbl.add_theme_font_size_override("font_size", 13)
		title_lbl.add_theme_color_override("font_color", text_color)
		title_lbl.add_theme_constant_override("outline_size", 1)
		title_lbl.add_theme_color_override("font_outline_color", text_color)
		
	var content_row := find_child("ContentRow", true, false) as BoxContainer
	if content_row:
		content_row.alignment = BoxContainer.ALIGNMENT_CENTER
		content_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		content_row.size_flags_vertical = Control.SIZE_EXPAND_FILL
		content_row.add_theme_constant_override("separation", 10)
		
	var icon_rect := _get_icon_rect()
	var final_texture: Texture2D = null
	if p_icon is Texture2D:
		final_texture = p_icon
	elif p_icon is String and (p_icon == "txt" or p_icon == "file"):
		final_texture = _generate_retro_file_icon()
		
	if icon_rect:
		if final_texture != null:
			icon_rect.texture = final_texture
			icon_rect.custom_minimum_size = Vector2(28, 32)
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
			icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			icon_rect.visible = true
		else:
			icon_rect.visible = false
			icon_rect.texture = null
			
	var msg_lbl := _get_message_label()
	if msg_lbl:
		msg_lbl.text = p_message
		msg_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
		msg_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		
		var chosen_font: Font = italic_font if is_italic else body_font
		msg_lbl.add_theme_font_override("font", custom_font if custom_font else chosen_font)
		msg_lbl.add_theme_font_size_override("font_size", 13)
		msg_lbl.add_theme_color_override("font_color", text_color)
		msg_lbl.add_theme_constant_override("outline_size", 0)
		msg_lbl.add_theme_constant_override("line_spacing", 4)
		
		# Disables word wrap when an icon is present so letters do not stack vertically.
		if final_texture != null:
			msg_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			msg_lbl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			msg_lbl.custom_minimum_size = Vector2.ZERO
			msg_lbl.autowrap_mode = TextServer.AUTOWRAP_OFF
		else:
			msg_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			msg_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			msg_lbl.custom_minimum_size = Vector2(win_w - 60, 0)
			msg_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		
	var btn_margin := find_child("MarginContainer", true, false) as MarginContainer
	if btn_margin:
		if buttons.is_empty():
			btn_margin.visible = false
		else:
			btn_margin.visible = true
			btn_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			btn_margin.size_flags_vertical = Control.SIZE_SHRINK_END
			btn_margin.add_theme_constant_override("margin_top", 4)
			btn_margin.add_theme_constant_override("margin_bottom", 14)
		
	var btn_container := _get_button_container()
	if btn_container:
		for child in btn_container.get_children():
			child.queue_free()
			
		btn_container.alignment = BoxContainer.ALIGNMENT_CENTER
		btn_container.add_theme_constant_override("separation", 18)
		
		for btn_text in buttons:
			var btn := Button.new()
			btn.text = str(btn_text).to_upper()
			btn.mouse_filter = Control.MOUSE_FILTER_STOP
			_apply_satantech_button_style(btn)
			btn.pressed.connect(func() -> void:
				closed.emit(str(btn_text))
				queue_free()
				DisplayServer.window_move_to_foreground(DisplayServer.MAIN_WINDOW_ID)
				get_tree().root.get_window().grab_focus()
			)
			btn_container.add_child(btn)
			
	show()


# Sets center coordinates and sizes.
func _apply_frame_geometry(win_w: float, win_h: float) -> void:
	var outer := _get_outer_frame()
	if not outer:
		return
		
	outer.anchor_left = 0.5
	outer.anchor_top = 0.5
	outer.anchor_right = 0.5
	outer.anchor_bottom = 0.5
	outer.offset_left = -win_w / 2.0
	outer.offset_right = win_w / 2.0
	outer.offset_top = -win_h / 2.0
	outer.offset_bottom = win_h / 2.0
	outer.grow_horizontal = Control.GROW_DIRECTION_BOTH
	outer.grow_vertical = Control.GROW_DIRECTION_BOTH
	
	outer.custom_minimum_size = Vector2(win_w, win_h)
	outer.size = Vector2(win_w, win_h)
	
	var inner := _get_inner_bevel()
	if inner:
		inner.set_anchors_preset(Control.PRESET_FULL_RECT)
		
	var main_layout := find_child("MainLayout", true, false) as BoxContainer
	if main_layout:
		main_layout.set_anchors_preset(Control.PRESET_FULL_RECT)
		main_layout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		main_layout.size_flags_vertical = Control.SIZE_EXPAND_FILL


# Allows dragging the window with the mouse.
func _on_title_bar_gui_input(event: InputEvent) -> void:
	var outer := _get_outer_frame()
	if not outer:
		return
		
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			is_dragging = true
			drag_offset = outer.global_position - event.global_position
		else:
			is_dragging = false
	elif event is InputEventMouseMotion and is_dragging:
		var new_pos: Vector2 = event.global_position + drag_offset
		var vp_size: Vector2 = get_viewport_rect().size
		new_pos.x = clampf(new_pos.x, 0.0, max(0.0, vp_size.x - outer.size.x))
		new_pos.y = clampf(new_pos.y, 0.0, max(0.0, vp_size.y - outer.size.y))
		outer.global_position = new_pos


# Configures the fonts.
func _setup_system_fonts() -> void:
	var font_names_list := PackedStringArray([
		"Cartograph Mono", 
		"Cartograph CF", 
		"TG Frekuent Mono", 
		"Cascadia Code", 
		"Consolas", 
		"monospace"
	])
	
	body_font = SystemFont.new()
	body_font.font_names = font_names_list
	body_font.font_weight = 400
	body_font.hinting = TextServer.HINTING_NORMAL
	body_font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	
	italic_font = SystemFont.new()
	italic_font.font_names = font_names_list
	italic_font.font_weight = 400
	italic_font.font_italic = true
	italic_font.hinting = TextServer.HINTING_NORMAL
	italic_font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	
	bold_font = SystemFont.new()
	bold_font.font_names = font_names_list
	bold_font.font_weight = 600
	bold_font.hinting = TextServer.HINTING_NORMAL
	bold_font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED


# Vector icon for text files.
func _generate_retro_file_icon() -> ImageTexture:
	var svg_data := """<svg xmlns="http://www.w3.org/2000/svg" width="28" height="32" viewBox="0 0 28 32">
		<path d="M 4 2 L 18 2 L 24 8 L 24 30 L 4 30 Z" fill="#000000" stroke="#ffffff" stroke-width="2"/>
		<path d="M 18 2 L 18 8 L 24 8" fill="none" stroke="#ffffff" stroke-width="2"/>
		<line x1="8" y1="14" x2="20" y2="14" stroke="#ffffff" stroke-width="2"/>
		<line x1="8" y1="19" x2="20" y2="19" stroke="#ffffff" stroke-width="2"/>
		<line x1="8" y1="24" x2="16" y2="24" stroke="#ffffff" stroke-width="2"/>
	</svg>"""
	var img := Image.new()
	if img.load_svg_from_string(svg_data) == OK:
		return ImageTexture.create_from_image(img)
	return null


# Styling for the dialogue box frame and title bar.
func _apply_satantech_theme() -> void:
	var outer := _get_outer_frame()
	if outer:
		var out_style := StyleBoxFlat.new()
		out_style.bg_color = Color.BLACK
		out_style.border_width_left = 2
		out_style.border_width_top = 2
		out_style.border_width_right = 2
		out_style.border_width_bottom = 2
		out_style.border_color = Color.WHITE
		outer.add_theme_stylebox_override("panel", out_style)
		
	var inner := _get_inner_bevel()
	if inner:
		inner.set_anchors_preset(Control.PRESET_FULL_RECT)
		var in_style := StyleBoxFlat.new()
		in_style.bg_color = Color.TRANSPARENT
		inner.add_theme_stylebox_override("panel", in_style)
		
	var bar := _get_title_bar()
	if bar:
		var bar_style := StyleBoxFlat.new()
		bar_style.bg_color = Color.BLACK
		bar_style.border_width_bottom = 2
		bar_style.border_color = Color.WHITE
		bar_style.content_margin_left = 8
		bar_style.content_margin_right = 4
		bar_style.content_margin_top = 3
		bar_style.content_margin_bottom = 4
		bar.add_theme_stylebox_override("panel", bar_style)
		
	var x_btn := _get_close_button()
	if x_btn:
		x_btn.text = "X"
		x_btn.custom_minimum_size = Vector2(20, 20)
		x_btn.mouse_filter = Control.MOUSE_FILTER_STOP
		_apply_close_button_style(x_btn)


# Inverted hover styling for buttons.
func _apply_satantech_button_style(btn: Button) -> void:
	var font_to_use: Font = custom_font if custom_font else bold_font
	btn.add_theme_font_override("font", font_to_use)
	btn.add_theme_font_size_override("font_size", 12)
	btn.add_theme_constant_override("outline_size", 1)
	
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color.BLACK
	normal.border_width_left = 2
	normal.border_width_top = 2
	normal.border_width_right = 2
	normal.border_width_bottom = 2
	normal.border_color = Color.WHITE
	normal.content_margin_left = 18
	normal.content_margin_right = 18
	normal.content_margin_top = 6
	normal.content_margin_bottom = 6
	
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color.WHITE
	hover.border_width_left = 2
	hover.border_width_top = 2
	hover.border_width_right = 2
	hover.border_width_bottom = 2
	hover.border_color = Color.WHITE
	hover.content_margin_left = 18
	hover.content_margin_right = 18
	hover.content_margin_top = 6
	hover.content_margin_bottom = 6
	
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_outline_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.BLACK)
	btn.add_theme_color_override("font_pressed_color", Color.BLACK)
	btn.add_theme_color_override("font_focus_color", Color.WHITE)


# Close button styling.
func _apply_close_button_style(btn: Button) -> void:
	var font_to_use: Font = custom_font if custom_font else bold_font
	btn.add_theme_font_override("font", font_to_use)
	btn.add_theme_font_size_override("font_size", 11)
	btn.add_theme_constant_override("outline_size", 1)
	
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
	
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_outline_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.BLACK)
	btn.add_theme_color_override("font_pressed_color", Color.BLACK)


# Node getters with fallback support.
func _get_outer_frame() -> Control:
	return find_child("OuterFrame", true, false) as Control

func _get_inner_bevel() -> Control:
	return find_child("InnerBevel", true, false) as Control

func _get_title_bar() -> Control:
	return find_child("TitleBar", true, false) as Control

func _get_title_label() -> Label:
	if has_node("%TitleLabel"): return get_node("%TitleLabel") as Label
	return find_child("TitleLabel", true, false) as Label

func _get_close_button() -> Button:
	if has_node("%CloseButton"): return get_node("%CloseButton") as Button
	return find_child("CloseButton", true, false) as Button

func _get_icon_rect() -> TextureRect:
	if has_node("%IconRect"): return get_node("%IconRect") as TextureRect
	return find_child("IconRect", true, false) as TextureRect

func _get_message_label() -> Label:
	if has_node("%MessageLabel"): return get_node("%MessageLabel") as Label
	if has_node("%MessageLa"): return get_node("%MessageLa") as Label
	var found = find_child("MessageLa*", true, false)
	if found is Label: return found as Label
	return null

func _get_button_container() -> HBoxContainer:
	if has_node("%ButtonContainer"): return get_node("%ButtonContainer") as HBoxContainer
	return find_child("ButtonContainer", true, false) as HBoxContainer


# Close action and punishment handling.
func _on_close_clicked() -> void:
	if allow_close:
		closed.emit("__CLOSE_X__")
		queue_free()
		DisplayServer.window_move_to_foreground(DisplayServer.MAIN_WINDOW_ID)
		get_tree().root.get_window().grab_focus()
	else:
		_shake_window()


# Window shake punishment animation.
func _shake_window() -> void:
	if is_shaking:
		return
	is_shaking = true
	var outer := _get_outer_frame()
	if not outer:
		is_shaking = false
		return
		
	var orig_pos: Vector2 = outer.global_position
	var tween: Tween = create_tween()
	
	for i in range(4):
		var jitter := Vector2(randi_range(-8, 8), 0)
		tween.tween_property(outer, "global_position", orig_pos + jitter, 0.04)
		
	tween.tween_property(outer, "global_position", orig_pos, 0.04)
	tween.tween_callback(func() -> void: is_shaking = false)
