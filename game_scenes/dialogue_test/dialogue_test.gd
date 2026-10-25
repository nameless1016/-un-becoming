extends Control
## Dev tool: lists every Dialogic timeline under res://dialogue/timelines.
## Click one to play it; every Dialogic signal it sends shows in the log,
## so unlocks can be checked before the systems that listen for them exist.

const TIMELINE_ROOT := "res://dialogue/timelines"

var _paths: PackedStringArray = []

@onready var _list: ItemList = %TimelineList
@onready var _log: RichTextLabel = %SignalLog


func _ready() -> void:
	for path in _find_timelines(TIMELINE_ROOT):
		_paths.append(path)
		_list.add_item(path.trim_prefix(TIMELINE_ROOT + "/").trim_suffix(".dtl"))
	_list.item_selected.connect(_play)
	Dialogic.signal_event.connect(_on_dialogic_signal)
	Dialogic.timeline_ended.connect(_log_line.bind("[color=#8a93b8]-- ended --[/color]"))


func _play(index: int) -> void:
	_list.deselect_all()
	if Dialogic.current_timeline != null:
		return
	_log_line("[b]%s[/b]" % _list.get_item_text(index))
	Dialogic.start(_paths[index])


func _on_dialogic_signal(argument: Variant) -> void:
	_log_line("  signal: [color=#9fe0a0]%s[/color]" % str(argument))


func _log_line(text: String) -> void:
	_log.append_text(text + "\n")


func _find_timelines(folder: String) -> PackedStringArray:
	var found: PackedStringArray = []
	var dir := DirAccess.open(folder)
	if dir == null:
		return found
	for sub in dir.get_directories():
		found.append_array(_find_timelines(folder.path_join(sub)))
	for file in dir.get_files():
		if file.ends_with(".dtl"):
			found.append(folder.path_join(file))
	return found
