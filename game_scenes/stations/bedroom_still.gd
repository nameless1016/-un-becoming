extends PointAndClickScene
## The bedroom still. The redacted "///// ////" object on the floor isn't readable:
## clicking it shows an error pop-up (MetaOS, the team's pop-up system) instead
## of dialogue.

const REDACTED_LOCK := &"redacted_error"


func _handle_hotspot(hotspot: Hotspot) -> void:
	if hotspot.name == &"Hotspot_Redacted":
		_show_redacted_error()
		return
	super(hotspot)


func _show_redacted_error() -> void:
	lock_input(REDACTED_LOCK)
	SoundBank.play_sfx("ui_error", Vector2.ZERO, 1.0, 1.0)
	await MetaOS.show_critical_error("ERROR", "///// ////\nThis file could not be read.")
	unlock_input(REDACTED_LOCK)
