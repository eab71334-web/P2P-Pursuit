# Copyright (c) 2026 AVF. All rights reserved. See LICENSE.
class_name Track
extends RefCounted
## Procedural rally stage. The same seed always gives the same stage on every machine.
## Contains: the main road, dead-end side roads (forks), obstacles (rocks, logs, bumps)
## and the "pace notes" (Chill left, Yikes right, Fork...) that the co-driver reads.

const STEP := 5.0
const ROAD_WIDTH := 14.0
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

## cliff sections without guard rails: {from, to}
var edges: Array[Dictionary] = []
## slippery sections: {from, to}
var ices: Array[Dictionary] = []

# stage parameters (filled by the stage director)
var theme := "snow"
var stage_name := "Test Stage"
var fork_p := 0.25
var fork_gap := 45
var obst_p := 0.3
var relief := 0.0      # mountain height variation in metres (0 = flat)
var open_p := 0.0      # chance of cliff sections
var rare_p := 0.0      # chance of rare hazards (ice, rockfall)
var floor_y := 0.0     # valley floor height

var _pos := Vector3.ZERO
var _h := 0.0


const THEMES := ["mountain", "mountain", "mountain", "snow", "autumn"]
const ADJ := ["Misty", "Frozen", "Wild", "Hidden", "Black", "Silver", "Howling", "Broken", "Lonely", "Golden", "Thunder"]
const NOUNS := {
	"mountain": ["Pass", "Ridge", "Summit", "Gorge", "Col", "Peak"],
	"snow": ["Valley", "Forest", "Lake", "Trail", "Hollow"],
	"autumn": ["Woods", "Orchard", "Canyon", "Vineyard", "Hills"],
}


## Offline "stage director": invents several stage candidates, builds them and keeps the most
## interesting one (many closed roads, tough corners, rare hazards, cliffs). Pure maths, no internet.
static func design_stage(base_seed: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = base_seed
	var best := {}
	var best_score := -INF
	for c in 6:
		var st := {
			"theme": THEMES[rng.randi() % THEMES.size()],
			"difficulty": rng.randf_range(0.3, 1.0),
			"fork_p": rng.randf_range(0.35, 0.6),
			"obst_p": rng.randf_range(0.25, 0.45),
			"seed": rng.randi(),
		}
		var mountain: bool = st["theme"] == "mountain"
		st["relief"] = rng.randf_range(7.0, 13.0) if mountain else 0.0
		st["open_p"] = rng.randf_range(0.35, 0.7) if mountain else 0.0
		st["rare_p"] = rng.randf_range(0.5, 1.0)
		var found := false
		for attempt in 40:
			var t := Track.from_stage(st, true, attempt * 7919)
			if t != null:
				st["seed"] = int(st["seed"]) + attempt * 7919
				var sc := t._score(float(st["difficulty"])) + rng.randf()
				if sc > best_score:
					best_score = sc
					best = st.duplicate()
					best["name"] = "%s %s" % [ADJ[rng.randi() % ADJ.size()], (NOUNS[st["theme"]] as Array)[rng.randi() % 5]]
				found = true
				break
		if not found and best.is_empty():
			best = st.duplicate()
			best["name"] = "Test Stage"
	return best


## Builds a stage. With validate it returns null when the road overlaps itself.
static func from_stage(st: Dictionary, validate := false, seed_offset := 0) -> Track:
	var t := Track.new()
	t.theme = st.get("theme", "snow")
	t.stage_name = st.get("name", "Stage")
	t.fork_p = st.get("fork_p", 0.25)
	t.fork_gap = 32 if t.theme == "mountain" else 45
	t.obst_p = st.get("obst_p", 0.3)
	t.relief = st.get("relief", 0.0)
	t.open_p = st.get("open_p", 0.0)
	t.rare_p = st.get("rare_p", 0.0)
	var ok := t._build(int(st.get("seed", 1)) + seed_offset, validate)
	if validate and not ok:
		return null
	return t


static func generate(seed_value: int) -> Track:
	return from_stage({"seed": seed_value})


func _score(difficulty: float) -> float:
	var forks := 0
	var hard := 0
	for n in notes:
		if n["kind"] == "fork":
			forks += 1
		elif n["kind"] == "corner" and n["sev"] >= 4:
			hard += 1
	var hazards := ices.size() + obstacles.filter(func(o: Dictionary) -> bool: return o["kind"] == "rockfall").size()
	var sc := minf(forks, 7.0) * 2.0 + minf(hazards, 3.0) * 2.0 + minf(edges.size(), 4.0) * 1.5
	sc -= absf(hard - difficulty * 10.0) * 0.6
	return sc


func y_at(i: int) -> float:
	return points[clampi(i, 0, points.size() - 1)].y


func is_open(i: int) -> bool:
	for e in edges:
		if i >= e["from"] and i <= e["to"]:
			return true
	return false


func ice_at(i: int) -> bool:
	for e in ices:
		if i >= e["from"] and i <= e["to"]:
			return true
	return false


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
	edges.clear()
	ices.clear()
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
	_apply_relief(rng)
	_add_edges(rng)
	_add_rare(rng)
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
		if idx - last < fork_gap:
			continue
		if not _is_straight(idx - 4, idx + 5):
			continue
		if rng.randf() > fork_p:
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
		if near_fork or rng.randf() > obst_p:
			continue
		last = idx
		var side := 1 if rng.randf() < 0.5 else -1
		var r := rng.randf()
		var kind := "rock" if r < 0.4 else ("log" if r < 0.75 else "bump")
		obstacles.append({"index": idx, "kind": kind, "side": side})
		var text := "Rock" if kind == "rock" else ("Log" if kind == "log" else "Big bump")
		notes.append({"index": idx, "text": text, "dir": 0 if kind == "bump" else side, "sev": 3, "len": 0, "kind": kind})



func _apply_relief(rng: RandomNumberGenerator) -> void:
	if relief <= 0.0:
		floor_y = 0.0
		return
	var p1 := rng.randf() * TAU
	var p2 := rng.randf() * TAU
	var p3 := rng.randf() * TAU
	var n := points.size()
	var min_y := INF
	for i in n:
		var y := 0.55 * sin(i * 0.021 + p1) + 0.3 * sin(i * 0.053 + p2) + 0.15 * sin(i * 0.11 + p3) + 1.0
		var ramp := smoothstep(0.0, 70.0, float(i)) * smoothstep(0.0, 30.0, float(n - 1 - i))
		points[i].y = y * relief * ramp
		min_y = minf(min_y, points[i].y)
	for b in branches:
		var bp: PackedVector3Array = b["points"]
		var fy := points[b["fork"]].y
		for k in bp.size():
			bp[k].y = fy
		b["points"] = bp
	floor_y = -relief * 3.0 - 25.0
	# crests: the road disappears over the top, the co-driver has to warn about it
	var last := -100
	for i in range(20, n - 20):
		if i - last < 40:
			continue
		var y := points[i].y
		if y > points[i - 7].y + 1.2 and y > points[i + 7].y + 1.2 and y >= points[i - 1].y and y >= points[i + 1].y:
			last = i
			notes.append({"index": i, "text": "Over crest", "dir": 0, "sev": 3, "len": 0, "kind": "crest"})


func _near_special(idx: int, margin: int) -> bool:
	for b in branches:
		if absi(int(b["fork"]) - idx) < margin + 14:
			return true
	for o in obstacles:
		if absi(int(o["index"]) - idx) < margin:
			return true
	for e in edges:
		if idx > int(e["from"]) - margin and idx < int(e["to"]) + margin:
			return true
	for e in ices:
		if idx > int(e["from"]) - margin and idx < int(e["to"]) + margin:
			return true
	return false


func _add_edges(rng: RandomNumberGenerator) -> void:
	if open_p <= 0.0:
		return
	var n := points.size()
	var idx := 60
	while idx < n - 70:
		var len_pts := rng.randi_range(14, 30)
		if rng.randf() < open_p and not _near_special(idx, 6) and not _near_special(idx + len_pts, 6):
			edges.append({"from": idx, "to": idx + len_pts})
			notes.append({"index": idx, "text": "Cliff edge", "dir": 0, "sev": 4, "len": len_pts * int(STEP), "kind": "cliff"})
			idx += len_pts + 30
		else:
			idx += 20


func _add_rare(rng: RandomNumberGenerator) -> void:
	if rare_p <= 0.0:
		return
	var n := points.size()
	var count := 0
	var idx := 70
	while idx < n - 60 and count < 5:
		idx += rng.randi_range(25, 50)
		if rng.randf() > rare_p:
			continue
		if idx >= n - 60 or not _is_straight(idx - 6, idx + 12) or _near_special(idx, 12):
			continue
		count += 1
		if rng.randf() < 0.5:
			var len_pts := rng.randi_range(8, 13)
			ices.append({"from": idx, "to": idx + len_pts})
			notes.append({"index": idx, "text": "Ice", "dir": 0, "sev": 4, "len": len_pts * int(STEP), "kind": "ice"})
		else:
			var side := 1 if rng.randf() < 0.5 else -1
			obstacles.append({"index": idx, "kind": "rockfall", "side": side})
			notes.append({"index": idx, "text": "Rockfall", "dir": side, "sev": 5, "len": 0, "kind": "rockfall"})
