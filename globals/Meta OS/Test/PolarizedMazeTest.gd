extends Node2D

## Polarized Maze with Cinematic Desktop Escape Cutscene & FileSystem Desktop:
## 1. Shows "Obtained: a letter to ???.txt" immediately on startup (F6).
## 2. WASD movement + Polarized Lens X-ray window ('E').
## 3. Press 'Q' to toggle the FileSystem desktop window.
## 4. Press 'T' to open the Command Terminal directly.
## 5. ExitTrigger spawns a desktop icon crawl, followed by Windows 2-5.

@onready var player: CharacterBody2D = %Player
@onready var main_camera: Camera2D = %MainCamera
@onready var lens_window: Window = %LensWindow
@onready var lens_camera: Camera2D = %LensCamera
@onready var exit_trigger: Area2D = find_child("ExitTrigger", true, false) as Area2D

var is_dragging_lens: bool = false
var drag_start_mouse_pos: Vector2i = Vector2i.ZERO
var is_cutscene_active: bool = false

# File System UI Overlay
var file_system_ui: FileSystemUI

const MOVE_SPEED: float = 240.0
const WINDOWS_FRAME_OFFSET := Vector2(8, 40)


func _ready() -> void:
	# 1. Main window setup: Standard OS window, opaque black background
	var main_win: Window = get_window()
	main_win.title = "BLAIRE // PERCEPTION TEST"
	main_win.borderless = false        # Ensures standard Windows borders & title bar
	main_win.transparent = false         # Keeps the game window solid/opaque
	RenderingServer.set_default_clear_color(Color.BLACK) # Makes the empty space pure black
	
	main_win.size = Vector2i(1020, 680)
	main_win.content_scale_size = main_win.size
	main_win.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	main_win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	
	var screen_size: Vector2i = DisplayServer.screen_get_size()
	main_win.position = Vector2i((Vector2(screen_size) - Vector2(main_win.size)) / 2.0)
	
	main_camera.anchor_mode = Camera2D.ANCHOR_MODE_DRAG_CENTER
	main_camera.position = Vector2(main_win.size) / 2.0
	
	get_tree().root.gui_embed_subwindows = false
	main_win.canvas_cull_mask = 1
	
	# 2. Lens window setup
	lens_window.world_2d = get_viewport().world_2d
	lens_window.canvas_cull_mask = 3
	lens_window.size = Vector2i(320, 320)
	lens_window.unresizable = true
	lens_window.borderless = true
	lens_window.always_on_top = true
	
	lens_camera.position_smoothing_enabled = false
	lens_camera.zoom = Vector2.ONE
	
	lens_window.hide()
	lens_window.window_input.connect(_on_lens_window_input)
	
	if exit_trigger:
		exit_trigger.body_entered.connect(_on_exit_triggered)
		
	_format_all_maze_walls()
	
	# 3. Instantiate Floating FileSystem Desktop Window
	file_system_ui = FileSystemUI.new()
	add_child(file_system_ui)
	
	# 4. Populate starting test files matching your story
	_init_starter_files()
	
	# 5. IMMEDIATELY show Window 1 on F6 startup
	await get_tree().create_timer(0.3).timeout
	await MetaOS.show_dialog(
		"Obtained",
		"a letter to ???.txt",
		["CLOSE"],
		"txt"
	)


func _init_starter_files() -> void:
	# 1. Entry: Letter obtained right at the beginning
	var f1 := GameFile.new()
	f1.file_id = "entry_letter"
	f1.filename = "a letter to ???.txt"
	f1.category = GameFile.Category.ENTRY
	f1.content = "I saw her standing by the fence.\nShe looked distant.\nWas it something I said?"
	f1.can_interpret = true
	FileManager.obtain_file(f1)
	
	# 2. Photo: Blaire's Silhouette Photo from Image 1 (Can ONLY be intervened)
	var f2 := GameFile.new()
	f2.file_id = "photo_blaire"
	f2.filename = "small_blaire_teddy.png"
	f2.category = GameFile.Category.PHOTO
	f2.content = "A silhouette of Blaire holding her teddy bear."
	f2.can_intervene = true
	FileManager.obtain_file(f2)
	
	# 3. Secret: The Order Cipher (Decryptable via Terminal)
	var f3 := GameFile.new()
	f3.file_id = "cipher_order"
	f3.filename = "the_order_directive.txt"
	f3.category = GameFile.Category.SECRET
	f3.cipher_type = GameFile.CipherType.CAESAR
	f3.content = "XLI SVHIV MW EPVIEHC LIVI.\nGLSMGI MW ER MPPYWMSR."
	f3.solved_content = "THE ORDER IS ALREADY HERE.\nCHOICE IS AN ILLUSION."
	f3.ghost_hint_unsolved = "The signal is shifted backward by four letters."
	f3.ghost_hint_solved = "The directive is locked. They are watching."
	f3.can_interpret = true
	f3.can_decode = true
	FileManager.obtain_file(f3)
	
	# 4. About: The Order Lore
	var f4 := GameFile.new()
	f4.file_id = "about_order"
	f4.filename = "the_order.about"
	f4.category = GameFile.Category.ABOUT
	f4.content = "A community claiming to offer salvation from the fake world.\nThey gave Blaire her apartment."
	f4.can_interpret = true
	FileManager.obtain_file(f4)
	
	# 5. Item: The Notebook (Shows properties on hover)
	var f5 := GameFile.new()
	f5.file_id = "item_notebook"
	f5.filename = "notebook.item"
	f5.category = GameFile.Category.ITEM
	f5.item_size = "17KB"
	f5.item_location = "bedroom"
	f5.content = "allows for reading blaire's entries."
	FileManager.obtain_file(f5)


func _format_all_maze_walls() -> void:
	for body in find_children("*", "StaticBody2D", true, false):
		var col: CollisionShape2D = body.find_child("CollisionShape2D", true, false)
		var rect: ColorRect = body.find_child("ColorRect", true, false)
		var label: Label = body.find_child("Label", true, false)
		
		if not col or not col.shape is RectangleShape2D:
			continue
			
		if label:
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label.autowrap_mode = TextServer.AUTOWRAP_OFF
		
		var text_len: int = label.text.length() if label else 20
		var box_width: float = max(200.0, text_len * 9.5 + 48.0)
		var box_height: float = 46.0
		var final_size := Vector2(box_width, box_height)
		
		col.shape.size = final_size
		col.position = Vector2.ZERO
		
		if rect:
			rect.size = final_size
			rect.position = -final_size / 2.0
			if label:
				label.size = final_size
				label.position = Vector2.ZERO


func _physics_process(_delta: float) -> void:
	# Disable movement while cutscene or FileSystem window is open
	if is_cutscene_active or (file_system_ui and file_system_ui.visible):
		player.velocity = Vector2.ZERO
		return
		
	var move_input := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_action_pressed("ui_up"):
		move_input.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_action_pressed("ui_down"):
		move_input.y += 1.0
	if Input.is_key_pressed(KEY_A) or Input.is_action_pressed("ui_left"):
		move_input.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_action_pressed("ui_right"):
		move_input.x += 1.0
		
	player.velocity = move_input.normalized() * MOVE_SPEED
	player.move_and_slide()


func _process(_delta: float) -> void:
	if not lens_window.visible:
		return
		
	var main_win_pos: Vector2i = DisplayServer.window_get_position(DisplayServer.MAIN_WINDOW_ID)
	var lens_win_pos: Vector2i = lens_window.position
	
	var main_viewport_center: Vector2 = Vector2(main_win_pos) + WINDOWS_FRAME_OFFSET + Vector2(get_window().size) / 2.0
	var lens_viewport_center: Vector2 = Vector2(lens_win_pos) + Vector2(lens_window.size) / 2.0
	var screen_delta: Vector2 = lens_viewport_center - main_viewport_center
	
	lens_camera.global_position = main_camera.get_screen_center_position() + screen_delta


## Triggered when player steps into the exit zone
func _on_exit_triggered(body: Node2D) -> void:
	if body == player and not is_cutscene_active:
		is_cutscene_active = true
		
		# Close other overlays
		lens_window.hide()
		if file_system_ui:
			if file_system_ui.is_open:
				file_system_ui.toggle_filesystem()
			else:
				file_system_ui.hide_all_windows()
		player.hide()
		
		# 1. Desktop Icon Window
		var icon_win := Window.new()
		icon_win.size = Vector2i(48, 48)
		icon_win.borderless = true
		icon_win.transparent = true
		icon_win.unresizable = true
		icon_win.always_on_top = true
		icon_win.transient = false
		icon_win.exclusive = false
		
		var main_win_pos: Vector2i = DisplayServer.window_get_position(DisplayServer.MAIN_WINDOW_ID)
		var player_screen_pos: Vector2i = main_win_pos + Vector2i(WINDOWS_FRAME_OFFSET) + Vector2i(player.global_position)
		icon_win.position = player_screen_pos - Vector2i(24, 24)
		
		var sprite_clone := TextureRect.new()
		var icon_tex := load("res://icon.svg")
		if icon_tex:
			sprite_clone.texture = icon_tex
		sprite_clone.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		sprite_clone.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		sprite_clone.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon_win.add_child(sprite_clone)
		
		get_tree().root.add_child(icon_win)
		icon_win.show()
		
		# 2. Desktop Crawl
		var start_pos: Vector2i = icon_win.position
		var screen_height: int = DisplayServer.screen_get_size().y
		var target_pos: Vector2i = Vector2i(start_pos.x, screen_height + 150)
		
		var distance: float = float(target_pos.y - start_pos.y)
		var duration: float = distance / 220.0
		
		var slide_tween: Tween = create_tween()
		slide_tween.tween_method(
			func(val: Vector2i): icon_win.position = val,
			start_pos,
			target_pos,
			duration
		).set_trans(Tween.TRANS_LINEAR)
		
		await slide_tween.finished
		icon_win.queue_free()
		
		# 3. 1-second silence
		await get_tree().create_timer(1.0).timeout
		
		# 4. Satantech Windows 2 through 5
		await MetaOS.show_dialog(
			"Info",
			"[i]Please help me.[/i]",
			["YES", "YES"]
		)
		
		await MetaOS.show_dialog(
			"Blocked",
			"She didn't come here.",
			["OKAY"]
		)
		
		await MetaOS.show_dialog(
			"Info",
			"[i]It hurts.[/i]",
			["I'M SORRY"]
		)
		
		var no_buttons: Array[String] = []
		await MetaOS.show_dialog(
			"Info",
			"[color=red][i]Burn down the house, Blaire.[/i][/color]",
			no_buttons
		)
		
		get_tree().quit()


## Allows dragging the lens with left-click
func _on_lens_window_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			is_dragging_lens = true
			drag_start_mouse_pos = DisplayServer.mouse_get_position() - lens_window.position
		else:
			is_dragging_lens = false
			
	elif event is InputEventMouseMotion and is_dragging_lens:
		lens_window.position = DisplayServer.mouse_get_position() - drag_start_mouse_pos


func _unhandled_input(event: InputEvent) -> void:
	if is_cutscene_active:
		return
		
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_Q:
			file_system_ui.toggle_filesystem()
		elif event.keycode == KEY_T:
			file_system_ui.toggle_terminal()
		elif event.keycode == KEY_E:
			_toggle_lens_window()
		elif event.keycode == KEY_ESCAPE:
			get_tree().quit()


func _toggle_lens_window() -> void:
	if lens_window.visible:
		lens_window.hide()
	else:
		var main_win_pos: Vector2i = DisplayServer.window_get_position(DisplayServer.MAIN_WINDOW_ID)
		var player_canvas_pos: Vector2 = player.get_global_transform_with_canvas().origin
		var spawn_pos: Vector2 = Vector2(main_win_pos) + WINDOWS_FRAME_OFFSET + player_canvas_pos - Vector2(lens_window.size) / 2.0
		
		lens_window.position = Vector2i(spawn_pos)
		lens_window.show()
		lens_window.grab_focus()
