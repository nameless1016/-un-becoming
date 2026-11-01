extends State
class_name PlayerScripted_TopDown

## The player moves on its own and the keyboard does nothing. Build a list of
## steps, call play() with it, and the player goes back to Idle when they're done.
##
## var s = player.get_node("FSM/Scripted")
## s.play([s.walk_to(Vector2(300, 190)), s.wait(0.5), s.face(Vector2.UP)])

signal finished

## 0 uses the player's MAX_SPEED
@export var speed: float = 0.0
## If the player can't get anywhere for this long (something in the way), that step is skipped
@export var stuck_limit: float = 0.5

var steps: Array = []
var step_index: int = 0
var step_time: float = 0.0
var stuck_time: float = 0.0
var return_to: String = "Idle"
var current_step: Dictionary = {}

# these make the steps
func walk_to(target: Vector2) -> Dictionary:
	return {"type": "walk_to", "target": target}

func walk_by(offset: Vector2) -> Dictionary:
	return {"type": "walk_by", "offset": offset}

func wait(seconds: float) -> Dictionary:
	return {"type": "wait", "seconds": seconds}

func face(direction: Vector2) -> Dictionary:
	return {"type": "face", "direction": direction}

# runs any function in the middle of the steps
func do(callback: Callable) -> Dictionary:
	return {"type": "do", "callback": callback}

# starts the steps, the player stops listening to the keyboard until they're done
func play(new_steps: Array, state_after: String = "Idle") -> void:
	steps = new_steps
	return_to = state_after
	var fsm := PLAYER.get_node_or_null("FSM")
	if fsm == null:
		push_warning("couldn't find the player's FSM, can't start the scripted movement")
		return
	if fsm.get("cur_state") == self:
		begin()
	else:
		fsm.force_change_state(String(name))

func is_playing() -> bool:
	return step_index < steps.size()

func enterState():
	begin()

func updateState(delta: float):
	if step_index >= steps.size():
		finish()
		return
	match current_step.get("type", ""):
		"walk_to", "walk_by":
			walk_toward(current_step["target"], delta)
		"wait":
			stand_still()
			step_time += delta
			if step_time >= current_step["seconds"]:
				next_step()
		"face":
			stand_still()
			PLAYER.CUR_DIR = current_step["direction"]
			PLAYER.sprite.play("idle_" + PLAYER.get_facing_string())
			next_step()
		"do":
			current_step["callback"].call()
			next_step()
		_:
			next_step()

func begin() -> void:
	step_index = -1
	next_step()

func next_step() -> void:
	step_index += 1
	step_time = 0.0
	stuck_time = 0.0
	if step_index >= steps.size():
		return
	current_step = steps[step_index].duplicate()
	# walk_by needs to know where we are right when its turn starts
	if current_step.get("type", "") == "walk_by":
		current_step["target"] = PLAYER.global_position + current_step["offset"]

# the player stops dead when leaving this state
func exitState():
	PLAYER.velocity = Vector2.ZERO

func finish() -> void:
	steps = []
	step_index = 0
	PLAYER.velocity = Vector2.ZERO
	PLAYER.sprite.play("idle_" + PLAYER.get_facing_string())
	finished.emit()
	transition.emit(self, return_to)

func stand_still() -> void:
	PLAYER.velocity = Vector2.ZERO
	PLAYER.sprite.play("idle_" + PLAYER.get_facing_string())

func walk_toward(target: Vector2, delta: float) -> void:
	var move_speed: float = speed if speed > 0.0 else PLAYER.MAX_SPEED
	var to_target: Vector2 = target - PLAYER.global_position
	# close enough, so stop here and go to the next step
	if to_target.length() <= maxf(1.0, move_speed * delta):
		PLAYER.global_position = target
		PLAYER.velocity = Vector2.ZERO
		next_step()
		return
	var direction := to_target.normalized()
	PLAYER.CUR_DIR = direction
	PLAYER.velocity = direction * move_speed
	PLAYER.sprite.play("walk_" + PLAYER.get_facing_string())
	var before: Vector2 = PLAYER.global_position
	PLAYER.move_and_slide()
	# if something is in the way, skip the step instead of hanging forever
	if PLAYER.global_position.distance_to(before) < move_speed * delta * 0.1:
		stuck_time += delta
		if stuck_time >= stuck_limit:
			push_warning("scripted movement got stuck, skipping a step")
			PLAYER.velocity = Vector2.ZERO
			next_step()
	else:
		stuck_time = 0.0
