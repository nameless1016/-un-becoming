extends State
class_name PlayerIdle_TopDown

func enterState():
	PLAYER.sprite.play("idle_" + PLAYER.get_facing_string())

func updateState(_delta : float):
	if(Input.get_vector("move_left", "move_right", "move_up", "move_down")):
		#Transition to Run State
		transition.emit(self, "Run")
