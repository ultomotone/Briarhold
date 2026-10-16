## The screenshot gate. Windowed run (headless renders nothing):
##   godot --path . --windowed --resolution 1600x900 --log-file logs/shot.log res://tools/shot.tscn
## Boots main.tscn from the fixture save, waits, captures, checks the image is not uniform, poses
## a throw and captures again, then a night shot. Exit 0 clean · 1 game broke · 2 harness broke.
extends Node

const OUT: String = "res://logs/"
const FIXTURE: String = "res://tests/fixtures/save-v1.json"


func _ready() -> void:
	var packed: Variant = load("res://game/main.tscn")
	if packed == null or not packed is PackedScene:
		_quit(2, "main.tscn missing")
		return
	var scene: PackedScene = packed
	var game: Node = scene.instantiate()
	if not game is Main:
		_quit(2, "main.tscn root is not Main")
		return
	var main: Main = game
	add_child(main)
	main.boot_for_shot(FIXTURE)
	await _settle(75)
	if not await _capture("latest-desktop.png"):
		return
	main.shot_pose("throw")
	await _settle(18)
	if not await _capture("latest-throw.png"):
		return
	main.shot_pose("whistle")
	await _settle(40)
	if not await _capture("latest-whistle.png"):
		return
	main.shot_pose("region:wire_fence")
	await _settle(45)
	if not await _capture("latest-region-fence.png"):
		return
	main.shot_pose("region:mere")
	await _settle(45)
	if not await _capture("latest-region-mere.png"):
		return
	main.shot_pose("bestiary")
	await _settle(30)
	if not await _capture("latest-bestiary.png"):
		return
	main.shot_pose("far")
	await _settle(40)
	if not await _capture("latest-far.png"):
		return
	main.shot_pose("night")
	await _settle(30)
	if not await _capture("latest-night.png"):
		return
	# the title, for the shell
	main.quit_to_title()
	await _settle(10)
	if not await _capture("latest-title.png"):
		return
	_quit(0, "ok")


func _settle(frames: int) -> void:
	for i: int in frames:
		await get_tree().physics_frame
	await RenderingServer.frame_post_draw


func _capture(name: String) -> bool:
	var img: Image = get_viewport().get_texture().get_image()
	if img == null or img.is_empty():
		_quit(1, "rendered nothing for " + name)
		return false
	if _is_uniform(img):
		_quit(1, "uniform image for " + name)
		return false
	var err: Error = img.save_png(ProjectSettings.globalize_path(OUT + name))
	if err != OK:
		_quit(2, "cannot write " + name)
		return false
	print("SHOT wrote " + name)
	return true


func _is_uniform(img: Image) -> bool:
	var w: int = img.get_width()
	var h: int = img.get_height()
	var first: Color = img.get_pixel(0, 0)
	for i: int in 16:
		for j: int in 16:
			var c: Color = img.get_pixel(int((float(i) + 0.5) / 16.0 * float(w)), int((float(j) + 0.5) / 16.0 * float(h)))
			if absf(c.r - first.r) > 0.02 or absf(c.g - first.g) > 0.02 or absf(c.b - first.b) > 0.02:
				return false
	return true


func _quit(code: int, why: String) -> void:
	print("SHOT %d %s" % [code, why])
	get_tree().quit(code)
