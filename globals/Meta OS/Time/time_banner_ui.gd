class_name TimeBannerUI
extends Window

# Scaled up desktop time banner with frosted blur backdrop and sliding animations.

var system_font: SystemFont
var blur_backdrop: PanelContainer
var banner_container: HBoxContainer
var day_card_vbox: VBoxContainer
var weekday_box: PanelContainer
var weekday_lbl: Label
var day_box: PanelContainer
var day_lbl: Label
var slot_lbl: Label

var active_tween: Tween
var is_sliding: bool = false


func _init() -> void:
	# Scaled window size to comfortably fit the larger widget.
	size = Vector2i(340, 130)
	unresizable = true
	borderless = true
	always_on_top = true
	transient = false
	exclusive = false
	transparent = true
	transparent_bg = true
	title = "TIME BANNER"
	
	_setup_fonts()
	_build_ui()


func _ready() -> void:
	hide()
	
	TimeManager.time_changed.connect(func(_slot): show_banner())
	TimeManager.day_changed.connect(func(_y, _m, _d): show_banner())
	
	show_banner()


# Animates the banner sliding in from off screen on the left.
func show_banner() -> void:
	if is_sliding:
		return
	is_sliding = true
	
	_update_labels()
	
	var screen_id: int = DisplayServer.get_primary_screen()
	var screen_origin: Vector2i = DisplayServer.screen_get_position(screen_id)
	
	var start_x: int = screen_origin.x - size.x - 30
	var target_x: int = screen_origin.x + 40
	var target_y: int = screen_origin.y + 40
	
	position = Vector2i(start_x, target_y)
	show()
	
	if active_tween and active_tween.is_valid():
		active_tween.kill()
		
	# Slide in from the left edge of the physical monitor.
	active_tween = create_tween()
	active_tween.tween_method(
		func(cur_x: int): position = Vector2i(cur_x, target_y),
		start_x,
		target_x,
		0.38
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	await active_tween.finished
	await get_tree().create_timer(2.6).timeout
	
	# Slide back off screen to the left.
	active_tween = create_tween()
	active_tween.tween_method(
		func(cur_x: int): position = Vector2i(cur_x, target_y),
		target_x,
		start_x,
		0.35
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	
	await active_tween.finished
	hide()
	is_sliding = false


func _update_labels() -> void:
	weekday_lbl.text = TimeManager.get_weekday_name()
	day_lbl.text = "%02d" % TimeManager.current_day
	slot_lbl.text = TimeManager.get_slot_symbol() + "  " + TimeManager.get_slot_name()


func _setup_fonts() -> void:
	system_font = SystemFont.new()
	system_font.font_names = PackedStringArray(["Cartograph Mono", "Cartograph CF", "TG Frekuent Mono", "Consolas", "monospace"])
	system_font.font_weight = 600
	system_font.hinting = TextServer.HINTING_NORMAL
	system_font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED


func _build_ui() -> void:
	# Frosted translucent backdrop replacing the harsh black box.
	blur_backdrop = PanelContainer.new()
	blur_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	var glass_style := StyleBoxFlat.new()
	glass_style.bg_color = Color(0.12, 0.12, 0.14, 0.65)
	glass_style.border_width_left = 1
	glass_style.border_width_top = 1
	glass_style.border_width_right = 1
	glass_style.border_width_bottom = 1
	glass_style.border_color = Color(1.0, 1.0, 1.0, 0.18)
	glass_style.corner_radius_top_left = 6
	glass_style.corner_radius_top_right = 6
	glass_style.corner_radius_bottom_right = 6
	glass_style.corner_radius_bottom_left = 6
	glass_style.content_margin_left = 12
	glass_style.content_margin_right = 18
	glass_style.content_margin_top = 10
	glass_style.content_margin_bottom = 10
	blur_backdrop.add_theme_stylebox_override("panel", glass_style)
	add_child(blur_backdrop)
	
	banner_container = HBoxContainer.new()
	banner_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	banner_container.add_theme_constant_override("separation", 18)
	blur_backdrop.add_child(banner_container)
	
	day_card_vbox = VBoxContainer.new()
	day_card_vbox.add_theme_constant_override("separation", 0)
	day_card_vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	banner_container.add_child(day_card_vbox)
	
	# Scaled up weekday box.
	weekday_box = PanelContainer.new()
	weekday_box.custom_minimum_size = Vector2(88, 32)
	var white_style := StyleBoxFlat.new()
	white_style.bg_color = Color.WHITE
	white_style.border_width_left = 3
	white_style.border_width_top = 3
	white_style.border_width_right = 3
	white_style.border_color = Color.WHITE
	weekday_box.add_theme_stylebox_override("panel", white_style)
	day_card_vbox.add_child(weekday_box)
	
	weekday_lbl = Label.new()
	weekday_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	weekday_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	weekday_lbl.add_theme_font_override("font", system_font)
	weekday_lbl.add_theme_font_size_override("font_size", 16)
	weekday_lbl.add_theme_color_override("font_color", Color.BLACK)
	weekday_box.add_child(weekday_lbl)
	
	# Scaled up day number box.
	day_box = PanelContainer.new()
	day_box.custom_minimum_size = Vector2(88, 58)
	var black_style := StyleBoxFlat.new()
	black_style.bg_color = Color.BLACK
	black_style.border_width_left = 3
	black_style.border_width_bottom = 3
	black_style.border_width_right = 3
	black_style.border_color = Color.WHITE
	day_box.add_theme_stylebox_override("panel", black_style)
	day_card_vbox.add_child(day_box)
	
	day_lbl = Label.new()
	day_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	day_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	day_lbl.add_theme_font_override("font", system_font)
	day_lbl.add_theme_font_size_override("font_size", 34)
	day_lbl.add_theme_color_override("font_color", Color.WHITE)
	day_box.add_child(day_lbl)
	
	# Scaled up slot name label.
	slot_lbl = Label.new()
	slot_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	slot_lbl.add_theme_font_override("font", system_font)
	slot_lbl.add_theme_font_size_override("font_size", 24)
	slot_lbl.add_theme_color_override("font_color", Color("#f0f0f0"))
	banner_container.add_child(slot_lbl)
