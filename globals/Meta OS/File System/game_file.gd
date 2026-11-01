@tool
class_name GameFile
extends Resource

## Data resource representing either a desktop folder file or an inventory item.

enum Destination { FILE_SYSTEM, ITEM_DOCK }
enum Category { ENTRY, ABOUT, PHOTO, EXECUTABLE, SECRET, ITEM }

enum CipherType {
	NONE,
	REVERSED,
	CAESAR,
	VIGENERE,
	BASE32,
	BASE64,
	ASCII85,
	MORSE,
	NIHILIST
}

@export_group("Identification")
@export var file_id: String = "file_001":
	set(val):
		file_id = val
		_sync_inspector_name()

@export var filename: String = "journal_01.txt":
	set(val):
		filename = val
		_sync_inspector_name()

@export var destination: Destination = Destination.FILE_SYSTEM
@export var category: Category = Category.ENTRY
@export var icon: Texture2D

@export_group("Folder File Properties")
@export_multiline var description: String = ""
@export_multiline var content: String = "Default raw content."

@export_group("Item Dock Properties")
@export var item_size: String = "12KB"
@export var item_location: String = "apartment"
@export_multiline var short_description: String = ""

@export_group("Cipher & Decryption")
@export var cipher_type: CipherType = CipherType.NONE
@export var cipher_key: String = ""
@export var cipher_shift: int = 0
@export_multiline var solved_content: String = ""
@export var is_solved: bool = false

@export_group("Ghost Hints")
@export_multiline var ghost_hint_unsolved: String = "It's encrypted. I can't read it yet."
@export_multiline var ghost_hint_solved: String = "I remember this now."

@export_group("Terminal Command Permissions")
@export var can_interpret: bool = false
@export var can_rearrange: bool = false
@export var can_decode: bool = false
@export var can_execute: bool = false
@export var can_intervene: bool = false


## Automatically sets Godot's built-in resource_name so the Inspector displays the file's name
func _sync_inspector_name() -> void:
	resource_name = "%s [%s]" % [filename, file_id]
