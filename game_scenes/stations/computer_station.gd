class_name ComputerStation
extends PointAndClickScene
## Blaire's computer. FileHotspots play their dialogue, then open their files
## in the FileViewer; every other hotspot just plays its dialogue.

## Hook evidence/progression here. [param first_time] is true once per file per visit.
signal file_opened(file: ComputerFile, first_time: bool)

const VIEWER_LOCK := &"file_viewer"

@onready var file_viewer: FileViewer = $FileViewer


func _ready() -> void:
	super()
	file_viewer.file_opened.connect(file_opened.emit)
	file_viewer.closed.connect(unlock_input.bind(VIEWER_LOCK))


func _handle_hotspot(hotspot: Hotspot) -> void:
	var file_hotspot := hotspot as FileHotspot
	if file_hotspot == null or file_hotspot.files.is_empty():
		super(hotspot)
		return
	# Let the ghost react first, then open the folder.
	if play_dialogue(file_hotspot.dialogue_timeline):
		await dialogue_ended
	open_files(file_hotspot.get_folder_title(), file_hotspot.files)


func open_files(title: String, files: Array[ComputerFile]) -> void:
	lock_input(VIEWER_LOCK)
	# Deferred: after dialogue, Dialogic is still handling the click that closed
	# it, and that click would otherwise land in the file list and open a file.
	file_viewer.open.call_deferred(title, files)
