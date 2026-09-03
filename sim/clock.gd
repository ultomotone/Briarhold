## The day: a soft cycle. Nothing is forced at dusk; the night just has teeth.
## time runs 0..day+night within a day; day counts up forever. Offline time is applied as one
## capped delta (advance_offline), never simulated tick by tick.
class_name Clock
extends RefCounted

var day_seconds: float = 900.0
var night_seconds: float = 360.0
var dusk_warning: float = 90.0
var time: float = 0.0
var day: int = 1
var warned: bool = false


func _init(day_s: float = 900.0, night_s: float = 360.0, warn_s: float = 90.0) -> void:
	day_seconds = day_s
	night_seconds = night_s
	dusk_warning = warn_s


func cycle() -> float:
	return day_seconds + night_seconds


func is_night() -> bool:
	return time >= day_seconds


## 0 at dawn, 1 at dusk (clamped to 1 through the night).
func sun_t() -> float:
	return clampf(time / day_seconds, 0.0, 1.0)


## 0..1 through the night, 0 by day.
func night_t() -> float:
	if not is_night():
		return 0.0
	return clampf((time - day_seconds) / night_seconds, 0.0, 1.0)


func seconds_to_dusk() -> float:
	return maxf(0.0, day_seconds - time)


## Returns the events crossed this step: "dusk_warning", "night", "dawn".
func advance(dt: float) -> PackedStringArray:
	var out: PackedStringArray = []
	var was_night: bool = is_night()
	time += dt
	if not was_night and not warned and seconds_to_dusk() <= dusk_warning:
		warned = true
		out.append("dusk_warning")
	if not was_night and is_night():
		out.append("night")
	if time >= cycle():
		time -= cycle()
		day += 1
		warned = false
		out.append("dawn")
	return out


## One-step offline resolution. Returns the number of whole nights that passed.
func advance_offline(elapsed: float, cap_days: int) -> int:
	var capped: float = minf(maxf(0.0, elapsed), float(cap_days) * cycle())
	var nights: int = 0
	var was_night: bool = is_night()
	time += capped
	while time >= cycle():
		time -= cycle()
		day += 1
		nights += 1
	if not was_night and is_night():
		nights += 1
	warned = not is_night() and seconds_to_dusk() <= dusk_warning
	return nights
