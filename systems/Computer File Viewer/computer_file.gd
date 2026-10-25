class_name ComputerFile
extends Resource
## One file the player can open in a FileViewer: text, an image, or both.
## Save each as its own .tres so other systems (evidence, journal) can reference it.

@export var file_name: String = "untitled.txt"
## Shown next to the name, e.g. "Mar 14, 11:52 PM". Free text, not parsed.
@export var modified: String = ""
## Supports BBCode ([b], [i], [color], ...).
@export_multiline var body: String = ""
@export var image: Texture2D
