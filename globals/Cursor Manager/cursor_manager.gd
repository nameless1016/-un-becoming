extends Node
## Autoload (as CursorManager) that owns the mouse cursor.
##
## Anything the mouse can hover (hotspots, the exit button, ...) calls
## [method push_hover] on enter and [method pop_hover] on exit. The most
## recently entered source decides the cursor image and tooltip, so
## overlapping hotspots behave sensibly.

enum Mode { DEFAULT, INTERACT, EXAMINE, TALK, EXIT }

@export_group("Default")
@export var default_texture: Texture2D
@export var default_hotspot: Vector2 = Vector2.ZERO
@export_group("Interact")
@export var interact_texture: Texture2D
@export var interact_hotspot: Vector2 = Vector2.ZERO
@export_group("Examine")
@export var examine_texture: Texture2D
@export var examine_hotspot: Vector2 = Vector2.ZERO
@export_group("Talk")
@export var talk_texture: Texture2D
@export var talk_hotspot: Vector2 = Vector2.ZERO
@export_group("Exit")
@export var exit_texture: Texture2D
@export var exit_hotspot: Vector2 = Vector2.ZERO
@export_group("Tooltip")
## Distance from the cursor's hotspot to the tooltip's top-left corner.
@export var tooltip_offset: Vector2 = Vector2(10, 12)

var mode: Mode = Mode.DEFAULT

# Each entry: { source: Object, mode: Mode, label: String }. Last entry wins.
var _hover_stack: Array[Dictionary] = []

@onready var _tooltip: Control = %Tooltip
@onready var _tooltip_label: Label = %TooltipLabel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_tooltip.hide()
	_apply_mode(Mode.DEFAULT)


func _process(_delta: float) -> void:
	if not _tooltip.visible:
		return
	var viewport_size := get_viewport().get_visible_rect().size
	var pos := get_viewport().get_mouse_position() + tooltip_offset
	# Flip to the other side of the cursor instead of running off-screen.
	if pos.x + _tooltip.size.x > viewport_size.x:
		pos.x -= _tooltip.size.x + tooltip_offset.x * 2.0
	if pos.y + _tooltip.size.y > viewport_size.y:
		pos.y -= _tooltip.size.y + tooltip_offset.y * 2.0
	_tooltip.position = pos


## Start hovering [param source]. Calling again for the same source updates it.
func push_hover(source: Object, cursor_mode: Mode, label: String = "") -> void:
	_remove_source(source)
	_hover_stack.append({ source = source, mode = cursor_mode, label = label })
	_refresh()


func pop_hover(source: Object) -> void:
	_remove_source(source)
	_refresh()


## Forget every hover source and go back to the default cursor.
## Call when input gets locked (dialogue, menus) or a scene is left.
func clear_hover() -> void:
	_hover_stack.clear()
	_refresh()


func _remove_source(source: Object) -> void:
	for i in range(_hover_stack.size() - 1, -1, -1):
		if _hover_stack[i].source == source:
			_hover_stack.remove_at(i)


func _refresh() -> void:
	_hover_stack = _hover_stack.filter(func(entry: Dictionary) -> bool: return is_instance_valid(entry.source))
	if _hover_stack.is_empty():
		_apply_mode(Mode.DEFAULT)
		_tooltip.hide()
		return
	var top: Dictionary = _hover_stack.back()
	_apply_mode(top.mode)
	_tooltip_label.text = top.label
	_tooltip.visible = not top.label.is_empty()
	# Shrink back to fit when going from a long label to a short one.
	_tooltip.reset_size()


func _apply_mode(new_mode: Mode) -> void:
	mode = new_mode
	var texture: Texture2D = default_texture
	var hotspot: Vector2 = default_hotspot
	match new_mode:
		Mode.INTERACT:
			texture = interact_texture
			hotspot = interact_hotspot
		Mode.EXAMINE:
			texture = examine_texture
			hotspot = examine_hotspot
		Mode.TALK:
			texture = talk_texture
			hotspot = talk_hotspot
		Mode.EXIT:
			texture = exit_texture
			hotspot = exit_hotspot
	if texture == null:
		texture = default_texture
		hotspot = default_hotspot
	# Controls default to CURSOR_ARROW, so replacing that one shape covers
	# both the 2D world and buttons. A null texture restores the OS cursor.
	Input.set_custom_mouse_cursor(texture, Input.CURSOR_ARROW, hotspot)
