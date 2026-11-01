extends Node2D

func _ready() -> void:
	MusicManager.change_music("outside")
	FileManager.allow_keybinds = true
