## The one seam between the sim and NavigationServer3D. The default walks a straight line, which
## is what tests use; game/nav/nav_paths.gd overrides path() with baked navmesh queries.
##
## avoid: hazard ids the carriers are not all immune to; the route goes around those zones.
## fly: every carrier flies; the route is a straight line over walls and water.
## An empty result means there is no way there from here.
class_name PathProvider
extends RefCounted


func path(from: Vector3, to: Vector3, _avoid: PackedStringArray = PackedStringArray(), _fly: bool = false) -> PackedVector3Array:
	return PackedVector3Array([from, to])


## False while routes are still being worked out (a navmesh baking); carriers wait, quietly.
func is_ready() -> bool:
	return true


## Bump when the walkable set changes (a gate falls); carry jobs re-request on a mismatch.
var generation: int = 0
