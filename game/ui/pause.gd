## Escape: freezes the world under a glass panel. Resume, Save, Settings, the full control list,
## Quit to title. It never ejects him from the game.
class_name Pause
extends CanvasLayer

var pal: PaletteData
var main: Main
var _settings: SettingsPanel


func build(p: PaletteData, m: Main) -> void:
	pal = p
	main = m
	layer = 8
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.03, 0.04, 0.45)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 30)
	centre.add_child(row)
	var menu := VBoxContainer.new()
	menu.add_theme_constant_override("separation", 10)
	row.add_child(menu)
	menu.add_child(UiKit.label(pal, "Paused", 30, 1.0, true))
	var b_resume := UiKit.button(pal, "Resume")
	b_resume.pressed.connect(func() -> void:
		main.mode = Main.Mode.PLAY
		close())
	menu.add_child(b_resume)
	var b_save := UiKit.button(pal, "Save")
	b_save.pressed.connect(func() -> void: main.save_game("by hand"))
	menu.add_child(b_save)
	var b_set := UiKit.button(pal, "Settings")
	b_set.pressed.connect(func() -> void: _settings.visible = not _settings.visible)
	menu.add_child(b_set)
	var b_quit := UiKit.button(pal, "Quit to title")
	b_quit.pressed.connect(func() -> void: main.quit_to_title())
	menu.add_child(b_quit)
	var controls := UiKit.panel(pal, 0.85)
	row.add_child(controls)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 3)
	controls.add_child(cv)
	cv.add_child(UiKit.label(pal, "Controls", 18, 1.0, true))
	var lines: PackedStringArray = [
		"W A S D   move",
		"Right-click   walk there",
		"Left-click   sword (behind a foe: backstrike)",
		"Space   throw the selected sprig at the cursor",
		"R (hold)   whistle: the ring grows, sprigs come",
		"X   dismiss the squad into piles by type",
		"C   charge the selected type at the cursor",
		"Shift (hold)   swarm the squad toward the cursor",
		"Q / E   select sprig type",
		"F (hold)   pluck sprouts",
		"Z / V   turn the camera · wheel zooms",
		"Esc   this menu",
	]
	for l: String in lines:
		cv.add_child(UiKit.label(pal, l, 13, 0.85))
	_settings = SettingsPanel.new()
	_settings.build(pal, main.settings, Callable(self, "_settings_changed"))
	_settings.visible = false
	row.add_child(_settings)


func _settings_changed() -> void:
	if main.fx != null:
		main.fx.reduced_motion = main.settings.reduced_motion
	main.rig.reduced_motion = main.settings.reduced_motion


func open() -> void:
	visible = true
	_settings.visible = false


func close() -> void:
	visible = false
