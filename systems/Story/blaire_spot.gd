class_name BlaireSpot
extends Marker2D
## A place where Blaire simply is for a part of the story (her seat on the bus, say).
## Put the marker where she stands. For a room she walks through, use BlaireRoute.

## She's here once the story has reached this step...
@export var from_step: StringName = StoryProgress.A1_OUTSIDE
## ...and gone again once it reaches this one. Empty: she stays.
@export var until_step: StringName
## The story moves to this step when the player comes into the room while she's
## here. Empty: the story stays where it is.
@export var arrive_step: StringName
## Which way she faces.
@export var facing: Vector2 = Vector2.DOWN


func _ready() -> void:
	if not StoryProgress.reached(from_step):
		return
	if until_step != &"" and StoryProgress.reached(until_step):
		return
	if arrive_step != &"" and StoryProgress.advance_to(arrive_step):
		# Deferred: saved once the room has finished loading.
		SaveManager.save_game.call_deferred()
	var blaire := BlaireNpc.new()
	blaire.name = "Blaire"
	blaire.position = position
	blaire.z_index = z_index
	blaire.face(facing)
	get_parent().add_child.call_deferred(blaire)
