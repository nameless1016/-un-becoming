@tool
class_name StillPoint
extends PointAndClickTrigger
## A point of interest in a top-down room that opens a point-and-click still.
##
## Compared to the plain PointAndClickTrigger it:
## - works with any player in the "player" group (PlayerBlaire as well as PlayerTopDown),
## - is drawn at the room's pixel scale: a small "E" key cap, no grey box,
## - remembers where the player stood, so the still's Back button returns them there.
## Set [member body_size] to the furniture's footprint and [member interact_radius] to
## how close the player must stand.

const KEY_FONT := preload("res://game_assets/fonts/Space Mono/SpaceMono-Bold.ttf")
const LABEL_FONT := preload("res://game_assets/fonts/Space Mono/SpaceMono-Regular.ttf")

## Draws a labelled outline where furniture art doesn't exist yet. Turn off once it does.
@export var show_placeholder: bool = true:
	set(value):
		show_placeholder = value
		queue_redraw()


func _init() -> void:
	# Defaults for 16 px tiles and 32 px characters; scenes can still override them.
	interact_radius = 26.0
	body_size = Vector2(32, 32)
	solid = false
	glow_enabled = false


func _ready() -> void:
	super()
	if not Engine.is_editor_hint():
		_place_returning_player.call_deferred()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player = body
		player_near = true
		queue_redraw()


func _on_interact(who: Node2D) -> void:
	if station_scene == "":
		push_warning("%s has no station_scene set" % name)
		return
	PointAndClickScene.return_scene = get_tree().current_scene.scene_file_path
	PointAndClickScene.return_position = who.global_position
	PointAndClickScene.return_facing = who.get(&"CUR_DIR") if &"CUR_DIR" in who else Vector2.ZERO
	GameManager.load_next_level(station_scene)


## Coming back from a still: put the player where they stood when they opened it.
## The first StillPoint in the room that runs this does it, then clears the record.
func _place_returning_player() -> void:
	if PointAndClickScene.return_position == null:
		return
	var scene := get_tree().current_scene
	if scene == null or scene.scene_file_path != PointAndClickScene.return_scene:
		return
	var who := get_tree().get_first_node_in_group(&"player") as Node2D
	if who == null:
		return
	who.global_position = PointAndClickScene.return_position
	if PointAndClickScene.return_facing != Vector2.ZERO and &"CUR_DIR" in who:
		who.set(&"CUR_DIR", PointAndClickScene.return_facing)
	PointAndClickScene.return_position = null


func draw_body() -> void:
	if not show_placeholder:
		return
	var rect := Rect2(-body_size * 0.5, body_size)
	draw_rect(rect, Color(0, 0, 0, 0.06))
	draw_rect(rect, Color(0, 0, 0, 0.45), false, 1.0)
	var text := display_name if display_name != "" else String(name)
	draw_string(LABEL_FONT, rect.position + Vector2(0, -2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 6, Color(0, 0, 0, 0.6))


func draw_prompt() -> void:
	if not player_near or not can_interact or bubble_text != "":
		return
	# A small black key cap with a white border, matching the menu's style.
	var key := Rect2(Vector2(-5, -body_size.y * 0.5 - 14), Vector2(10, 11))
	draw_rect(key, Color.BLACK)
	draw_rect(key, Color.WHITE, false, 1.0)
	draw_string(KEY_FONT, key.position + Vector2(0, 8.5), prompt_text, HORIZONTAL_ALIGNMENT_CENTER, key.size.x, 7, Color.WHITE)
