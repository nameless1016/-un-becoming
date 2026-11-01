class_name CalendarEventWindow
extends Window

# Separate window showing plans for a clicked date.

var system_font: SystemFont
var content_font: SystemFont

var outer_frame: PanelContainer
var title_bar: PanelContainer
var title_lbl: Label
var close_btn: Button

var empty_lbl: Label
var is_dragging: bool = false
var drag_offset: Vector2i = Vector2i.ZERO


func _init() -> void:
	size = Vector2i(380, 240)
	unresizable = true
	borderless = true
	always_on_top = true
	transient = false
	exclusive = false
	title = "EVENT DETAILS"
	
	_setup_fonts()
	_build_ui()


func _ready() -> void:
	hide()
	close_btn.pressed.connect(hide)
	title_bar.gui_input.connect(_on_title_bar_gui_input)
	window_input.connect(_on_window_input)


# Listens to keyboard input while this window has focus.
func _on_window_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_C or event.keycode == KEY_ESCAPE:
			hide()


func open_for_date(year: int, month: int, day: int, spawn_pos: Vector2i) -> void:
	var month_names := [
		"January", "February", "March", "April", "May", "June",
		"July", "August", "September", "October", "November", "December"
	]
	title_lbl.text = " %s %02d, %04d" % [month_names[month - 1], day, year]
	
	position = spawn_pos
	show()
	grab_focus()


func _on_title_bar_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		is_dragging = event.pressed
		drag_offset = DisplayServer.mouse_get_position() - position
	elif event is InputEventMouseMotion and is_dragging:
		position = DisplayServer.mouse_get_position() - drag_offset


func _setup_fonts() -> void:
	system_font = SystemFont.new()
	system_font.font_names = PackedStringArray(["Cartograph Mono", "Cartograph CF", "TG Frekuent Mono", "Consolas", "monospace"])
	system_font.font_weight = 550
	
	content_font = SystemFont.new()
	content_font.font_names = PackedStringArray(["Jost", "Futura", "Inter", "Segoe UI", "sans-serif"])
	content_font.font_weight = 400


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
	
	title_lbl = Label.new()
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_lbl.add_theme_font_override("font", system_font)
	title_lbl.add_theme_font_size_override("font_size", 13)
	t_row.add_child(title_lbl)
	
	close_btn = Button.new()
	close_btn.text = "X"
	close_btn.custom_minimum_size = Vector2(18, 18)
	close_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_apply_btn_style(close_btn)
	t_row.add_child(close_btn)
	
	var body_margin := MarginContainer.new()
	body_margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_margin.add_theme_constant_override("margin_left", 20)
	body_margin.add_theme_constant_override("margin_top", 24)
	layout.add_child(body_margin)
	
	empty_lbl = Label.new()
	empty_lbl.text = "No Plans Today"
	empty_lbl.add_theme_font_override("font", content_font)
	empty_lbl.add_theme_font_size_override("font_size", 16)
	empty_lbl.add_theme_color_override("font_color", Color.WHITE)
	body_margin.add_child(empty_lbl)


func _apply_btn_style(btn: Button) -> void:
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
