## The one seam between the sim and NavigationServer3D. The default walks a straight line, which
## is what tests use; game/nav/nav_paths.gd overrides path() with a baked navmesh query.
class_name PathProvider
extends RefCounted


func path(from: Vector3, to: Vector3) -> PackedVector3Array:
	return PackedVector3Array([from, to])


## Bump when the walkable set changes (a gate falls); carry jobs re-request on a mismatch.
var generation: int = 0
