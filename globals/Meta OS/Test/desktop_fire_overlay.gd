class_name DesktopFireOverlay
extends Window

# Monitor wide desktop fire running in the background behind the game window.

var heat_vignette: ColorRect
var ember_particles: CPUParticles2D
var active_tween: Tween


func _init() -> void:
	var screen_id: int = DisplayServer.get_primary_screen()
	size = DisplayServer.screen_get_size(screen_id)
	position = DisplayServer.screen_get_position(screen_id)
	
	borderless = true
	# Placed behind the game window instead of on top.
	always_on_top = false
	unresizable = true
	transient = false
	exclusive = false
	transparent = true
	transparent_bg = true
	mouse_passthrough = true
	title = "DESKTOP FIRE"
	
	_build_particles()


func _ready() -> void:
	hide()


# Starts the monitor wide fire and ember storm behind the game window.
func ignite(duration: float = 3.5) -> void:
	var screen_id: int = DisplayServer.get_primary_screen()
	size = DisplayServer.screen_get_size(screen_id)
	position = DisplayServer.screen_get_position(screen_id)
	
	heat_vignette.modulate.a = 0.0
	ember_particles.emitting = true
	show()
	
	# Keep the game window in the foreground so the fire stays in the desktop background.
	DisplayServer.window_move_to_foreground(DisplayServer.MAIN_WINDOW_ID)
	get_tree().root.get_window().grab_focus()
	
	if active_tween and active_tween.is_valid():
		active_tween.kill()
		
	# Subtle heat opacity capped at 0.28 so it remains soft on the eyes.
	active_tween = create_tween().set_parallel(true)
	active_tween.tween_property(heat_vignette, "modulate:a", 0.28, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)


# Fades the screen fire out.
func extinguish(fade_duration: float = 1.0) -> void:
	if active_tween and active_tween.is_valid():
		active_tween.kill()
		
	active_tween = create_tween().set_parallel(true)
	active_tween.tween_property(heat_vignette, "modulate:a", 0.0, fade_duration)
	active_tween.tween_property(ember_particles, "modulate:a", 0.0, fade_duration)
	
	await active_tween.finished
	ember_particles.emitting = false
	hide()


func _build_particles() -> void:
	# Subtle orange heat background tint with lowered base alpha.
	heat_vignette = ColorRect.new()
	heat_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	heat_vignette.color = Color(1.0, 0.32, 0.05, 0.85)
	heat_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(heat_vignette)
	
	# Burning embers rising up across the desktop screen.
	ember_particles = CPUParticles2D.new()
	ember_particles.position = Vector2(size.x / 2.0, size.y + 10)
	ember_particles.amount = 140
	ember_particles.lifetime = 4.5
	ember_particles.preprocess = 1.0
	ember_particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	ember_particles.emission_rect_extents = Vector2(size.x / 2.0, 10.0)
	
	ember_particles.direction = Vector2(0, -1)
	ember_particles.spread = 24.0
	ember_particles.gravity = Vector2(0, -55)
	ember_particles.initial_velocity_min = 160.0
	ember_particles.initial_velocity_max = 340.0
	ember_particles.scale_amount_min = 2.0
	ember_particles.scale_amount_max = 4.5
	
	# Softer transparency ramp for the embers.
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.95, 0.7, 0.75))
	grad.add_point(0.25, Color(1.0, 0.5, 0.0, 0.65))
	grad.add_point(0.7, Color(0.85, 0.15, 0.02, 0.45))
	grad.set_color(1, Color(0.2, 0.02, 0.0, 0.0))
	ember_particles.color_ramp = grad
	
	add_child(ember_particles)
