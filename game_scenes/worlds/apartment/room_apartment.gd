extends Node2D

func _ready() -> void:
	MusicManager.change_music("outside", 0.5)
	FileManager.allow_keybinds = true
