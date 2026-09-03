## Autoload "Palette": the one PaletteData the view reads. Logic lives in sim/palette_data.gd.
extends Node

var data: PaletteData


func _init() -> void:
	data = PaletteData.load_from("res://content/palette.json")


func col(key: String) -> Color:
	return data.col(key)


func num(key: String) -> float:
	return data.num(key)
