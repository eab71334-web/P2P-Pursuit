class_name Clipboard
extends Control
## The co-driver's clipboard: stage map (with CLOSED roads in red) + the next pace notes.

var track: Track
var progress := 0
var wrong_way := false
var others: Array = []      # [{idx:int, color:Color}] other teams' cars
var my_color := Color(0.9, 0.1, 0.1)
var tablet := false         # drawn on the 3D iPad instead of the HUD clipboard

var _pts := PackedVector2Array()
var _branch_pts: Array[PackedVector2Array] = []
var _last_size := Vector2.ZERO


func set_track(t: Track) -> void:
	track = t
	_last_size = Vector2.ZERO
	queue_redraw()


func set_state(p: int, wrong: bool, other_cars: Array) -> void:
	if p != progress or wrong != wrong_way or other_cars != others:
		progress = p
		wrong_way = wrong
		others = other_cars
		queue_redraw()


func _paper_rect() -> Rect2:
	if tablet:
		return Rect2(8, 8, size.x - 16, size.y - 16)
	return Rect2(14, 22, size.x - 28, size.y - 36)


func _rebuild_map(area: Rect2) -> void:
	_pts.clear()
	_branch_pts.clear()
	var minp := Vector2(INF, INF)
	var maxp := Vector2(-INF, -INF)
	var all: Array = [track.points]
	for b in track.branches:
		all.append(b["points"])
	for arr in all:
		for p in arr:
			minp = minp.min(Vector2(p.x, p.z))
			maxp = maxp.max(Vector2(p.x, p.z))
	var ext := (maxp - minp).max(Vector2(1, 1))
	var sc := minf(area.size.x / ext.x, area.size.y / ext.y)
	var off := area.position + (area.size - ext * sc) * 0.5
	for p in track.points:
		_pts.append(off + (Vector2(p.x, p.z) - minp) * sc)
	for b in track.branches:
		var arr := PackedVector2Array()
		for p in b["points"]:
			arr.append(off + (Vector2(p.x, p.z) - minp) * sc)
		_branch_pts.append(arr)
	_last_size = size


func _note_label(n: Dictionary) -> String:
	var label: String = str(n["text"]).to_upper()
	match n["kind"]:
		"fork":
			return "FORK: %s CLOSED" % ("LEFT" if n["dir"] > 0 else "RIGHT")
		"flat":
			return "%s  %dm" % [label, n["len"]]
		"bump", "crest", "ice":
			return label if n["len"] == 0 else "%s  %dm" % [label, n["len"]]
		"cliff":
			return "CLIFF EDGE  %dm" % n["len"]
		"rockfall":
			return "ROCKFALL  " + ("< LEFT" if n["dir"] > 0 else "RIGHT >")
	if n["dir"] > 0:
		return label + "  < LEFT"
	if n["dir"] < 0:
		return label + "  RIGHT >"
	return label


func _draw() -> void:
	var font := ThemeDB.fallback_font
	if tablet:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.1, 0.1, 0.12))
	else:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.66, 0.45, 0.2))
		draw_rect(Rect2(Vector2.ZERO, size).grow(-5), Color(0.45, 0.3, 0.13), false, 4.0)
		draw_rect(Rect2(size.x * 0.34, 0, size.x * 0.32, 24), Color(0.78, 0.78, 0.82))
	var paper := _paper_rect()
	draw_rect(paper, Color(0.06, 0.06, 0.09))
	if track == null:
		return
	var map_area := Rect2(paper.position + Vector2(10, 10), Vector2(paper.size.x - 20, paper.size.y * 0.5 - 20))
	if _last_size != size or _pts.is_empty():
		_rebuild_map(map_area)
	var idx := clampi(progress, 0, _pts.size() - 1)
	# closed side roads (red, with a cross at the dead end)
	for arr in _branch_pts:
		draw_polyline(arr, Color(0.95, 0.25, 0.25), 3.0, true)
		var e := arr[arr.size() - 1]
		draw_line(e + Vector2(-6, -6), e + Vector2(6, 6), Color(1, 0.3, 0.3), 3.0)
		draw_line(e + Vector2(-6, 6), e + Vector2(6, -6), Color(1, 0.3, 0.3), 3.0)
	for e in track.edges:
		var a: int = e["from"]
		var b: int = mini(e["to"], _pts.size() - 1)
		if b - a >= 1:
			draw_polyline(_pts.slice(a, b + 1), Color(1.0, 0.55, 0.1), 7.0, true)
	for e in track.ices:
		var a: int = e["from"]
		var b: int = mini(e["to"], _pts.size() - 1)
		if b - a >= 1:
			draw_polyline(_pts.slice(a, b + 1), Color(0.4, 0.9, 1.0), 7.0, true)
	for o in track.obstacles:
		if o["kind"] == "rockfall":
			var c := _pts[clampi(int(o["index"]), 0, _pts.size() - 1)]
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -8), c + Vector2(8, 7), c + Vector2(-8, 7)]), Color(1, 0.2, 0.2))
	if idx > 1:
		draw_polyline(_pts.slice(0, idx + 1), Color(0.45, 0.42, 0.28), 3.0, true)
	if _pts.size() - idx >= 2:
		draw_polyline(_pts.slice(idx), Color(0.98, 0.93, 0.6), 3.0, true)
	draw_circle(_pts[0], 6.0, Color(0.3, 0.9, 0.4))
	draw_circle(_pts[_pts.size() - 1], 6.0, Color.WHITE)
	for o in others:
		draw_circle(_pts[clampi(int(o["idx"]), 0, _pts.size() - 1)], 5.0, o["color"])
	draw_circle(_pts[idx], 8.0, Color.WHITE)
	draw_circle(_pts[idx], 5.0, my_color)

	draw_string(font, paper.position + Vector2(8, 16), track.stage_name.to_upper(), HORIZONTAL_ALIGNMENT_LEFT, paper.size.x - 16, 14, Color(0.7, 0.75, 0.85))
	# next pace notes
	var fs := int(clampf(size.y * 0.052, 15.0, 28.0))
	var y := paper.position.y + paper.size.y * 0.5 + fs + 4
	var shown := 0
	var x0 := paper.position.x + 12
	var w := paper.size.x - 24
	for n in track.notes:
		if n["index"] < idx - 1:
			continue
		var dist := maxi(0, (n["index"] - idx) * int(Track.STEP))
		var col := Color(0.4, 0.95, 0.5)
		if n["kind"] == "fork":
			col = Color(1.0, 0.35, 0.3)
		elif n["kind"] in ["cliff", "rockfall", "crest"]:
			col = Color(1.0, 0.6, 0.2)
		elif n["kind"] == "ice":
			col = Color(0.5, 0.95, 1.0)
		elif n["kind"] in ["rock", "log", "bump"]:
			col = Color(0.5, 0.8, 1.0)
		elif n["sev"] >= 4:
			col = Color(1.0, 0.35, 0.3)
		elif n["sev"] >= 2:
			col = Color(1.0, 0.85, 0.3)
		var f := fs if shown > 0 else fs + 5
		draw_string(font, Vector2(x0, y), _note_label(n), HORIZONTAL_ALIGNMENT_LEFT, w, f, col)
		draw_string(font, Vector2(x0, y), "%dm" % dist, HORIZONTAL_ALIGNMENT_RIGHT, w, f, Color(0.85, 0.85, 0.9))
		y += f + 8
		shown += 1
		if shown >= 4 or y > paper.end.y - 6:
			break
	if shown == 0:
		var left_m := maxi(0, (track.points.size() - 1 - idx) * int(Track.STEP))
		draw_string(font, Vector2(x0, y), "FINISH IN %dm" % left_m, HORIZONTAL_ALIGNMENT_LEFT, w, fs + 5, Color(1, 1, 1))
	if wrong_way and int(Time.get_ticks_msec() / 250.0) % 2 == 0:
		draw_rect(Rect2(paper.position + Vector2(6, 6), Vector2(paper.size.x - 12, fs + 14)), Color(0.8, 0.1, 0.1))
		draw_string(font, paper.position + Vector2(12, fs + 8), "WRONG ROAD! WARN THE DRIVER", HORIZONTAL_ALIGNMENT_LEFT, paper.size.x - 24, fs, Color.WHITE)


func _process(_d: float) -> void:
	if wrong_way:
		queue_redraw()
