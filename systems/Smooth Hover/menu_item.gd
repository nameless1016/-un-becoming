class_name MenuItem
extends Button
## Text-only menu entry. When hovered, focused or [member selected], a ">" eases
## in on its left, the text slides right a little and brightens. Hovering also
## takes keyboard focus, so mouse and keyboard never show two markers at once.

const FADE_TIME := 0.18
const FONT_COLORS: Array[StringName] = [&"font_color", &"font_hover_color", &"font_focus_color", &"font_pressed_color", &"font_hover_pressed_color"]

## Shows the ">" marker. Off for the Settings tabs, which use bold instead.
@export var show_arrow: bool = true
## How far the text slides right when active, in pixels.
@export var nudge: float = 4.0
## Font used while [member selected] (e.g. bold for the active Settings tab).
@export var selected_font: Font
## Stays highlighted without hover (the active Settings tab).
@export var selected: bool = false:
	set(value):
		selected = value
		if is_node_ready():
			_update_font()
			_refresh()

var _t: float = 0.0
var _tween: Tween
var _box := StyleBoxEmpty.new()
var _arrow: Label
var _rest_color: Color
var _active_color: Color


func _ready() -> void:
	for style in [&"normal", &"hover", &"pressed", &"hover_pressed", &"focus", &"disabled"]:
		add_theme_stylebox_override(style, _box)
	_rest_color = get_theme_color(&"font_color")
	_active_color = get_theme_color(&"font_hover_color")
	if show_arrow:
		_arrow = Label.new()
		_arrow.text = ">"
		_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_arrow.add_theme_font_size_override(&"font_size", get_theme_font_size(&"font_size"))
		_arrow.add_theme_font_override(&"font", get_theme_font(&"font"))
		add_child(_arrow)
	mouse_entered.connect(_on_mouse_entered)
	for sig in [mouse_exited, focus_entered, focus_exited]:
		sig.connect(_refresh.call_deferred)
	resized.connect(_place_arrow)
	_update_font()
	_apply(0.0)
	_refresh()


func _on_mouse_entered() -> void:
	if not disabled and focus_mode != Control.FOCUS_NONE:
		grab_focus()
		SoundBank.play_sfx("ui_hover")
	_refresh.call_deferred()


func _refresh() -> void:
	var on := not disabled and (selected or has_focus() or is_hovered())
	if _tween:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_tween.tween_method(_apply, _t, 1.0 if on else 0.0, FADE_TIME)


func _apply(t: float) -> void:
	_t = t
	_box.content_margin_left = nudge * t
	if not disabled:
		var color := _rest_color.lerp(_active_color, t)
		for name in FONT_COLORS:
			add_theme_color_override(name, color)
	_place_arrow()


func _place_arrow() -> void:
	if _arrow == null:
		return
	_arrow.modulate.a = _t
	_arrow.reset_size()
	_arrow.position = Vector2(-_arrow.size.x - 6.0 + 2.0 * _t, (size.y - _arrow.size.y) * 0.5)


func _update_font() -> void:
	if selected_font and selected:
		add_theme_font_override(&"font", selected_font)
	else:
		remove_theme_font_override(&"font")
