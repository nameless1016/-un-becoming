extends Node

# Central autoload managing in game dates and time periods.

signal time_changed(current_slot: TimeSlot)
signal day_changed(year: int, month: int, day: int)

# The five distinct time periods of each day.
enum TimeSlot { MORNING, NOON, AFTERNOON, EVENING, MIDNIGHT }

var current_year: int = 2012
var current_month: int = 10
var current_day: int = 27
var current_slot: TimeSlot = TimeSlot.NOON


# Call this function to advance time by one slot.
func advance_time_slot() -> void:
	if current_slot == TimeSlot.MIDNIGHT:
		sleep_to_next_day()
	else:
		current_slot = (current_slot + 1) as TimeSlot
		time_changed.emit(current_slot)


# Advances the date to the next morning when sleeping in bed.
func sleep_to_next_day() -> void:
	current_slot = TimeSlot.MORNING
	current_day += 1
	
	var days_in_month: int = _get_days_in_month(current_year, current_month)
	if current_day > days_in_month:
		current_day = 1
		current_month += 1
		if current_month > 12:
			current_month = 1
			current_year += 1
			
	day_changed.emit(current_year, current_month, current_day)
	time_changed.emit(current_slot)


# Returns the three letter weekday string.
func get_weekday_name() -> String:
	var date_dict := {"year": current_year, "month": current_month, "day": current_day}
	var unix: int = Time.get_unix_time_from_datetime_dict(date_dict)
	var weekday_idx: int = Time.get_datetime_dict_from_unix_time(unix)["weekday"]
	var names := ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"]
	return names[weekday_idx % 7]


# Returns the readable name for the current time slot.
func get_slot_name() -> String:
	match current_slot:
		TimeSlot.MORNING: return "Morning"
		TimeSlot.NOON: return "Noon"
		TimeSlot.AFTERNOON: return "Afternoon"
		TimeSlot.EVENING: return "Evening"
		TimeSlot.MIDNIGHT: return "Midnight"
	return "Noon"


# Returns the sun or moon icon string.
func get_slot_symbol() -> String:
	match current_slot:
		TimeSlot.MORNING, TimeSlot.NOON, TimeSlot.AFTERNOON:
			return "☼"
		TimeSlot.EVENING, TimeSlot.MIDNIGHT:
			return "☽"
	return "☼"


# Helper calculating how many days are in each month.
func _get_days_in_month(y: int, m: int) -> int:
	if m in [4, 6, 9, 11]: return 30
	if m == 2: return 29 if (y % 4 == 0) else 28
	return 31
