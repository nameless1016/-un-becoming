@tool
class_name FileHotspot
extends Hotspot
## A Hotspot that opens [member files] in the station's FileViewer when clicked.
## Its dialogue_timeline (if set) plays first, then the files open.
## To make one: instance hotspot.tscn, then Extend Script / load this script on it.

@export var files: Array[ComputerFile] = []
## Window title in the viewer. Falls back to hotspot_name.
@export var folder_title: String = ""


func get_folder_title() -> String:
	return folder_title if not folder_title.is_empty() else hotspot_name
