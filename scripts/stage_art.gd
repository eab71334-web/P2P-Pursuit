# Copyright (c) 2026 Sabak Studios. All rights reserved. See LICENSE.
class_name StageArt
extends Control
## Animated stage picture drawn in code: sky, ridges, trees, a road that scrolls towards you, and the weather.
## Used as the big preview in Custom Race and as the poster on every Career stage card.

const N := 22
const THEMES := {
	"mountain": {"far": Color(0.46, 0.53, 0.63), "mid": Color(0.30, 0.38, 0.43), "near": Color(0.17, 0.25, 0.24), "ground": Color(0.24, 0.29, 0.23),
		"tree": Color(0.08, 0.22, 0.14), "amp": [0.36, 0.27, 0.17], "sharp": true},
	"snow": {"far": Color(0.62, 0.72, 0.86), "mid": Color(0.78, 0.85, 0.94), "near": Color(0.88, 0.92, 0.98), "ground": Color(0.9, 0.93, 0.97),
		"tree": Color(0.1, 0.26, 0.22), "amp": [0.30, 0.22, 0.13], "sharp": true},
	"autumn": {"far": Color(0.55, 0.42, 0.44), "mid": Color(0.5, 0.32, 0.2), "near": Color(0.4, 0.26, 0.12), "ground": Color(0.38, 0.33, 0.14),
		"tree": Color(0.86, 0.4, 0.1), "amp": [0.2, 0.15, 0.1], "sharp": false},
}
const WX := {
	"clear": {"top": Color(0.2, 0.44, 0.82), "bot": Color(0.74, 0.85, 0.95), "mul": 1.0, "haze": 0.0, "rain": 0.0},
	"fog": {"top": Color(0.6, 0.65, 0.7), "bot": Color(0.82, 0.85, 0.88), "mul": 0.86, "haze": 0.6, "rain": 0.0},
	"rain": {"top": Color(0.26, 0.31, 0.38), "bot": Color(0.55, 0.6, 0.66), "mul": 0.68, "haze": 0.22, "rain": 0.6},
	"night": {"top": Color(0.01, 0.02, 0.07), "bot": Color(0.08, 0.12, 0.26), "mul": 0.22, "haze": 0.05, "rain": 0.0},
	"storm": {"top": Color(0.06, 0.08, 0.12), "bot": Color(0.24, 0.28, 0.35), "mul": 0.4, "haze": 0.16, "rain": 1.0},
}

var scene_theme := "mountain"
var weather := "clear"
var cycle := false  # rotate the theme every few seconds (random track)
var speed := 3.0
var dim := 0.0
var show_car := false
var poster := false  # richer cover look: warm grade, light rays, halftone, grain, vignette
var grade := Color(0, 0, 0, 0)
var _scroll := 0.0
var _t := 0.0
var _cyc_t := 0.0
var _trees: Array = []
var _drops: Array = []
var _stars: Array = []
var _flash := 0.0
var _next_bolt := 2.0
var _bolt := PackedVector2Array()
var _sky_bot := Color.WHITE
var _mul := 1.0
var _haze := 0.0
var _seed := 0.0


func _init(th := "mountain", wx := "clear") -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(120, 80)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in 16:
		_trees.append({"u": float(i) / 16.0 + rng.randf() * 0.03, "side": 1 if i % 2 == 0 else -1, "off": rng.randf_range(1.35, 2.6), "k": rng.randi() % 3})
	for i in 130:
		_drops.append(Vector2(rng.randf(), rng.randf()))
	for i in 60:
		_stars.append(Vector3(rng.randf(), rng.randf() * 0.9, rng.randf() * 6.0))
	_seed = rng.randf() * 6.0
	set_scene(th, wx)


func set_scene(th: String, wx: String) -> void:
	scene_theme = th if THEMES.has(th) else "mountain"
	weather = wx if WX.has(wx) else "clear"
	var w: Dictionary = WX[weather]
	_sky_bot = w["bot"]
	_mul = float(w["mul"])
	_haze = float(w["haze"])
	queue_redraw()


func _process(dt: float) -> void:
	if not is_visible_in_tree() or size.x < 8:
		return
	_t += dt
	_scroll += dt * speed * (0.0 if dim > 0.5 else 1.0)
	var rain := float(WX[weather]["rain"])
	if rain > 0.0:
		for i in _drops.size():
			var d: Vector2 = _drops[i]
			d.y += dt * (1.5 + (i % 5) * 0.12)
			d.x -= dt * 0.25
			if d.y > 1.0:
				d.y -= 1.0
			if d.x < 0.0:
				d.x += 1.0
			_drops[i] = d
	if weather == "storm":
		_next_bolt -= dt
		if _next_bolt <= 0.0:
			_flash = 1.0
			_next_bolt = randf_range(2.0, 4.5)
			_bolt = PackedVector2Array()
			var x := size.x * randf_range(0.2, 0.8)
			var y := 0.0
			while y < size.y * 0.5:
				_bolt.append(Vector2(x, y))
				x += randf_range(-18.0, 18.0)
				y += randf_range(12.0, 26.0)
		_flash = maxf(0.0, _flash - dt * 2.6)
	if cycle:
		_cyc_t += dt
		if _cyc_t > 3.2:
			_cyc_t = 0.0
			var order := ["mountain", "snow", "autumn"]
			set_scene(order[(order.find(scene_theme) + 1) % 3], weather)
	queue_redraw()


func _tc(c: Color, depth := 0.0) -> Color:
	var k := Color(c.r * _mul, c.g * _mul, c.b * _mul, c.a)
	if weather == "night" or weather == "storm":
		k = k.lerp(Color(0.04, 0.07, 0.16, c.a), 0.25)
	return k.lerp(Color(_sky_bot.r, _sky_bot.g, _sky_bot.b, c.a), _haze * (0.35 + 0.55 * depth))


func _cx(p: float, w: float, bend: float) -> float:
	var q := 1.0 - p
	return w * 0.5 + bend * w * 0.42 * q * q


func _hw(p: float, w: float) -> float:
	return lerpf(w * 0.012, w * 0.43, p)


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 8:
		return
	var th: Dictionary = THEMES[scene_theme]
	var wx: Dictionary = WX[weather]
	var hz := h * 0.5
	var bend := sin(_t * 0.4 + _seed) * 0.55
	# sky
	var top: Color = wx["top"]
	var bot: Color = wx["bot"]
	if poster and weather == "clear":
		bot = bot.lerp(Color(1.0, 0.72, 0.42), 0.5)
		top = top.lerp(Color(0.12, 0.22, 0.55), 0.35)
	var midc := top.lerp(bot, 0.55)
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, hz * 0.55), Vector2(0, hz * 0.55)]), PackedColorArray([top, top, midc, midc]))
	draw_polygon(PackedVector2Array([Vector2(0, hz * 0.55), Vector2(w, hz * 0.55), Vector2(w, hz), Vector2(0, hz)]), PackedColorArray([midc, midc, bot, bot]))
	if poster and weather == "clear":
		var sunp := Vector2(w * 0.5, hz * 0.8)
		for q in 7:
			var a0 := -PI * 0.5 + (q - 3) * 0.19 + sin(_t * 0.2 + q) * 0.02
			draw_colored_polygon(PackedVector2Array([sunp, sunp + Vector2(cos(a0 - 0.045), sin(a0 - 0.045)) * w * 1.3, sunp + Vector2(cos(a0 + 0.045), sin(a0 + 0.045)) * w * 1.3]), Color(1.0, 0.9, 0.65, 0.07))
	if weather == "night" or weather == "storm":
		var sa := 1.0 if weather == "night" else 0.25
		for s in _stars:
			var tw := 0.5 + 0.5 * sin(_t * 1.6 + s.z)
			draw_circle(Vector2(s.x * w, s.y * hz), 1.1, Color(1, 1, 1, (0.35 + 0.5 * tw) * sa))
	if weather == "night":
		var mp := Vector2(w * 0.78, hz * 0.34)
		for r in [46.0, 30.0, 18.0]:
			draw_circle(mp, r * h / 340.0, Color(0.7, 0.8, 1.0, 0.07))
		draw_circle(mp, 11.0 * h / 340.0, Color(0.92, 0.95, 1.0, 0.95))
	elif weather == "clear":
		var sp := Vector2(w * 0.22, hz * 0.62)
		for r in [90.0, 60.0, 36.0, 20.0]:
			draw_circle(sp, r * h / 340.0, Color(1.0, 0.92, 0.7, 0.08))
		draw_circle(sp, 13.0 * h / 340.0, Color(1.0, 0.97, 0.85, 0.95))
	if _flash > 0.35 and _bolt.size() > 1:
		draw_polyline(_bolt, Color(0.9, 0.93, 1.0, _flash), 2.0)
	# ridges
	var layers := [["far", 1.0], ["mid", 0.6], ["near", 0.25]]
	for li in 3:
		var base: Color = th[layers[li][0]]
		var col := _tc(base, float(layers[li][1]))
		var amp: float = th["amp"][li]
		var pts := PackedVector2Array()
		var cols := PackedColorArray()
		var cap := _tc(Color(0.96, 0.98, 1.0) if scene_theme != "autumn" else base.lightened(0.25), float(layers[li][1]))
		var n := 40
		for i in n + 1:
			var u := float(i) / n
			var ph := _seed + li * 2.3 + bend * (0.5 + li * 0.3)
			var v: float
			if th["sharp"]:
				v = absf(sin(u * (3.0 + li * 1.6) + ph)) * 0.62 + absf(sin(u * (7.5 + li * 2.1) + ph * 1.7)) * 0.38
			else:
				v = 0.5 + 0.32 * sin(u * (3.5 + li * 1.4) + ph) + 0.18 * sin(u * (8.0 + li) + ph * 2.0)
			pts.append(Vector2(u * w, hz - amp * h * v))
			var cf := 0.0
			if scene_theme != "snow":
				cf = smoothstep(0.62, 0.95, v) if li < 2 and scene_theme == "mountain" else 0.0
			cols.append(col.lerp(cap, cf))
		pts.append(Vector2(w, hz + 2.0))
		pts.append(Vector2(0, hz + 2.0))
		cols.append(col)
		cols.append(col)
		draw_polygon(pts, cols)
	# ground
	var g := _tc(th["ground"], 0.5)
	var g2 := _tc(th["ground"], 0.0).darkened(0.12)
	draw_polygon(PackedVector2Array([Vector2(0, hz), Vector2(w, hz), Vector2(w, h), Vector2(0, h)]), PackedColorArray([g, g, g2, g2]))
	# road strips (perspective, scrolling)
	var k := floori(_scroll)
	var s := _scroll - k
	for i in range(-1, N):
		var t0 := clampf((float(i) + s) / N, 0.0, 1.0)
		var t1 := clampf((float(i) + 1.0 + s) / N, 0.0, 1.0)
		if t1 <= t0:
			continue
		var p0 := t0 * t0
		var p1 := t1 * t1
		var y0 := hz + (h - hz) * p0
		var y1 := hz + (h - hz) * p1
		var par := (i - k) & 1
		# verge shading
		if par == 0:
			draw_rect(Rect2(0, y0, w, y1 - y0 + 0.6), Color(0, 0, 0, 0.07))
		var c0 := _cx(p0, w, bend)
		var c1 := _cx(p1, w, bend)
		var h0 := _hw(p0, w)
		var h1 := _hw(p1, w)
		var asp := _tc(Color(0.2, 0.2, 0.225) if par == 0 else Color(0.225, 0.225, 0.25), 0.2 * (1.0 - t1))
		draw_polygon(PackedVector2Array([Vector2(c0 - h0, y0), Vector2(c0 + h0, y0), Vector2(c1 + h1, y1), Vector2(c1 - h1, y1)]), PackedColorArray([asp, asp, asp, asp]))
		# edge lines
		var el := _tc(Color(0.92, 0.92, 0.92) if par == 0 else Color(0.72, 0.72, 0.72), 0.2 * (1.0 - t1))
		var e0 := h0 * 0.07
		var e1 := h1 * 0.07
		draw_polygon(PackedVector2Array([Vector2(c0 - h0, y0), Vector2(c0 - h0 + e0, y0), Vector2(c1 - h1 + e1, y1), Vector2(c1 - h1, y1)]), PackedColorArray([el, el, el, el]))
		draw_polygon(PackedVector2Array([Vector2(c0 + h0 - e0, y0), Vector2(c0 + h0, y0), Vector2(c1 + h1, y1), Vector2(c1 + h1 - e1, y1)]), PackedColorArray([el, el, el, el]))
		if par == 0:
			var d0 := h0 * 0.035
			var d1 := h1 * 0.035
			var dc := _tc(Color(0.95, 0.8, 0.3), 0.2 * (1.0 - t1))
			draw_polygon(PackedVector2Array([Vector2(c0 - d0, y0), Vector2(c0 + d0, y0), Vector2(c1 + d1, y1), Vector2(c1 - d1, y1)]), PackedColorArray([dc, dc, dc, dc]))
	# headlights on dark scenes
	if show_car and (weather == "night" or weather == "storm" or weather == "fog"):
		var cp := 0.9
		var hy := hz + (h - hz) * cp
		var base_c := _cx(cp, w, bend)
		var a := 0.34 if weather == "night" else 0.16
		var ha := _hw(cp, w) * 0.8
		var tip := _cx(0.02, w, bend)
		draw_polygon(PackedVector2Array([Vector2(base_c - ha, hy), Vector2(base_c + ha, hy), Vector2(tip + 5.0, hz + 6.0), Vector2(tip - 5.0, hz + 6.0)]),
			PackedColorArray([Color(1, 0.95, 0.8, a), Color(1, 0.95, 0.8, a), Color(1, 0.95, 0.8, 0.0), Color(1, 0.95, 0.8, 0.0)]))
	# roadside trees (sorted far to near)
	var order: Array = []
	for tr in _trees:
		var u := fposmod(float(tr["u"]) + _scroll / float(N), 1.0)
		order.append([u, tr])
	order.sort_custom(func(a, b): return a[0] < b[0])
	for e in order:
		var u: float = e[0]
		if u < 0.06:
			continue
		var tr: Dictionary = e[1]
		var p := u * u
		var y := hz + (h - hz) * p
		var x := _cx(p, w, bend) + float(tr["side"]) * (_hw(p, w) * float(tr["off"]) + w * 0.01)
		var sz := h * 0.62 * p + 3.0
		_tree(x, y, sz, int(tr["k"]), u)
	if show_car:
		_car(w, h, hz, bend)
	# haze at the horizon
	if _haze > 0.01:
		var hc := Color(_sky_bot.r, _sky_bot.g, _sky_bot.b, 0.0)
		var hc2 := Color(_sky_bot.r, _sky_bot.g, _sky_bot.b, _haze * 0.9)
		draw_polygon(PackedVector2Array([Vector2(0, hz - h * 0.2), Vector2(w, hz - h * 0.2), Vector2(w, hz), Vector2(0, hz)]), PackedColorArray([hc, hc, hc2, hc2]))
		draw_polygon(PackedVector2Array([Vector2(0, hz), Vector2(w, hz), Vector2(w, hz + h * 0.28), Vector2(0, hz + h * 0.28)]), PackedColorArray([hc2, hc2, hc, hc]))
	# rain
	var rain := float(wx["rain"])
	if rain > 0.0:
		var cnt := int(_drops.size() * rain)
		for i in cnt:
			var d: Vector2 = _drops[i]
			var a := Vector2(d.x * w, d.y * h)
			draw_line(a, a + Vector2(-5.0, 16.0) * (h / 340.0), Color(0.85, 0.9, 1.0, 0.45), 1.3)
	if _flash > 0.0:
		draw_rect(Rect2(0, 0, w, h), Color(0.85, 0.9, 1.0, _flash * 0.3))
	if poster:
		_poster_fx(w, h, hz)
	# bottom shade for captions
	draw_polygon(PackedVector2Array([Vector2(0, h * 0.55), Vector2(w, h * 0.55), Vector2(w, h), Vector2(0, h)]),
		PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0.55), Color(0, 0, 0, 0.55)]))
	if dim > 0.0:
		draw_rect(Rect2(0, 0, w, h), Color(0.02, 0.025, 0.04, dim))


func _tree(x: float, y: float, sz: float, kind: int, depth_u: float) -> void:
	var th: Dictionary = THEMES[scene_theme]
	var base: Color = th["tree"]
	var col := _tc(base, 1.0 - depth_u)
	var trunk := _tc(Color(0.22, 0.14, 0.08), 1.0 - depth_u)
	if scene_theme == "autumn":
		var pal := [Color(0.88, 0.42, 0.1), Color(0.78, 0.22, 0.1), Color(0.92, 0.7, 0.16)]
		col = _tc(pal[kind % 3], 1.0 - depth_u)
		draw_rect(Rect2(x - sz * 0.04, y - sz * 0.35, sz * 0.08, sz * 0.35), trunk)
		draw_circle(Vector2(x, y - sz * 0.55), sz * 0.3, col)
		draw_circle(Vector2(x - sz * 0.16, y - sz * 0.42), sz * 0.2, col.darkened(0.12))
		draw_circle(Vector2(x + sz * 0.17, y - sz * 0.44), sz * 0.2, col.lightened(0.06))
	else:
		draw_rect(Rect2(x - sz * 0.035, y - sz * 0.14, sz * 0.07, sz * 0.14), trunk)
		for j in 3:
			var yy := y - sz * (0.12 + j * 0.26)
			var ww := sz * (0.3 - j * 0.07)
			draw_colored_polygon(PackedVector2Array([Vector2(x - ww, yy), Vector2(x + ww, yy), Vector2(x, yy - sz * 0.42)]), col)
			if scene_theme == "snow":
				var sc := _tc(Color(0.96, 0.98, 1.0), 1.0 - depth_u)
				draw_colored_polygon(PackedVector2Array([Vector2(x - ww * 0.55, yy - sz * 0.19), Vector2(x + ww * 0.55, yy - sz * 0.19), Vector2(x, yy - sz * 0.42)]), sc)


func _car(w: float, h: float, hz: float, bend: float) -> void:
	var p := 0.9
	var y := hz + (h - hz) * p
	var x := _cx(p, w, bend) + sin(_t * 1.3) * w * 0.006
	var cw := _hw(p, w) * 0.46
	var ch := cw * 0.62
	var lit := 1.0 if (weather == "night" or weather == "storm") else 0.0
	draw_rect(Rect2(x - cw * 1.02, y - ch * 0.12, cw * 2.04, ch * 0.2), Color(0, 0, 0, 0.35))
	var body := _tc(Color(0.9, 0.91, 0.94), 0.0).lerp(Color(0.4, 0.42, 0.5), 0.3 * lit)
	var dark := Color(0.06, 0.07, 0.09)
	draw_rect(Rect2(x - cw * 0.98, y - ch * 0.22, cw * 0.22, ch * 0.3), dark)
	draw_rect(Rect2(x + cw * 0.76, y - ch * 0.22, cw * 0.22, ch * 0.3), dark)
	draw_colored_polygon(PackedVector2Array([Vector2(x - cw, y - ch * 0.12), Vector2(x - cw * 0.9, y - ch * 0.6), Vector2(x + cw * 0.9, y - ch * 0.6), Vector2(x + cw, y - ch * 0.12)]), body)
	draw_colored_polygon(PackedVector2Array([Vector2(x - cw * 0.72, y - ch * 0.6), Vector2(x - cw * 0.52, y - ch * 1.08), Vector2(x + cw * 0.52, y - ch * 1.08), Vector2(x + cw * 0.72, y - ch * 0.6)]), body.darkened(0.08))
	draw_colored_polygon(PackedVector2Array([Vector2(x - cw * 0.62, y - ch * 0.64), Vector2(x - cw * 0.46, y - ch * 1.0), Vector2(x + cw * 0.46, y - ch * 1.0), Vector2(x + cw * 0.62, y - ch * 0.64)]), Color(0.05, 0.07, 0.1))
	var tl := Color(1.0, 0.12, 0.1)
	for sx in [-1.0, 1.0]:
		var lp := Vector2(x + sx * cw * 0.72, y - ch * 0.38)
		draw_rect(Rect2(lp.x - cw * 0.17, lp.y - ch * 0.07, cw * 0.34, ch * 0.14), tl)
		if lit > 0.0 or weather == "rain":
			draw_circle(lp, cw * 0.4, Color(1.0, 0.1, 0.08, 0.16))
	draw_rect(Rect2(x - cw * 0.9, y - ch * 0.14, cw * 1.8, ch * 0.06), Color(0.04, 0.05, 0.06))


func _poster_fx(w: float, h: float, hz: float) -> void:
	# warm / cool grade over everything
	if grade.a > 0.0:
		draw_rect(Rect2(0, 0, w, h), grade)
	# speed streaks along the road
	for q in 9:
		var u := fposmod(_t * 0.5 + q * 0.111, 1.0)
		var p := u * u
		var y := hz + (h - hz) * p
		var side := -1.0 if q % 2 == 0 else 1.0
		var x := w * 0.5 + side * (w * 0.02 + w * 0.5 * p * (0.9 + 0.5 * float(q % 3) * 0.3))
		draw_line(Vector2(x, y), Vector2(x - side * w * 0.04 * p, y + h * 0.05 * p), Color(1, 1, 1, 0.16 * p), 1.0 + 2.2 * p)
	# halftone dots, bottom-left corner
	var st := maxf(10.0, w / 38.0)
	var nx := int(w * 0.45 / st)
	var ny := int(h * 0.4 / st)
	for iy in ny:
		for ix in nx:
			var f := (1.0 - float(ix) / nx) * (float(iy) / ny)
			if f > 0.12:
				draw_circle(Vector2(ix * st + st * 0.5, h - (ny - iy) * st + st * 0.5 - 2.0), 0.6 + 2.6 * f, Color(1, 1, 1, 0.07 + 0.1 * f))
	# film grain
	for s in _stars:
		draw_rect(Rect2(fposmod(s.x * 977.0 + s.z * 311.0, 1.0) * w, fposmod(s.y * 733.0 + s.z * 197.0, 1.0) * h, 1.5, 1.5), Color(1, 1, 1, 0.07))
	# vignette
	var vw := w * 0.2
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(vw, 0), Vector2(vw, h), Vector2(0, h)]), PackedColorArray([Color(0, 0, 0, 0.4), Color(0, 0, 0, 0), Color(0, 0, 0, 0), Color(0, 0, 0, 0.4)]))
	draw_polygon(PackedVector2Array([Vector2(w - vw, 0), Vector2(w, 0), Vector2(w, h), Vector2(w - vw, h)]), PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0.4), Color(0, 0, 0, 0.4), Color(0, 0, 0, 0)]))
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, h * 0.18), Vector2(0, h * 0.18)]), PackedColorArray([Color(0, 0, 0, 0.4), Color(0, 0, 0, 0.4), Color(0, 0, 0, 0), Color(0, 0, 0, 0)]))
