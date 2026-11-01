extends Node2D

# the engine hum, plays the whole time you're on the bus
const ENGINE_SFX := "res://sound/sfx/sfx_bus_engine.mp3"
@export var engine_volume_db: float = -6.0

func _ready() -> void:
	MusicManager.change_music("outside", 0.5)
	start_engine()

func start_engine() -> void:
	var stream := load(ENGINE_SFX) as AudioStreamMP3
	if stream == null:
		push_warning("couldn't load the bus engine sound at " + ENGINE_SFX)
		return
	# so it keeps humming instead of stopping when the file ends
	stream.loop = true
	
	var player := AudioStreamPlayer.new()
	player.stream = stream
	# goes through the SFX volume slider, falls back to Master if there's no SFX bus
	player.bus = "SFX" if AudioServer.get_bus_index("SFX") != -1 else "Master"
	player.volume_db = -40.0
	add_child(player)
	player.play()
	
	# fade in so it doesn't pop
	create_tween().tween_property(player, "volume_db", engine_volume_db, 1.0)
