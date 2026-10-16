## The layout over the world: what the fight runs on is on screen, never in a menu.
## Top-left: day, clock, his health. Top-right: the Hold total, field count against the cap.
## Bottom: the squad by type with the selected type marked; the log; the controls.
class_name Hud
extends CanvasLayer

var pal: PaletteData
var tables: ContentTables
var _day: Label
var _clock: Label
var _hp: ProgressBar
var _daybar: ProgressBar
var _total: Label
var _field: Label
var _relics: Label
var _lost: Label
var _chips: HBoxContainer
var _chip_nodes: Dictionary = {} # type_id -> {panel, count}
var _log: Label
var _banner: Label
var _banner_t: float = 0.0
var _hint: Label
var _cursor_hint: Label
var _map: Minimap


func build(p: PaletteData, t: ContentTables) -> void:
	pal = p
	tables = t
	layer = 5
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	# top-left
	var tl := UiKit.panel(pal)
	tl.set_anchors_preset(Control.PRESET_TOP_LEFT)
	tl.position = Vector2(18.0, 18.0)
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tl)
	var tlv := VBoxContainer.new()
	tlv.add_theme_constant_override("separation", 4)
	tl.add_child(tlv)
	var name := UiKit.label(pal, "Briarhold", 22, 1.0, true)
	name.add_theme_color_override("font_color", pal.col("hud_accent"))
	tlv.add_child(name)
	_day = UiKit.label(pal, "Day 1", 14, 0.9, true)
	tlv.add_child(_day)
	_clock = UiKit.label(pal, "", 12, 0.75)
	tlv.add_child(_clock)
	_daybar = UiKit.bar(pal, pal.col("hud_accent"), 5.0)
	tlv.add_child(_daybar)
	tlv.add_child(UiKit.spacer(4.0))
	var hprow := HBoxContainer.new()
	hprow.add_child(UiKit.label(pal, "HP", 12, 0.8))
	_hp = UiKit.bar(pal, Color(0.55, 0.8, 0.5), 9.0)
	hprow.add_child(_hp)
	tlv.add_child(hprow)
	# top-right
	var tr := UiKit.panel(pal)
	tr.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	tr.anchor_left = 1.0
	tr.anchor_right = 1.0
	tr.offset_left = -290.0
	tr.offset_right = -18.0
	tr.offset_top = 18.0
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(tr)
	var trv := VBoxContainer.new()
	trv.add_theme_constant_override("separation", 3)
	tr.add_child(trv)
	trv.add_child(UiKit.label(pal, "Hold total", 12, 0.7, true))
	_total = UiKit.label(pal, "0", 30)
	_total.add_theme_color_override("font_color", pal.col("hud_accent"))
	trv.add_child(_total)
	_field = UiKit.label(pal, "", 13, 0.9)
	trv.add_child(_field)
	_relics = UiKit.label(pal, "", 13, 0.9)
	trv.add_child(_relics)
	_lost = UiKit.label(pal, "", 12, 0.7)
	trv.add_child(_lost)
	# the map, under the Hold panel
	_map = Minimap.new()
	_map.setup(pal, tables)
	_map.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_map.anchor_left = 1.0
	_map.anchor_right = 1.0
	_map.offset_left = -Minimap.SIZE - 18.0
	_map.offset_right = -18.0
	_map.offset_top = 214.0
	_map.offset_bottom = 214.0 + Minimap.SIZE
	root.add_child(_map)
	# bottom-centre chips
	_chips = HBoxContainer.new()
	_chips.add_theme_constant_override("separation", 8)
	_chips.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_chips.anchor_left = 0.5
	_chips.anchor_right = 0.5
	_chips.anchor_top = 1.0
	_chips.anchor_bottom = 1.0
	_chips.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_chips.offset_top = -74.0
	_chips.offset_bottom = -22.0
	_chips.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_chips)
	# bottom-left log
	_log = UiKit.label(pal, "", 13, 0.85)
	_log.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_log.anchor_top = 1.0
	_log.anchor_bottom = 1.0
	_log.offset_left = 20.0
	_log.offset_top = -150.0
	_log.offset_bottom = -20.0
	_log.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_log.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	_log.add_theme_constant_override("shadow_offset_x", 1)
	_log.add_theme_constant_override("shadow_offset_y", 1)
	root.add_child(_log)
	# bottom-right controls
	_hint = UiKit.label(pal, "WASD move · right-click walk · left-click sword\nSpace throw · R whistle · X dismiss · C charge · Shift swarm\nQ / E type · F pluck · at a shrine: F takes out, G sends in · Z / V camera · Esc pause", 12, 0.6)
	_hint.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_hint.anchor_left = 1.0
	_hint.anchor_top = 1.0
	_hint.anchor_right = 1.0
	_hint.anchor_bottom = 1.0
	_hint.offset_left = -620.0
	_hint.offset_top = -80.0
	_hint.offset_right = -20.0
	_hint.offset_bottom = -20.0
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_hint.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.8))
	_hint.add_theme_constant_override("shadow_offset_x", 1)
	_hint.add_theme_constant_override("shadow_offset_y", 1)
	root.add_child(_hint)
	# centre banner
	_banner = UiKit.label(pal, "", 26, 1.0, true)
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.anchor_left = 0.5
	_banner.anchor_right = 0.5
	_banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner.offset_top = 90.0
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_color_override("font_color", pal.col("hud_warn"))
	_banner.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.9))
	_banner.add_theme_constant_override("shadow_offset_x", 2)
	_banner.add_theme_constant_override("shadow_offset_y", 2)
	_banner.visible = false
	root.add_child(_banner)


func reset() -> void:
	for id: Variant in _chip_nodes.keys():
		var d: Dictionary = _chip_nodes[id]
		var pn: Control = d["panel"]
		pn.queue_free()
	_chip_nodes.clear()
	_banner.visible = false


func handle(ev: Dictionary) -> void:
	match str(ev["kind"]):
		"dusk_warning":
			_show_banner("Dusk soon", 4.0)
		"night":
			_show_banner("Night", 4.0)
		"dawn":
			_show_banner("Dawn", 3.0)
		"knight_down":
			_show_banner("Down", 2.2)
		"region_found":
			_show_banner("Found: " + str(ev["name"]), 3.5)


func _show_banner(text: String, seconds: float) -> void:
	_banner.text = text.to_upper()
	_banner.visible = true
	_banner_t = seconds


func update(w: SimWorld, notes: Array[String], cursor: Vector3) -> void:
	_day.text = "DAY %d" % w.clock.day
	_clock.text = UiKit.clock_text(w.clock)
	_daybar.value = w.clock.time / w.clock.cycle()
	var fill: StyleBoxFlat = _daybar.get_theme_stylebox("fill")
	fill.bg_color = pal.col("hud_accent") if not w.clock.is_night() else pal.col("sprig_frost")
	_hp.value = w.knight.hp / maxf(1.0, w.knight.max_hp)
	_total.text = str(w.hold.total())
	_field.text = "In the field %d of %d   Inside shrines %d" % [w.field_count(), w.hold.cap, w.hold.stored_total()]
	_relics.text = "Relics %d   Value %d" % [w.hold.relics_banked, w.hold.value]
	_lost.text = "Lost tonight %d   Lost ever %d" % [w.lost_tonight, w.lost_total]
	_sync_chips(w)
	_map.show_world(w)
	_log.text = "\n".join(notes)
	if _banner.visible:
		_banner_t -= get_process_delta_time()
		if _banner_t <= 0.0:
			_banner.visible = false


func _sync_chips(w: SimWorld) -> void:
	var census: Dictionary = w.census()
	var order: PackedStringArray = tables.sprig_order
	for id: String in order:
		var n: int = int(census.get(id, 0))
		var following: int = w.squad_count(id)
		var have: bool = n > 0 or int(w.hold.stored.get(id, 0)) > 0
		if not have:
			if _chip_nodes.has(id):
				var d: Dictionary = _chip_nodes[id]
				var pn: Control = d["panel"]
				pn.queue_free()
				_chip_nodes.erase(id)
			continue
		if not _chip_nodes.has(id):
			_chip_nodes[id] = _make_chip(id)
		var d: Dictionary = _chip_nodes[id]
		var count: Label = d["count"]
		var inside: int = int(w.hold.stored.get(id, 0))
		count.text = "%d with you · %d in field · %d inside" % [following, n, inside]
		var pn: PanelContainer = d["panel"]
		var sb: StyleBoxFlat = pn.get_theme_stylebox("panel")
		var selected: bool = id == w.knight.selected_type
		sb.border_color = pal.col("hud_accent") if selected else Color(1.0, 1.0, 1.0, 0.07)
		sb.border_width_bottom = 2 if selected else 1
		sb.bg_color.a = 0.8 if selected else pal.num("hud_glass_alpha")
	# keep chips in table order
	for i: int in order.size():
		var id: String = order[i]
		if _chip_nodes.has(id):
			var d: Dictionary = _chip_nodes[id]
			var pn: Control = d["panel"]
			_chips.move_child(pn, mini(i, _chips.get_child_count() - 1))


func _make_chip(id: String) -> Dictionary:
	var t: Types.SprigType = tables.sprig(id)
	var pn := UiKit.panel(pal)
	pn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	pn.add_child(h)
	var sw := ColorRect.new()
	sw.color = pal.col(t.colour_key)
	sw.custom_minimum_size = Vector2(14.0, 26.0)
	h.add_child(sw)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	h.add_child(v)
	v.add_child(UiKit.label(pal, t.name, 13, 1.0, true))
	var count := UiKit.label(pal, "0 with you · 0 in field · 0 inside", 12, 0.75)
	v.add_child(count)
	_chips.add_child(pn)
	return {"panel": pn, "count": count}
