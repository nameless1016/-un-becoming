class_name HoverFade
extends Node
## Add as a child of a Button to fade its background and text colour when it's
## hovered or focused (or while [member forced]) instead of snapping between styles.
## The button's "normal" style must be a StyleBoxFlat; its bg_color is the resting colour.

const FONT_COLORS: Array[StringName] = [&"font_color", &"font_hover_color", &"font_focus_color", &"font_pressed_color", &"font_hover_pressed_color"]

@export var hover_bg: Color = Color.WHITE
@export var hover_font: Color = Color.BLACK
@export var fade_time: float = 0.15
## Also treat a toggle button's "on" state as hovered (for option buttons).
@export var include_pressed: bool = true

## Holds the hovered look regardless of the mouse, e.g. while a key cell waits for input.
var forced: bool = false:
	set(value):
		forced = value
		refresh()

var _button: Button
var _box: StyleBoxFlat
var _normal_bg: Color
var _normal_font: Color
var _t: float = 0.0
var _tween: Tween


func _ready() -> void:
	_button = get_parent() as Button
	if _button == null:
		push_warning("HoverFade must be a child of a Button.")
		return
	var base := _button.get_theme_stylebox(&"normal")
	_box = base.duplicate() if base is StyleBoxFlat else StyleBoxFlat.new()
	for style in [&"normal", &"hover", &"pressed", &"hover_pressed"]:
		_button.add_theme_stylebox_override(style, _box)
	_normal_bg = _box.bg_color
	_normal_font = _button.get_theme_color(&"font_color")
	for sig in [_button.mouse_entered, _button.mouse_exited, _button.focus_entered, _button.focus_exited]:
		sig.connect(refresh.call_deferred)
	_button.toggled.connect(func(_on: bool) -> void: refresh())
	_apply(0.0)
	refresh()


## Re-reads the button's state and fades toward it. Call after changing colours.
func refresh() -> void:
	if _button == null or not is_inside_tree():
		return
	var on := forced or (not _button.disabled and (_button.is_hovered() or _button.has_focus() or (include_pressed and _button.button_pressed)))
	if _tween:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tween.tween_method(_apply, _t, 1.0 if on else 0.0, fade_time)


func _apply(t: float) -> void:
	_t = t
	_box.bg_color = _normal_bg.lerp(hover_bg, t)
	var color := _normal_font.lerp(hover_font, t)
	for name in FONT_COLORS:
		_button.add_theme_color_override(name, color)
