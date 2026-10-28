extends Npc
class_name ApproachNpc

## An NPC that notices the player, shows an alert cue, walks up to them, and starts dialogue automatically.
##
## Freezes the player in place while noticing and approaching. Once the NPC arrives within
## stop distance, dialogue initiates via Dialogic or generated lines, releasing the player
## when the conversation finishes. Manual interaction remains available when not approaching.

## Emitted when the NPC spots the player and begins the approach sequence.
signal approach_started
## Emitted when the NPC reaches the player within stop distance.
signal approach_arrived

## Discrete lifecycle states for the approach sequence.
enum ApproachState {
	WAITING,
	NOTICING,
	APPROACHING,
	TALKING,
	DONE
}

@export_group("Approach")
## Distance in pixels at which the NPC spots the player and starts the approach sequence.
@export var notice_radius: float = 450.0
## Walking speed in pixels per second during the approach.
@export var approach_speed: float = 300.0
## Proximity threshold (center to center) where the NPC stops walking and prepares to talk.
@export var stop_distance: float = 150.0
## Pause in seconds between arriving at the player and opening dialogue.
@export var talk_delay: float = 0.25
## When true, triggers only once. When false, re-arms after the player exits notice_radius.
@export var trigger_once: bool = true

@export_group("Notice Cue")
## Enables the pop-in alert cue above the NPC upon detection.
@export var show_notice_cue: bool = true
## Duration in seconds the NPC remains stationary showing the cue before walking.
@export var notice_pause: float = 0.5

const CUE_TAIL := 0.3
const CUE_HEIGHT := 60.0

var bar_shape := PackedVector2Array([Vector2(-11, -28), Vector2(11, -28), Vector2(6, 12), Vector2(-6, 12)])
var bar_outline_shape := PackedVector2Array([Vector2(-16, -33), Vector2(16, -33), Vector2(11, 17), Vector2(-11, 17)])

var state: ApproachState = ApproachState.WAITING
var target: Node2D
var player_frozen: bool = false
var cue_active: bool = false
var cue_time: float = 0.0


func _ready() -> void:
	super()
	if Engine.is_editor_hint():
		set_physics_process(false)
		return
	dialogue_finished.connect(_on_approach_dialogue_finished)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	if cue_active:
		cue_time += delta
		if cue_time >= notice_pause + CUE_TAIL:
			cue_active = false
		queue_redraw()

	match state:
		ApproachState.WAITING:
			_process_waiting()
		ApproachState.NOTICING:
			_process_noticing()
		ApproachState.APPROACHING:
			_process_approaching(delta)
		ApproachState.DONE:
			_process_done()


## Scans for the player node within notice radius while in the waiting state.
func _process_waiting() -> void:
	if not can_interact or is_dialogue_running():
		return
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if p == null:
		return
	if global_position.distance_to(p.global_position) <= notice_radius:
		target = p
		begin_approach()


## Manages the alert pause duration before the NPC begins walking.
func _process_noticing() -> void:
	if target == null or not is_instance_valid(target):
		cancel_approach()
		return
	if cue_time >= notice_pause or not show_notice_cue:
		state = ApproachState.APPROACHING


## Interpolates position toward the player until stop distance is satisfied.
func _process_approaching(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		cancel_approach()
		return
	var to_player := target.global_position - global_position
	if to_player.length() <= stop_distance:
		arrive()
		return
	global_position += to_player.normalized() * approach_speed * delta


## Handles re-arming logic once the player moves beyond notice radius.
func _process_done() -> void:
	if trigger_once:
		return
	var p := get_tree().get_first_node_in_group("player") as Node2D
	if p != null and global_position.distance_to(p.global_position) > notice_radius:
		state = ApproachState.WAITING


## Initiates the approach sequence, freezes the player, and activates the alert cue.
func begin_approach() -> void:
	state = ApproachState.NOTICING
	freeze_player(true)
	cue_time = 0.0
	cue_active = show_notice_cue
	queue_redraw()
	approach_started.emit()


## Transitions to the talking state, applies talk delay, and launches dialogue.
func arrive() -> void:
	state = ApproachState.TALKING
	approach_arrived.emit()
	if talk_delay > 0.0:
		await get_tree().create_timer(talk_delay).timeout
	if state != ApproachState.TALKING:
		return
	if not start_dialogue(get_timeline(), pause_world):
		finish_approach()


## Aborts an active approach sequence and restores player controls.
func cancel_approach() -> void:
	freeze_player(false)
	target = null
	cue_active = false
	state = ApproachState.WAITING
	queue_redraw()


## Concludes the approach sequence, unlocks the player, and transitions to done.
func finish_approach() -> void:
	freeze_player(false)
	state = ApproachState.DONE


func _on_approach_dialogue_finished() -> void:
	if state == ApproachState.TALKING:
		finish_approach()


## Overrides base interaction to prevent manual triggering during active approaches.
func interact(who: Node2D) -> void:
	if state != ApproachState.WAITING and state != ApproachState.DONE:
		return
	super(who)


## Toggles player movement and FSM processing states.
func freeze_player(on: bool) -> void:
	if target == null or not is_instance_valid(target) or player_frozen == on:
		return
	player_frozen = on
	var fsm := target.get_node_or_null("FSM")
	if on:
		if target is CharacterBody2D:
			(target as CharacterBody2D).velocity = Vector2.ZERO
		if fsm != null:
			fsm.process_mode = Node.PROCESS_MODE_DISABLED
		target.set_physics_process(false)
	else:
		if fsm != null:
			fsm.process_mode = Node.PROCESS_MODE_INHERIT
		target.set_physics_process(true)


func _exit_tree() -> void:
	if player_frozen:
		freeze_player(false)
	super()

#region Visuals

func _draw() -> void:
	super()
	draw_notice_cue()


## Overrides prompt drawing to hide the interact key while approaching or noticing.
func draw_prompt() -> void:
	if state != ApproachState.WAITING and state != ApproachState.DONE:
		return
	super()


## Draws the animated alert exclamation mark with elastic scaling, hopping, and fading.
func draw_notice_cue() -> void:
	if not cue_active:
		return
	var t := cue_time
	var life := notice_pause + CUE_TAIL

	var s := 1.0
	if t < 0.12:
		s = lerpf(0.0, 1.3, t / 0.12)
	elif t < 0.22:
		s = lerpf(1.3, 1.0, (t - 0.12) / 0.10)

	var hop := -absf(sin(t * 9.0)) * 8.0 * (1.0 - clampf(t / life, 0.0, 1.0))
	var alpha := clampf((life - t) / 0.15, 0.0, 1.0)

	var base := Vector2(0.0, -body_size.y * 0.5 - CUE_HEIGHT + hop)
	draw_set_transform(base, 0.0, Vector2(s, s))
	var white := Color(1.0, 1.0, 1.0, alpha)
	var black := Color(0.0, 0.0, 0.0, alpha)
	draw_colored_polygon(bar_outline_shape, white)
	draw_circle(Vector2(0.0, 28.0), 13.0, white)
	draw_colored_polygon(bar_shape, black)
	draw_circle(Vector2(0.0, 28.0), 8.0, black)
	draw_set_transform(Vector2.ZERO)

#endregion
