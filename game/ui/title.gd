## The title: New Hold, Continue, Load, Settings, Quit, and a version stamp so he can always say
## which build he is looking at.
class_name Title
extends CanvasLayer

var pal: PaletteData
var main: Main
var _menu: VBoxContainer
var _loads: VBoxContainer
var _settings: SettingsPanel
var _continue: Button


func build(p: PaletteData, m: Main) -> void:
	pal = p
	main = m
	layer = 10
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.07, 0.08, 0.72)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 40)
	centre.add_child(row)
	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override("separation", 10)
	row.add_child(_menu)
	var name := UiKit.label(pal, "Briarhold", 54, 1.0, true)
	name.add_theme_color_override("font_color", pal.col("hud_accent"))
	_menu.add_child(name)
	_menu.add_child(UiKit.label(pal, "A thumb-high gnome. A kingdom gone to briar. Sprigs at your heel.", 14, 0.75))
	_menu.add_child(UiKit.spacer(14.0))
	var b_new := UiKit.button(pal, "New Hold")
	b_new.pressed.connect(func() -> void: main.new_game())
	_menu.add_child(b_new)
	_continue = UiKit.button(pal, "Continue")
	_continue.pressed.connect(func() -> void: main.continue_game())
	_menu.add_child(_continue)
	var b_load := UiKit.button(pal, "Load")
	b_load.pressed.connect(func() -> void: _toggle_loads())
	_menu.add_child(b_load)
	var b_set := UiKit.button(pal, "Settings")
	b_set.pressed.connect(func() -> void: _settings.visible = not _settings.visible)
	_menu.add_child(b_set)
	var b_quit := UiKit.button(pal, "Quit")
	b_quit.pressed.connect(func() -> void: main.get_tree().quit())
	_menu.add_child(b_quit)
	_loads = VBoxContainer.new()
	_loads.add_theme_constant_override("separation", 6)
	_loads.visible = false
	row.add_child(_loads)
	_settings = SettingsPanel.new()
	_settings.build(pal, main.settings, Callable())
	_settings.visible = false
	row.add_child(_settings)
	var stamp := UiKit.label(pal, "v%s · Godot %s · %s" % [ProjectSettings.get_setting("application/config/version", "0"), Engine.get_version_info()["string"], _build_date()], 12, 0.55)
	stamp.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	stamp.anchor_top = 1.0
	stamp.anchor_bottom = 1.0
	stamp.offset_left = 18.0
	stamp.offset_top = -40.0
	add_child(stamp)


func open() -> void:
	visible = true
	_loads.visible = false
	_settings.visible = false
	_continue.disabled = SaveStore.list_slots().is_empty()
	_continue.grab_focus()


func _toggle_loads() -> void:
	_loads.visible = not _loads.visible
	for c: Node in _loads.get_children():
		c.queue_free()
	if not _loads.visible:
		return
	_loads.add_child(UiKit.label(pal, "Holds on disk", 16, 1.0, true))
	var slots: Array[Dictionary] = SaveStore.list_slots()
	if slots.is_empty():
		_loads.add_child(UiKit.label(pal, "None yet.", 13, 0.7))
	for s: Dictionary in slots:
		var b := UiKit.button(pal, "%s · day %d · %d sprigs · value %d · %s" % [str(s["slot"]), int(s["day"]), int(s["sprigs"]), int(s["value"]), UiKit.ago(int(s["saved_at"]))], 13)
		b.custom_minimum_size = Vector2(420.0, 40.0)
		var slot_name: String = str(s["slot"])
		b.pressed.connect(func() -> void: main.load_slot(slot_name))
		_loads.add_child(b)


static func _build_date() -> String:
	var f := FileAccess.open("res://BUILD_STAMP.txt", FileAccess.READ)
	if f == null:
		return "dev"
	var s: String = f.get_line().strip_edges()
	f.close()
	return s if not s.is_empty() else "dev"
