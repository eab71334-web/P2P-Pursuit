class_name Track
extends RefCounted
## Procedural rally stage. The same seed always gives the same stage on every machine.
## Contains: the main road, dead-end side roads (forks), obstacles (rocks, logs, bumps)
## and the "pace notes" (Chill left, Yikes right, Fork...) that the co-driver reads.

const STEP := 5.0
const ROAD_WIDTH := 11.0
const TOTAL_LENGTH := 2600.0
const ANGLES := [18.0, 32.0, 50.0, 75.0, 105.0, 150.0]
const RADII := [140.0, 90.0, 62.0, 42.0, 28.0, 17.0]
const NAMES := ["Easy", "Chill", "Medium", "Hard", "Yikes", "Oh no"]
const WEIGHTS := [3.0, 4.0, 4.0, 3.0, 2.0, 1.0]
const BRANCH_POINTS := 18
const BRANCH_ANGLE := 28.0

var points := PackedVector3Array()
var headings := PackedFloat32Array()   # yaw; forward = (-sin h, 0, -cos h); +h turns left
## {index, text, dir (+1 left, -1 right, 0), sev, len, kind: corner|flat|fork|rock|log|bump}
var notes: Array[Dictionary] = []
## {fork: int, side: int (+1 left), points, headings}  -> dead ends, the road is CLOSED
var branches: Array[Dictionary] = []
## {index, kind: rock|log|bump, side}
var obstacles: Array[Dictionary] = []

var _pos := Vector3.ZERO
var _h := 0.0


static func generate(seed_value: int) -> Track:
	for attempt in 120:
		var t := Track.new()
		if t._build(seed_value + attempt * 7919, true):
			return t
	var fallback := Track.new()
	fallback._build(seed_value, false)
	return fallback


func length() -> float:
	return points.size() * STEP


static func forward(h: float) -> Vector3:
	return Vector3(-sin(h), 0.0, -cos(h))


static func left_of(h: float) -> Vector3:
	return Vector3(-cos(h), 0.0, sin(h))


func _push() -> void:
	points.append(_pos)
	headings.append(_h)


func _straight(len_m: float) -> void:
	var n := maxi(1, int(len_m / STEP))
	for i in n:
		_pos += forward(_h) * STEP
		_push()


func _corner(dir: int, sev: int) -> void:
	var angle := deg_to_rad(ANGLES[sev])
	var n := maxi(2, ceili(RADII[sev] * angle / STEP))
	var dh := angle / n
	for i in n:
		_h += dir * dh
		_pos += forward(_h) * STEP
		_push()


func _pick_sev(rng: RandomNumberGenerator) -> int:
	var total := 0.0
	for w in WEIGHTS:
		total += w
	var r := rng.randf() * total
	for i in WEIGHTS.size():
		r -= WEIGHTS[i]
		if r <= 0.0:
			return i
	return 0


func _is_straight(a: int, b: int) -> bool:
	if a < 0 or b >= headings.size():
		return false
	return absf(headings[a] - headings[b]) < 0.001


func _build(seed_value: int, validate: bool) -> bool:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	_pos = Vector3.ZERO
	_h = 0.0
	points.clear()
	headings.clear()
	notes.clear()
	branches.clear()
	obstacles.clear()
	_push()
	_straight(70.0)
	var total_turn := 0.0
	while length() < TOTAL_LENGTH:
		var sev := _pick_sev(rng)
		var dir := 1 if rng.randf() < 0.5 else -1
		if absf(total_turn) > 90.0 and rng.randf() < 0.85:
			dir = -int(signf(total_turn))
		notes.append({"index": points.size() - 1, "text": NAMES[sev], "dir": dir, "sev": sev, "len": 0, "kind": "corner"})
		_corner(dir, sev)
		total_turn += dir * ANGLES[sev]
		var s := rng.randf_range(20.0, 100.0)
		if sev >= 4:
			s = rng.randf_range(15.0, 45.0)
		_straight(s)
		if s >= 85.0:
			notes.append({"index": points.size() - 1 - int(s / STEP), "text": "Flat out", "dir": 0, "sev": 0, "len": int(s), "kind": "flat"})
	_straight(60.0)

	_add_forks(rng)
	_add_obstacles(rng)
	notes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["index"] < b["index"])

	if validate:
		var skip := int(180.0 / STEP)
		var min_d2 := 24.0 * 24.0
		for i in points.size():
			for j in range(i + skip, points.size()):
				var dx := points[i].x - points[j].x
				var dz := points[i].z - points[j].z
				if dx * dx + dz * dz < min_d2:
					return false
		# dead-end roads must not run into the main road
		for b in branches:
			var f: int = b["fork"]
			var bp: PackedVector3Array = b["points"]
			for k in range(5, bp.size()):
				for j in points.size():
					if absi(j - f) <= 14:
						continue
					var dx := bp[k].x - points[j].x
					var dz := bp[k].z - points[j].z
					if dx * dx + dz * dz < 22.0 * 22.0:
						return false
	return true


func _add_forks(rng: RandomNumberGenerator) -> void:
	var last := 0
	var n := points.size()
	for idx in range(50, n - 60):
		if idx - last < 45:
			continue
		if not _is_straight(idx - 4, idx + 5):
			continue
		if rng.randf() > 0.25:
			continue
		last = idx
		var side := 1 if rng.randf() < 0.5 else -1
		branches.append(_make_branch(rng, idx, side))
		notes.append({"index": idx, "text": "Fork", "dir": side, "sev": 5, "len": 0, "kind": "fork"})


func _make_branch(rng: RandomNumberGenerator, f: int, side: int) -> Dictionary:
	var p := points[f]
	var h := headings[f] + side * deg_to_rad(BRANCH_ANGLE)
	var pts := PackedVector3Array()
	var hs := PackedFloat32Array()
	pts.append(p)
	hs.append(h)
	var curve := rng.randf_range(-0.035, 0.035)
	for i in BRANCH_POINTS:
		h += curve
		p += forward(h) * STEP
		pts.append(p)
		hs.append(h)
	return {"fork": f, "side": side, "points": pts, "headings": hs}


func _add_obstacles(rng: RandomNumberGenerator) -> void:
	var last := 0
	var n := points.size()
	for idx in range(24, n - 20, 3):
		if idx - last < 10:
			continue
		if not _is_straight(idx - 3, idx + 3):
			continue
		var near_fork := false
		for b in branches:
			if absi(int(b["fork"]) - idx) < 14:
				near_fork = true
		if near_fork or rng.randf() > 0.3:
			continue
		last = idx
		var side := 1 if rng.randf() < 0.5 else -1
		var r := rng.randf()
		var kind := "rock" if r < 0.4 else ("log" if r < 0.75 else "bump")
		obstacles.append({"index": idx, "kind": kind, "side": side})
		var text := "Rock" if kind == "rock" else ("Log" if kind == "log" else "Big bump")
		notes.append({"index": idx, "text": text, "dir": 0 if kind == "bump" else side, "sev": 3, "len": 0, "kind": kind})
