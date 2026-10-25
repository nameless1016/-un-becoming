class_name MapLocations

## Every place you can ride to. To add a new map, add one more entry here
## id is what the SubwayStop in that map uses as its location_id
## spawn is the name of the Marker2D under Spawns where you show up
## map_pos is where the label sits on the map screen, from 0 to 1 across the screen
const LIST = [
	{
		"id": "town",
		"name": "Downtown",
		"scene": "res://maps/map_town.tscn",
		"spawn": "SubwayArrive",
		"map_pos": Vector2(0.38, 0.36),
	},
	{
		"id": "shopping",
		"name": "Shopping Area",
		"scene": "res://maps/map_shopping.tscn",
		"spawn": "SubwayArrive",
		"map_pos": Vector2(0.20, 0.70),
	},
	{
		"id": "school",
		"name": "School",
		"scene": "res://maps/map_school.tscn",
		"spawn": "SubwayArrive",
		"map_pos": Vector2(0.60, 0.55),
	},
	{
		"id": "riverside",
		"name": "Riverside",
		"scene": "res://maps/map_riverside.tscn",
		"spawn": "SubwayArrive",
		"map_pos": Vector2(0.80, 0.28),
	},
]

static func get_location(id: String) -> Dictionary:
	for loc in LIST:
		if loc["id"] == id:
			return loc
	return {}
