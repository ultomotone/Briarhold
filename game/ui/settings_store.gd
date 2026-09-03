## Settings that actually exist: fullscreen, reduced motion, UI scale. Saved to user://settings.json.
class_name SettingsStore
extends RefCounted

const PATH: String = "user://settings.json"

var fullscreen: bool = true
var reduced_motion: bool = false
var ui_scale: float = 1.0


func load_from_disk() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var j := JSON.new()
	if j.parse(FileAccess.get_file_as_string(PATH)) != OK:
		return
	if not j.data is Dictionary:
		return
	var d: Dictionary = j.data
	fullscreen = bool(d.get("fullscreen", fullscreen))
	reduced_motion = bool(d.get("reduced_motion", reduced_motion))
	ui_scale = clampf(float(d.get("ui_scale", ui_scale)), 0.75, 1.5)


func save_to_disk() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify({"fullscreen": fullscreen, "reduced_motion": reduced_motion, "ui_scale": ui_scale}, "\t"))
	f.close()


func apply_window() -> void:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var w: Window = tree.root
	if OS.has_feature("editor") or DisplayServer.get_name() == "headless":
		return
	w.mode = Window.MODE_FULLSCREEN if fullscreen else Window.MODE_MAXIMIZED
	w.content_scale_factor = ui_scale
