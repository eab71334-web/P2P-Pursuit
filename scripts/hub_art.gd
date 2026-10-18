class_name HubArt
extends RefCounted
## Small vector illustrations for the garage and chest screens (drawn with _draw, no textures).


## Side silhouette of a car. Front points to the right.
class CarArt extends Control:
	var model := "hatch"
	var paint := Color(0.8, 0.1, 0.1)
	var rim := Color(0.7, 0.72, 0.76)
	var locked := false
	var accent := Color(1.0, 0.47, 0.1)
	# cab: [front base x, roof front x, roof back x, rear base x, cabin height, belt y]
	const SHAPES := {
		"hatch": {"cab": [134, 116, 64, 50, 30, 52], "wing": "small", "nose": 0.0},
		"buggy": {"cab": [126, 112, 74, 66, 26, 54], "wing": "cage", "nose": 0.0},
		"muscle": {"cab": [128, 112, 72, 56, 22, 52], "wing": "duck", "nose": 4.0},
		"sierra": {"cab": [130, 114, 64, 48, 26, 52], "wing": "whale", "nose": 0.0},
		"pickup": {"cab": [136, 120, 92, 86, 32, 50], "wing": "bed", "nose": 0.0},
		"charger": {"cab": [130, 114, 66, 50, 24, 52], "wing": "duck", "nose": 2.0},
		"m4": {"cab": [128, 110, 70, 54, 22, 53], "wing": "lip", "nose": 4.0},
		"coupe": {"cab": [128, 110, 70, 54, 22, 53], "wing": "lip", "nose": 4.0},
		"gt3": {"cab": [124, 108, 74, 58, 20, 54], "wing": "gt", "nose": 6.0},
		"hyper": {"cab": [122, 104, 72, 56, 19, 55], "wing": "gt", "nose": 8.0},
	}

	func _draw() -> void:
		var sc := minf(size.x / 200.0, size.y / 90.0)
		var off := Vector2((size.x - 200.0 * sc) * 0.5, (size.y - 90.0 * sc) * 0.5)
		draw_set_transform(off, 0.0, Vector2(sc, sc))
		var body := paint
		var dark := Color(0.06, 0.07, 0.09)
		var glass := Color(0.55, 0.7, 0.85, 0.9)
		if locked:
			var g := (paint.r + paint.g + paint.b) / 3.0
			body = Color(0.2 + g * 0.15, 0.22 + g * 0.15, 0.27 + g * 0.15)
			glass = Color(0.3, 0.35, 0.42)
			rim = Color(0.3, 0.33, 0.4)
		var sh: Dictionary = SHAPES.get(model, SHAPES["hatch"])
		var cab: Array = sh["cab"]
		var nose: float = sh["nose"]
		var belt: float = cab[5]
		var ch: float = float(cab[4]) * 1.35
		# ground shadow
		draw_rect(Rect2(14, 78, 172, 3), Color(0, 0, 0, 0.35))
		# lower body
		var low := PackedVector2Array([Vector2(10, belt + 2), Vector2(14, belt - 4), Vector2(cab[0] + 8, belt - 2 + nose * 0.2), Vector2(190, belt + 3 + nose * 0.3),
			Vector2(192, 70), Vector2(188, 74), Vector2(10, 74), Vector2(8, 70)])
		draw_colored_polygon(low, body)
		# cabin
		var cabin := PackedVector2Array([Vector2(cab[0], belt - 2), Vector2(cab[1], belt - ch), Vector2(cab[2], belt - ch), Vector2(cab[3], belt - 3)])
		if model == "buggy":
			draw_polyline(PackedVector2Array([Vector2(cab[0], belt - 2), Vector2(cab[1], belt - ch), Vector2(cab[2], belt - ch), Vector2(cab[3], belt - 3)]), body.darkened(0.2), 3.0)
		else:
			draw_colored_polygon(cabin, body.lightened(0.04))
			var inset := PackedVector2Array([Vector2(cab[0] - 5, belt - 4), Vector2(cab[1] - 2, belt - ch + 4), Vector2(cab[2] + 3, belt - ch + 4), Vector2(cab[3] + 6, belt - 5)])
			draw_colored_polygon(inset, glass)
			var mid: float = (float(cab[1]) + float(cab[2])) * 0.5 + 6.0
			draw_line(Vector2(mid, belt - ch + 4), Vector2(mid, belt - 4), body, 3.0)
		if model == "pickup":
			draw_rect(Rect2(14, belt - 8, cab[3] - 14 + 4, 6), body.darkened(0.25))
		# gloss line along the shoulder
		draw_line(Vector2(16, belt + 3), Vector2(186, belt + 4 + nose * 0.3), Color(1, 1, 1, 0.16), 1.5)
		# lower sill + bumpers
		draw_rect(Rect2(28, 69, 144, 4), dark)
		draw_rect(Rect2(184, belt + 6, 8, 12), dark)
		draw_rect(Rect2(8, belt + 6, 6, 12), dark)
		# lights
		draw_rect(Rect2(184, belt + 2, 7, 4), Color(1, 0.96, 0.75) if not locked else Color(0.5, 0.52, 0.58))
		draw_rect(Rect2(8, belt + 2, 5, 4), Color(0.95, 0.15, 0.1) if not locked else Color(0.4, 0.3, 0.32))
		# spoilers
		match sh["wing"]:
			"gt":
				draw_rect(Rect2(6, belt - ch - 2, 3, ch + 4), dark)
				draw_rect(Rect2(0, belt - ch - 5, 30, 4), dark if not locked else Color(0.25, 0.28, 0.33))
			"whale":
				draw_rect(Rect2(4, belt - 8, 24, 3), body.darkened(0.15))
			"duck", "lip":
				draw_rect(Rect2(6, belt - 6, 20, 3), body.darkened(0.15))
			"small":
				draw_rect(Rect2(8, belt - 14, 20, 3), body.darkened(0.2))
			"cage":
				draw_rect(Rect2(10, 30, 120, 2), dark)
		# wheels
		for wx in [48.0, 154.0]:
			draw_circle(Vector2(wx, 66), 14.0, Color(0.03, 0.03, 0.04))
			draw_circle(Vector2(wx, 66), 9.0, rim)
			draw_circle(Vector2(wx, 66), 5.0, Color(0.08, 0.09, 0.11))
			draw_circle(Vector2(wx, 66), 1.8, rim)
		if locked:
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Preview of a paint / stripe / rim / underglow option.
class SwatchArt extends Control:
	var slot := "paint"
	var col := Color.WHITE
	var base := Color(0.8, 0.1, 0.1)        # current car paint (for stripes)
	var metal := 0.0
	var rough := 0.5
	var none := false
	var selected := false

	func _draw() -> void:
		var r := Rect2(Vector2.ZERO, size)
		var cx := size.x * 0.5
		var cy := size.y * 0.5
		match slot:
			"paint":
				var st := UI.sb(col, 10)
				draw_style_box(st, r)
				# finish: glossy sweep (metallic = stronger, matte = none)
				var gl := clampf(1.0 - rough, 0.0, 1.0)
				if gl > 0.15:
					draw_colored_polygon(PackedVector2Array([Vector2(size.x * 0.12, 4), Vector2(size.x * 0.5, 4), Vector2(size.x * 0.22, size.y - 4), Vector2(size.x * 0.12, size.y - 4)]), Color(1, 1, 1, 0.07 + gl * 0.2))
				draw_rect(Rect2(0, size.y * 0.72, size.x, size.y * 0.28), Color(0, 0, 0, 0.18))
				if metal > 0.9:
					draw_rect(Rect2(0, 0, size.x, 3), Color(1, 1, 1, 0.35))
			"stripe":
				draw_style_box(UI.sb(base, 10), r)
				if none:
					draw_line(Vector2(size.x * 0.25, size.y * 0.8), Vector2(size.x * 0.75, size.y * 0.2), Color(1, 1, 1, 0.5), 3.0)
				else:
					for k in [-1.0, 1.0]:
						draw_rect(Rect2(cx + k * size.x * 0.1 - size.x * 0.055, 0, size.x * 0.11, size.y), col)
			"rim":
				draw_style_box(UI.sb(Color(0.07, 0.075, 0.09), 10), r)
				var rad := minf(size.x, size.y) * 0.42
				draw_circle(Vector2(cx, cy), rad, Color(0.03, 0.03, 0.04))
				draw_circle(Vector2(cx, cy), rad * 0.74, col)
				draw_circle(Vector2(cx, cy), rad * 0.6, Color(0.07, 0.08, 0.1))
				for k in 5:
					var a := TAU * k / 5.0 - PI / 2.0
					draw_line(Vector2(cx, cy), Vector2(cx, cy) + Vector2(cos(a), sin(a)) * rad * 0.72, col, 3.5)
				draw_circle(Vector2(cx, cy), rad * 0.16, col.lightened(0.3))
			"glow":
				draw_style_box(UI.sb(Color(0.07, 0.075, 0.09), 10), r)
				if none:
					draw_arc(Vector2(cx, cy), minf(size.x, size.y) * 0.25, 0, TAU, 28, Color(1, 1, 1, 0.35), 2.0)
					draw_line(Vector2(cx - 14, cy + 14), Vector2(cx + 14, cy - 14), Color(1, 1, 1, 0.35), 2.0)
				else:
					for i in 6:
						var k := 1.0 - i / 6.0
						draw_circle(Vector2(cx, cy + 6), size.x * 0.4 * k, Color(col.r, col.g, col.b, 0.07 + (1.0 - k) * 0.16))
					draw_rect(Rect2(cx - size.x * 0.3, cy - 3, size.x * 0.6, 6), col)
		if selected:
			draw_style_box(UI.sb(Color.TRANSPARENT, 10, UI.ACCENT, 3), r)


## Treasure chest: wooden body with metal bands in the tier colour, hinged lid, lock, light beam when open.
class ChestBox extends Control:
	var tier := Color(0.8, 0.5, 0.25)       # band colour
	var burst := Color(1.0, 0.85, 0.4)      # light colour when open
	var t := 0.0
	var shake := 0.0
	var open := 0.0                          # 0 closed .. 1 fully open
	var charge := 0.0                        # glow building up while it shakes
	var idle := true
	var _sparks: Array = []

	func _process(d: float) -> void:
		t += d
		if open > 0.4 and _sparks.size() < 40 and randf() < 0.7:
			_sparks.append({"p": Vector2(randf_range(-0.3, 0.3), 0.0), "v": Vector2(randf_range(-0.25, 0.25), randf_range(-0.9, -0.4)), "life": randf_range(0.8, 1.5), "age": 0.0})
		for s in _sparks:
			s["age"] += d
			s["p"] += s["v"] * d
		_sparks = _sparks.filter(func(s): return s["age"] < s["life"])
		queue_redraw()

	func _draw() -> void:
		var u := minf(size.x, size.y) / 100.0
		var cx := size.x * 0.5 + sin(t * 55.0) * shake * 4.0 * u
		var base_y := size.y * 0.5 + 34.0 * u
		var bob := sin(t * 2.0) * 1.5 * u if idle else 0.0
		var wood := Color(0.30, 0.19, 0.11)
		var wood2 := Color(0.38, 0.25, 0.15)
		var band := tier
		var o := Vector2(cx, base_y + bob)
		# shadow
		draw_set_transform(Vector2(cx, base_y + 4.0 * u), 0.0, Vector2(1.0, 0.22))
		draw_circle(Vector2.ZERO, 46.0 * u, Color(0, 0, 0, 0.35))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# light beam + rays (behind the chest)
		var glow := maxf(open, charge * 0.6)
		if glow > 0.01:
			for i in 9:
				var a := -PI / 2.0 + (i - 4) * 0.16 + sin(t * 0.8 + i) * 0.03
				var len := (70.0 + 90.0 * open) * u
				var p1 := o + Vector2(0, -34.0 * u)
				var p2 := p1 + Vector2(cos(a - 0.05), sin(a - 0.05)) * len
				var p3 := p1 + Vector2(cos(a + 0.05), sin(a + 0.05)) * len
				draw_colored_polygon(PackedVector2Array([p1, p2, p3]), Color(burst.r, burst.g, burst.b, 0.16 * glow))
			for i in 5:
				var k := 1.0 - i / 5.0
				draw_circle(o + Vector2(0, -34.0 * u), 46.0 * u * k * (0.6 + glow * 0.6), Color(burst.r, burst.g, burst.b, 0.05 + 0.08 * glow))
		# body
		var bw := 84.0 * u
		var bh := 38.0 * u
		var body := Rect2(o.x - bw * 0.5, o.y - bh, bw, bh)
		draw_rect(body, wood)
		for k in 3:                                  # planks
			draw_rect(Rect2(body.position.x, body.position.y + bh * k / 3.0, bw, 1.5 * u), Color(0, 0, 0, 0.25))
		draw_rect(Rect2(body.position.x, body.position.y, bw, 4.0 * u), wood2)
		for sx in [-0.38, 0.38]:                     # vertical metal bands
			draw_rect(Rect2(o.x + sx * bw - 5.0 * u, body.position.y, 10.0 * u, bh), band.darkened(0.15))
			draw_rect(Rect2(o.x + sx * bw - 5.0 * u, body.position.y, 2.5 * u, bh), band.lightened(0.25))
		draw_rect(Rect2(body.position.x - 1.5 * u, body.end.y - 5.0 * u, bw + 3.0 * u, 5.0 * u), band.darkened(0.3))   # foot rail
		# inside glow
		if open > 0.02:
			draw_rect(Rect2(body.position.x + 3.0 * u, body.position.y - 3.0 * u * open, bw - 6.0 * u, 5.0 * u), Color(burst.r, burst.g, burst.b, 0.9))
		# lid: pivots on the rear top edge, flips up
		var hinge := Vector2(o.x, body.position.y - open * 20.0 * u)
		draw_set_transform(hinge, 0.0, Vector2(1.0, 1.0 - 0.5 * open))
		var lw := bw + 4.0 * u
		var lh := 20.0 * u
		var lid := PackedVector2Array()
		for i in 13:
			var a := PI + PI * i / 12.0
			lid.append(Vector2(cos(a) * lw * 0.5, sin(a) * lh))
		lid.append(Vector2(lw * 0.5, 0))
		lid.append(Vector2(-lw * 0.5, 0))
		draw_colored_polygon(lid, wood2)
		for sx in [-0.38, 0.38]:
			var bx: float = sx * bw
			draw_rect(Rect2(bx - 5.0 * u, -lh * (1.0 - sx * sx * 0.0) * 0.82, 10.0 * u, lh * 0.82), band.darkened(0.15))
		draw_rect(Rect2(-lw * 0.5, -2.0 * u, lw, 4.0 * u), band)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# lock plate (fades away when open)
		if open < 0.3:
			var la := 1.0 - open / 0.3
			draw_rect(Rect2(o.x - 7.0 * u, body.position.y - 2.0 * u, 14.0 * u, 16.0 * u), Color(band.r, band.g, band.b, la))
			draw_circle(Vector2(o.x, body.position.y + 5.0 * u), 2.6 * u, Color(0.05, 0.04, 0.03, la))
			draw_rect(Rect2(o.x - 1.0 * u, body.position.y + 5.0 * u, 2.0 * u, 6.0 * u), Color(0.05, 0.04, 0.03, la))
		# sparkles
		for s in _sparks:
			var k: float = 1.0 - float(s["age"]) / float(s["life"])
			var p: Vector2 = o + Vector2(0, -34.0 * u) + (s["p"] as Vector2) * 100.0 * u
			draw_rect(Rect2(p - Vector2(1.5, 1.5) * u, Vector2(3, 3) * u), Color(burst.r, burst.g, burst.b, k))
