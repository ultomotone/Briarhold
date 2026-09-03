## Angled overhead camera centred on the knight. Yaw turns in 45-degree steps (Z/V), the wheel
## zooms, the cursor stays free: the mouse is never captured, by law.
class_name CameraRig
extends Node3D

var cam: Camera3D
var yaw_target: float = 0.0
var yaw: float = 0.0
var pitch_deg: float = 48.0
var dist: float = 12.0
var dist_target: float = 12.0
var focus: Vector3 = Vector3.ZERO
var reduced_motion: bool = false


func _ready() -> void:
	cam = Camera3D.new()
	cam.fov = 48.0
	cam.near = 0.1
	cam.far = 400.0
	add_child(cam)
	cam.current = true


func turn(steps: int) -> void:
	yaw_target += float(steps) * PI * 0.25


func zoom(delta: float) -> void:
	dist_target = clampf(dist_target + delta, 7.0, 18.0)


func follow(target: Vector3, delta: float) -> void:
	var k: float = 1.0 if reduced_motion else clampf(delta * 9.0, 0.0, 1.0)
	focus = focus.lerp(target, k) if focus != Vector3.ZERO else target
	yaw = lerp_angle(yaw, yaw_target, 1.0 if reduced_motion else clampf(delta * 6.0, 0.0, 1.0))
	dist = lerpf(dist, dist_target, 1.0 if reduced_motion else clampf(delta * 6.0, 0.0, 1.0))
	var p: float = deg_to_rad(pitch_deg)
	var off := Vector3(sin(yaw) * cos(p), sin(p), cos(yaw) * cos(p)) * dist
	global_position = focus + off
	cam.look_at(focus + Vector3(0.0, 0.6, 0.0), Vector3.UP)


## The ground-plane forward the knight's WASD is relative to.
func forward() -> Vector3:
	return Vector3(-sin(yaw), 0.0, -cos(yaw)).normalized()


## Screen-right: forward x up. (It was the mirror of this; D walked left. Owner verdict 2026-09-02.)
func right() -> Vector3:
	var f: Vector3 = forward()
	return Vector3(-f.z, 0.0, f.x)
