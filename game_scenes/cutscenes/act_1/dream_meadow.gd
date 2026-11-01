extends Node2D
## Act 1's opening, for now: the dream meadow right after Act 0's flash.
##
## Fades in from the flash's white and plays the machine's voice (a1_dream_awakening).
## The meadow then melts into a blurry view of Blaire's bedroom (she's surfacing),
## "W A K E  U P" breaks in as an error pop-up, her eyes blink open on the room,
## she says her wake-up monologue, and the game moves to the top-down bedroom.
## The full dream (exploring, the files, the maze, finding the machine) isn't
## built yet; this is the part that runs without it.
##
## The meadow is placeholder art; swap the Background texture for the final
## illustration (Planescape on the drive). The bedroom view is the bedroom still's layout.

const TIMELINE := "a1_dream_awakening"
const WAKE_MONOLOGUE := "a1_blaire_wake_up"
## Per the brief this is an error message, not a line of dialogue.
const WAKE_UP := "W A K E  U P"
const GLITCH_WHILE_TALKING := 0.12
## The bedroom while she's still half asleep: dim and out of focus.
const DROWSY_TINT := Color(0.5, 0.5, 0.58)
## Size of the out-of-focus copy; stretched back to full screen it reads as blur.
const BLUR_SIZE := Vector2i(160, 90)

@export_file("*.tscn") var next_scene: String = "res://game_scenes/worlds/apartment/room/room_blaire.tscn"

@onready var _background: TextureRect = $Background
@onready var _petals: CanvasItem = $Petals
@onready var _bedroom: Node2D = $Bedroom
@onready var _bedroom_blurred: TextureRect = $Bedroom/Blurred
@onready var _bedroom_sharp: TextureRect = $Bedroom/Sharp
@onready var _lid_top: ColorRect = $OverLayer/LidTop
@onready var _lid_bottom: ColorRect = $OverLayer/LidBottom
@onready var _glitch: ColorRect = $OverLayer/Glitch
@onready var _flash: ColorRect = $OverLayer/Flash
@onready var _dialogue_layer: CanvasLayer = $DialogueLayer


func _ready() -> void:
	_set_glitch(0.0)
	_bedroom_blurred.texture = _make_blurred(_bedroom_sharp.texture)
	Dialogic.signal_event.connect(_on_dialogic_signal)
	MusicManager.change_music("dream", 2.0)
	# A slow sway so the still feels like a place, not a picture.
	var drift := create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	drift.tween_property(_background, ^"position:x", -12.0, 9.0)
	drift.tween_property(_background, ^"position:x", 12.0, 9.0)
	_run.call_deferred()


func _exit_tree() -> void:
	if Dialogic.signal_event.is_connected(_on_dialogic_signal):
		Dialogic.signal_event.disconnect(_on_dialogic_signal)
	if Dialogic.current_timeline != null:
		Dialogic.end_timeline(true)


func _run() -> void:
	# The white from Act 0's flash clears slowly, like eyes adjusting.
	await create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC) \
		.tween_property(_flash, ^"modulate:a", 0.0, 2.5).finished
	await _wait(1.5)
	await _play(TIMELINE)

	# The dream melts into her bedroom: she's surfacing, not awake yet.
	MusicManager.stop_music(3.0)
	var melt := create_tween().set_parallel()
	melt.tween_property(_bedroom, ^"modulate", DROWSY_TINT, 3.0)
	melt.tween_property(_petals, ^"modulate:a", 0.0, 2.0)
	melt.tween_method(_set_glitch, GLITCH_WHILE_TALKING, 0.0, 1.5)
	await melt.finished
	await _wait(0.8)

	# The error breaks in.
	_set_glitch(1.0)
	SoundBank.play_sfx("ui_error", Vector2.ZERO, 1.0, 1.0)
	await DesktopPopup.ask(self, "ERROR", WAKE_UP, ["OK"], "", false)

	# Eyes shut... then they open on the room: a crack, a blink, then wide, coming into focus.
	_set_glitch(0.0)
	_set_eyes(0.0)
	_lid_top.visible = true
	_lid_bottom.visible = true
	await _wait(1.0)
	await _tween_eyes(0.0, 0.3, 0.5)
	await _tween_eyes(0.3, 0.0, 0.18)
	await _wait(0.3)
	var focus := create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	focus.tween_method(_set_eyes, 0.0, 1.0, 1.4)
	focus.tween_property(_bedroom_sharp, ^"modulate:a", 1.0, 2.2)
	focus.tween_property(_bedroom, ^"modulate", Color.WHITE, 2.2)
	await focus.finished
	await _wait(0.6)

	await _play(WAKE_MONOLOGUE)
	# She gets up: over to the top-down room, with the usual transition.
	GameManager.load_next_level(next_scene)


func _play(timeline: String) -> void:
	if not Dialogic.timeline_exists(timeline):
		push_warning("Dream: no timeline '%s'." % timeline)
		return
	if not Dialogic.Styles.has_active_layout_node():
		Dialogic.Styles.load_style("", _dialogue_layer)
	Dialogic.start(timeline)
	await Dialogic.timeline_ended


func _on_dialogic_signal(argument: Variant) -> void:
	if str(argument) == "fx:glitch_start":
		create_tween().tween_method(_set_glitch, 0.0, GLITCH_WHILE_TALKING, 1.0)


## 0 = eyes shut (both lids meet in the middle), 1 = wide open.
func _set_eyes(open: float) -> void:
	_lid_top.position.y = -180.0 * open
	_lid_bottom.position.y = 180.0 + 180.0 * open


func _tween_eyes(from: float, to: float, seconds: float) -> void:
	await create_tween().set_trans(Tween.TRANS_SINE).tween_method(_set_eyes, from, to, seconds).finished


## A small copy of [param texture]: shown stretched to the screen, it's soft and out of focus.
func _make_blurred(texture: Texture2D) -> Texture2D:
	var image := texture.get_image()
	if image == null:
		return texture
	if image.is_compressed():
		image.decompress()
	# Averaging through mipmaps keeps thin lines as a soft smudge instead of dropping them.
	if not image.has_mipmaps():
		image.generate_mipmaps()
	image.resize(BLUR_SIZE.x, BLUR_SIZE.y, Image.INTERPOLATE_TRILINEAR)
	return ImageTexture.create_from_image(image)


func _set_glitch(value: float) -> void:
	_glitch.visible = value > 0.0
	(_glitch.material as ShaderMaterial).set_shader_parameter(&"amount", value)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
