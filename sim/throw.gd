## Throw arithmetic, shared by the sim (flight) and the view (arc preview) so they never disagree.
## A throw is a parabola of fixed flight time T from start to end; the peak is g*T^2/8 above the
## chord. Position at time t is analytic, so flight is deterministic and needs no integration.
class_name Throw
extends RefCounted


static func peak_height(t_total: float, g: float) -> float:
	return g * t_total * t_total / 8.0


static func point_at(start: Vector3, end: Vector3, t_total: float, g: float, t: float) -> Vector3:
	var u: float = clampf(t / t_total, 0.0, 1.0)
	var p: Vector3 = start.lerp(end, u)
	p.y += 4.0 * peak_height(t_total, g) * u * (1.0 - u)
	return p


static func arc_points(start: Vector3, end: Vector3, t_total: float, g: float, n: int = 24) -> PackedVector3Array:
	var out: PackedVector3Array = []
	for i: int in n + 1:
		out.append(point_at(start, end, t_total, g, t_total * float(i) / float(n)))
	return out


## Clamp a wanted landing point to the thrower's range on the XZ plane.
static func clamp_target(from: Vector3, want: Vector3, max_range: float) -> Vector3:
	var d: Vector3 = want - from
	d.y = 0.0
	var len: float = d.length()
	if len <= max_range or len < 0.001:
		return want
	return from + d * (max_range / len)
