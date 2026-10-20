## Campsites. The Hold is wherever its camp is: hold T at another campsite's beacon for a
## second and the Hold moves there, shrines, safe ring, night and all. The origin is camp "home".
class_name CampSystem
extends RefCounted

const BEACON_REACH: float = 3.5
const HOLD_SECONDS: float = 1.0


static func step(w: SimWorld, cmd: Commands, dt: float) -> void:
	var near: Dictionary = camp_near(w, w.knight.pos)
	if not cmd.camp_held or near.is_empty() or str(near["id"]) == w.camp_id or w.knight.down_t >= 0.0:
		w.camp_t = 0.0
		return
	w.camp_t += dt
	if w.camp_t >= HOLD_SECONDS:
		w.camp_t = 0.0
		move_to(w, str(near["id"]))


## The campsite whose beacon is within reach of p, or {}.
static func camp_near(w: SimWorld, p: Vector3) -> Dictionary:
	for cp: Dictionary in w.camps:
		if SimWorld.flat_dist(p, beacon(w, cp)) <= BEACON_REACH:
			return cp
	return {}


static func camp_by_id(w: SimWorld, id: String) -> Dictionary:
	for cp: Dictionary in w.camps:
		if str(cp["id"]) == id:
			return cp
	return {}


## The beacon stands a little off the camp's centre, so the shrines can ring the centre.
static func beacon(w: SimWorld, cp: Dictionary) -> Vector3:
	var c: Vector3 = cp["pos"]
	return w.ground(c + Vector3(0.0, 0.0, -3.5))


## Move the Hold: its centre, its rooted shrines (set round the new centre in a fixed order), and
## the safe ring all go to the camp. Sprigs following him come along; the rest stay where they are.
static func move_to(w: SimWorld, id: String) -> void:
	var cp: Dictionary = camp_by_id(w, id)
	if cp.is_empty():
		return
	w.camp_id = id
	w.hold.pos = w.ground(cp["pos"])
	place_shrines(w)
	if not w.discovered.has(id):
		w.discovered.append(id)
	w.events.push("camp_moved", {"id": id, "name": cp["name"], "pos": w.hold.pos})


static func place_shrines(w: SimWorld) -> void:
	var n: int = w.shrines.size()
	for i: int in n:
		var sh: Entities.Shrine = w.shrines[i]
		var a: float = 0.6 + float(i) / float(maxi(1, n)) * TAU
		var r: float = 6.0 if n <= 6 else 7.0
		sh.pos = w.ground(w.hold.pos + Vector3(sin(a), 0.0, cos(a)) * r)
