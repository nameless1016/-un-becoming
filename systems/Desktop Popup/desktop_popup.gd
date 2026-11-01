class_name DesktopPopup
extends Window
## A small Windows-style pop-up that opens as its own window on the player's
## desktop, outside the game window. Where that isn't possible (exclusive
## fullscreen, which would minimise the game, or single-window platforms) it
## opens inside the game instead.
##
## [codeblock]
## var choice := await DesktopPopup.ask(self, "Exit", "Don't leave me...", ["Yes", "No"], "Yes")
## [/codeblock]

signal answered(choice: String)

## Returned when the player closes the pop-up with its X, Esc or Alt+F4.
const CLOSED := "close"
const SCENE_PATH := "res://systems/Desktop Popup/desktop_popup.tscn"
const MIN_SIZE := Vector2(168, 88)
const DANGER_COLOR := Color(0.79, 0.29, 0.29)

var _dragging: bool = false
var _answered: bool = false

@onready var _title_bar: Control = %TitleBar
@onready var _title_label: Label = %TitleLabel
@onready var _close_button: Button = %CloseButton
@onready var _message: Label = %Message
@onready var _buttons: HBoxContainer = %Buttons
@onready var _frame: Control = %Frame


## Opens a pop-up and waits for the player's choice: one of [param buttons], or [constant CLOSED].
## [param danger] names a button drawn in red (e.g. "Yes" on a quit prompt).
static func ask(host: Node, title_text: String, message: String, buttons: Array[String], danger: String = "", italic: bool = true) -> String:
	var popup: DesktopPopup = load(SCENE_PATH).instantiate()
	host.add_child(popup)
	popup._setup(title_text, message, buttons, danger, italic)
	popup._open()
	return await popup.answered


func _ready() -> void:
	close_requested.connect(_answer.bind(CLOSED))
	_close_button.pressed.connect(_answer.bind(CLOSED))
	_title_bar.gui_input.connect(_on_title_bar_input)


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		set_input_as_handled()
		_answer(CLOSED)


func _setup(title_text: String, message: String, buttons: Array[String], danger: String, italic: bool) -> void:
	title = title_text
	_title_label.text = title_text
	_message.text = message
	if not italic:
		_message.remove_theme_font_override(&"font")
	for text in buttons:
		var button := Button.new()
		button.text = text.to_upper()
		button.theme_type_variation = &"PopupButton"
		if text == danger:
			button.add_theme_color_override(&"font_color", DANGER_COLOR)
		button.pressed.connect(_answer.bind(text))
		var fade := HoverFade.new()
		button.add_child(fade)
		_buttons.add_child(button)


func _open() -> void:
	var root := get_tree().root
	var native := _can_open_on_desktop()
	# Native windows need the root to stop embedding sub-windows; Meta OS also sets this.
	if root.gui_embed_subwindows == native:
		root.gui_embed_subwindows = not native
	var logical := _frame.get_combined_minimum_size().max(MIN_SIZE).ceil()
	if native:
		# Scale the pop-up like the game window so it looks the same size on screen.
		var scale := root.get_final_transform().get_scale().x
		content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		content_scale_size = Vector2i(logical)
		size = Vector2i((logical * scale).round())
		var area := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
		position = area.position + (area.size - size) / 2
	else:
		content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		size = Vector2i(logical)
		position = Vector2i((root.get_visible_rect().size - logical) / 2.0)
	show()
	grab_focus()
	var last := _buttons.get_child_count() - 1
	if last >= 0:
		(_buttons.get_child(last) as Button).grab_focus()


## True when the pop-up can be a real window on the desktop.
func _can_open_on_desktop() -> bool:
	if not DisplayServer.has_feature(DisplayServer.FEATURE_SUBWINDOWS):
		return false
	return DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN


func _on_title_bar_input(event: InputEvent) -> void:
	var button := event as InputEventMouseButton
	if button and button.button_index == MOUSE_BUTTON_LEFT:
		_dragging = button.pressed
	elif event is InputEventMouseMotion and _dragging:
		var delta: Vector2 = (event as InputEventMouseMotion).screen_relative
		if is_embedded():
			delta /= get_tree().root.get_final_transform().get_scale().x
		position += Vector2i(delta.round())


func _answer(choice: String) -> void:
	if _answered:
		return
	_answered = true
	var was_native := not is_embedded()
	hide()
	answered.emit(choice)
	queue_free()
	if was_native:
		DisplayServer.window_move_to_foreground(DisplayServer.MAIN_WINDOW_ID)
