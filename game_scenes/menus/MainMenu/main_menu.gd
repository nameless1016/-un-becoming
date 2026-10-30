extends Control
## The main menu, styled after the Windows XP login screen:
## title -> "click your username" -> "Welcome / loading files..." -> the game.
## Settings has General (volume, reset), Viewport (resolution, window mode)
## and Controls (rebinding). Quit and Reset ask through a DesktopPopup, which
## opens as its own window on the player's desktop.

@export_file("*.tscn") var next_level_path: String
## Set by the Act 0 cutscene once it has played.
const INTRO_SEEN_FLAG := "act_0_seen"

## Plays on Start until the save says it was seen (Act 0). Empty: skip straight to the game.
@export_file("*.tscn") var intro_scene: String = "res://game_scenes/cutscenes/act_0/act_0_cutscene.tscn"
## Blaire's silhouette behind the title (from Meta OS). Skipped if the file isn't there.
@export_file("*.png") var silhouette_path: String = "res://globals/Meta OS/File System/blaire_silhouette.png"
## How long "loading files..." shows before the game starts, in seconds.
@export var welcome_time: float = 2.5

const SCREEN_FADE := 0.2
const RESOLUTIONS: Array[Vector2i] = [Vector2i(1920, 1080), Vector2i(1280, 720), Vector2i(960, 540)]
const WINDOW_MODES: Array[DisplayServer.WindowMode] = [
	DisplayServer.WINDOW_MODE_WINDOWED,
	DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN,
	DisplayServer.WINDOW_MODE_FULLSCREEN,
]

var _screen: Control
var _screen_tween: Tween
var _busy: bool = false
var _tile_tween: Tween

@onready var _silhouette: TextureRect = %Silhouette
@onready var _title_screen: Control = %TitleScreen
@onready var _user_screen: Control = %UserScreen
@onready var _welcome_screen: Control = %WelcomeScreen
@onready var _settings_screen: Control = %SettingsScreen

@onready var _start_button: Button = %StartButton
@onready var _settings_button: Button = %SettingsButton
@onready var _quit_button: Button = %QuitButton
@onready var _user_tile: Button = %UserTile
@onready var _avatar_box: StyleBoxFlat = (%Avatar as Panel).get_theme_stylebox(&"panel")
@onready var _last_saved: Label = %LastSaved
@onready var _loading_label: Label = %LoadingLabel

@onready var _tabs: Array[MenuItem] = [%GeneralTab, %ViewportTab, %ControlsTab]
@onready var _pages: Array[Control] = [%GeneralPage, %ViewportPage, %ControlsPage]
@onready var _sliders: Array[HSlider] = [%MasterSlider, %MusicSlider, %SfxSlider]
@onready var _resolution_buttons: Array[Node] = %ResolutionRow.get_children()
@onready var _mode_buttons: Array[Node] = %ModeRow.get_children()


func _ready() -> void:
	MusicManager.change_music("title", 0)
	
	if ResourceLoader.exists(silhouette_path):
		_silhouette.texture = load(silhouette_path)

	_start_button.pressed.connect(_show_screen.bind(_user_screen))
	_settings_button.pressed.connect(_open_settings)
	_quit_button.pressed.connect(_ask_quit)
	%UserBackButton.pressed.connect(_show_screen.bind(_title_screen))
	%SettingsBackButton.pressed.connect(_show_screen.bind(_title_screen))
	_user_tile.pressed.connect(_start_game)
	for sig in [_user_tile.mouse_entered, _user_tile.mouse_exited, _user_tile.focus_entered, _user_tile.focus_exited]:
		sig.connect(_refresh_tile.call_deferred)
	_user_tile.mouse_entered.connect(_user_tile.grab_focus)

	for i in _tabs.size():
		_tabs[i].pressed.connect(_select_tab.bind(i))
	_sliders[0].value = SettingsManager.master_vol
	_sliders[1].value = SettingsManager.music_vol
	_sliders[2].value = SettingsManager.sfx_vol
	for slider in _sliders:
		slider.value_changed.connect(_on_volume_changed.unbind(1))
	%ResetGameButton.pressed.connect(_ask_reset)
	%ResetControlsButton.pressed.connect(SettingsManager.reset_keybinds_to_default)
	for i in _resolution_buttons.size():
		(_resolution_buttons[i] as Button).pressed.connect(_on_resolution_pressed.bind(i))
	for i in _mode_buttons.size():
		(_mode_buttons[i] as Button).pressed.connect(_on_mode_pressed.bind(i))

	_update_last_saved()
	for screen in [_title_screen, _user_screen, _welcome_screen, _settings_screen]:
		screen.hide()
	_show_screen(_title_screen, false)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed(&"ui_cancel") or _busy:
		return
	get_viewport().set_input_as_handled()
	if _screen == _title_screen:
		_ask_quit()
	elif _screen == _user_screen or _screen == _settings_screen:
		_show_screen(_title_screen)


#region Screens

func _show_screen(screen: Control, fade: bool = true) -> void:
	var old := _screen
	_screen = screen
	if _screen_tween:
		_screen_tween.kill()
	_screen_tween = create_tween()
	if old and old != screen:
		if fade:
			SoundBank.play_sfx("ui_accept")
			_screen_tween.tween_property(old, "modulate:a", 0.0, SCREEN_FADE)
		_screen_tween.tween_callback(old.hide)
	_screen_tween.tween_callback(func() -> void:
		screen.modulate.a = 0.0 if fade else 1.0
		screen.show()
		_focus_default(screen)
	)
	if fade:
		_screen_tween.tween_property(screen, "modulate:a", 1.0, SCREEN_FADE)


func _focus_default(screen: Control) -> void:
	match screen:
		_title_screen:
			_start_button.grab_focus()
		_user_screen:
			_user_tile.grab_focus()
		_settings_screen:
			for tab in _tabs:
				if tab.selected:
					tab.grab_focus()


func _open_settings() -> void:
	_select_tab(0)
	_sync_viewport_buttons()
	_show_screen(_settings_screen)


func _start_game() -> void:
	if _busy:
		return
	_busy = true
	_show_screen(_welcome_screen)
	var dots := create_tween().set_loops()
	for text in ["loading files", "loading files.", "loading files..", "loading files..."]:
		dots.tween_callback(_loading_label.set_text.bind(text))
		dots.tween_interval(0.35)
	await get_tree().create_timer(welcome_time).timeout
	if next_level_path.is_empty():
		push_warning("Main menu has no next_level_path set.")
		return
	# goes to the saved spot, or the start point if there's no save yet
	SaveManager.fallback_scene = next_level_path
	# Act 0 plays until a save says it was seen. Saves from before Act 0 existed
	# don't have the flag, so they get it too.
	var seen_intro: bool = SaveManager.has_save() and SaveManager.load_game() and SaveManager.get_flag(INTRO_SEEN_FLAG)
	if not intro_scene.is_empty() and not seen_intro:
		GameManager.load_next_level(intro_scene)
	elif SaveManager.has_save():
		SaveManager.continue_game()
	else:
		SaveManager.new_game()


func _refresh_tile() -> void:
	var on := _user_tile.is_hovered() or _user_tile.has_focus()
	if _tile_tween:
		_tile_tween.kill()
	_tile_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_tile_tween.tween_property(_avatar_box, "bg_color", Color(1, 1, 1, 0.18) if on else Color.BLACK, 0.18)


func _update_last_saved() -> void:
	var text := "--/--/--"
	if FileAccess.file_exists(SaveManager.SAVE_PATH):
		var local_time := FileAccess.get_modified_time(SaveManager.SAVE_PATH) + int(Time.get_time_zone_from_system().bias) * 60
		var date := Time.get_datetime_dict_from_unix_time(local_time)
		text = "%02d/%02d/%02d" % [date.month, date.day, date.year % 100]
	_last_saved.text = "last saved: " + text

#endregion


#region Settings

func _select_tab(index: int) -> void:
	for i in _tabs.size():
		_tabs[i].selected = i == index
		_pages[i].visible = i == index
	_pages[index].modulate.a = 0.0
	create_tween().tween_property(_pages[index], "modulate:a", 1.0, SCREEN_FADE)


func _on_volume_changed() -> void:
	SettingsManager.master_vol = _sliders[0].value
	SettingsManager.music_vol = _sliders[1].value
	SettingsManager.sfx_vol = _sliders[2].value
	SettingsManager.save_settings()
	
	#SoundBank.play_sfx("ui_hover")


func _on_resolution_pressed(index: int) -> void:
	var window_size := RESOLUTIONS[index]
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(window_size)
	var area := DisplayServer.screen_get_usable_rect(DisplayServer.window_get_current_screen())
	DisplayServer.window_set_position(area.position + (area.size - window_size) / 2)
	_sync_viewport_buttons()
	
	SoundBank.play_sfx("ui_click")


func _on_mode_pressed(index: int) -> void:
	DisplayServer.window_set_mode(WINDOW_MODES[index])
	_sync_viewport_buttons()
	
	SoundBank.play_sfx("ui_click")


## Lights up the buttons that match the current window.
func _sync_viewport_buttons() -> void:
	var mode := DisplayServer.window_get_mode()
	if mode == DisplayServer.WINDOW_MODE_MAXIMIZED or mode == DisplayServer.WINDOW_MODE_MINIMIZED:
		mode = DisplayServer.WINDOW_MODE_WINDOWED
	var window_size := DisplayServer.window_get_size()
	for i in _mode_buttons.size():
		(_mode_buttons[i] as Button).set_pressed_no_signal(WINDOW_MODES[i] == mode)
	for i in _resolution_buttons.size():
		(_resolution_buttons[i] as Button).set_pressed_no_signal(mode == DisplayServer.WINDOW_MODE_WINDOWED and RESOLUTIONS[i] == window_size)
	for button in _resolution_buttons + _mode_buttons:
		var fade := button.get_node_or_null(^"HoverFade") as HoverFade
		if fade:
			fade.refresh()

#endregion


#region Pop-ups

func _ask_quit() -> void:
	if _busy:
		return
	SoundBank.play_sfx("ui_message")
	_busy = true
	var choice := await DesktopPopup.ask(self, "Exit", "Don't leave me...", ["Yes", "No"], "Yes")
	_busy = false
	if choice == "Yes":
		get_tree().quit()
	else:
		SoundBank.play_sfx("ui_back")
		_quit_button.grab_focus()


func _ask_reset() -> void:
	if _busy:
		return
	SoundBank.play_sfx("ui_message")
	_busy = true
	var choice := await DesktopPopup.ask(self, "Reset game", "This erases your save, settings and controls.\nAre you sure?", ["Reset", "Cancel"], "Reset", false)
	_busy = false
	if choice == "Reset":
		_reset_everything()
		SoundBank.play_sfx("ui_error")
	else: SoundBank.play_sfx("ui_back")
	%ResetGameButton.grab_focus()


## Same reset as the template's old menu: audio, save file, keybinds.
func _reset_everything() -> void:
	SettingsManager.master_vol = 1.0
	SettingsManager.music_vol = 1.0
	SettingsManager.sfx_vol = 1.0
	SettingsManager.save_settings()
	for slider in _sliders:
		slider.set_value_no_signal(1.0)
	if FileAccess.file_exists(GameManager.SAVE_PATH):
		DirAccess.remove_absolute(GameManager.SAVE_PATH)
	SaveManager.delete_save()
	SettingsManager.reset_keybinds_to_default()
	_update_last_saved()

#endregion
