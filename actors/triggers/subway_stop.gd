extends Area2D
class_name SubwayStop

## Has to match an id in map_locations.gd so the map knows where you are
@export var location_id: String = "town"

var menu_open: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if menu_open:
		return
	if body is PlayerTopDown or body.name == "PlayerTopDown":
		open_map()

func open_map() -> void:
	menu_open = true
	var menu := MapMenu.new()
	menu.current_id = location_id
	menu.tree_exited.connect(_on_menu_closed)
	get_tree().current_scene.add_child(menu)

func _on_menu_closed() -> void:
	# step off the pad and back on to open it again
	if is_instance_valid(self):
		menu_open = false
