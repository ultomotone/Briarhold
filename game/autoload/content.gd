## Autoload "Content": the one ContentTables the game runs on. Logic lives in sim/content_tables.gd.
extends Node

var tables: ContentTables


func _init() -> void:
	tables = ContentTables.load_all()
	for e: String in tables.errors:
		push_error("content: " + e)
