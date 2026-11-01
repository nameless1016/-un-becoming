extends Node2D
## Act 0: a glimpse of the bad ending. Blaire's monologue (a0_blaire_burning)
## plays over the burning house, the close-ups push in on her face, then the
## game "errors" and the voice asks the player for help.
##
## After the player answers YES, a white flash cuts to [member next_scene] (the dream).
##
## The shots are cued from the timeline with Dialogic signals:
## fx:burning_start (fire sound + wide shot), fx:shot_face, fx:shot_closer
## (each one pushes the close-up in a step) and fx:glitch_start.
##
## All art here is placeholder: the house is the Home layout and the face is a
## crop of the character concept sheet. Swap the textures when the real
## illustrations exist; the shots and timing stay the same.

signal finished

const MONOLOGUE := "a0_blaire_burning"
## Picked by [member resets]: first time, then after the player has reset once.
const HELP_TIMELINES: Array[String] = ["a0_ghost_help", "a0_ghost_help_again"]
## Scale of the face for each close-up step: the face shot, then each fx:shot_closer.
## The first step is the smallest that still fills the screen with the crop.
const FACE_STEPS: Array[float] = [1.12, 1.5, 2.0, 2.7]
const FIRE_VOLUME_DB := -4.0
## Saved flag the main menu checks, so Start only plays Act 0 until it's been seen.
const SEEN_FLAG := "act_0_seen"
## Placeholder error messages shown between the cutscene and the voice.
const ERRORS: Array[Array] = [
	["FATAL ERROR", "The memory at 0x00000000 could not be read."],
	["FATAL ERROR", "blaire.exe has stopped responding."],
]

## Where the flash cuts to when Act 0 ends (Act 1's dream). Empty: start a new
## game through SaveManager instead, with the usual transition.
@export_file("*.tscn") var next_scene: String = ""
## How many times the player has reset the loop. Until the save system tracks it,
## set it here to preview the second variant of the voice's lines.
@export var resets: int = 0

var _face_step: int = 0

@onready var _wide: CanvasItem = $WideShot
@onready var _face_shot: CanvasItem = $FaceShot
@onready var _face: Sprite2D = $FaceShot/Face
@onready var _fire: AudioStreamPlayer = $FireLoop
@onready var _glitch: ColorRect = $GlitchLayer/Glitch
@onready var _flash: ColorRect = $GlitchLayer/Flash
@onready var _dialogue_layer: CanvasLayer = $DialogueLayer


func _ready() -> void:
	_wide.modulate.a = 0.0
	_face_shot.modulate.a = 0.0
	_face_shot.visible = false
	_set_glitch(0.0)
	_flash.modulate.a = 0.0
	# The menu's music would otherwise carry on under the fire.
	MusicManager.stop_music(1.5)
	var stream := _fire.stream.duplicate() as AudioStreamMP3
	if stream:
		stream.loop = true
		_fire.stream = stream
	Dialogic.signal_event.connect(_on_dialogic_signal)
	_run.call_deferred()


func _exit_tree() -> void:
	if Dialogic.signal_event.is_connected(_on_dialogic_signal):
		Dialogic.signal_event.disconnect(_on_dialogic_signal)
	if Dialogic.current_timeline != null:
		Dialogic.end_timeline(true)


func _run() -> void:
	# A moment of black before anything happens.
	await _wait(1.0)
	await _play(MONOLOGUE)
	await _break_down()
	await _play(HELP_TIMELINES[mini(resets, HELP_TIMELINES.size() - 1)])
	await DesktopPopup.ask(self, "Info", "Please help me.", ["YES", "YES"])
	SaveManager.set_flag(SEEN_FLAG)
	finished.emit()
	if next_scene.is_empty():
		SaveManager.new_game()
		return
	# Flashbang: snap to white, hold, then a hard cut. The dream fades in from the same white.
	await create_tween().tween_property(_flash, ^"modulate:a", 1.0, 0.08).finished
	await _wait(0.5)
	get_tree().change_scene_to_file(next_scene)


func _play(timeline: String) -> void:
	if not Dialogic.timeline_exists(timeline):
		push_warning("Act 0: no timeline '%s'." % timeline)
		return
	# In our own layer (like the stills) so the box is freed with this scene.
	if not Dialogic.Styles.has_active_layout_node():
		Dialogic.Styles.load_style("", _dialogue_layer)
	Dialogic.start(timeline)
	await Dialogic.timeline_ended


func _on_dialogic_signal(argument: Variant) -> void:
	match str(argument):
		"fx:burning_start":
			_fire.volume_db = -40.0
			_fire.play()
			create_tween().tween_property(_fire, ^"volume_db", FIRE_VOLUME_DB, 2.5)
			create_tween().tween_property(_wide, ^"modulate:a", 1.0, 3.0)
		"fx:shot_face":
			_face_step = 0
			_face.scale = Vector2.ONE * FACE_STEPS[0]
			_face_shot.visible = true
			var tween := create_tween().set_parallel()
			tween.tween_property(_face_shot, ^"modulate:a", 1.0, 1.2)
			tween.tween_property(_wide, ^"modulate:a", 0.0, 1.2)
		"fx:shot_closer":
			_face_step = mini(_face_step + 1, FACE_STEPS.size() - 1)
			create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT) \
				.tween_property(_face, ^"scale", Vector2.ONE * FACE_STEPS[_face_step], 0.9)
		"fx:glitch_start":
			create_tween().tween_method(_set_glitch, 0.0, 0.35, 1.5)


## The cutscene tears apart: full glitch, the fire cuts out, black, then error pop-ups.
func _break_down() -> void:
	await create_tween().tween_method(_set_glitch, 0.35, 1.0, 0.4).finished
	await _wait(0.3)
	_fire.stop()
	_wide.visible = false
	_face_shot.visible = false
	_set_glitch(0.0)
	await _wait(1.2)
	for error in ERRORS:
		SoundBank.play_sfx("ui_error", Vector2.ZERO, 1.0, 1.0)
		await DesktopPopup.ask(self, error[0], error[1], ["OK"], "", false)
		await _wait(0.3)
	await _wait(0.8)


func _set_glitch(value: float) -> void:
	_glitch.visible = value > 0.0
	(_glitch.material as ShaderMaterial).set_shader_parameter(&"amount", value)


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
