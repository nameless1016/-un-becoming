extends Node
## Runs Act 1's top-down dream area (PoorCoconut's world_dream): a short tutorial
## hint, the "Obtained" pop-up when indoctrination.exe is picked up, and the way
## back to the meadow for the machine's voice.
##
## Executing indoctrination.exe should turn the dream into RJ's maze, which then
## hands back to the meadow (DreamMeadow.resume_at_awakening). The maze can't
## hand back yet (it quits the game when it ends), so for now picking the file up
## goes straight back to the meadow after the pop-up.

const MEADOW := "res://game_scenes/cutscenes/act_1/dream_meadow.tscn"
const HINT := "Move: WASD / Arrows   ·   Interact: E"
const HINT_FONT := preload("res://game_assets/fonts/Space Mono/SpaceMono-Regular.ttf")

## The indoctrination.exe pickup in the dream.
@export var exe_pickup: Node
@export var hint_hold: float = 5.0

var _hint: Label


func _ready() -> void:
	if exe_pickup and exe_pickup.has_signal(&"collected"):
		exe_pickup.collected.connect(_on_exe_collected)
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


func _on_exe_collected() -> void:
	# The pickup adds the file right after this signal; wait a frame so it's there.
	await get_tree().process_frame
	var file_id: String = exe_pickup.get(&"file_id")
	var file = FileManager.collected_files.get(file_id)
	var file_name: String = file.filename if file else file_id
	# Through MetaOS, the team's pop-up system.
	await MetaOS.show_dialog("Obtained", file_name, ["CLOSE"], "txt")
	await get_tree().create_timer(0.8).timeout
	# Placeholder until the maze can hand back: straight to the machine's voice.
	DreamMeadow.resume_at_awakening = true
	GameManager.load_next_level(MEADOW)
