class_name Clipboard
extends Control
## The co-driver's clipboard: stage map + the next pace notes. Only the co-driver sees this.

var track: Track
var progress := 0

var _pts := PackedVector2Array()
var _last_size := Vector2.ZERO


func set_track(t: Track) -> void:
	track = t
	_last_size = Vector2.ZERO
	queue_redraw()


func set_progress(p: int) -> void:
	if p != progress:
		progress = p
		queue_redraw()


func _paper_rect() -> Rect2:
	return Rect2(14, 22, size.x - 28, size.y - 36)


func _rebuild_map(area: Rect2) -> void:
	_pts.clear()
	var minp := Vector2(INF, INF)
	var maxp := Vector2(-INF, -INF)
	for p in track.points:
		minp = minp.min(Vector2(p.x, p.z))
		maxp = maxp.max(Vector2(p.x, p.z))
	var ext := (maxp - minp).max(Vector2(1, 1))
	var sc := minf(area.size.x / ext.x, area.size.y / ext.y)
	var off := area.position + (area.size - ext * sc) * 0.5
	for p in track.points:
		_pts.append(off + (Vector2(p.x, p.z) - minp) * sc)
	_last_size = size


func _draw() -> void:
	var font := ThemeDB.fallback_font
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
	if idx > 1:
		draw_polyline(_pts.slice(0, idx + 1), Color(0.45, 0.42, 0.28), 3.0, true)
	draw_polyline(_pts.slice(idx), Color(0.98, 0.93, 0.6), 3.0, true)
	draw_circle(_pts[0], 6.0, Color(0.3, 0.9, 0.4))
	draw_circle(_pts[_pts.size() - 1], 6.0, Color(0.95, 0.2, 0.2))
	draw_circle(_pts[idx], 8.0, Color.WHITE)
	draw_circle(_pts[idx], 5.0, Color(0.9, 0.1, 0.1))

	# next pace notes
	var fs := int(clampf(size.y * 0.055, 16.0, 30.0))
	var y := paper.position.y + paper.size.y * 0.5 + fs + 4
	var shown := 0
	var x0 := paper.position.x + 12
	var w := paper.size.x - 24
	for n in track.notes:
		if n["index"] < idx - 1:
			continue
		var dist := maxi(0, (n["index"] - idx) * int(Track.STEP))
		var col := Color(0.4, 0.95, 0.5)
		if n["sev"] >= 4:
			col = Color(1.0, 0.35, 0.3)
		elif n["sev"] >= 2:
			col = Color(1.0, 0.85, 0.3)
		var label: String = str(n["text"]).to_upper()
		if n["dir"] > 0:
			label += "  < LEFT"
		elif n["dir"] < 0:
			label += "  RIGHT >"
		else:
			label += "  %dm" % n["len"]
		var f := fs if shown > 0 else fs + 6
		draw_string(font, Vector2(x0, y), label, HORIZONTAL_ALIGNMENT_LEFT, w, f, col)
		draw_string(font, Vector2(x0, y), "%dm" % dist, HORIZONTAL_ALIGNMENT_RIGHT, w, f, Color(0.85, 0.85, 0.9))
		y += f + 10
		shown += 1
		if shown >= 4 or y > paper.end.y - 6:
			break
	if shown == 0:
		var left_m := maxi(0, (track.points.size() - 1 - idx) * int(Track.STEP))
		draw_string(font, Vector2(x0, y), "FINISH IN %dm" % left_m, HORIZONTAL_ALIGNMENT_LEFT, w, fs + 6, Color(1, 1, 1))
