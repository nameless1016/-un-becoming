class_name TerminalWindow
extends Window

## Floating Landscape Command Terminal with Backspace Retarget Animation

signal terminal_closed
signal file_decoded(file: GameFile)

var active_file: GameFile = null
var system_font: SystemFont
var is_dragging: bool = false
var drag_offset: Vector2i = Vector2i.ZERO
var is_animating: bool = false

const WIN_WIDTH: int = 580
const BASE_WIN_HEIGHT: int = 295

# UI References
var outer_frame: PanelContainer
var title_bar: PanelContainer
var title_lbl: Label
var close_btn: Button

var terminal_output: RichTextLabel
var prompt_row: HBoxContainer
var prompt_lbl: Label
var line_input: LineEdit


func _init() -> void:
	# Fixed size floating window on the desktop.
	size = Vector2i(WIN_WIDTH, BASE_WIN_HEIGHT)
	unresizable = true
	borderless = true
	always_on_top = true
	transient = false
	exclusive = false
	title = "TERMINAL"
	
	_setup_system_font()
	_build_terminal_ui()


func _ready() -> void:
	hide()
	close_btn.pressed.connect(close_terminal)
	title_bar.gui_input.connect(_on_title_bar_gui_input)
	line_input.text_submitted.connect(_on_command_submitted)


# Opens the terminal for the highlighted file.
func open_for_file(file: GameFile) -> void:
	var screen_id: int = DisplayServer.get_primary_screen()
	var screen_origin: Vector2i = DisplayServer.screen_get_position(screen_id)
	var screen_size: Vector2i = DisplayServer.screen_get_size(screen_id)
	
	# Positions the terminal on the far left of the monitor with a 35px margin.
	if not visible:
		var base_y: int = screen_origin.y + int((float(screen_size.y) - float(BASE_WIN_HEIGHT)) / 2.0)
		position = Vector2i(screen_origin.x + 35, base_y)
		show()
		
	grab_focus()
	DisplayServer.window_move_to_foreground(get_window_id())
	
	# If targeting a new file while open, play the backspace animation.
	if active_file != null and active_file != file and visible:
		active_file = file
		_animate_backspace_and_retype()
	else:
		active_file = file
		_render_static_menu()


# Closes the terminal and resets height.
func close_terminal() -> void:
	hide()
	active_file = null
	_update_window_height("")
	terminal_closed.emit()


# Expands the window downward to prevent text clipping.
func _update_window_height(extra_feedback: String = "") -> void:
	var target_h: int = BASE_WIN_HEIGHT
	
	if extra_feedback != "":
		var line_count: int = extra_feedback.count("\n") + int(float(extra_feedback.length()) / 50.0) + 2
		target_h += line_count * 22
		target_h = maxi(target_h, BASE_WIN_HEIGHT)
		
	size = Vector2i(WIN_WIDTH, target_h)
	if outer_frame:
		outer_frame.custom_minimum_size = Vector2(WIN_WIDTH, target_h)
		outer_frame.size = Vector2(WIN_WIDTH, target_h)


# Simulates backspacing characters and retyping new text.
func _animate_backspace_and_retype() -> void:
	is_animating = true
	line_input.editable = false
	prompt_row.hide()
	_update_window_height("")
	
	var current_text := terminal_output.get_parsed_text()
	
	# Erases characters in small chunks.
	while current_text.length() > 0:
		var erase_count: int = mini(6, current_text.length())
		current_text = current_text.substr(0, current_text.length() - erase_count)
		terminal_output.text = current_text
		await get_tree().create_timer(0.012).timeout
		
	terminal_output.text = ""
	await get_tree().create_timer(0.06).timeout
	
	# Types new text forward.
	var target_text := _get_menu_plain_text()
	var typed := ""
	var idx: int = 0
	while idx < target_text.length():
		var chunk_size: int = mini(3, target_text.length() - idx)
		typed += target_text.substr(idx, chunk_size)
		idx += chunk_size
		terminal_output.text = typed
		await get_tree().create_timer(0.012).timeout
		
	_render_static_menu()
	is_animating = false
	line_input.editable = true
	prompt_row.show()
	line_input.grab_focus.call_deferred()


# Returns the plain text string used for typing animations.
func _get_menu_plain_text() -> String:
	var target_name: String = active_file.filename if active_file else "fourth_wall.txt"
	var txt := "> What do you want to with '" + target_name + "'?\n"
	txt += "    1. INTERPRET\n"
	txt += "    2. REARRANGE\n"
	txt += "    3. DECODE\n"
	txt += "    4. ⣿⣿⣿⣿⣿⣿⣿\n" if not FileManager.is_command_unlocked(4) else "    4. EXECUTE\n"
	txt += "    5. INTERVENE\n"
	txt += "    6. CLOSE\n"
	return txt


# Renders the formatted menu and enables the input cursor.
func _render_static_menu(extra_feedback: String = "") -> void:
	_update_window_height(extra_feedback)
	
	var target_name: String = active_file.filename if active_file else "fourth_wall.txt"
	
	var bbcode := "> What do you want to with '" + target_name + "'?\n"
	bbcode += "    1. INTERPRET\n"
	bbcode += "    2. REARRANGE\n"
	bbcode += "    3. DECODE\n"
	
	if FileManager.is_command_unlocked(4):
		bbcode += "    4. EXECUTE\n"
	else:
		bbcode += "    [color=#555555]4. ⣿⣿⣿⣿⣿⣿⣿[/color]\n"
		
	if FileManager.is_command_unlocked(5):
		bbcode += "    [color=#ff4444]5. INTERVENE[/color]\n"
	else:
		bbcode += "    [color=#555555]5. ⣿⣿⣿⣿⣿⣿⣿[/color]\n"
		
	bbcode += "    6. CLOSE\n"
	
	if extra_feedback != "":
		bbcode += "\n" + extra_feedback
		
	terminal_output.text = bbcode
	prompt_row.show()
	
	line_input.editable = true
	line_input.grab_focus.call_deferred()


# Processes commands entered by the player.
func _on_command_submitted(text: String) -> void:
	if is_animating:
		return
		
	var cmd := text.strip_edges()
	line_input.clear()
	
	if cmd == "6":
		close_terminal()
		return
		
	var target_name: String = active_file.filename if active_file else "fourth_wall.txt"
	
	var cmd_id: int = cmd.to_int()
	if cmd_id in [1, 2, 3, 4, 5] and not FileManager.is_command_unlocked(cmd_id):
		_render_static_menu("[color=#ff4444]> COMMAND CORRUPTED / LOCKED.[/color]")
		return
		
	if active_file == null:
		_render_static_menu("[color=#ff4444]> What the fuck do you think you're doing?\n  No target file selected.[/color]")
		return
		
	match cmd:
		"1":
			if not active_file.can_interpret:
				_render_static_menu("[color=#ff4444]> What the fuck do you think you're doing?[/color]")
			else:
				var hint := active_file.ghost_hint_solved if active_file.is_solved else active_file.ghost_hint_unsolved
				_render_static_menu("[color=#ffffff]> GHOST: " + hint + "[/color]")
		"2", "3":
			var can_solve: bool = active_file.can_rearrange if cmd == "2" else active_file.can_decode
			if not can_solve:
				_render_static_menu("[color=#ff4444]> What the fuck do you think you're doing?[/color]")
			else:
				_solve_target_cipher()
		"4":
			if not active_file.can_execute:
				_render_static_menu("[color=#ff4444]> What the fuck do you think you're doing?[/color]")
			else:
				_render_static_menu("[color=#ffffff]> EXECUTING [" + target_name + "]...\n> DIRECTIVE CONFIRMED: THE FIRE IS ALREADY LIT.[/color]")
		"5":
			if not active_file.can_intervene:
				_render_static_menu("[color=#ff4444]> What the fuck do you think you're doing?[/color]")
			else:
				_render_static_menu("[color=#ff4444]> INTERVENTION OVERRIDE: YOU REACH ACROSS TIME.\n> A FAINT WHISPER CALLS OUT: 'Burn down the house, Blaire.'[/color]")
		_:
			_render_static_menu("[color=#ff4444]> INVALID COMMAND. Choose options (1-6).[/color]")


# Solves ciphers and updates the game file.
func _solve_target_cipher() -> void:
	if active_file.is_solved:
		_render_static_menu("[color=#888888]> CIPHER ALREADY RESOLVED.[/color]")
		return
		
	FileManager.solve_file(active_file.file_id)
	active_file.is_solved = true
	file_decoded.emit(active_file)
	
	var recovered: String = active_file.solved_content if active_file.solved_content != "" else active_file.content
	var msg := "[color=#55ff55]> DECRYPTION COMPLETE. DATA RECOVERED:\n----------------------------------------\n" + recovered + "\n----------------------------------------[/color]"
	_render_static_menu(msg)


# Dragging behavior for the terminal window.
func _on_title_bar_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		is_dragging = event.pressed
		drag_offset = DisplayServer.mouse_get_position() - position
	elif event is InputEventMouseMotion and is_dragging:
		position = DisplayServer.mouse_get_position() - drag_offset


# Programmatic UI setup for the terminal.
func _build_terminal_ui() -> void:
	outer_frame = PanelContainer.new()
	outer_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	var out_style := StyleBoxFlat.new()
	out_style.bg_color = Color.BLACK
	out_style.border_width_left = 2
	out_style.border_width_top = 2
	out_style.border_width_right = 2
	out_style.border_width_bottom = 2
	out_style.border_color = Color.WHITE
	outer_frame.add_theme_stylebox_override("panel", out_style)
	add_child(outer_frame)
	
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 0)
	outer_frame.add_child(layout)
	
	# Title bar container.
	title_bar = PanelContainer.new()
	title_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	var bar_style := StyleBoxFlat.new()
	bar_style.bg_color = Color.BLACK
	bar_style.border_width_bottom = 2
	bar_style.border_color = Color.WHITE
	title_bar.add_theme_stylebox_override("panel", bar_style)
	layout.add_child(title_bar)
	
	var t_margin := MarginContainer.new()
	t_margin.add_theme_constant_override("margin_left", 8)
	t_margin.add_theme_constant_override("margin_right", 6)
	t_margin.add_theme_constant_override("margin_top", 4)
	t_margin.add_theme_constant_override("margin_bottom", 4)
	title_bar.add_child(t_margin)
	
	var t_row := HBoxContainer.new()
	t_margin.add_child(t_row)
	
	title_lbl = Label.new()
	title_lbl.text = "Terminal"
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_override("font", system_font)
	title_lbl.add_theme_font_size_override("font_size", 13)
	t_row.add_child(title_lbl)
	
	close_btn = Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(18, 18)
	close_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_apply_close_button_style(close_btn)
	t_row.add_child(close_btn)
	
	var body_margin := MarginContainer.new()
	body_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_margin.add_theme_constant_override("margin_left", 20)
	body_margin.add_theme_constant_override("margin_top", 16)
	body_margin.add_theme_constant_override("margin_right", 20)
	body_margin.add_theme_constant_override("margin_bottom", 16)
	layout.add_child(body_margin)
	
	var t_flow := VBoxContainer.new()
	t_flow.add_theme_constant_override("separation", 2)
	body_margin.add_child(t_flow)
	
	terminal_output = RichTextLabel.new()
	terminal_output.bbcode_enabled = true
	terminal_output.fit_content = true
	terminal_output.scroll_active = false
	terminal_output.add_theme_font_override("normal_font", system_font)
	terminal_output.add_theme_font_size_override("normal_font_size", 14)
	terminal_output.add_theme_constant_override("line_separation", 3)
	t_flow.add_child(terminal_output)
	
	# Prompt row directly below option 6.
	prompt_row = HBoxContainer.new()
	prompt_row.add_theme_constant_override("separation", 0)
	t_flow.add_child(prompt_row)
	
	prompt_lbl = Label.new()
	prompt_lbl.text = "> Pick an option (1-5): "
	prompt_lbl.add_theme_font_override("font", system_font)
	prompt_lbl.add_theme_font_size_override("font_size", 14)
	prompt_row.add_child(prompt_lbl)
	
	line_input = LineEdit.new()
	line_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line_input.max_length = 1
	line_input.flat = true
	line_input.add_theme_font_override("font", system_font)
	line_input.add_theme_font_size_override("font_size", 14)
	line_input.add_theme_color_override("font_color", Color.WHITE)
	
	var empty_style := StyleBoxEmpty.new()
	line_input.add_theme_stylebox_override("normal", empty_style)
	line_input.add_theme_stylebox_override("focus", empty_style)
	line_input.caret_blink = true
	line_input.caret_blink_interval = 0.5
	prompt_row.add_child(line_input)


# Sets up the font.
func _setup_system_font() -> void:
	system_font = SystemFont.new()
	system_font.font_names = PackedStringArray([
		"Cartograph Mono", 
		"Cartograph CF", 
		"TG Frekuent Mono", 
		"Cascadia Code", 
		"Consolas", 
		"monospace"
	])
	system_font.font_weight = 550
	system_font.hinting = TextServer.HINTING_NORMAL
	system_font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED


# Close button style.
func _apply_close_button_style(btn: Button) -> void:
	btn.add_theme_font_override("font", system_font)
	btn.add_theme_font_size_override("font_size", 11)
	
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color.BLACK
	normal.border_width_left = 2
	normal.border_width_top = 2
	normal.border_width_right = 2
	normal.border_width_bottom = 2
	normal.border_color = Color.WHITE
	normal.content_margin_left = 0
	normal.content_margin_right = 0
	normal.content_margin_top = 0
	normal.content_margin_bottom = 0
	
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color.WHITE
	hover.border_width_left = 2
	hover.border_width_top = 2
	hover.border_width_right = 2
	hover.border_width_bottom = 2
	hover.border_color = Color.WHITE
	hover.content_margin_left = 0
	hover.content_margin_right = 0
	hover.content_margin_top = 0
	hover.content_margin_bottom = 0
	
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.BLACK)
	btn.add_theme_color_override("font_pressed_color", Color.BLACK)
