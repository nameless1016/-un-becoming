extends Player
class_name PlayerTopDown

# what gets saved for the player
func serialize() -> Dictionary:
	return {
		"x": global_position.x,
		"y": global_position.y,
		"dir_x": CUR_DIR.x,
		"dir_y": CUR_DIR.y,
	}

func deserialize(d: Dictionary) -> void:
	global_position = Vector2(d.get("x", global_position.x), d.get("y", global_position.y))
	CUR_DIR = Vector2(d.get("dir_x", CUR_DIR.x), d.get("dir_y", CUR_DIR.y))
