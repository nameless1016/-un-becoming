@tool
class_name Hotspot
extends Area2D
## A clickable region in a PointAndClickScene.
##
## Changes the cursor and shows [member hotspot_name] as a tooltip on hover,
## and emits [signal activated] on left click. The owning PointAndClickScene
## decides what a click does (by default: play [member dialogue_timeline]).
## Instance res://systems/Point And Click/hotspot.tscn rather than building one
## by hand, and set [member size] instead of editing the collision shape.

signal activated(hotspot: Hotspot)

enum InteractionType { EXAMINE, INTERACT, TALK }

## Shown next to the cursor while hovering.
@export var hotspot_name: String = ""
## Picks the cursor: EXAMINE = eye, INTERACT = hand, TALK = speech bubble.
@export var interaction_type: InteractionType = InteractionType.EXAMINE
## Dialogic timeline to play on click: a timeline identifier or a res:// path to a .dtl file.
@export var dialogue_timeline: String = ""
## Size of the clickable rectangle, centred on the node. Also stretches a
## Sprite2D "Visual" (the placeholder icon) to match, so it previews in the editor.
@export var size: Vector2 = Vector2(64, 64):
	set(value):
		size = value
		if is_node_ready():
			_apply_size()
## Disabled hotspots ignore the mouse entirely.
@export var enabled: bool = true:
	set(value):
		enabled = value
		_update_pickable()
## Brightens the child named "Visual" (if any) while hovered.
@export var highlight_on_hover: bool = true

## Set by the owning scene while dialogue is playing. Unlike [member enabled],
## this is temporary and never saved.
var locked: bool = false:
	set(value):
		locked = value
		_update_pickable()
var is_hovered: bool = false

@onready var _visual: CanvasItem = get_node_or_null(^"Visual")


var _owns_shape: bool = false

@onready var _collision: CollisionShape2D = get_node_or_null(^"CollisionShape2D")


func _ready() -> void:
	_apply_size()
	if Engine.is_editor_hint():
		return
	_update_pickable()
	mouse_entered.connect(_set_hovered.bind(true))
	mouse_exited.connect(_set_hovered.bind(false))
	input_event.connect(_on_input_event)


func _exit_tree() -> void:
	_set_hovered(false)


func _apply_size() -> void:
	if _collision:
		# Own a copy so resizing one hotspot never resizes another that shares the shape.
		if not _owns_shape or not _collision.shape is RectangleShape2D:
			var rect := _collision.shape as RectangleShape2D
			_collision.shape = rect.duplicate() if rect else RectangleShape2D.new()
			_owns_shape = true
		(_collision.shape as RectangleShape2D).size = size
	var sprite := _visual as Sprite2D
	if sprite and sprite.texture:
		sprite.scale = size / sprite.texture.get_size()


func _on_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event and mouse_event.button_index == MOUSE_BUTTON_LEFT and mouse_event.pressed:
		get_viewport().set_input_as_handled()
		activated.emit(self)


func _update_pickable() -> void:
	input_pickable = enabled and not locked
	# Physics picking won't always send mouse_exited when we stop being pickable.
	if not input_pickable:
		_set_hovered(false)


func _set_hovered(value: bool) -> void:
	if value == is_hovered:
		return
	is_hovered = value
	if value:
		CursorManager.push_hover(self, _cursor_mode(), hotspot_name)
	else:
		CursorManager.pop_hover(self)
	if highlight_on_hover and _visual:
		_visual.modulate = Color(1.35, 1.35, 1.35) if value else Color.WHITE


func _cursor_mode() -> int:
	match interaction_type:
		InteractionType.INTERACT:
			return CursorManager.Mode.INTERACT
		InteractionType.TALK:
			return CursorManager.Mode.TALK
		_:
			return CursorManager.Mode.EXAMINE
