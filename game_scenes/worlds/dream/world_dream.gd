extends Node2D

func _ready() -> void:
	MusicManager.change_music("dream", 1)
	FileManager.allow_keybinds = true
