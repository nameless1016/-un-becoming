class_name StoryUnlocks
extends RefCounted
## Turns the unlock signals in our dialogue into RJ's file system. A timeline sends
## e.g. [signal arg="obtain:item:notebook"]; the scene playing it calls
## [method handle], which pauses the dialogue, adds the file, shows MetaOS's
## "Obtained" pop-up (the team's pop-up system) and resumes.
##
## Signals with no match in RJ's database yet are only logged.

## Our obtain signals -> file_id in master_file_database.tres.
const FILES := {
	"obtain:item:notebook": "item_notebook",
	"obtain:item:picture_frame": "item_picture_frame",
	"obtain:item:glue": "item_glue",
	"obtain:about:friend_1": "about_friend_1",
	"obtain:about:friend_2": "about_friend_2",
	"obtain:about:friend_3": "about_friend_3",
	"obtain:about:machine": "about_ghost_machine",
	# The fridge's "???" about file. The brief keeps The Order unnamed until Act 3,
	# so the pop-up says "???" even though the file is The_Order.info.
	"obtain:about:unknown": "about_the_order",
}
## What the pop-up shows instead of the real file name, where it must stay hidden.
const SHOWN_AS := {
	"about_the_order": "???.info",
}
## Our unlock signals -> terminal command ids (1 Interpret, 2 Rearrange, ...).
const COMMANDS := {
	"unlock:command:interpret": 1,
	"unlock:command:rearrange": 2,
}


## True for any obtain:/unlock: signal, so callers can skip the rest.
static func is_story_signal(argument: Variant) -> bool:
	var text := str(argument)
	return text.begins_with("obtain:") or text.begins_with("unlock:")


static func handle(argument: Variant) -> void:
	var text := str(argument)
	if COMMANDS.has(text):
		FileManager.unlock_terminal_command(COMMANDS[text])
		return
	if not FILES.has(text):
		if is_story_signal(text):
			print("[StoryUnlocks] No file system match yet for '%s'." % text)
		return
	var file_id: String = FILES[text]
	if FileManager.collected_files.has(file_id):
		return
	Dialogic.paused = true
	FileManager.obtain_file_by_id(file_id)
	var file = FileManager.collected_files.get(file_id)
	var shown: String = SHOWN_AS.get(file_id, file.filename if file else file_id)
	await MetaOS.show_dialog("Obtained", shown, ["CLOSE"], "txt")
	Dialogic.paused = false
