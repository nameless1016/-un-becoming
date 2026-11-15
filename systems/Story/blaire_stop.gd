class_name BlaireStop
extends Marker2D
## One place where Blaire waits for the ghost on a BlaireRoute. Put it where she stands.

## The step the story moves to when the ghost catches up with her here
## (one of StoryProgress's steps, e.g. a1_living_room).
@export var step: StringName
## Dialogic timeline she says when the ghost catches up. Empty: she just moves on.
@export var timeline: String = ""
## Which way she faces while she waits.
@export var facing: Vector2 = Vector2.DOWN
## How close the ghost has to come, in pixels.
@export var notice_radius: float = 48.0
