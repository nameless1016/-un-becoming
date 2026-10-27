class_name GameFile
extends Resource

# Resource container for files, notes, photos, and inventory items.

# Enumeration for file categories.
enum Category { ENTRY, ABOUT, PHOTO, ITEM, SECRET }

# Enumeration for cipher types.
enum CipherType { NONE, ANAGRAM, CAESAR, BASE64, BINARY, INVERT_IMAGE }

@export var file_id: String = "file_001"
@export var filename: String = "journal_01.txt"
@export var category: Category = Category.ENTRY
@export_multiline var content: String = "Default raw content."

# Metadata shown in the item hover box on the right dock.
@export var item_size: String = "17KB"
@export var item_location: String = "bedroom"

# Cipher variables used by the terminal.
@export var cipher_type: CipherType = CipherType.NONE
@export_multiline var solved_content: String = ""
@export var is_solved: bool = false

# Ghost hint texts shown when selecting option 1 in the terminal.
@export_multiline var ghost_hint_unsolved: String = "It's encrypted. I can't read it yet."
@export_multiline var ghost_hint_solved: String = "I remember this now."

# Command permission switches.
# If a switch is false, the terminal prints an error message.
@export_group("Terminal Command Permissions")
@export var can_interpret: bool = false
@export var can_rearrange: bool = false
@export var can_decode: bool = false
@export var can_execute: bool = false
@export var can_intervene: bool = false
