## Per-tick input intent, built by the driver from Input and handed to SimWorld.step().
## The sim never reads Input; this is the only door. Pulses are true for one tick.
class_name Commands
extends RefCounted

var move_dir: Vector3 = Vector3.ZERO # world-space XZ, unit or zero
var walk_target: Vector3 = Vector3.INF # INF = none
var cursor: Vector3 = Vector3.INF # ground point under the mouse, INF when off the field
var strike: bool = false
var throw_pressed: bool = false
var throw_held: bool = false
var whistle_held: bool = false
var swarm_held: bool = false
var pluck_held: bool = false
var store_held: bool = false
var charge_pressed: bool = false
var dismiss_pressed: bool = false
var select_delta: int = 0


func clear_pulses() -> void:
	strike = false
	throw_pressed = false
	charge_pressed = false
	dismiss_pressed = false
	select_delta = 0
	walk_target = Vector3.INF


func has_cursor() -> bool:
	return cursor != Vector3.INF
