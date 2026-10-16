## Angled overhead camera centred on the knight. Yaw turns in 45-degree steps (Z/V) or freely
## while the middle mouse button is held and dragged (sideways turns, up and down tilts); the
## wheel zooms. The cursor stays free: the mouse is never captured, by law.
class_name CameraRig
extends Node3D

const DIST_MIN: float = 6.0
const DIST_MAX: float = 46.0
const PITCH_MIN: float = 22.0
const PITCH_MAX: float = 82.0

var cam: Camera3D
var yaw_target: float = 0.0
var yaw: float = 0.0
var pitch_deg: float = 48.0
var pitch_target: float = 48.0
var dist: float = 12.0
var dist_target: float = 12.0
var focus: Vector3 = Vector3.ZERO
var reduced_motion: bool = false


func _ready() -> void:
	cam = Camera3D.new()
	cam.fov = 48.0
	cam.near = 0.1
	cam.far = 600.0
	add_child(cam)
	cam.current = true


func turn(steps: int) -> void:
	yaw_target += float(steps) * PI * 0.25


## One wheel notch. Steps scale with the distance so the far end is reached in a few notches
## and the near end stays fine-grained.
func zoom(notches: float) -> void:
	dist_target = clampf(dist_target * pow(1.14, notches), DIST_MIN, DIST_MAX)


## Middle-button drag: pixels moved since the last motion event.
func orbit(rel: Vector2) -> void:
	yaw_target -= rel.x * 0.0065
	pitch_target = clampf(pitch_target + rel.y * 0.22, PITCH_MIN, PITCH_MAX)


func follow(target: Vector3, delta: float) -> void:
	var k: float = 1.0 if reduced_motion else clampf(delta * 9.0, 0.0, 1.0)
	var ease_k: float = 1.0 if reduced_motion else clampf(delta * 8.0, 0.0, 1.0)
	focus = focus.lerp(target, k) if focus != Vector3.ZERO else target
	yaw = lerp_angle(yaw, yaw_target, ease_k)
	pitch_deg = lerpf(pitch_deg, pitch_target, ease_k)
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
