class_name CalendarWindow
extends Window
signal request_open_filesystem

# Main interactive timeline calendar window covering June to December 2012.

var system_font: SystemFont

var current_year: int = 2012
var current_month: int = 10

const MIN_MONTH: int = 6
const MAX_MONTH: int = 12

var outer_frame: PanelContainer
var title_bar: PanelContainer
var month_header_lbl: Label
var prev_btn: Button
var next_btn: Button
var close_btn: Button
var grid_container: GridContainer
var today_lbl: Label

var is_dragging: bool = false
var drag_offset: Vector2i = Vector2i.ZERO

var event_popup: CalendarEventWindow


func _init() -> void:
	size = Vector2i(540, 520)
	unresizable = true
	borderless = true
	always_on_top = true
	transient = false
	exclusive = false
	title = "CALENDAR"
	
	_setup_fonts()
	_build_ui()


func _ready() -> void:
	hide()
	close_btn.pressed.connect(toggle_calendar)
	title_bar.gui_input.connect(_on_title_bar_gui_input)
	window_input.connect(_on_window_input)
	
	prev_btn.pressed.connect(_on_prev_month)
	next_btn.pressed.connect(_on_next_month)
	
	event_popup = CalendarEventWindow.new()
	add_child(event_popup)


# Toggles the calendar window open or closed, and returns focus to the game.
func toggle_calendar() -> void:
	if visible:
		hide()
		if event_popup:
			event_popup.hide()
		DisplayServer.window_move_to_foreground(DisplayServer.MAIN_WINDOW_ID)
		get_tree().root.get_window().grab_focus()
	else:
		open_calendar()


# Listens to keyboard input while this window has focus.
func _on_window_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_C or event.keycode == KEY_ESCAPE:
			toggle_calendar()
		elif event.keycode == KEY_Q:
			request_open_filesystem.emit()


# Opens the calendar and centers it on screen.
func open_calendar() -> void:
	var screen_id: int = DisplayServer.get_primary_screen()
	var screen_origin: Vector2i = DisplayServer.screen_get_position(screen_id)
	var screen_size: Vector2i = DisplayServer.screen_get_size(screen_id)
	
	if not visible:
		current_year = TimeManager.current_year
		current_month = TimeManager.current_month
		position = screen_origin + (screen_size - size) / 2
		show()
		
	grab_focus()
	DisplayServer.window_move_to_foreground(get_window_id())
	render_calendar()


# Moves to the previous month.
func _on_prev_month() -> void:
	if current_month > MIN_MONTH:
		current_month -= 1
		render_calendar()


# Moves to the next month.
func _on_next_month() -> void:
	if current_month < MAX_MONTH:
		current_month += 1
		render_calendar()


# Renders the month grid and days.
func render_calendar() -> void:
	var month_names := [
		"January", "February", "March", "April", "May", "June",
		"July", "August", "September", "October", "November", "December"
	]
	month_header_lbl.text = "%s %04d" % [month_names[current_month - 1], current_year]
	today_lbl.text = "Today: %02d/%02d/%04d" % [TimeManager.current_month, TimeManager.current_day, TimeManager.current_year]
	
	prev_btn.disabled = (current_month <= MIN_MONTH)
	next_btn.disabled = (current_month >= MAX_MONTH)
	
	for child in grid_container.get_children():
		child.queue_free()
		
	var days_in_month: int = _get_days_in_month(current_year, current_month)
	var first_day_weekday: int = _get_first_weekday(current_year, current_month)
	
	var prev_month: int = current_month - 1 if current_month > 1 else 12
	var prev_year: int = current_year if current_month > 1 else current_year - 1
	var days_in_prev_month: int = _get_days_in_month(prev_year, prev_month)
	
	# Fills greyed out days from the previous month.
	for i in range(first_day_weekday):
		var prev_d: int = days_in_prev_month - (first_day_weekday - 1 - i)
		grid_container.add_child(_create_cell(prev_d, true, false))
		
	# Fills active days of the current month.
	for d in range(1, days_in_month + 1):
		var is_today: bool = (current_year == TimeManager.current_year and current_month == TimeManager.current_month and d == TimeManager.current_day)
		var cell: Button = _create_cell(d, false, is_today)
		cell.pressed.connect(func(): _on_day_clicked(d, cell))
		grid_container.add_child(cell)
		
	# Fills trailing days to complete the grid.
	var cells_total: int = first_day_weekday + days_in_month
	var remaining: int = 35 - cells_total
	if remaining < 0:
		remaining += 7
	for next_d in range(1, remaining + 1):
		grid_container.add_child(_create_cell(next_d, true, false))


# Creates an individual day button.
func _create_cell(day_num: int, is_other: bool, is_today: bool) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(68, 62)
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color.BLACK
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	
	if is_today:
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.border_color = Color.WHITE
	else:
		style.border_color = Color("#333333")
		
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)
	
	var cell_vbox := VBoxContainer.new()
	cell_vbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	cell_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(cell_vbox)
	
	var day_num_lbl := Label.new()
	day_num_lbl.text = "%02d " % day_num
	day_num_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	day_num_lbl.add_theme_font_override("font", system_font)
	day_num_lbl.add_theme_font_size_override("font_size", 10)
	day_num_lbl.add_theme_color_override("font_color", Color("#555555") if is_other else Color.WHITE)
	cell_vbox.add_child(day_num_lbl)
	
	return btn


# Opens the event popup window for the clicked day.
func _on_day_clicked(day_num: int, cell_btn: Button) -> void:
	var spawn_pos: Vector2i = position + Vector2i(int(cell_btn.position.x) + 30, int(cell_btn.position.y) - 20)
	event_popup.open_for_date(current_year, current_month, day_num, spawn_pos)


# Dragging behavior for the calendar title bar.
func _on_title_bar_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		is_dragging = event.pressed
		drag_offset = DisplayServer.mouse_get_position() - position
	elif event is InputEventMouseMotion and is_dragging:
		position = DisplayServer.mouse_get_position() - drag_offset


# Sets up the fonts.
func _setup_fonts() -> void:
	system_font = SystemFont.new()
	system_font.font_names = PackedStringArray(["Cartograph Mono", "Cartograph CF", "TG Frekuent Mono", "Consolas", "monospace"])
	system_font.font_weight = 550


# Calculates the number of days in the month.
func _get_days_in_month(y: int, m: int) -> int:
	if m in [4, 6, 9, 11]: return 30
	if m == 2: return 29 if (y % 4 == 0) else 28
	return 31


# Calculates the starting weekday.
func _get_first_weekday(y: int, m: int) -> int:
	var dict := {"year": y, "month": m, "day": 1}
	var unix: int = Time.get_unix_time_from_datetime_dict(dict)
	var weekday: int = Time.get_datetime_dict_from_unix_time(unix)["weekday"]
	return weekday % 7


# Builds the window interface.
func _build_ui() -> void:
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
	
	var title_lbl := Label.new()
	title_lbl.text = "Calendar"
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.add_theme_font_override("font", system_font)
	title_lbl.add_theme_font_size_override("font_size", 13)
	t_row.add_child(title_lbl)
	
	close_btn = Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(18, 18)
	close_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_apply_square_button_style(close_btn)
	t_row.add_child(close_btn)
	
	var nav_margin := MarginContainer.new()
	nav_margin.add_theme_constant_override("margin_left", 14)
	nav_margin.add_theme_constant_override("margin_right", 14)
	nav_margin.add_theme_constant_override("margin_top", 8)
	nav_margin.add_theme_constant_override("margin_bottom", 6)
	layout.add_child(nav_margin)
	
	var nav_row := HBoxContainer.new()
	nav_margin.add_child(nav_row)
	
	prev_btn = Button.new()
	prev_btn.text = "<"
	prev_btn.custom_minimum_size = Vector2(22, 22)
	_apply_square_button_style(prev_btn)
	nav_row.add_child(prev_btn)
	
	month_header_lbl = Label.new()
	month_header_lbl.text = "October 2012"
	month_header_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	month_header_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	month_header_lbl.add_theme_font_override("font", system_font)
	month_header_lbl.add_theme_font_size_override("font_size", 16)
	nav_row.add_child(month_header_lbl)
	
	next_btn = Button.new()
	next_btn.text = ">"
	next_btn.custom_minimum_size = Vector2(22, 22)
	_apply_square_button_style(next_btn)
	nav_row.add_child(next_btn)
	
	var days_row := HBoxContainer.new()
	days_row.alignment = BoxContainer.ALIGNMENT_CENTER
	days_row.add_theme_constant_override("separation", 6)
	layout.add_child(days_row)
	
	var day_names := ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
	for day_name in day_names:
		var d_lbl := Label.new()
		d_lbl.text = day_name
		d_lbl.custom_minimum_size = Vector2(68, 20)
		d_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		d_lbl.add_theme_font_override("font", system_font)
		d_lbl.add_theme_font_size_override("font_size", 12)
		
		if day_name == "Sat":
			d_lbl.add_theme_color_override("font_color", Color("#dd4444"))
		elif day_name == "Sun":
			d_lbl.add_theme_color_override("font_color", Color("#aa88ff"))
		else:
			d_lbl.add_theme_color_override("font_color", Color.WHITE)
			
		days_row.add_child(d_lbl)
		
	var grid_margin := MarginContainer.new()
	grid_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid_margin.add_theme_constant_override("margin_left", 14)
	grid_margin.add_theme_constant_override("margin_right", 14)
	grid_margin.add_theme_constant_override("margin_top", 4)
	grid_margin.add_theme_constant_override("margin_bottom", 6)
	layout.add_child(grid_margin)
	
	grid_container = GridContainer.new()
	grid_container.columns = 7
	grid_container.add_theme_constant_override("h_separation", 2)
	grid_container.add_theme_constant_override("v_separation", 2)
	grid_margin.add_child(grid_container)
	
	var footer_margin := MarginContainer.new()
	footer_margin.add_theme_constant_override("margin_left", 14)
	footer_margin.add_theme_constant_override("margin_bottom", 8)
	layout.add_child(footer_margin)
	
	today_lbl = Label.new()
	today_lbl.add_theme_font_override("font", system_font)
	today_lbl.add_theme_font_size_override("font_size", 12)
	footer_margin.add_child(today_lbl)


# Button style.
func _apply_square_button_style(btn: Button) -> void:
	btn.add_theme_font_override("font", system_font)
	btn.add_theme_font_size_override("font_size", 11)
	
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
	btn.add_theme_color_override("font_hover_color", Color.BLACK)
