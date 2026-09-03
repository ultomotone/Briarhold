## The settings box, shared by the title and the pause menu.
class_name SettingsPanel
extends PanelContainer

var store: SettingsStore
var on_change: Callable


func build(pal: PaletteData, s: SettingsStore, changed: Callable) -> void:
	store = s
	on_change = changed
	add_theme_stylebox_override("panel", UiKit.glass(pal, 0.85))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	add_child(v)
	v.add_child(UiKit.label(pal, "Settings", 20, 1.0, true))
	var fs := CheckButton.new()
	fs.text = "Fullscreen"
	fs.button_pressed = store.fullscreen
	fs.toggled.connect(func(on: bool) -> void:
		store.fullscreen = on
		_apply())
	v.add_child(fs)
	var rm := CheckButton.new()
	rm.text = "Reduced motion"
	rm.button_pressed = store.reduced_motion
	rm.toggled.connect(func(on: bool) -> void:
		store.reduced_motion = on
		_apply())
	v.add_child(rm)
	var row := HBoxContainer.new()
	row.add_child(UiKit.label(pal, "UI scale", 15))
	var sl := HSlider.new()
	sl.min_value = 0.75
	sl.max_value = 1.5
	sl.step = 0.05
	sl.value = store.ui_scale
	sl.custom_minimum_size = Vector2(180.0, 20.0)
	sl.value_changed.connect(func(val: float) -> void:
		store.ui_scale = val
		_apply())
	row.add_child(sl)
	v.add_child(row)
	v.add_child(UiKit.label(pal, "Camera: Z and V turn, wheel zooms. The cursor is never captured.", 12, 0.7))


func _apply() -> void:
	store.save_to_disk()
	store.apply_window()
	if on_change.is_valid():
		on_change.call()
