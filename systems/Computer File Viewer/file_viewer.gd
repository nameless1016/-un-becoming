class_name FileViewer
extends CanvasLayer
## A simple desktop-style window: a file list on the left, the selected file on
## the right. Unread files are marked with a dot. Closes with the X or Esc.

## Emitted whenever a file is shown; [param first_time] is true only once per file.
signal file_opened(file: ComputerFile, first_time: bool)
signal closed

const UNREAD_MARK := "● "

var _files: Array[ComputerFile] = []
# ComputerFile -> true. Lives as long as this viewer (one station visit).
var _seen: Dictionary = {}

@onready var _title: Label = %TitleLabel
@onready var _close_button: Button = %CloseButton
@onready var _list: ItemList = %FileList
@onready var _file_header: Label = %FileHeader
@onready var _scroll: ScrollContainer = %ContentScroll
@onready var _image: TextureRect = %FileImage
@onready var _body: RichTextLabel = %FileBody


func _ready() -> void:
	hide()
	_list.item_selected.connect(_show_file)
	_close_button.pressed.connect(close)
	_list.mouse_entered.connect(CursorManager.push_hover.bind(_list, CursorManager.Mode.INTERACT, ""))
	_list.mouse_exited.connect(CursorManager.pop_hover.bind(_list))
	_close_button.mouse_entered.connect(CursorManager.push_hover.bind(_close_button, CursorManager.Mode.EXIT, ""))
	_close_button.mouse_exited.connect(CursorManager.pop_hover.bind(_close_button))


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


## Shows the window with [param files], opening the first one.
func open(title: String, files: Array[ComputerFile]) -> void:
	_files = files
	_title.text = title
	_list.clear()
	for file in _files:
		_list.add_item(_item_text(file))
	show()
	if not _files.is_empty():
		_list.select(0)
		_show_file(0)


func close() -> void:
	if not visible:
		return
	hide()
	# Hidden controls don't send mouse_exited.
	CursorManager.pop_hover(_list)
	CursorManager.pop_hover(_close_button)
	closed.emit()


func is_seen(file: ComputerFile) -> bool:
	return _seen.has(file)


func _show_file(index: int) -> void:
	var file := _files[index]
	_file_header.text = file.file_name if file.modified.is_empty() else "%s   ·   %s" % [file.file_name, file.modified]
	_image.texture = file.image
	_image.visible = file.image != null
	_body.text = file.body
	_body.visible = not file.body.is_empty()
	_scroll.scroll_vertical = 0

	var first_time := not _seen.has(file)
	_seen[file] = true
	_list.set_item_text(index, _item_text(file))
	file_opened.emit(file, first_time)


func _item_text(file: ComputerFile) -> String:
	return file.file_name if _seen.has(file) else UNREAD_MARK + file.file_name
