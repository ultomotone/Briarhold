## The map, top right under the Hold panel: centred on the gnome, north-up (the default camera's
## up), showing VIEW metres around him. The ground is tinted by biome and climate (green
## country, woods, rock, marsh, snow, sand, jungle) so the change of country shows before he
## reaches it. On it: the Hold and its safe ring, campsites (a tent mark, lit if it is the Hold),
## boss arenas once found, territories ("?" until walked into), rooted shrines, the gnome's arrow.
## Known places beyond the edge are pinned to the rim in their direction. Drawn, not textured.
class_name Minimap
extends Control

const SIZE: float = 200.0
const VIEW: float = 150.0 # metres from the centre to the rim
const CELL: float = 12.0 # metres per tinted ground cell

var pal: PaletteData
var tables: ContentTables
var w: SimWorld
var _font: Font
var _cells: Dictionary = {} # Vector2i -> Color, filled as cells come into view
var _cells_world: SimWorld


func setup(p: PaletteData, t: ContentTables) -> void:
	pal = p
	tables = t
	custom_minimum_size = Vector2(SIZE, SIZE)
	size = Vector2(SIZE, SIZE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_font = ThemeDB.fallback_font


func show_world(world: SimWorld) -> void:
	w = world
	if _cells_world != w:
		_cells.clear()
		_cells_world = w
	queue_redraw()


func _scale() -> float:
	return (SIZE * 0.5 - 8.0) / VIEW


func _to_map(p: Vector3) -> Vector2:
	var half: float = SIZE * 0.5
	var k: Vector3 = w.knight.pos
	return Vector2(half + (p.x - k.x) * _scale(), half + (p.z - k.z) * _scale())


## Inside the disc, or pinned to its rim in the same direction (for known far places).
func _clamp(m: Vector2) -> Vector2:
	var c := Vector2(SIZE * 0.5, SIZE * 0.5)
	var d: Vector2 = m - c
	var lim: float = SIZE * 0.5 - 10.0
	if d.length() > lim:
		return c + d.normalized() * lim
	return m


func _inside(m: Vector2) -> bool:
	return m.distance_to(Vector2(SIZE * 0.5, SIZE * 0.5)) <= SIZE * 0.5 - 9.0


func _cell_col(gx: int, gz: int) -> Color:
	var key := Vector2i(gx, gz)
	if _cells.has(key):
		return _cells[key]
	var x: float = (float(gx) + 0.5) * CELL
	var z: float = (float(gz) + 0.5) * CELL
	var col: Color
	if absf(x) > w.field.bound or absf(z) > w.field.bound:
		col = pal.col("hud_glass")
	else:
		var cl: Vector3 = w.field.climate(x, z)
		var bw: Vector4 = w.field.biome(x, z)
		var meadow: float = clampf(1.0 - bw.x - bw.y - bw.z - bw.w - cl.x - cl.y - cl.z, 0.0, 1.0)
		col = pal.col("terrain_moss") * meadow + pal.col("terrain_wood") * bw.x + pal.col("terrain_rock") * bw.y
		col += pal.col("terrain_marsh") * bw.z + pal.col("terrain_garden") * bw.w
		col += pal.col("snow") * cl.x + pal.col("sand") * cl.y + pal.col("jungle_canopy") * cl.z
	col.a = 0.85
	_cells[key] = col
	return col


func _draw() -> void:
	if w == null:
		return
	var half: float = SIZE * 0.5
	var c := Vector2(half, half)
	var glass: Color = pal.col("hud_glass")
	glass.a = 0.82
	draw_circle(c, half, glass)
	# the ground, cell by cell, inside the disc
	var sc: float = _scale()
	var k: Vector3 = w.knight.pos
	var n: int = int(ceilf(VIEW / CELL)) + 1
	var kx: int = floori(k.x / CELL)
	var kz: int = floori(k.z / CELL)
	var px: float = CELL * sc + 0.6
	for gx: int in range(kx - n, kx + n + 1):
		for gz: int in range(kz - n, kz + n + 1):
			var mp: Vector2 = _to_map(Vector3((float(gx) + 0.5) * CELL, 0.0, (float(gz) + 0.5) * CELL))
			if mp.distance_to(c) > half - 9.0:
				continue
			draw_rect(Rect2(mp - Vector2(px, px) * 0.5, Vector2(px, px)), _cell_col(gx, gz))
	# water
	for z: Entities.HazardZone in w.hazards:
		if z.hazard_id != "water":
			continue
		var zp: Vector2 = _to_map(z.pos)
		if _inside(zp):
			draw_circle(zp, maxf(1.5, z.radius * sc), pal.col("pool_water"))
	var edge: Color = pal.col("hud_ink")
	edge.a = 0.25
	draw_arc(c, half - 1.0, 0.0, TAU, 64, edge, 1.5)
	# the Hold
	var ring: Color = pal.col("hold_ring")
	var hold_p: Vector2 = _to_map(w.hold.pos)
	if _inside(hold_p):
		ring.a = 0.7
		draw_arc(hold_p, w.hold.safe_radius * sc, 0.0, TAU, 32, ring, 1.2)
	draw_circle(_clamp(hold_p), 4.0, pal.col("hold_ring"))
	# campsites: a tent mark, filled if the Hold is there; far ones pinned to the rim once found
	for cp: Dictionary in w.camps:
		var id: String = cp["id"]
		var known: bool = w.discovered.has(id) or id == "home" or id == w.camp_id
		var mp: Vector2 = _to_map(cp["pos"])
		if not _inside(mp) and not known:
			continue
		mp = _clamp(mp)
		var tc: Color = pal.col("camp_fire") if id == w.camp_id else pal.col("tent")
		var tri := PackedVector2Array([mp + Vector2(0.0, -5.0), mp + Vector2(5.0, 4.0), mp + Vector2(-5.0, 4.0)])
		if id == w.camp_id or known:
			draw_colored_polygon(tri, tc)
		else:
			draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), tc, 1.2)
	# boss arenas, once found: a red ring with a mark
	for ar: Dictionary in w.arenas:
		if not w.discovered.has(str(ar["id"])):
			continue
		var ap: Vector2 = _clamp(_to_map(ar["pos"]))
		draw_arc(ap, 5.5, 0.0, TAU, 16, pal.col("hud_warn"), 2.0)
		draw_circle(ap, 2.0, pal.col("hud_warn"))
	# territories
	for r: Dictionary in w.regions:
		var rp: Vector2 = _to_map(r["pos"])
		var known: bool = w.discovered.has(str(r["id"]))
		if not _inside(rp):
			if known:
				var tcf: Color = pal.col(tables.sprig(str(r["type"])).colour_key)
				draw_circle(_clamp(rp), 3.0, tcf)
			continue
		var rr: float = float(r["radius"]) * sc
		if known:
			var tc2: Color = pal.col(tables.sprig(str(r["type"])).colour_key)
			var fill: Color = tc2
			fill.a = 0.3
			draw_circle(rp, rr, fill)
			draw_arc(rp, rr, 0.0, TAU, 24, tc2, 1.5)
			var label: String = str(r["name"]).replace("The ", "")
			draw_string(_font, rp + Vector2(-rr - 15.0, rr + 11.0), label, HORIZONTAL_ALIGNMENT_CENTER, rr * 2.0 + 30.0, 10, pal.col("hud_ink"))
		else:
			var dim: Color = pal.col("hud_ink")
			dim.a = 0.5
			draw_arc(rp, rr, 0.0, TAU, 24, dim, 1.0)
			draw_string(_font, rp + Vector2(-4.0, 5.0), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, dim)
	# rooted shrines
	for sh: Entities.Shrine in w.shrines:
		var sp: Vector2 = _to_map(sh.pos)
		if _inside(sp):
			draw_rect(Rect2(sp - Vector2(2.5, 2.5), Vector2(5.0, 5.0)), pal.col(tables.sprig(sh.type_id).colour_key))
	# the gnome: an arrow along his facing, always at the centre
	var f := Vector2(sin(w.knight.yaw), cos(w.knight.yaw))
	var sidev := Vector2(f.y, -f.x)
	var pts := PackedVector2Array([c + f * 7.0, c - f * 4.0 + sidev * 4.5, c - f * 2.0, c - f * 4.0 - sidev * 4.5])
	draw_colored_polygon(pts, Color(1.0, 1.0, 1.0, 0.95))
	# night: the stalkers, as red points
	if w.clock.is_night():
		for e: Entities.Enemy in w.enemies:
			if e.night and e.state != Entities.Enemy.State.DEAD:
				var ep: Vector2 = _to_map(e.pos)
				if _inside(ep):
					draw_circle(ep, 2.0, pal.col("enemy_night_eye"))
