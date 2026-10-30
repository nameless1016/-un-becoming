@tool
class_name Hotspot
extends Area2D
## A clickable region in a PointAndClickScene.
##
## Shows [member hotspot_name] as a tag on the object (a black box with a white
## border, like the menu) that inverts on hover, changes the cursor, and emits
## [signal activated] on left click. The owning PointAndClickScene
## decides what a click does (by default: play [member dialogue_timeline]).
## Instance res://systems/Point And Click/hotspot.tscn rather than building one
## by hand, and set [member size] instead of editing the collision shape.

signal activated(hotspot: Hotspot)

enum InteractionType { EXAMINE, INTERACT, TALK }

## The object's name, shown on its tag (or next to the cursor if [member show_label] is off).
@export var hotspot_name: String = "":
	set(value):
		hotspot_name = value
		queue_redraw()
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
## Draws [member hotspot_name] as a tag on the object. Off: the name shows next
## to the cursor on hover instead.
@export var show_label: bool = true:
	set(value):
		show_label = value
		queue_redraw()
## Moves the tag from the centre of the hotspot, for objects whose middle isn't
## the best place for it.
@export var label_offset: Vector2 = Vector2.ZERO:
	set(value):
		label_offset = value
		queue_redraw()
## Shows the placeholder "Visual" (the Godot icon). Turn off on stills whose
## background already shows the object; the cursor and tooltip still react.
@export var show_placeholder: bool = true:
	set(value):
		show_placeholder = value
		if is_node_ready() and _visual:
			_visual.visible = value

## Set by the owning scene while dialogue is playing. Unlike [member enabled],
## this is temporary and never saved.
var locked: bool = false:
	set(value):
		locked = value
		_update_pickable()
var is_hovered: bool = false

const LABEL_FONT := preload("res://game_assets/fonts/Space Mono/SpaceMono-Bold.ttf")
const LABEL_FONT_SIZE := 9
const LABEL_PADDING := Vector2(8, 3)
const LABEL_FADE_TIME := 0.15

var _owns_shape: bool = false
# 0 = resting tag, 1 = hovered (inverted). Tweened so the tag fades like the menu buttons.
var _hover_t: float = 0.0
# 1 = tag shown, 0 = hidden while the scene is busy (dialogue, a window).
var _shown_t: float = 1.0
var _hover_tween: Tween
var _shown_tween: Tween
var _leaving: bool = false

@onready var _visual: CanvasItem = get_node_or_null(^"Visual")

@onready var _collision: CollisionShape2D = get_node_or_null(^"CollisionShape2D")


func _ready() -> void:
	_apply_size()
	if _visual:
		_visual.visible = show_placeholder
	if Engine.is_editor_hint():
		return
	_update_pickable()
	mouse_entered.connect(_set_hovered.bind(true))
	mouse_exited.connect(_set_hovered.bind(false))
	input_event.connect(_on_input_event)


func _exit_tree() -> void:
	_leaving = true
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
	if is_node_ready() and not _leaving and not Engine.is_editor_hint():
		_shown_tween = _fade(_shown_tween, "_shown_t", 1.0 if input_pickable else 0.0)
	# Physics picking won't always send mouse_exited when we stop being pickable.
	if not input_pickable:
		_set_hovered(false)


func _set_hovered(value: bool) -> void:
	if value == is_hovered:
		return
	is_hovered = value
	if value:
		# With a tag on the object, a cursor tooltip would just repeat it.
		CursorManager.push_hover(self, _cursor_mode(), "" if show_label else hotspot_name)
	else:
		CursorManager.pop_hover(self)
	if highlight_on_hover and _visual:
		_visual.modulate = Color(1.35, 1.35, 1.35) if value else Color.WHITE
	if is_inside_tree() and not _leaving:
		_hover_tween = _fade(_hover_tween, "_hover_t", 1.0 if value else 0.0)


func _draw() -> void:
	if not show_label or hotspot_name.is_empty() or _shown_t <= 0.0:
		return
	var text_size := LABEL_FONT.get_string_size(hotspot_name, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT_SIZE)
	var box_size := (text_size + LABEL_PADDING * 2).round()
	var box := Rect2((label_offset - box_size * 0.5).round(), box_size)
	var bg := Color.BLACK.lerp(Color.WHITE, _hover_t)
	var fg := Color.WHITE.lerp(Color.BLACK, _hover_t)
	bg.a = _shown_t
	fg.a = _shown_t
	draw_rect(box, bg)
	draw_rect(box.grow(-0.5), Color(1, 1, 1, _shown_t), false, 1.0)
	var baseline := box.position.y + (box.size.y + LABEL_FONT.get_ascent(LABEL_FONT_SIZE) - LABEL_FONT.get_descent(LABEL_FONT_SIZE)) * 0.5
	draw_string(LABEL_FONT, Vector2(box.position.x, baseline), hotspot_name, HORIZONTAL_ALIGNMENT_CENTER, box.size.x, LABEL_FONT_SIZE, fg)


func _fade(tween: Tween, property: String, to: float) -> Tween:
	if tween:
		tween.kill()
	if get(property) == to:
		return null
	var new_tween := create_tween()
	new_tween.tween_method(func(t: float) -> void:
		set(property, t)
		queue_redraw(), get(property), to, LABEL_FADE_TIME)
	return new_tween


func _cursor_mode() -> int:
	match interaction_type:
		InteractionType.INTERACT:
			return CursorManager.Mode.INTERACT
		InteractionType.TALK:
			return CursorManager.Mode.TALK
		_:
			return CursorManager.Mode.EXAMINE
