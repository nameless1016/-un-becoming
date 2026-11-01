extends Node2D

func _ready() -> void:
	#MusicManager.change_music("outside", 0.5)
	MusicManager.change_music_sync("outside", 0.1)
	FileManager.allow_keybinds = true
