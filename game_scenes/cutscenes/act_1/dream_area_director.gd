extends Node
## Our part of Act 1's top-down dream area (PoorCoconut's world_dream): a short
## movement hint when the player arrives.
##
## The rest of the dream is the team's: the indoctrination.exe pickup shows its own
## "Obtained" pop-up, executing it from the file system opens RJ's maze, and the
## maze is meant to hand back to the meadow for the machine's voice
## (DreamMeadow.resume_at_awakening). The maze doesn't hand back yet.

const HINT := "Move: WASD / Arrows   ·   Interact: E"
const HINT_FONT := preload("res://game_assets/fonts/Space Mono/SpaceMono-Regular.ttf")

@export var hint_hold: float = 5.0

var _hint: Label


func _ready() -> void:
	_show_hint.call_deferred()


func _show_hint() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	_hint = Label.new()
	_hint.text = HINT
	_hint.add_theme_font_override(&"font", HINT_FONT)
	_hint.add_theme_font_size_override(&"font_size", 9)
	_hint.add_theme_color_override(&"font_color", Color.WHITE)
	_hint.add_theme_color_override(&"font_outline_color", Color.BLACK)
	_hint.add_theme_constant_override(&"outline_size", 3)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_hint.position = Vector2(0, 330)
	_hint.size = Vector2(640, 16)
	_hint.modulate.a = 0.0
	layer.add_child(_hint)
	var tween := create_tween()
	tween.tween_interval(1.0)
	tween.tween_property(_hint, ^"modulate:a", 1.0, 0.8)
	tween.tween_interval(hint_hold)
	tween.tween_property(_hint, ^"modulate:a", 0.0, 0.8)
