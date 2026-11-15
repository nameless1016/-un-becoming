class_name StoryProgress
extends RefCounted
## Where the story is. The story is a list of steps in order ([constant ORDER]); the
## current one is kept in the save (SaveManager's flags), so it comes back on Continue.
##
## Scenes move the story forward and ask where it is:
## [codeblock]
## StoryProgress.advance_to(StoryProgress.A1_LIVING_ROOM)   # forward only
## if StoryProgress.reached(StoryProgress.A1_BEDROOM): ...  # at that step or past it
## StoryProgress.on_change(_on_story_step)                  # called with the new step
## [/codeblock]
## Nothing here writes the save file: call SaveManager.save_game() at a checkpoint.
##
## To add a step: add a constant and put it in ORDER where it happens. Names start
## with the act ("a1_..."), which is where [method act] reads the act number from.

const FLAG := "story_step"
## Saves from before this existed only have this flag, set when the ghost took over.
const OLD_INTRO_FLAG := "intro_seen"

## Act 0: Blaire's monologue over the burning house, the errors, "Please help me."
const A0_BURNING := &"a0_burning"
## Act 1: the dream meadow's intro dialogue.
const A1_DREAM_INTRO := &"a1_dream_intro"
## The top-down dream area: the tutorial, indoctrination.exe and RJ's maze.
const A1_DREAM_AREA := &"a1_dream_area"
## Back from the maze: the machine's voice.
const A1_DREAM_VOICE := &"a1_dream_voice"
## The WAKE UP error, her eyes opening, the wake-up monologue.
const A1_WAKE_UP := &"a1_wake_up"
## Blaire has left her room and the player is the ghost. The intro is over.
const A1_BEDROOM := &"a1_bedroom"
## Blaire's morning, one area at a time (nothing moves the story to these yet).
const A1_LIVING_ROOM := &"a1_living_room"
const A1_DINING_ROOM := &"a1_dining_room"
const A1_OUTSIDE := &"a1_outside"
const A1_BUS := &"a1_bus"
## Act 2: the bus driver has taken the ghost to school.
const A2_SCHOOL := &"a2_school"

const ORDER: Array[StringName] = [
	A0_BURNING,
	A1_DREAM_INTRO,
	A1_DREAM_AREA,
	A1_DREAM_VOICE,
	A1_WAKE_UP,
	A1_BEDROOM,
	A1_LIVING_ROOM,
	A1_DINING_ROOM,
	A1_OUTSIDE,
	A1_BUS,
	A2_SCHOOL,
]

static var _listeners: Array[Callable] = []


## The step the story is at. A game that hasn't started is at the first step.
static func current() -> StringName:
	var saved := StringName(str(SaveManager.get_flag(FLAG, "")))
	if ORDER.has(saved):
		return saved
	if SaveManager.get_flag(OLD_INTRO_FLAG):
		return A1_BEDROOM
	return ORDER[0]


## The act the current step belongs to: 0, 1, 2...
static func act() -> int:
	return act_of(current())


static func act_of(step: StringName) -> int:
	return str(step).trim_prefix("a").get_slice("_", 0).to_int()


static func is_at(step: StringName) -> bool:
	return current() == step


## True when the story is at [param step] or past it.
static func reached(step: StringName) -> bool:
	return _index(current()) >= _index(step)


## Moves the story forward to [param step]. Does nothing (and returns false) when the
## story is already there or past it, so a scene can call this every time it runs.
static func advance_to(step: StringName) -> bool:
	if not ORDER.has(step) or reached(step):
		return false
	_move_to(step)
	return true


## Puts the story at [param step] no matter where it was, backwards too: for the
## start of the loop and for jumping around while testing.
static func set_step(step: StringName) -> void:
	if ORDER.has(step) and not is_at(step):
		_move_to(step)


## [param listener] is called with the new step (a StringName) every time the story
## moves. Listeners that have been freed are dropped by themselves.
static func on_change(listener: Callable) -> void:
	if not _listeners.has(listener):
		_listeners.append(listener)


## Steps this script doesn't know count as never reached.
static func _index(step: StringName) -> int:
	var index := ORDER.find(step)
	if index == -1:
		push_warning("StoryProgress: no step named '%s'." % step)
		return ORDER.size()
	return index


static func _move_to(step: StringName) -> void:
	SaveManager.set_flag(FLAG, String(step))
	print("[StoryProgress] %s" % step)
	for listener in _listeners.duplicate():
		if listener.is_valid():
			listener.call(step)
		else:
			_listeners.erase(listener)
