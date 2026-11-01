class_name KeyCell
extends RebindButton
## One cell of the Controls table. Shows the bound key, fades grey on hover,
## and turns white while it waits for a new key (the mockup's "changing key" state).

const HOVER_BG := Color(0.16, 0.16, 0.16)

var _fade: HoverFade
var _was_listening: bool = false


func _ready() -> void:
	super()
	_fade = HoverFade.new()
	_fade.hover_bg = HOVER_BG
	_fade.hover_font = Color.WHITE
	add_child(_fade)


func _process(_delta: float) -> void:
	if is_listening == _was_listening:
		return
	_was_listening = is_listening
	_fade.hover_bg = Color.WHITE if is_listening else HOVER_BG
	_fade.hover_font = Color.BLACK if is_listening else Color.WHITE
	_fade.forced = is_listening


func _pressed() -> void:
	super()
	text = "-Press a key-"


func update_button_text() -> void:
	super()
	if current_event == null and action_name != "":
		text = "-Unassigned-"
