# Copyright (c) 2026 KRG Studios. All rights reserved. See LICENSE.
class_name ZoneIcon
extends Control
## Vector icon drawn inside a race button. `tall`: icon above the label; otherwise icon at the left edge.

var kind := ""
var tall := true


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var r: float
	var c: Vector2
	if tall:
		var f := 0.25 if size.y >= 100.0 else (0.17 if size.y < 70.0 else 0.2)
		r = clampf(minf(size.y * f, size.x * 0.24), 9.0, 36.0)
		c = Vector2(size.x * 0.5, size.y * (0.3 if size.y >= 70.0 else 0.28))
	else:
		r = clampf(size.y * 0.27, 8.0, 16.0)
		c = Vector2(size.y * 0.52, size.y * 0.5)
	var col := Color(1, 1, 1, 0.97)
	if kind == "hazard" or kind == "bulb":
		col = Color(1.0, 0.8, 0.25)
	elif kind == "beam":
		col = Color(0.55, 0.8, 1.0)
	draw_set_transform(c + Vector2(0, r * 0.07), 0.0, Vector2(r, r))
	_shape(Color(0, 0, 0, 0.5), r)
	draw_set_transform(c, 0.0, Vector2(r, r))
	_shape(col, r)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _poly(pts: Array, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array(pts), col)


## everything is drawn in a -1..1 box; the transform scales it to the button
func _shape(c: Color, r: float) -> void:
	var w := 2.2 / r * 1.0 * 1.0
	w = 2.4 / r
	match kind:
		"gas":
			_poly([Vector2(-0.55, 0.95), Vector2(0.55, 0.95), Vector2(0.38, -0.95), Vector2(-0.38, -0.95)], c)
			for y in [-0.5, -0.05, 0.4]:
				draw_line(Vector2(-0.35, y), Vector2(0.35, y), Color(0, 0, 0, 0.55), w)
		"brake":
			draw_rect(Rect2(-0.95, -0.55, 1.9, 1.1), c)
			for x in [-0.5, 0.0, 0.5]:
				draw_line(Vector2(x, -0.4), Vector2(x, 0.4), Color(0, 0, 0, 0.55), w)
		"horn":
			_poly([Vector2(-0.9, -0.3), Vector2(-0.35, -0.3), Vector2(0.25, -0.8), Vector2(0.25, 0.8), Vector2(-0.35, 0.3), Vector2(-0.9, 0.3)], c)
			draw_arc(Vector2(0.3, 0), 0.5, -0.9, 0.9, 10, c, w)
			draw_arc(Vector2(0.3, 0), 0.9, -0.8, 0.8, 12, c, w)
		"arrow_l":
			_poly([Vector2(-0.95, 0), Vector2(-0.1, -0.8), Vector2(-0.1, -0.3), Vector2(0.9, -0.3), Vector2(0.9, 0.3), Vector2(-0.1, 0.3), Vector2(-0.1, 0.8)], c)
		"arrow_r":
			_poly([Vector2(0.95, 0), Vector2(0.1, -0.8), Vector2(0.1, -0.3), Vector2(-0.9, -0.3), Vector2(-0.9, 0.3), Vector2(0.1, 0.3), Vector2(0.1, 0.8)], c)
		"arrow_u":
			_poly([Vector2(0, -0.95), Vector2(-0.8, -0.1), Vector2(-0.3, -0.1), Vector2(-0.3, 0.9), Vector2(0.3, 0.9), Vector2(0.3, -0.1), Vector2(0.8, -0.1)], c)
		"light", "beam":
			draw_arc(Vector2(-0.45, 0), 0.5, -PI * 0.5, PI * 0.5, 12, c, w * 1.3)
			draw_line(Vector2(-0.45, -0.5), Vector2(-0.45, 0.5), c, w * 1.3)
			var n := 3 if kind == "light" else 4
			for i in n:
				var y := (float(i) - float(n - 1) * 0.5) * (0.62 if n == 3 else 0.5)
				draw_line(Vector2(0.2, y), Vector2(0.95, y), c, w)
		"wiper":
			draw_arc(Vector2(0, 0.7), 1.5, -2.4, -0.74, 14, c, w)
			draw_line(Vector2(0, 0.7), Vector2(0.55, -0.55), c, w * 1.3)
			draw_circle(Vector2(0, 0.7), 0.13, c)
		"more":
			draw_polyline(PackedVector2Array([Vector2(-0.8, -0.7), Vector2(-0.1, 0), Vector2(-0.8, 0.7)]), c, w * 1.4)
			draw_polyline(PackedVector2Array([Vector2(0.0, -0.7), Vector2(0.7, 0), Vector2(0.0, 0.7)]), c, w * 1.4)
		"back":
			draw_polyline(PackedVector2Array([Vector2(0.8, -0.7), Vector2(0.1, 0), Vector2(0.8, 0.7)]), c, w * 1.4)
			draw_polyline(PackedVector2Array([Vector2(0.0, -0.7), Vector2(-0.7, 0), Vector2(0.0, 0.7)]), c, w * 1.4)
		"cup":
			_poly([Vector2(-0.55, -0.4), Vector2(0.55, -0.4), Vector2(0.4, 0.95), Vector2(-0.4, 0.95)], c)
			draw_line(Vector2(0.15, -0.4), Vector2(0.4, -0.95), c, w)
		"mirror_l", "mirror_r":
			var s := -1.0 if kind == "mirror_l" else 1.0
			draw_rect(Rect2(-0.6 + s * 0.2, -0.65, 1.2, 1.1), c, false, w * 1.2)
			draw_line(Vector2(-s * 0.4, 0.45), Vector2(-s * 0.95, 0.9), c, w * 1.3)
		"hazard":
			draw_polyline(PackedVector2Array([Vector2(0, -0.9), Vector2(0.95, 0.8), Vector2(-0.95, 0.8), Vector2(0, -0.9)]), c, w * 1.3)
			draw_line(Vector2(0, -0.35), Vector2(0, 0.25), c, w * 1.3)
			draw_circle(Vector2(0, 0.55), 0.09, c)
		"hbrake":
			draw_arc(Vector2.ZERO, 0.85, 0, TAU, 24, c, w * 1.2)
			draw_arc(Vector2.ZERO, 1.05, 0.6, 2.5, 8, c, w)
			draw_arc(Vector2.ZERO, 1.05, 3.7, 5.6, 8, c, w)
			draw_line(Vector2(-0.2, 0.4), Vector2(-0.2, -0.4), c, w * 1.3)
			draw_arc(Vector2(0.0, -0.2), 0.25, -PI * 0.5, PI * 0.5, 8, c, w * 1.3)
		"window":
			draw_rect(Rect2(-0.8, -0.8, 1.6, 1.6), c, false, w * 1.2)
			draw_line(Vector2(0, 0.5), Vector2(0, -0.5), c, w)
			draw_polyline(PackedVector2Array([Vector2(-0.3, -0.2), Vector2(0, -0.55), Vector2(0.3, -0.2)]), c, w)
		"fan":
			for i in 3:
				var a := float(i) * TAU / 3.0
				draw_arc(Vector2.ZERO.move_toward(Vector2.from_angle(a), 0.45), 0.45, a - 1.0, a + 1.6, 8, c, w * 1.2)
			draw_circle(Vector2.ZERO, 0.16, c)
		"bulb":
			draw_arc(Vector2(0, -0.2), 0.6, 0, TAU, 20, c, w * 1.2)
			draw_rect(Rect2(-0.3, 0.45, 0.6, 0.4), c)
			for a in [-2.4, -1.57, -0.74]:
				draw_line(Vector2.from_angle(a) * 0.9 + Vector2(0, -0.2), Vector2.from_angle(a) * 1.2 + Vector2(0, -0.2), c, w)
		"hand":
			draw_rect(Rect2(-0.5, -0.1, 1.0, 0.95), c)
			for x in [-0.4, -0.13, 0.13, 0.4]:
				draw_line(Vector2(x, -0.1), Vector2(x, -0.85 if absf(x) < 0.3 else -0.65), c, w * 1.6)
		"reset":
			draw_arc(Vector2.ZERO, 0.7, -1.2, 4.0, 18, c, w * 1.3)
			_poly([Vector2(0.45, -1.0), Vector2(0.95, -0.35), Vector2(0.1, -0.3)], c)
		"smile":
			draw_arc(Vector2.ZERO, 0.9, 0, TAU, 24, c, w * 1.2)
			draw_circle(Vector2(-0.32, -0.25), 0.11, c)
			draw_circle(Vector2(0.32, -0.25), 0.11, c)
			draw_arc(Vector2(0, 0.05), 0.5, 0.4, PI - 0.4, 10, c, w * 1.2)
		"fist":
			draw_rect(Rect2(-0.75, -0.4, 1.5, 1.2), c)
			for x in [-0.4, 0.0, 0.4]:
				draw_line(Vector2(x, -0.4), Vector2(x, 0.1), Color(0, 0, 0, 0.5), w)
			draw_rect(Rect2(-0.95, 0.1, 0.3, 0.55), c)
		"star":
			var pts: Array = []
			for i in 10:
				var rr := 1.0 if i % 2 == 0 else 0.42
				pts.append(Vector2.from_angle(-PI * 0.5 + float(i) * PI / 5.0) * rr)
			_poly(pts, c)
		"camera":
			draw_rect(Rect2(-0.95, -0.5, 1.9, 1.4), c, false, w * 1.2)
			draw_rect(Rect2(-0.4, -0.85, 0.8, 0.35), c)
			draw_arc(Vector2(0, 0.2), 0.42, 0, TAU, 16, c, w * 1.2)
		"menu":
			for y in [-0.6, 0.0, 0.6]:
				draw_line(Vector2(-0.8, y), Vector2(0.8, y), c, w * 1.6)
		"grid":
			for p in [Vector2(-0.85, -0.85), Vector2(0.1, -0.85), Vector2(-0.85, 0.1), Vector2(0.1, 0.1)]:
				draw_rect(Rect2(p, Vector2(0.75, 0.75)), c, false, w * 1.2)
		"play":
			_poly([Vector2(-0.6, -0.85), Vector2(0.9, 0), Vector2(-0.6, 0.85)], c)
		"radio":
			draw_rect(Rect2(-0.95, -0.35, 1.9, 1.3), c, false, w * 1.2)
			draw_line(Vector2(-0.4, -0.35), Vector2(0.5, -0.95), c, w)
			draw_circle(Vector2(-0.4, 0.3), 0.28, c)
			draw_line(Vector2(0.1, 0.1), Vector2(0.7, 0.1), c, w)
			draw_line(Vector2(0.1, 0.5), Vector2(0.7, 0.5), c, w)
		"expand":
			for q in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
				draw_line(q * 0.9, Vector2(q.x * 0.9, q.y * 0.35), c, w * 1.4)
				draw_line(q * 0.9, Vector2(q.x * 0.35, q.y * 0.9), c, w * 1.4)
		"zoom":
			draw_arc(Vector2(-0.2, -0.2), 0.62, 0, TAU, 18, c, w * 1.3)
			draw_line(Vector2(0.25, 0.25), Vector2(0.9, 0.9), c, w * 1.8)
			draw_line(Vector2(-0.2, -0.45), Vector2(-0.2, 0.05), c, w)
			draw_line(Vector2(-0.45, -0.2), Vector2(0.05, -0.2), c, w)
		"pin":
			draw_arc(Vector2(0, -0.3), 0.6, PI * 0.15, PI * 0.85 + PI, 18, c, w * 1.3)
			_poly([Vector2(-0.5, 0.05), Vector2(0.5, 0.05), Vector2(0, 0.95)], c)
			draw_circle(Vector2(0, -0.3), 0.2, Color(0, 0, 0, 0.55))
		"wave":
			draw_circle(Vector2.ZERO, 0.2, c)
			draw_arc(Vector2.ZERO, 0.6, -0.9, 0.9, 8, c, w * 1.2)
			draw_arc(Vector2.ZERO, 0.95, -0.8, 0.8, 10, c, w * 1.2)
			draw_arc(Vector2.ZERO, 0.6, PI - 0.9, PI + 0.9, 8, c, w * 1.2)
			draw_arc(Vector2.ZERO, 0.95, PI - 0.8, PI + 0.8, 10, c, w * 1.2)
		"stop":
			var o: Array = []
			for i in 8:
				o.append(Vector2.from_angle(PI / 8.0 + float(i) * PI / 4.0) * 0.95)
			_poly(o, c)
			draw_line(Vector2(-0.45, 0), Vector2(0.45, 0), Color(0, 0, 0, 0.6), w * 1.6)
