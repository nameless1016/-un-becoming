@tool
class_name FileDatabase
extends Resource

## Click this checkbox in the Inspector to force Godot to rename every item in the list.
@export var refresh_names_now: bool = false:
	set(val):
		if val:
			sync_all_names()
			# Forces the Godot Inspector to redraw the list immediately
			notify_property_list_changed()
			emit_changed()
		refresh_names_now = false

@export var all_files: Array[GameFile] = []:
	set(val):
		all_files = val
		sync_all_names()
		notify_property_list_changed()


## Loops through all items and writes their filename and ID directly into Godot's resource_name
func sync_all_names() -> void:
	for f in all_files:
		if f:
			var name_to_show: String = f.filename if f.filename != "" else f.file_id
			f.resource_name = "%s [%s]" % [name_to_show, f.file_id]
			f.emit_changed()
