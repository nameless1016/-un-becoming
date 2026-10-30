class_name FileSystemUI
extends Node
signal request_open_calendar

# This export variable lets you drop an image from the editor.
@export var silhouette_image: Texture2D

# These are the four views the center window can show.
enum CenterMode { SILHOUETTE, EXPLORER, NOTEPAD, NOTICE }

var current_mode: CenterMode = CenterMode.SILHOUETTE
var active_category: GameFile.Category = GameFile.Category.ENTRY
var highlighted_file: GameFile = null
var system_font: SystemFont

# This tracks if the file system is currently open on screen.
var is_open: bool = false

# This property lets other scripts check or set visibility safely.
var visible: bool:
	get: return is_open
	set(val):
		if val != is_open: toggle_filesystem()

# Dragging variables for the center window.
var is_dragging_center: bool = false
var center_drag_offset: Vector2i = Vector2i.ZERO
var is_retract_animating: bool = false
var retract_tween: Tween

# Separate native desktop windows.
var folders_win: Window
var center_win: Window
var items_win: Window
var props_win: Window
var retract_win: Window
var terminal_win: TerminalWindow

# The home position where the center window docks.
var center_dock_pos: Vector2i = Vector2i.ZERO
const SNAP_THRESHOLD: float = 80.0

# References to UI elements on the left window.
var folder_list_vbox: VBoxContainer
var inspect_btn: Button
var command_btn: Button
var retract_btn: Button

# References to UI elements inside the center window.
var center_title_lbl: Label
var c_close_btn: Button
var silhouette_view: TextureRect
var explorer_view: VBoxContainer
var notepad_view: VBoxContainer
var notepad_text: RichTextLabel
var notice_view: VBoxContainer
var notice_label: Label

# References to items on the right dock.
var right_dock_vbox: VBoxContainer
var item_properties_label: Label


func _ready() -> void:
	_setup_system_font()
	_build_windows()
	hide_all_windows()
	
	# Listen to file signals and refresh views automatically.
	FileManager.file_obtained.connect(func(_f): _refresh_current_view())
	FileManager.file_solved.connect(func(_f): _refresh_current_view())
	FileManager.command_unlocked.connect(func(_cmd): _refresh_current_view())
	
	# Refresh views when a cipher is solved in the terminal.
	terminal_win.file_decoded.connect(func(_f): _refresh_current_view())


# Handles hotkeys when any of the desktop subwindows have OS focus.
func _on_subwindow_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_Q or event.keycode == KEY_ESCAPE:
			toggle_filesystem()
		elif event.keycode == KEY_T:
			toggle_terminal()
		elif event.keycode == KEY_C:
			request_open_calendar.emit()


# Opens or closes the file system, and resets everything on close.
func toggle_filesystem() -> void:
	if is_open:
		is_open = false
		hide_all_windows()
		_reset_to_beginning()
		_safe_window_move_to_foreground(get_tree().root.get_window())
		get_tree().root.get_window().grab_focus()
	else:
		is_open = true
		_position_and_show_windows()
		_reset_to_beginning()
		_refresh_items_dock()


# Clears selections and resets the center view to the silhouette.
func _reset_to_beginning() -> void:
	highlighted_file = null
	active_category = GameFile.Category.ENTRY
	current_mode = CenterMode.SILHOUETTE
	
	center_title_lbl.text = "File System"
	silhouette_view.show()
	explorer_view.hide()
	notepad_view.hide()
	notice_view.hide()


# Toggles the terminal window open or closed.
func toggle_terminal() -> void:
	if terminal_win.visible:
		terminal_win.close_terminal()
	else:
		if highlighted_file != null:
			terminal_win.open_for_file(highlighted_file)
		else:
			show_center_notice("Select or Highlight an item first.")


# Shows a text message in the center window.
func show_center_notice(msg: String) -> void:
	if not center_win.visible and is_open:
		_restore_center_window()
	current_mode = CenterMode.NOTICE
	
	# Keep the silhouette visible behind the text.
	silhouette_view.show()
	explorer_view.hide()
	notepad_view.hide()
	notice_label.text = "\n\n" + msg
	notice_view.show()
	center_title_lbl.text = "Notice"


# Hides all windows and cancels active slide animations.
func hide_all_windows() -> void:
	if retract_tween and retract_tween.is_valid():
		retract_tween.kill()
	is_retract_animating = false
	
	if folders_win: folders_win.hide()
	if center_win: center_win.hide()
	if items_win: items_win.hide()
	if props_win: props_win.hide()
	if retract_win: retract_win.hide()
	if terminal_win: terminal_win.hide()


# Calculates monitor positions and shows the initial windows.
func _position_and_show_windows() -> void:
	var screen_id: int = DisplayServer.get_primary_screen()
	var screen_origin: Vector2i = DisplayServer.screen_get_position(screen_id)
	var screen_size: Vector2i = DisplayServer.screen_get_size(screen_id)
	
	var base_y: int = screen_origin.y + int((float(screen_size.y) - 540.0) / 2.0)
	var left_x: int = screen_origin.x + int(max(40.0, (float(screen_size.x) - 1100.0) / 2.0))
	
	# Left window position.
	folders_win.position = Vector2i(left_x, base_y)
	folders_win.show()
	
	# Retract button position.
	retract_win.position = Vector2i(left_x + 226, base_y + 10)
	retract_win.hide()
	
	# Center window home dock position.
	center_dock_pos = Vector2i(left_x + 256, base_y)
	center_win.position = center_dock_pos
	center_win.show()
	
	# Right items dock position.
	var right_x: int = screen_origin.x + screen_size.x - 110
	items_win.position = Vector2i(right_x, base_y)
	items_win.show()


# Safely focuses a window without crashing if the window is hidden.
func _safe_window_move_to_foreground(win: Window) -> void:
	if win and win.visible and win.get_window_id() != DisplayServer.INVALID_WINDOW_ID:
		DisplayServer.window_move_to_foreground(win.get_window_id())


# Slides the center window to the left behind the folders window.
func _retract_center_window() -> void:
	if is_retract_animating or not center_win.visible:
		return
	is_retract_animating = true
	
	# Put the left window on top so the center slides underneath it.
	_safe_window_move_to_foreground(folders_win)
	
	var start_pos: Vector2i = center_win.position
	var target_pos: Vector2i = Vector2i(folders_win.position.x + 20, start_pos.y)
	
	if retract_tween and retract_tween.is_valid():
		retract_tween.kill()
		
	retract_tween = create_tween()
	retract_tween.tween_method(
		func(pos: Vector2i): center_win.position = pos, 
		start_pos, 
		target_pos, 
		0.22
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	
	await retract_tween.finished
	center_win.hide()
	retract_win.show()
	_safe_window_move_to_foreground(retract_win)
	is_retract_animating = false


# Slides the center window out from behind the left window back to its dock.
func _restore_center_window() -> void:
	if is_retract_animating:
		return
	is_retract_animating = true
	
	retract_win.hide()
	center_win.position = Vector2i(folders_win.position.x + 20, center_dock_pos.y)
	center_win.show()
	
	_safe_window_move_to_foreground(folders_win)
	
	if retract_tween and retract_tween.is_valid():
		retract_tween.kill()
		
	retract_tween = create_tween()
	retract_tween.tween_method(
		func(pos: Vector2i): center_win.position = pos, 
		center_win.position, 
		center_dock_pos, 
		0.26
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	await retract_tween.finished
	_safe_window_move_to_foreground(center_win)
	center_win.grab_focus()
	is_retract_animating = false


# Dragging and snapping behavior for the center window title bar.
func _on_center_title_bar_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			is_dragging_center = true
			center_drag_offset = DisplayServer.mouse_get_position() - center_win.position
		else:
			is_dragging_center = false
			# If dragged near the dock position, snap back automatically.
			var current_pos: Vector2 = Vector2(center_win.position)
			var target_pos: Vector2 = Vector2(center_dock_pos)
			if current_pos.distance_to(target_pos) < SNAP_THRESHOLD:
				var snap_tween := create_tween()
				snap_tween.tween_method(func(pos: Vector2i): center_win.position = pos, center_win.position, center_dock_pos, 0.12).set_trans(Tween.TRANS_QUAD)
				
	elif event is InputEventMouseMotion and is_dragging_center:
		center_win.position = DisplayServer.mouse_get_position() - center_drag_offset


# Switches between silhouette, file list, text viewer, and notices.
func switch_center_mode(mode: CenterMode) -> void:
	if not center_win.visible and is_open:
		_restore_center_window()
		
	current_mode = mode
	
	# The silhouette stays visible as a background layer.
	silhouette_view.show()
	explorer_view.hide()
	notepad_view.hide()
	notice_view.hide()
	
	match mode:
		CenterMode.SILHOUETTE:
			center_title_lbl.text = "File System"
			
		CenterMode.EXPLORER:
			center_title_lbl.text = "Explorer // " + _get_category_name(active_category).to_upper()
			explorer_view.show()
			_render_explorer_file_list()
			
		CenterMode.NOTEPAD:
			if highlighted_file:
				center_title_lbl.text = "Notepad // " + highlighted_file.filename
				_render_notepad_content()
				notepad_view.show()
			else:
				switch_center_mode(CenterMode.SILHOUETTE)


# Updates the visible view when files change.
func _refresh_current_view() -> void:
	_refresh_items_dock()
	match current_mode:
		CenterMode.EXPLORER:
			_render_explorer_file_list()
		CenterMode.NOTEPAD:
			_render_notepad_content()


# Populates the file list buttons for the active folder.
func _render_explorer_file_list() -> void:
	for child in explorer_view.get_children():
		child.queue_free()
		
	var files := FileManager.get_files_by_category(active_category)
	
	if files.is_empty():
		var empty_lbl := Label.new()
		empty_lbl.text = "\n[DIRECTORY EMPTY]"
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_font_override("font", system_font)
		empty_lbl.add_theme_font_size_override("font_size", 13)
		empty_lbl.add_theme_color_override("font_color", Color("#888888"))
		explorer_view.add_child(empty_lbl)
		return
		
	for f in files:
		var btn := Button.new()
		var prefix := "[OK] " if f.is_solved else "     "
		btn.text = prefix + f.filename
		btn.icon = _generate_file_icon()
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(0, 32)
		btn.add_theme_font_override("font", system_font)
		btn.add_theme_font_size_override("font_size", 12)
		
		var is_selected: bool = (highlighted_file != null and highlighted_file.file_id == f.file_id)
		_apply_file_item_theme(btn, is_selected)
		
		# One click highlights the file, double click opens the notepad view.
		btn.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
				_set_highlighted_file(f, btn)
				if event.double_click:
					switch_center_mode(CenterMode.NOTEPAD)
		)
		explorer_view.add_child(btn)


# Sets the active file and updates button highlight styles.
func _set_highlighted_file(file: GameFile, active_btn: Button) -> void:
	highlighted_file = file
	for child in explorer_view.get_children():
		if child is Button:
			_apply_file_item_theme(child, child == active_btn)


# Displays file content in the notepad view.
func _render_notepad_content() -> void:
	if not highlighted_file:
		return
	var display_text := highlighted_file.solved_content if (highlighted_file.is_solved and highlighted_file.solved_content != "") else highlighted_file.content
	notepad_text.clear()
	notepad_text.append_text("[color=#aaaaaa]FILE: " + highlighted_file.filename + "[/color]\n")
	notepad_text.append_text("[color=#aaaaaa]CATEGORY: " + _get_category_name(highlighted_file.category) + "[/color]\n")
	notepad_text.append_text("[color=#666666]--------------------------------------------------[/color]\n\n")
	notepad_text.append_text(display_text)


# Creates all desktop subwindows programmatically.
func _build_windows() -> void:
	# 1. Left folders window.
	folders_win = _create_os_window(Vector2i(220, 520))
	add_child(folders_win)
	folders_win.window_input.connect(_on_subwindow_input)
	
	var left_panel := _create_retro_panel()
	folders_win.add_child(left_panel)
	
	var left_vbox := VBoxContainer.new()
	left_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	left_panel.add_child(left_vbox)
	
	folder_list_vbox = VBoxContainer.new()
	folder_list_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	folder_list_vbox.add_theme_constant_override("separation", 16)
	left_vbox.add_child(folder_list_vbox)
	
	var folder_names := ["Entry", "About", "Photo", "Executable", "Secret"]
	var folder_enums := [
		GameFile.Category.ENTRY,
		GameFile.Category.ABOUT,
		GameFile.Category.PHOTO,
		GameFile.Category.ITEM,
		GameFile.Category.SECRET
	]
	
	for i in range(folder_names.size()):
		var f_btn := Button.new()
		f_btn.text = "  " + folder_names[i]
		f_btn.icon = _generate_folder_icon()
		f_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		f_btn.custom_minimum_size = Vector2(0, 36)
		_apply_button_theme(f_btn)
		
		var cat_enum: GameFile.Category = folder_enums[i]
		f_btn.pressed.connect(func():
			active_category = cat_enum
			switch_center_mode(CenterMode.EXPLORER)
		)
		folder_list_vbox.add_child(f_btn)
		
	var left_bottom_sep := HSeparator.new()
	left_bottom_sep.add_theme_stylebox_override("separator", _create_white_separator())
	left_vbox.add_child(left_bottom_sep)
	
	var left_actions := HBoxContainer.new()
	left_actions.add_theme_constant_override("separation", 8)
	left_vbox.add_child(left_actions)
	
	# Inspect button switches directly to notepad view.
	inspect_btn = Button.new()
	inspect_btn.text = "INSPECT"
	inspect_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inspect_btn.custom_minimum_size = Vector2(0, 32)
	_apply_button_theme(inspect_btn)
	inspect_btn.pressed.connect(func():
		if highlighted_file:
			switch_center_mode(CenterMode.NOTEPAD)
		else:
			show_center_notice("Select or Highlight an item first.")
	)
	left_actions.add_child(inspect_btn)
	
	# Command button opens the external terminal window.
	command_btn = Button.new()
	command_btn.text = "COMMAND"
	command_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	command_btn.custom_minimum_size = Vector2(0, 32)
	_apply_button_theme(command_btn)
	command_btn.pressed.connect(func():
		if highlighted_file != null:
			terminal_win.open_for_file(highlighted_file)
		else:
			show_center_notice("Select or Highlight an item first.")
	)
	left_actions.add_child(command_btn)
	
	# Small button that restores the center window after retracting.
	retract_win = _create_os_window(Vector2i(24, 24))
	add_child(retract_win)
	retract_win.window_input.connect(_on_subwindow_input)
	
	retract_btn = Button.new()
	retract_btn.text = "<"
	retract_btn.set_anchors_preset(Control.PRESET_FULL_RECT)
	_apply_button_theme(retract_btn)
	retract_btn.pressed.connect(_restore_center_window)
	retract_win.add_child(retract_btn)
	
	# 2. Center window.
	center_win = _create_os_window(Vector2i(540, 520))
	add_child(center_win)
	center_win.window_input.connect(_on_subwindow_input)
	
	var center_panel := _create_retro_panel()
	center_win.add_child(center_panel)
	
	var center_vbox := VBoxContainer.new()
	center_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_vbox.add_theme_constant_override("separation", 0)
	center_panel.add_child(center_vbox)
	
	# Title bar for the center window.
	var c_title_bar := PanelContainer.new()
	c_title_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	var c_bar_style := StyleBoxFlat.new()
	c_bar_style.bg_color = Color.BLACK
	c_bar_style.border_width_bottom = 2
	c_bar_style.border_color = Color.WHITE
	c_title_bar.add_theme_stylebox_override("panel", c_bar_style)
	c_title_bar.gui_input.connect(_on_center_title_bar_input)
	center_vbox.add_child(c_title_bar)
	
	var c_title_margin := MarginContainer.new()
	c_title_margin.add_theme_constant_override("margin_left", 8)
	c_title_margin.add_theme_constant_override("margin_right", 6)
	c_title_margin.add_theme_constant_override("margin_top", 4)
	c_title_margin.add_theme_constant_override("margin_bottom", 4)
	c_title_bar.add_child(c_title_margin)
	
	var c_title_row := HBoxContainer.new()
	c_title_margin.add_child(c_title_row)
	
	center_title_lbl = Label.new()
	center_title_lbl.text = "File System"
	center_title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_title_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	center_title_lbl.add_theme_font_override("font", system_font)
	center_title_lbl.add_theme_font_size_override("font_size", 13)
	c_title_row.add_child(center_title_lbl)
	
	# Center window close button.
	c_close_btn = Button.new()
	c_close_btn.text = "X"
	c_close_btn.custom_minimum_size = Vector2(18, 18)
	c_close_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_apply_close_button_style(c_close_btn)
	c_close_btn.pressed.connect(_retract_center_window)
	c_title_row.add_child(c_close_btn)
	
	var center_content := Control.new()
	center_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	center_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_vbox.add_child(center_content)
	
	# View 1, persistent background silhouette.
	silhouette_view = TextureRect.new()
	silhouette_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	# Update this path if you change where the image is stored.
	if silhouette_image:
		silhouette_view.texture = silhouette_image
	else:
		silhouette_view.texture = load("res://globals/Meta OS/File System/blaire_silhouette.png")
	
	silhouette_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	silhouette_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	# Offsets tuned to center the silhouette portrait.
	silhouette_view.offset_top = 10
	silhouette_view.offset_bottom = 95
	silhouette_view.offset_left = -10
	silhouette_view.offset_right = -10
	silhouette_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center_content.add_child(silhouette_view)
	
	# View 2, file explorer list.
	explorer_view = VBoxContainer.new()
	explorer_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	explorer_view.add_theme_constant_override("separation", 6)
	explorer_view.hide()
	center_content.add_child(explorer_view)
	
	# View 3, in place notepad text viewer.
	notepad_view = VBoxContainer.new()
	notepad_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	notepad_view.hide()
	center_content.add_child(notepad_view)
	
	notepad_text = RichTextLabel.new()
	notepad_text.bbcode_enabled = true
	notepad_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	notepad_text.add_theme_font_override("normal_font", system_font)
	notepad_text.add_theme_font_size_override("normal_font_size", 13)
	notepad_view.add_child(notepad_text)
	
	var back_btn := Button.new()
	back_btn.text = "< BACK TO FOLDER"
	back_btn.custom_minimum_size = Vector2(0, 30)
	_apply_button_theme(back_btn)
	back_btn.pressed.connect(func(): switch_center_mode(CenterMode.EXPLORER))
	notepad_view.add_child(back_btn)
	
	# View 4, notice message view.
	notice_view = VBoxContainer.new()
	notice_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	notice_view.alignment = BoxContainer.ALIGNMENT_CENTER
	notice_view.hide()
	center_content.add_child(notice_view)
	
	notice_label = Label.new()
	notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	notice_label.add_theme_font_override("font", system_font)
	notice_label.add_theme_font_size_override("font_size", 14)
	notice_label.add_theme_color_override("font_color", Color("#ffffff"))
	notice_view.add_child(notice_label)
	
	# 3. Right items window.
	items_win = _create_os_window(Vector2i(80, 520))
	add_child(items_win)
	items_win.window_input.connect(_on_subwindow_input)
	
	var items_panel := _create_retro_panel()
	items_win.add_child(items_panel)
	
	right_dock_vbox = VBoxContainer.new()
	right_dock_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right_dock_vbox.add_theme_constant_override("separation", 18)
	items_panel.add_child(right_dock_vbox)
	
	for i in range(6):
		var slot := Button.new()
		slot.custom_minimum_size = Vector2(56, 56)
		_apply_button_theme(slot)
		right_dock_vbox.add_child(slot)
		
	# 4. Item properties hover window.
	props_win = _create_os_window(Vector2i(290, 160))
	add_child(props_win)
	
	var props_panel := _create_retro_panel()
	props_win.add_child(props_panel)
	
	item_properties_label = Label.new()
	item_properties_label.add_theme_font_override("font", system_font)
	item_properties_label.add_theme_font_size_override("font_size", 12)
	item_properties_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	props_panel.add_child(item_properties_label)
	
	# 5. External floating terminal window.
	terminal_win = TerminalWindow.new()
	add_child(terminal_win)


# Helper function to create native borderless desktop windows.
func _create_os_window(win_size: Vector2i) -> Window:
	var win := Window.new()
	win.size = win_size
	win.borderless = true
	win.unresizable = true
	win.always_on_top = true
	win.transient = false
	win.exclusive = false
	return win


# Updates items in the right dock and connects hover signals safely.
func _refresh_items_dock() -> void:
	if not right_dock_vbox:
		return
	var items := FileManager.get_files_by_category(GameFile.Category.ITEM)
	var slots := right_dock_vbox.get_children()
	
	for i in range(slots.size()):
		var slot_btn := slots[i] as Button
		
		# Disconnect any old hover connections to prevent duplicates.
		for conn in slot_btn.mouse_entered.get_connections():
			slot_btn.mouse_entered.disconnect(conn.callable)
		for conn in slot_btn.mouse_exited.get_connections():
			slot_btn.mouse_exited.disconnect(conn.callable)
		
		if i < items.size():
			var item_file: GameFile = items[i]
			slot_btn.icon = _generate_notebook_icon()
			slot_btn.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			
			slot_btn.mouse_entered.connect(_on_item_hovered.bind(item_file, slot_btn))
			slot_btn.mouse_exited.connect(_on_item_unhovered)
			
			slot_btn.pressed.connect(func():
				highlighted_file = item_file
				switch_center_mode(CenterMode.NOTEPAD)
			)
		else:
			slot_btn.icon = null
			slot_btn.text = ""


# Shows the properties panel beside the hovered item slot.
func _on_item_hovered(item: GameFile, slot_btn: Button) -> void:
	var text := "NAME: " + item.filename.get_basename() + "\n"
	text += "SIZE: " + item.item_size + "\n"
	text += "LOCATION: " + item.item_location + "\n"
	text += "DESCRIPTION: " + item.content
	item_properties_label.text = text
	
	props_win.position = Vector2i(items_win.position.x - 305, items_win.position.y + int(slot_btn.position.y))
	props_win.show()


# Hides the item properties window when the mouse leaves.
func _on_item_unhovered() -> void:
	props_win.hide()


# Helper function to create black panels with white 2px borders.
func _create_retro_panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color.BLACK
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color.WHITE
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", style)
	return panel


# Creates a white divider line.
func _create_white_separator() -> StyleBoxLine:
	var line := StyleBoxLine.new()
	line.color = Color.WHITE
	line.thickness = 2
	return line


# Configures the retro monospace font.
func _setup_system_font() -> void:
	system_font = SystemFont.new()
	system_font.font_names = PackedStringArray(["Cartograph Mono", "Cartograph CF", "TG Frekuent Mono", "Cascadia Code", "Consolas", "monospace"])
	system_font.font_weight = 550
	system_font.hinting = TextServer.HINTING_NORMAL
	system_font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED


# Close button style.
func _apply_close_button_style(btn: Button) -> void:
	btn.add_theme_font_override("font", system_font)
	btn.add_theme_font_size_override("font_size", 11)
	
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color.BLACK
	normal.border_width_left = 2
	normal.border_width_top = 2
	normal.border_width_right = 2
	normal.border_width_bottom = 2
	normal.border_color = Color.WHITE
	normal.content_margin_left = 0
	normal.content_margin_right = 0
	normal.content_margin_top = 0
	normal.content_margin_bottom = 0
	
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color.WHITE
	hover.border_width_left = 2
	hover.border_width_top = 2
	hover.border_width_right = 2
	hover.border_width_bottom = 2
	hover.border_color = Color.WHITE
	hover.content_margin_left = 0
	hover.content_margin_right = 0
	hover.content_margin_top = 0
	hover.content_margin_bottom = 0
	
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.BLACK)
	btn.add_theme_color_override("font_pressed_color", Color.BLACK)


# File item style in the explorer list, inverting to white when highlighted.
func _apply_file_item_theme(btn: Button, is_selected: bool) -> void:
	btn.add_theme_font_override("font", system_font)
	btn.add_theme_font_size_override("font_size", 12)
	
	var style := StyleBoxFlat.new()
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	
	if is_selected:
		style.bg_color = Color.WHITE
		style.border_color = Color.WHITE
		btn.add_theme_color_override("font_color", Color.BLACK)
		btn.add_theme_color_override("font_hover_color", Color.BLACK)
	else:
		# Transparent background so the silhouette image shows through the list.
		style.bg_color = Color.TRANSPARENT
		style.border_color = Color.TRANSPARENT
		btn.add_theme_color_override("font_color", Color.WHITE)
		btn.add_theme_color_override("font_hover_color", Color.WHITE)
		
	btn.add_theme_stylebox_override("normal", style)
	btn.add_theme_stylebox_override("hover", style)
	btn.add_theme_stylebox_override("pressed", style)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


# General button style.
func _apply_button_theme(btn: Button) -> void:
	btn.add_theme_font_override("font", system_font)
	btn.add_theme_font_size_override("font_size", 11)
	
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color.BLACK
	normal.border_width_left = 2
	normal.border_width_top = 2
	normal.border_width_right = 2
	normal.border_width_bottom = 2
	normal.border_color = Color.WHITE
	
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color.WHITE
	hover.border_width_left = 2
	hover.border_width_top = 2
	hover.border_width_right = 2
	hover.border_width_bottom = 2
	hover.border_color = Color.WHITE
	
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", hover)
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.BLACK)


# Converts categories to readable names.
func _get_category_name(cat: GameFile.Category) -> String:
	match cat:
		GameFile.Category.ENTRY: return "Entry"
		GameFile.Category.ABOUT: return "About"
		GameFile.Category.PHOTO: return "Photo"
		GameFile.Category.ITEM: return "Executable"
		GameFile.Category.SECRET: return "Secret"
	return "Files"


# Vector icon for folders.
func _generate_folder_icon() -> ImageTexture:
	var svg := """<svg xmlns="http://www.w3.org/2000/svg" width="28" height="24" viewBox="0 0 28 24">
		<path d="M 2 4 L 10 4 L 13 8 L 26 8 L 26 22 L 2 22 Z" fill="#ffffff"/>
	</svg>"""
	var img := Image.new()
	if img.load_svg_from_string(svg) == OK:
		return ImageTexture.create_from_image(img)
	return null


# Vector icon for files.
func _generate_file_icon() -> ImageTexture:
	var svg := """<svg xmlns="http://www.w3.org/2000/svg" width="16" height="20" viewBox="0 0 16 20">
		<path d="M 2 2 L 10 2 L 14 6 L 14 18 L 2 18 Z" fill="#000000" stroke="#ffffff" stroke-width="2"/>
	</svg>"""
	var img := Image.new()
	if img.load_svg_from_string(svg) == OK:
		return ImageTexture.create_from_image(img)
	return null


# Vector icon for the notebook item.
func _generate_notebook_icon() -> ImageTexture:
	var svg := """<svg xmlns="http://www.w3.org/2000/svg" width="36" height="42" viewBox="0 0 36 42">
		<rect x="6" y="2" width="26" height="38" rx="2" fill="#000000" stroke="#ffffff" stroke-width="2"/>
		<circle cx="6" cy="8" r="2.5" fill="#ffffff"/>
		<circle cx="6" cy="15" r="2.5" fill="#ffffff"/>
		<circle cx="6" cy="22" r="2.5" fill="#ffffff"/>
		<circle cx="6" cy="29" r="2.5" fill="#ffffff"/>
		<circle cx="6" cy="36" r="2.5" fill="#ffffff"/>
	</svg>"""
	var img := Image.new()
	if img.load_svg_from_string(svg) == OK:
		return ImageTexture.create_from_image(img)
	return null


# Fallback texture if the silhouette image fails to load.
func _generate_silhouette_texture() -> ImageTexture:
	var img := Image.create(380, 440, false, Image.FORMAT_RGBA8)
	img.fill(Color("#1a1a1a"))
	return ImageTexture.create_from_image(img)


# Hides all windows and flags the desktop as closed.
func hide() -> void:
	hide_all_windows()
	is_open = false
