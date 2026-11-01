extends CanvasLayer
class_name MapMenu

const LAZY_LINE := "You not walking no more you lazy punk"
const OUTLINE_BLUE := Color(0.10, 0.28, 0.80)

## id of the stop you're standing at, SubwayStop sets this before adding the menu
var current_id: String = ""
var picked: bool = false

var root: Control
var pins: Array = []
var marker: MapMarker
var name_label: Label

func _ready() -> void:
	layer = 50
	# has to keep running while the game is paused or the buttons won't respond
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true
	build_ui()
	layout()

func build_ui() -> void:
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.resized.connect(layout)
	add_child(root)

	var canvas := MapCanvas.new()
	canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(canvas)

	build_pins()

	marker = MapMarker.new()
	root.add_child(marker)

	build_banner()
	build_bottom_bar()

func build_pins() -> void:
	var first_enabled: Button = null
	for loc in MapLocations.LIST:
		var btn := Button.new()
		btn.text = loc["name"]
		btn.add_theme_font_size_override("font_size", 32)
		btn.add_theme_color_override("font_color", Color.WHITE)
		btn.add_theme_color_override("font_hover_color", Color.WHITE)
		btn.add_theme_color_override("font_pressed_color", Color.WHITE)
		btn.add_theme_color_override("font_focus_color", Color(1.0, 0.95, 0.5))
		btn.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.8))
		btn.add_theme_color_override("font_outline_color", OUTLINE_BLUE)
		btn.add_theme_constant_override("outline_size", 12)

		# no button background, just floating text like on the DS map
		var empty := StyleBoxEmpty.new()
		empty.set_content_margin_all(10)
		btn.add_theme_stylebox_override("normal", empty)
		btn.add_theme_stylebox_override("hover", empty)
		btn.add_theme_stylebox_override("pressed", empty)
		btn.add_theme_stylebox_override("disabled", empty)

		# the highlight box around whichever place is selected
		var focus := make_box(Color(1.0, 0.9, 0.3, 0.18), 16, Color(1.0, 0.85, 0.2), 4)
		btn.add_theme_stylebox_override("focus", focus)

		if loc["id"] == current_id:
			btn.disabled = true
		else:
			btn.pressed.connect(_on_pick.bind(loc))
			btn.focus_entered.connect(_on_focus.bind(loc))
			btn.mouse_entered.connect(btn.grab_focus)
			if first_enabled == null:
				first_enabled = btn

		root.add_child(btn)
		pins.append({"btn": btn, "loc": loc})

	if first_enabled != null:
		first_enabled.grab_focus.call_deferred()

func build_banner() -> void:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", make_box(Color(0.05, 0.07, 0.15, 0.85), 14, Color(1.0, 0.8, 0.3, 0.9), 3))
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.offset_top = 16
	root.add_child(panel)

	var box := VBoxContainer.new()
	panel.add_child(box)

	var title := Label.new()
	title.text = "SUBWAY MAP"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", Color(0.8, 0.9, 1.0))
	box.add_child(title)

	var lazy := Label.new()
	lazy.text = LAZY_LINE
	lazy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lazy.add_theme_font_size_override("font_size", 28)
	lazy.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	box.add_child(lazy)

func build_bottom_bar() -> void:
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", make_box(Color(0.04, 0.04, 0.06, 0.95), 0))
	bar.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bar.offset_top = -78
	root.add_child(bar)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	bar.add_child(row)

	row.add_child(make_key_label("A", "Select"))

	name_label = Label.new()
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_label.add_theme_font_size_override("font_size", 34)
	name_label.add_theme_color_override("font_color", Color(0.95, 0.95, 1.0))
	var here := MapLocations.get_location(current_id)
	name_label.text = here.get("name", "")
	row.add_child(name_label)

	row.add_child(make_key_label("B", "Back"))

func make_key_label(key: String, action: String) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", make_box(Color(0.35, 0.68, 0.15), 10, Color(0.65, 0.9, 0.35), 3))
	var l := Label.new()
	l.text = key + "   " + action
	l.add_theme_font_size_override("font_size", 26)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color(0.1, 0.3, 0.05))
	l.add_theme_constant_override("outline_size", 6)
	p.add_child(l)
	return p

func make_box(bg: Color, radius: int, border: Color = Color(0, 0, 0, 0), border_w: int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb

func layout() -> void:
	# runs on open and again whenever the window size changes
	if root == null or pins.is_empty():
		return
	var s := root.size
	for pin in pins:
		var btn: Button = pin["btn"]
		var loc: Dictionary = pin["loc"]
		btn.size = btn.get_minimum_size()
		var center: Vector2 = loc["map_pos"] * s
		btn.position = center - btn.size * 0.5
		if loc["id"] == current_id and marker != null:
			marker.position = Vector2(center.x - marker.size.x * 0.5, btn.position.y - marker.size.y + 14.0)

func _on_focus(loc: Dictionary) -> void:
	name_label.text = loc["name"]

func _on_pick(loc: Dictionary) -> void:
	if picked:
		return
	picked = true

	var transition = get_node_or_null("/root/SceneTransition")
	if transition != null:
		transition.change_scene(loc["scene"], loc["spawn"])
	else:
		# no fade autoload set up yet, just cut straight to the map
		get_tree().paused = false
		get_tree().change_scene_to_file(loc["scene"])
	queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not picked:
		get_tree().paused = false
		queue_free()
		get_viewport().set_input_as_handled()
