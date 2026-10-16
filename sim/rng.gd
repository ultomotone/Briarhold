## Deterministic seeded RNG. Pure: no Node, no engine randomness.
##
## FNV-1a hashes a stream name to a 32-bit seed; mulberry32 turns it into a sequence. One stream
## per subsystem, keyed by an explicit string, consumed in a fixed order, so adding a roll to one
## system can never shift another's sequence. Never call randi()/randf() in gameplay code.
## Not RandomNumberGenerator: the docs call its algorithm an implementation detail, and a save that
## regenerates content from a seed cannot depend on an implementation detail across upgrades.
class_name Rng
extends RefCounted

const M32: int = 0xFFFFFFFF

var _a: int = 0


static func fnv1a(s: String) -> int:
	var h: int = 2166136261
	for b: int in s.to_utf8_buffer():
		h = ((h ^ b) * 16777619) & M32
	return h


static func stream(name: String) -> Rng:
	var r := Rng.new()
	r._a = fnv1a(name)
	return r


func next_u32() -> int:
	_a = (_a + 0x6D2B79F5) & M32
	var t: int = ((_a ^ (_a >> 15)) * (1 | _a)) & M32
	t = (t + (((t ^ (t >> 7)) * (61 | t)) & M32)) ^ t
	t &= M32
	return (t ^ (t >> 14)) & M32


## 0.0 <= x < 1.0
func randf() -> float:
	return float(next_u32()) / 4294967296.0


## Inside this class a bare randf() resolves to the engine's global randf(), not the method
## above: engine randomness, the one thing this class exists to keep out. Every internal draw goes
## through self. (Found 2026-10-16: randi_range was rolling the engine's dice; same-seed worlds
## diverged as soon as worldgen leaned on it.)
func randf_range(lo: float, hi: float) -> float:
	return lo + (hi - lo) * self.randf()


## Inclusive at both ends.
func randi_range(lo: int, hi: int) -> int:
	return lo + int(self.randf() * float(hi - lo + 1))


## Weighted pick, returns the index. Weights >= 0, sum > 0.
func pick_weighted(weights: PackedFloat32Array) -> int:
	var total: float = 0.0
	for w: float in weights:
		total += w
	var r: float = self.randf() * total
	for i: int in weights.size():
		r -= weights[i]
		if r < 0.0:
			return i
	return weights.size() - 1
