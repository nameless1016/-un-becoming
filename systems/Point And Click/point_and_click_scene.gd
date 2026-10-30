class_name PointAndClickScene
extends Node2D
## Base for the first-person close-up stations (Computer, Calendar, TV, ...).
##
## Make a station with Scene > New Inherited Scene from
## res://systems/Point And Click/point_and_click_scene.tscn, set the
## Background texture, and instance hotspot.tscn under Hotspots. Clicking a
## hotspot plays its Dialogic timeline; override [method _handle_hotspot] in
## a station script for anything else (e.g. opening a file).
##
## Hotspot positions are in the game's 640x360 viewport (the Background
## rect), so keep them inside it. Esc is left to the pause menu; Back leaves.
##
## Stills are illustrated, not pixel art: draw them at 1920x1080. Background
## uses smooth (linear) filtering, unlike the project's pixel-art default, so
## the full detail shows at the window's real resolution. A point in the
## 1920x1080 art is at (x / 3, y / 3) in hotspot coordinates.

signal hotspot_activated(hotspot: Hotspot)
signal dialogue_started(timeline: String)
signal dialogue_ended(timeline: String)
signal exit_requested

## Locks are released this long after they're let go, so the click that closes
## the last line of dialogue (or a window) doesn't also land on a hotspot underneath.
const INPUT_COOLDOWN := 0.15
const DIALOGUE_LOCK := &"dialogue"

## Scene to go to when the player leaves (the top-down view). Leave empty to go
## back to the room the still was opened from (see StillPoint); if there isn't
## one, Back only emits [signal exit_requested].
@export_file("*.tscn") var exit_scene: String = ""

## Set by StillPoint when it opens a still: the room to return to, and where the
## player stood and faced. StillPoint puts the player back when that room loads.
static var return_scene: String = ""
static var return_position: Variant = null
static var return_facing: Vector2 = Vector2.ZERO

## True while anything holds an input lock: dialogue, an open window, or the
## short cooldown after either.
var is_busy: bool:
	get:
		return not _locks.is_empty()

var _hotspots: Array[Hotspot] = []
var _current_timeline: String = ""
# Lock reason (StringName) -> true. Named so dialogue and overlays can overlap.
var _locks: Dictionary = {}
var _applied_busy: bool = false

@onready var background: TextureRect = $Background
@onready var hotspots_root: Node2D = $Hotspots
@onready var dialogue_layer: CanvasLayer = $DialogueLayer
@onready var exit_button: Button = $ExitButton


func _ready() -> void:
	var viewport := get_viewport()
	viewport.physics_object_picking = true
	# With overlapping hotspots, only the top-most one gets hover and clicks.
	viewport.physics_object_picking_sort = true
	viewport.physics_object_picking_first_only = true

	for node in hotspots_root.find_children("*", "Area2D", true, false):
		if node is Hotspot:
			register_hotspot(node)

	exit_button.pressed.connect(request_exit)
	exit_button.mouse_entered.connect(_on_exit_button_hovered)
	exit_button.mouse_exited.connect(CursorManager.pop_hover.bind(exit_button))


func _exit_tree() -> void:
	# Leaving mid-dialogue: stop Dialogic so it doesn't keep running headless.
	var dialogic := _get_dialogic()
	if dialogic and not _current_timeline.is_empty():
		if dialogic.timeline_ended.is_connected(_on_timeline_ended):
			dialogic.timeline_ended.disconnect(_on_timeline_ended)
		dialogic.end_timeline(true)
	CursorManager.clear_hover()


## Hotspots under the Hotspots node are registered automatically; call this
## for ones added at runtime.
func register_hotspot(hotspot: Hotspot) -> void:
	if hotspot in _hotspots:
		return
	_hotspots.append(hotspot)
	hotspot.activated.connect(_on_hotspot_activated)
	hotspot.tree_exited.connect(func() -> void: _hotspots.erase(hotspot))
	hotspot.locked = is_busy


func get_hotspots() -> Array[Hotspot]:
	return _hotspots


## Locks hotspots and the Back button until every lock is released.
## Use a [param reason] per source (dialogue, a window, ...) so they can overlap.
func lock_input(reason: StringName) -> void:
	_locks[reason] = true
	_apply_locks()


## Releases [param reason] after [param delay] seconds (see [constant INPUT_COOLDOWN]).
func unlock_input(reason: StringName, delay: float = INPUT_COOLDOWN) -> void:
	if delay <= 0.0:
		_release_lock(reason)
	else:
		# A connection (not await) so nothing resumes if this scene is freed first.
		get_tree().create_timer(delay).timeout.connect(_release_lock.bind(reason))


## Plays a Dialogic timeline (identifier or res:// path) inside DialogueLayer,
## locking input until it ends. Returns false (and plays nothing) if the scene
## is busy or the timeline can't be found; otherwise await [signal dialogue_ended].
func play_dialogue(timeline: String) -> bool:
	if is_busy or timeline.is_empty():
		return false
	var dialogic := _get_dialogic()
	if dialogic == null:
		push_warning("Dialogic 2 isn't installed or enabled; skipping timeline '%s'." % timeline)
		return false

	# Checked up front: Dialogic only logs a bad name and never emits timeline_ended,
	# which would leave this scene locked.
	if not dialogic.timeline_exists(timeline):
		push_warning("Dialogic has no timeline '%s'. Use its file name or a res:// path; names refresh when you press Play in the editor." % timeline)
		return false

	lock_input(DIALOGUE_LOCK)
	_current_timeline = timeline
	dialogue_started.emit(timeline)
	dialogic.timeline_ended.connect(_on_timeline_ended, CONNECT_ONE_SHOT)

	# Dialogic adds its layout to the scene root unless one already exists.
	# Loading it ourselves puts it in DialogueLayer, so it's freed with this scene.
	if not dialogic.Styles.has_active_layout_node():
		dialogic.Styles.load_style("", dialogue_layer)
	# The layout is added deferred, so the timeline actually starts next frame.
	dialogic.start(timeline)
	return true


func request_exit() -> void:
	exit_requested.emit()
	var target := exit_scene if not exit_scene.is_empty() else return_scene
	if not target.is_empty():
		# The template's transition + threaded loading, same as every other level change.
		GameManager.load_next_level(target)


## What a hotspot click does. The default plays its dialogue_timeline.
## Override in a station script for other behaviour (and call super to keep the dialogue).
func _handle_hotspot(hotspot: Hotspot) -> void:
	play_dialogue(hotspot.dialogue_timeline)


func _on_hotspot_activated(hotspot: Hotspot) -> void:
	if is_busy:
		return
	hotspot_activated.emit(hotspot)
	_handle_hotspot(hotspot)


func _on_exit_button_hovered() -> void:
	if not is_busy:
		CursorManager.push_hover(exit_button, CursorManager.Mode.EXIT, "")


func _on_timeline_ended() -> void:
	var timeline := _current_timeline
	_current_timeline = ""
	dialogue_ended.emit(timeline)
	unlock_input(DIALOGUE_LOCK)


func _release_lock(reason: StringName) -> void:
	_locks.erase(reason)
	_apply_locks()


func _apply_locks() -> void:
	var busy := is_busy
	if busy == _applied_busy:
		return
	_applied_busy = busy
	exit_button.disabled = busy
	for hotspot in _hotspots:
		hotspot.locked = busy
	# Only on the way in, so hovers inside an open window aren't wiped.
	if busy:
		CursorManager.clear_hover()


func _get_dialogic() -> Node:
	# Looked up by path so this script still loads before the plugin is installed.
	return get_node_or_null(^"/root/Dialogic")
