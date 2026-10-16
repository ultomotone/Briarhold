## The map, top right under the Hold panel: north-up (the default camera's up), the Hold and its
## safe ring, rooted shrines, the territories (a "?" until he has walked into one, then its name
## in its type's colour), the gnome as an arrow. Drawn, not textured; one redraw a frame.
class_name Minimap
extends Control

const SIZE: float = 200.0

var pal: PaletteData
var tables: ContentTables
var w: SimWorld
var _font: Font


func setup(p: PaletteData, t: ContentTables) -> void:
	pal = p
	tables = t
	custom_minimum_size = Vector2(SIZE, SIZE)
	size = Vector2(SIZE, SIZE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font


func show_world(world: SimWorld) -> void:
	w = world
	queue_redraw()


func _to_map(p: Vector3) -> Vector2:
	var half: float = SIZE * 0.5
	var scale_: float = (half - 8.0) / maxf(1.0, w.field.bound)
	return Vector2(half + p.x * scale_, half + p.z * scale_)


func _draw() -> void:
	if w == null:
		return
	var half: float = SIZE * 0.5
	var c := Vector2(half, half)
	var glass: Color = pal.col("hud_glass")
	glass.a = 0.78
	draw_circle(c, half, glass)
	var edge: Color = pal.col("hud_ink")
	edge.a = 0.18
	draw_arc(c, half - 1.0, 0.0, TAU, 64, edge, 1.5)
	# the field's own ground, a faint disc
	var field_c: Color = pal.col("terrain_moss")
	field_c.a = 0.35
	draw_circle(c, half - 8.0, field_c)
	var scale_: float = (half - 8.0) / maxf(1.0, w.field.bound)
	# the Hold
	var hold_p: Vector2 = _to_map(w.hold.pos)
	var ring: Color = pal.col("hold_ring")
	ring.a = 0.6
	draw_arc(hold_p, w.hold.safe_radius * scale_, 0.0, TAU, 32, ring, 1.0)
	draw_circle(hold_p, 3.5, pal.col("hold_ring"))
	# territories
	for r: Dictionary in w.regions:
		var rp: Vector2 = _to_map(r["pos"])
		var rr: float = float(r["radius"]) * scale_
		var known: bool = w.discovered.has(str(r["id"]))
		if known:
			var tc: Color = pal.col(tables.sprig(str(r["type"])).colour_key)
			var fill: Color = tc
			fill.a = 0.28
			draw_circle(rp, rr, fill)
			draw_arc(rp, rr, 0.0, TAU, 24, tc, 1.5)
			var label: String = str(r["name"]).replace("The ", "")
			draw_string(_font, rp + Vector2(-rr, rr + 11.0), label, HORIZONTAL_ALIGNMENT_CENTER, rr * 2.0 + 30.0, 10, pal.col("hud_ink"))
		else:
			var dim: Color = pal.col("hud_ink")
			dim.a = 0.35
			draw_arc(rp, rr, 0.0, TAU, 24, dim, 1.0)
			draw_string(_font, rp + Vector2(-5.0, 5.0), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, dim)
	# rooted shrines
	for sh: Entities.Shrine in w.shrines:
		var sp: Vector2 = _to_map(sh.pos)
		var tc: Color = pal.col(tables.sprig(sh.type_id).colour_key)
		draw_rect(Rect2(sp - Vector2(3.0, 3.0), Vector2(6.0, 6.0)), tc)
	# shrines still waiting in the field, once their region is known (or near the Hold)
	for o: Entities.WorldObject in w.objects:
		if o.kind != "shrine" or o.taken:
			continue
		var visible_: bool = SimWorld.flat_dist(o.pos, w.hold.pos) < 40.0
		for r: Dictionary in w.regions:
			if w.discovered.has(str(r["id"])) and SimWorld.flat_dist(o.pos, r["pos"]) <= float(r["radius"]):
				visible_ = true
		if visible_:
			var op: Vector2 = _to_map(o.pos)
			var tc: Color = pal.col(tables.sprig(o.shrine_type).colour_key)
			draw_rect(Rect2(op - Vector2(3.0, 3.0), Vector2(6.0, 6.0)), tc, false, 1.5)
	# the gnome: an arrow along his facing
	var kp: Vector2 = _to_map(w.knight.pos)
	var f := Vector2(sin(w.knight.yaw), cos(w.knight.yaw))
	var sidev := Vector2(f.y, -f.x)
	var pts := PackedVector2Array([kp + f * 7.0, kp - f * 4.0 + sidev * 4.5, kp - f * 2.0, kp - f * 4.0 - sidev * 4.5])
	draw_colored_polygon(pts, Color(1.0, 1.0, 1.0, 0.95))
	# night: the stalkers, as red points
	if w.clock.is_night():
		for e: Entities.Enemy in w.enemies:
			if e.night and e.state != Entities.Enemy.State.DEAD:
				draw_circle(_to_map(e.pos), 2.0, pal.col("enemy_night_eye"))
