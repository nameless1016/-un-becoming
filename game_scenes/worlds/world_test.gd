extends Node2D

## Test bed controller for auditioning audio playback and music system transitions.
##
## Provides button signal hooks to test SoundBank SFX triggers, music track changes,
## and interactive dynamic threat/intensity layering managed by MusicManager.


## Triggers a spatial test sound effect through the SoundBank autoload.
func _on_play_sfx_pressed() -> void:
	SoundBank.play_sfx("test_sfx", Vector2i(79, 31))
	print("playing sfx")


## Switches the active background track to 'music1' with a crossfade.
func _on_play_music_1_pressed() -> void:
	MusicManager.change_music("music1", 0.5)
	print("playing music1")


## Switches the active background track to 'music2' with a crossfade.
func _on_play_music_2_pressed() -> void:
	MusicManager.change_music("music2", 0.5)
	print("playing music2")


## Halts playback of the current background music track.
func _on_stop_music_pressed() -> void:
	MusicManager.stop_music()
	print("music stopped")


## Increments the music system's threat/intensity level by 0.1 (clamped to 1.0).
func _on_threat_increase_pressed() -> void:
	if MusicManager.current_intensity >= 1.0:
		print("Music Manager's intensity is already max ", MusicManager.current_intensity)
		return
	MusicManager.set_intensity(MusicManager.current_intensity + 0.1, 0.5)
	print("intensity increased ", MusicManager.current_intensity)


## Decrements the music system's threat/intensity level by 0.1 (clamped to 0.0).
func _on_threat_decrease_pressed() -> void:
	if MusicManager.current_intensity <= 0.0:
		print("Music Manager's intensity is already minimum ", MusicManager.current_intensity)
		return
	MusicManager.set_intensity(MusicManager.current_intensity - 0.1, 0.5)
	print("intensity decreased ", MusicManager.current_intensity)
