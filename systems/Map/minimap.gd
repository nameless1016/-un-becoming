extends CanvasLayer
class_name Minimap

## Displays an in-game HUD minimap representing the player's active room sector.
##
## Tracks room bounds, dynamically translates world positions into UI space,
## caches static room architecture (walls, teleporters, transit stops), and
## continuously updates mobile entities, player position, and orientation needles.

## Screen corner anchor presets for placing the minimap canvas panel.
enum Spot {
	TOP_LEFT,
	TOP_RIGHT,
	BOTTOM_LEFT,
	BOTTOM_RIGHT
}

@export_group("Layout")
## Corner of the viewport where the minimap anchors.
@export var corner: Spot = Spot.TOP_RIGHT
## Dimensions of the minimap UI panel in pixels.
@export var panel_size: Vector2 = Vector2(150, 150)
## Distance from the edges of the viewport in pixels.
@export var margin: float = 16.0

@export_group("Tracking")
## Whether to render registered interactable objects and NPCs on the map.
@export var show_entities: bool = true
## Target node to track. If left unassigned, automatically resolves "TopDownPlayer".
@export var player: Node2D
## Group the player is in, used when no player is assigned
@export var player_group: StringName = &"player"

## Internal padding between the panel boundary and drawn map content.
const PAD := 8.0

# --- UI Containers ---
var panel: Panel
var static_layer: Control
var dynamic_layer: Control

# --- Active Room Geometry Cache ---
var current_room: RoomBounds
var room_rect: Rect2
var scale_f: float = 1.0
var origin: Vector2 = Vector2.ZERO

# --- Static Marker Coordinates (Minimap Space) ---
var wall_rects: Array[Rect2] = []
var door_points: Array[Vector2] = []
var stop_points: Array[Vector2] = []


func _ready() -> void:
	layer = 10
	visible = true

	if player == null:
		player = get_tree().get_first_node_in_group(player_group) as Node2D

	build_ui()
	current_room = find_room()
	refresh_room()


## Builds the minimap backdrop panel and registers static and dynamic drawing surfaces.
func build_ui() -> void:
	panel = Panel.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.0, 0.0, 0.0, 0.90)
	sb.border_color = Color(1.0, 1.0, 1.0, 0.85)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(2)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)
	place_panel()

	static_layer = Control.new()
	static_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	static_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	static_layer.draw.connect(_draw_static)
	panel.add_child(static_layer)

	dynamic_layer = Control.new()
	dynamic_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	dynamic_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dynamic_layer.draw.connect(_draw_dynamic)
	panel.add_child(dynamic_layer)


## Computes anchor points and screen offsets based on the selected corner spot.
func place_panel() -> void:
	var right := corner == Spot.TOP_RIGHT or corner == Spot.BOTTOM_RIGHT
	var bottom := corner == Spot.BOTTOM_LEFT or corner == Spot.BOTTOM_RIGHT
	var ax := 1.0 if right else 0.0
	var ay := 1.0 if bottom else 0.0

	panel.anchor_left = ax
	panel.anchor_right = ax
	panel.anchor_top = ay
	panel.anchor_bottom = ay

	var x0 := -panel_size.x - margin if right else margin
	var y0 := -panel_size.y - margin if bottom else margin
	panel.offset_left = x0
	panel.offset_right = x0 + panel_size.x
	panel.offset_top = y0
	panel.offset_bottom = y0 + panel_size.y


func _process(_delta: float) -> void:
	if player == null:
		# the player might not be in the tree yet, keep looking
		player = get_tree().get_first_node_in_group(player_group) as Node2D
		if player == null:
			return

	var room := find_room()
	if room != null and room != current_room:
		current_room = room
		refresh_room()

	if visible:
		dynamic_layer.queue_redraw()


## Locates the RoomBounds node encapsulating the player's current global position.
func find_room() -> RoomBounds:
	if player == null:
		return null
	for node in get_tree().get_nodes_in_group("room_bounds"):
		var room := node as RoomBounds
		if room != null and room.get_rect().has_point(player.global_position):
			return room
	return null


## Projects world-space coordinates into the minimap panel's local drawing coordinate space.
func to_map(world: Vector2) -> Vector2:
	return origin + (world - room_rect.position) * scale_f


## Recalculates aspect-ratio scaling and caches static map geometry (walls, POIs) for the current room.
func refresh_room() -> void:
	wall_rects.clear()
	door_points.clear()
	stop_points.clear()

	if current_room == null:
		static_layer.queue_redraw()
		return

	room_rect = current_room.get_rect()

	# TileMapLayer rooms: shrink the map to the walls so there's no empty margin
	var layer_walls := collect_layer_walls()
	if not layer_walls.is_empty():
		room_rect = layer_walls[0]
		for r in layer_walls:
			room_rect = room_rect.merge(r)

	var area := panel_size - Vector2(PAD * 2.0, PAD * 2.0)
	scale_f = minf(area.x / room_rect.size.x, area.y / room_rect.size.y)
	var drawn := room_rect.size * scale_f
	origin = Vector2(PAD, PAD) + (area - drawn) * 0.5

	var tm := get_parent().get_node_or_null("TileMap") as TileMap
	if tm != null and tm.tile_set != null:
		var ts := Vector2(tm.tile_set.tile_size)
		for cell in tm.get_used_cells(0):
			var center := tm.to_global(tm.map_to_local(cell))
			if room_rect.has_point(center):
				wall_rects.append(Rect2(to_map(center - ts * 0.5), ts * scale_f))

	for r in layer_walls:
		wall_rects.append(Rect2(to_map(r.position), r.size * scale_f))

	for node in get_parent().find_children("*", "Area2D", true, false):
		var area2d := node as Area2D
		if area2d == null or not room_rect.has_point(area2d.global_position):
			continue
		if area2d is SubwayStop:
			stop_points.append(to_map(area2d.global_position))
		elif area2d is Teleporter:
			door_points.append(to_map(area2d.global_position))

	static_layer.queue_redraw()


## Finds the real blocking area of every wall tile in TileMapLayer rooms (world space).
## Only layers with collision count, and tiles without collision (like a doorway) are skipped.
func collect_layer_walls() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for node in get_parent().find_children("*", "TileMapLayer", true, false):
		var layer := node as TileMapLayer
		if layer == null or layer.tile_set == null or layer.tile_set.get_physics_layers_count() == 0:
			continue
		for cell in layer.get_used_cells():
			var data := layer.get_cell_tile_data(cell)
			if data == null or data.get_collision_polygons_count(0) == 0:
				continue
			var pts := data.get_collision_polygon_points(0, 0)
			if pts.is_empty():
				continue
			var lo := pts[0]
			var hi := pts[0]
			for pt in pts:
				lo = lo.min(pt)
				hi = hi.max(pt)
			var center := layer.to_global(layer.map_to_local(cell))
			var rect := Rect2(center + lo, hi - lo)
			if current_room.get_rect().grow(8.0).intersects(rect):
				out.append(rect)
	return out


## Draws static visual elements including the floor boundary, walls, teleporters, and subway stops.
func _draw_static() -> void:
	if current_room == null:
		return

	static_layer.draw_rect(Rect2(origin, room_rect.size * scale_f), Color(0.12, 0.12, 0.12, 0.95))

	for r in wall_rects:
		static_layer.draw_rect(r, Color(0.55, 0.55, 0.55))

	for p in door_points:
		static_layer.draw_circle(p, 4.0, Color(0.0, 0.0, 0.0))
		static_layer.draw_circle(p, 2.5, Color(1.0, 1.0, 1.0))

	for p in stop_points:
		static_layer.draw_rect(Rect2(p - Vector2(3.5, 3.5), Vector2(7, 7)), Color(0.0, 0.0, 0.0))
		static_layer.draw_rect(Rect2(p - Vector2(2.5, 2.5), Vector2(5, 5)), Color(0.85, 0.85, 0.85))


## Draws dynamic real-time elements including NPC markers, radar pulses, directional needles, and the player pip.
func _draw_dynamic() -> void:
	if player == null or current_room == null:
		return

	if show_entities and EntitySettings.show_on_minimap:
		for node in get_tree().get_nodes_in_group("interactables"):
			var e := node as Interactable
			if e == null or not e.show_on_minimap:
				continue
			if not room_rect.has_point(e.global_position):
				continue
			e.draw_minimap_icon(dynamic_layer, to_map(e.global_position))

	var p := to_map(player.global_position).clamp(origin, origin + room_rect.size * scale_f)

	var pulse := 1.0 + sin(Time.get_ticks_msec() / 1000.0 * 5.0) * 0.2
	dynamic_layer.draw_circle(p, 5.5 * pulse, Color(1.0, 1.0, 1.0, 0.18))

	if "rotation" in player:
		var forward := Vector2.RIGHT.rotated(player.rotation)
		var tip := p + forward * 6.5
		var left := p + forward.rotated(deg_to_rad(140.0)) * 4.0
		var right := p + forward.rotated(deg_to_rad(-140.0)) * 4.0
		dynamic_layer.draw_colored_polygon(PackedVector2Array([tip, left, right]), Color(1.0, 1.0, 1.0))

	dynamic_layer.draw_circle(p, 3.5, Color(0.0, 0.0, 0.0))
	dynamic_layer.draw_circle(p, 2.0, Color(1.0, 1.0, 1.0))
