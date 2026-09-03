## Hazards: a zone applies its status to any sprig not immune; the status kills on a timer
## unless whistled; the knight takes steady damage inside. Immunity is data on the sprig type.
class_name HazardSystem
extends RefCounted


static func step(w: SimWorld, dt: float) -> void:
	for z: Entities.HazardZone in w.hazards:
		z.pulse = fmod(z.pulse + dt * 0.7, 1.0)
		var hz: Types.HazardType = w.content.hazard(z.hazard_id)
		if hz == null:
			continue
		for sid: int in w.hash.query(z.pos, z.radius):
			var s: Entities.Sprig = w.sprig_by_id(sid)
			if s == null or s.state == Entities.Sprig.State.DEAD or s.state == Entities.Sprig.State.THROWN:
				continue
			var t: Types.SprigType = w.sprig_type(s)
			if t.immune.has(z.hazard_id):
				continue
			if hz.status.is_empty():
				continue
			if s.status.is_empty():
				s.status = hz.status
				s.status_t = 0.0
				s.hazard_id = z.hazard_id
				w.events.push("status", {"pos": s.pos, "type": s.type_id, "status": hz.status})
				if hz.flee:
					# it breaks and runs, away from the vent, dropping whatever it held
					w.set_state(s, Entities.Sprig.State.IDLE)
					var away: Vector3 = s.pos - z.pos
					away.y = 0.0
					if away.length() < 0.01:
						away = Vector3(1.0, 0.0, 0.0)
					s.charge_target = w.ground(z.pos + away.normalized() * (z.radius + 2.5))
		var k: Entities.Knight = w.knight
		if hz.knight_damage_per_sec > 0.0 and SimWorld.flat_dist(k.pos, z.pos) <= z.radius:
			Damage.to_knight(w, hz.knight_damage_per_sec * dt, hz.name)
	for s: Entities.Sprig in w.sprigs:
		if s.status.is_empty() or s.state == Entities.Sprig.State.DEAD:
			continue
		var hz: Types.HazardType = w.content.hazard(s.hazard_id)
		if hz == null:
			s.status = ""
			continue
		if hz.hazard_leave_cures and not _inside_hazard(w, s.pos, s.hazard_id):
			s.status = ""
			s.status_t = 0.0
			s.hazard_id = ""
			continue
		s.status_t += dt
		if hz.kill_after > 0.0 and s.status_t >= hz.kill_after:
			w.kill_sprig(s, hz.name.to_lower())


static func _inside_hazard(w: SimWorld, p: Vector3, hazard_id: String) -> bool:
	for z: Entities.HazardZone in w.hazards:
		if z.hazard_id == hazard_id and SimWorld.flat_dist(p, z.pos) <= z.radius:
			return true
	return false
