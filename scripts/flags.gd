# Copyright (c) 2026 Sabak Studios. All rights reserved. See LICENSE.
class_name Flags
extends RefCounted
## Country flags for the car. Pictures are drawn in code (no image files). To use an exact picture instead,
## put a PNG at res://flags/<code>.png (for example eg.png) and it replaces the drawn one.
## Israel is not offered (and is refused even if somebody puts it in a save file).

const BLOCKED := ["il"]
const TABLE := {
	"none": {"n": ["No flag", "بدون علم"], "r": 0, "price": 0},
	"ly": {"n": ["Libya", "ليبيا"], "r": 0, "price": 0},
	"tn": {"n": ["Tunisia", "تونس"], "r": 0, "price": 0},
	"dz": {"n": ["Algeria", "الجزائر"], "r": 0, "price": 0},
	"ma": {"n": ["Morocco", "المغرب"], "r": 0, "price": 0},
	"ae": {"n": ["UAE", "الإمارات"], "r": 0, "price": 0},
	"qa": {"n": ["Qatar", "قطر"], "r": 0, "price": 0},
	"bh": {"n": ["Bahrain", "البحرين"], "r": 0, "price": 0},
	"kw": {"n": ["Kuwait", "الكويت"], "r": 0, "price": 0},
	"jo": {"n": ["Jordan", "الأردن"], "r": 0, "price": 0},
	"ps": {"n": ["Palestine", "فلسطين"], "r": 0, "price": 0},
	"sd": {"n": ["Sudan", "السودان"], "r": 0, "price": 0},
	"ye": {"n": ["Yemen", "اليمن"], "r": 0, "price": 0},
	"tr": {"n": ["Turkey", "تركيا"], "r": 0, "price": 0},
	"pk": {"n": ["Pakistan", "باكستان"], "r": 0, "price": 0},
	"us": {"n": ["USA", "أمريكا"], "r": 0, "price": 0},
	"gb": {"n": ["UK", "بريطانيا"], "r": 0, "price": 0},
	"fr": {"n": ["France", "فرنسا"], "r": 0, "price": 0},
	"de": {"n": ["Germany", "ألمانيا"], "r": 0, "price": 0},
	"it": {"n": ["Italy", "إيطاليا"], "r": 0, "price": 0},
	"es": {"n": ["Spain", "إسبانيا"], "r": 0, "price": 0},
	"ru": {"n": ["Russia", "روسيا"], "r": 0, "price": 0},
	"nl": {"n": ["Netherlands", "هولندا"], "r": 0, "price": 0},
	"be": {"n": ["Belgium", "بلجيكا"], "r": 0, "price": 0},
	"pl": {"n": ["Poland", "بولندا"], "r": 0, "price": 0},
	"ua": {"n": ["Ukraine", "أوكرانيا"], "r": 0, "price": 0},
	"se": {"n": ["Sweden", "السويد"], "r": 0, "price": 0},
	"no": {"n": ["Norway", "النرويج"], "r": 0, "price": 0},
	"ch": {"n": ["Switzerland", "سويسرا"], "r": 0, "price": 0},
	"at": {"n": ["Austria", "النمسا"], "r": 0, "price": 0},
	"ie": {"n": ["Ireland", "أيرلندا"], "r": 0, "price": 0},
	"hu": {"n": ["Hungary", "المجر"], "r": 0, "price": 0},
	"ro": {"n": ["Romania", "رومانيا"], "r": 0, "price": 0},
	"jp": {"n": ["Japan", "اليابان"], "r": 0, "price": 0},
	"br": {"n": ["Brazil", "البرازيل"], "r": 0, "price": 0},
	"ar": {"n": ["Argentina", "الأرجنتين"], "r": 0, "price": 0},
	"cn": {"n": ["China", "الصين"], "r": 0, "price": 0},
	"in": {"n": ["India", "الهند"], "r": 0, "price": 0},
	"gr": {"n": ["Greece", "اليونان"], "r": 0, "price": 0},
	"fi": {"n": ["Finland", "فنلندا"], "r": 0, "price": 0},
	"dk": {"n": ["Denmark", "الدنمارك"], "r": 0, "price": 0},
	"cz": {"n": ["Czechia", "التشيك"], "r": 0, "price": 0},
	"ng": {"n": ["Nigeria", "نيجيريا"], "r": 0, "price": 0},
	"ml": {"n": ["Mali", "مالي"], "r": 0, "price": 0},
}
const ORDER := ["none", "ly", "tn", "dz", "ma", "ae", "qa", "bh", "kw", "jo", "ps", "sd", "ye", "tr", "pk", "us", "gb", "fr", "de", "it", "es", "ru", "nl", "be", "pl", "ua", "se", "no", "ch", "at", "ie", "hu", "ro", "jp", "br", "ar", "cn", "in", "gr", "fi", "dk", "cz", "ng", "ml"]

const W := 120
const H := 80
static var _cache := {}


static func valid(code: String) -> bool:
	return code != "none" and not BLOCKED.has(code) and TABLE.has(code)


static func tex(code: String) -> Texture2D:
	if not valid(code):
		return null
	if _cache.has(code):
		return _cache[code]
	var path := "res://flags/%s.png" % code
	var t: Texture2D = null
	if ResourceLoader.exists(path):
		t = load(path) as Texture2D
	if t == null:
		var img := Image.create(W, H, false, Image.FORMAT_RGB8)
		img.fill(Color.WHITE)
		_paint(code, img)
		t = ImageTexture.create_from_image(img)
	_cache[code] = t
	return t


# ------------------------------------------------------------------ drawing helpers (fractions of the flag)
static func _rect(img: Image, x0: float, y0: float, x1: float, y1: float, c: Color) -> void:
	img.fill_rect(Rect2i(int(x0 * W), int(y0 * H), maxi(int(ceil((x1 - x0) * W)), 1), maxi(int(ceil((y1 - y0) * H)), 1)), c)


static func _bands(img: Image, horizontal: bool, cols: Array, weights: Array = []) -> void:
	var tot := 0.0
	for i in cols.size():
		tot += float(weights[i]) if not weights.is_empty() else 1.0
	var p := 0.0
	for i in cols.size():
		var f := (float(weights[i]) if not weights.is_empty() else 1.0) / tot
		if horizontal:
			_rect(img, 0, p, 1, p + f, cols[i])
		else:
			_rect(img, p, 0, p + f, 1, cols[i])
		p += f


static func _disc(img: Image, cx: float, cy: float, r: float, c: Color) -> void:
	for y in range(maxi(int(cy - r - 1), 0), mini(int(cy + r + 2), H)):
		for x in range(maxi(int(cx - r - 1), 0), mini(int(cx + r + 2), W)):
			if Vector2(x + 0.5 - cx, y + 0.5 - cy).length() <= r:
				img.set_pixel(x, y, c)


## crescent = circle A (cx,cy,r) without circle B (cx+ox, cy, r2)
static func _crescent(img: Image, cx: float, cy: float, r: float, ox: float, r2: float, c: Color) -> void:
	for y in range(maxi(int(cy - r - 1), 0), mini(int(cy + r + 2), H)):
		for x in range(maxi(int(cx - r - 1), 0), mini(int(cx + r + 2), W)):
			var p := Vector2(x + 0.5, y + 0.5)
			if p.distance_to(Vector2(cx, cy)) <= r and p.distance_to(Vector2(cx + ox, cy)) > r2:
				img.set_pixel(x, y, c)


static func _poly(img: Image, pts: Array, c: Color) -> void:
	var ys: Array = []
	var miny := H
	var maxy := 0
	for p in pts:
		miny = mini(miny, int(p.y))
		maxy = maxi(maxy, int(ceil(p.y)))
	for y in range(maxi(miny, 0), mini(maxy + 1, H)):
		var xs: Array = []
		var fy := y + 0.5
		for i in pts.size():
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[(i + 1) % pts.size()]
			if (a.y <= fy and b.y > fy) or (b.y <= fy and a.y > fy):
				xs.append(a.x + (fy - a.y) / (b.y - a.y) * (b.x - a.x))
		xs.sort()
		for k in range(0, xs.size() - 1, 2):
			for x in range(maxi(int(xs[k]), 0), mini(int(ceil(xs[k + 1])), W)):
				img.set_pixel(x, y, c)


static func _star(img: Image, cx: float, cy: float, r: float, c: Color, n := 5, rot := -90.0, inner := 0.0) -> void:
	var ri := inner if inner > 0.0 else (r * 0.382 if n == 5 else r * 0.5)
	var pts: Array = []
	for i in n * 2:
		var a := deg_to_rad(rot + i * 180.0 / n)
		var rr := r if i % 2 == 0 else ri
		pts.append(Vector2(cx + cos(a) * rr, cy + sin(a) * rr))
	_poly(img, pts, c)


static func _line(img: Image, a: Vector2, b: Vector2, c: Color, th := 2.0) -> void:
	var n := int(a.distance_to(b) * 2.0) + 1
	for i in n + 1:
		var p := a.lerp(b, float(i) / n)
		_disc(img, p.x, p.y, th * 0.5, c)


static func _cross(img: Image, cx: float, th: float, c: Color) -> void:
	_rect(img, cx - th * 0.5 * H / W, 0, cx + th * 0.5 * H / W, 1, c)
	_rect(img, 0, 0.5 - th * 0.5, 1, 0.5 + th * 0.5, c)


# ------------------------------------------------------------------ the flags
static func _paint(code: String, img: Image) -> void:
	var R := Color(0.82, 0.07, 0.12)
	var WH := Color(1, 1, 1)
	var BK := Color(0.04, 0.04, 0.05)
	var GN := Color(0.0, 0.5, 0.2)
	var BL := Color(0.0, 0.2, 0.6)
	var YL := Color(1.0, 0.8, 0.05)
	match code:
		"ly":
			_bands(img, true, [R, BK, GN], [1, 2, 1])
			_crescent(img, 56, 40, 14, 4.5, 11.5, WH)
			_star(img, 66, 40, 6, WH)
		"tn":
			img.fill(R)
			_disc(img, 60, 40, 22, WH)
			_crescent(img, 60, 40, 16.5, 4.5, 13.5, R)
			_star(img, 63, 40, 7.5, R)
		"dz":
			_bands(img, false, [GN, WH])
			_crescent(img, 60, 40, 21, 6.0, 17, R)
			_star(img, 63, 40, 8, R)
		"ma":
			img.fill(R)
			var pc := Vector2(60, 41)
			var pts: Array = []
			for i in 5:
				var a := deg_to_rad(-90.0 + i * 72.0)
				pts.append(pc + Vector2(cos(a), sin(a)) * 19.0)
			for i in 5:
				_line(img, pts[i], pts[(i + 2) % 5], GN, 2.4)
		"ae":
			_bands(img, true, [GN, WH, BK])
			_rect(img, 0, 0, 0.25, 1, R)
		"qa":
			img.fill(Color(0.55, 0.1, 0.25))
			_rect(img, 0, 0, 0.28, 1, WH)
			var z: Array = [Vector2(0, 0), Vector2(0.28 * W, 0)]
			for i in 9:
				z.append(Vector2(0.28 * W + (8.0 if i % 2 == 0 else 0.0) * 0.0 + (0.0 if i % 2 == 0 else 8.0), (i + 1) * H / 9.0 * 1.0 - H / 18.0))
			z.append(Vector2(0.28 * W, H))
			z.append(Vector2(0, H))
			_poly(img, z, WH)
		"bh":
			img.fill(R)
			var zz: Array = [Vector2(0, 0), Vector2(0.28 * W, 0)]
			for i in 5:
				zz.append(Vector2(0.28 * W + 12.0, (i + 0.5) * H / 5.0))
				zz.append(Vector2(0.28 * W, (i + 1) * H / 5.0))
			zz.append(Vector2(0, H))
			_poly(img, zz, WH)
		"kw":
			_bands(img, true, [GN, WH, R])
			_poly(img, [Vector2(0, 0), Vector2(26, 26), Vector2(26, 54), Vector2(0, H)], BK)
		"jo":
			_bands(img, true, [BK, WH, GN])
			_poly(img, [Vector2(0, 0), Vector2(60, 40), Vector2(0, H)], R)
			_star(img, 17, 40, 7, WH, 7, -90.0, 3.5)
		"ps":
			_bands(img, true, [BK, WH, GN])
			_poly(img, [Vector2(0, 0), Vector2(48, 40), Vector2(0, H)], R)
		"sd":
			_bands(img, true, [R, WH, BK])
			_poly(img, [Vector2(0, 0), Vector2(46, 40), Vector2(0, H)], GN)
		"ye":
			_bands(img, true, [R, WH, BK])
		"tr":
			img.fill(R)
			_crescent(img, 46, 40, 20, 6.0, 16, WH)
			_star(img, 62, 40, 8, WH, 5, -90.0 + 0.0)
		"pk":
			img.fill(Color(0.0, 0.33, 0.15))
			_rect(img, 0, 0, 0.25, 1, WH)
			_crescent(img, 72, 40, 21, 6.0, 17, WH)
			_star(img, 82, 33, 8, WH, 5, -60.0)
		"us":
			for i in 13:
				_rect(img, 0, i / 13.0, 1, (i + 1) / 13.0, R if i % 2 == 0 else WH)
			_rect(img, 0, 0, 0.4, 7.0 / 13.0, Color(0.1, 0.15, 0.45))
			for r in 5:
				for c in 6:
					_disc(img, 4.5 + c * 8.0, 4.5 + r * 8.0, 1.4, WH)
			for r in 4:
				for c in 5:
					_disc(img, 8.5 + c * 8.0, 8.5 + r * 8.0, 1.4, WH)
		"gb":
			img.fill(Color(0.0, 0.14, 0.4))
			_line(img, Vector2(0, 0), Vector2(W, H), WH, 14)
			_line(img, Vector2(0, H), Vector2(W, 0), WH, 14)
			_line(img, Vector2(0, 0), Vector2(W, H), R, 5)
			_line(img, Vector2(0, H), Vector2(W, 0), R, 5)
			_cross(img, 0.5, 0.34, WH)
			_cross(img, 0.5, 0.2, R)
		"fr":
			_bands(img, false, [Color(0, 0.15, 0.6), WH, R])
		"de":
			_bands(img, true, [BK, R, Color(1, 0.8, 0)])
		"it":
			_bands(img, false, [Color(0, 0.55, 0.27), WH, R])
		"es":
			_bands(img, true, [Color(0.78, 0.07, 0.1), Color(1, 0.76, 0), Color(0.78, 0.07, 0.1)], [1, 2, 1])
		"ru":
			_bands(img, true, [WH, Color(0, 0.22, 0.65), R])
		"nl":
			_bands(img, true, [Color(0.68, 0.1, 0.15), WH, Color(0.13, 0.27, 0.55)])
		"be":
			_bands(img, false, [BK, Color(1, 0.85, 0), R])
		"pl":
			_bands(img, true, [WH, Color(0.86, 0.08, 0.24)])
		"ua":
			_bands(img, true, [Color(0, 0.34, 0.72), Color(1, 0.84, 0)])
		"se":
			img.fill(Color(0, 0.42, 0.67))
			_rect(img, 0.3, 0, 0.42, 1, Color(1, 0.8, 0))
			_rect(img, 0, 0.4, 1, 0.6, Color(1, 0.8, 0))
		"no":
			img.fill(Color(0.73, 0.1, 0.2))
			_rect(img, 0.28, 0, 0.5, 1, WH)
			_rect(img, 0, 0.36, 1, 0.64, WH)
			_rect(img, 0.33, 0, 0.45, 1, Color(0, 0.13, 0.4))
			_rect(img, 0, 0.43, 1, 0.57, Color(0, 0.13, 0.4))
		"ch":
			img.fill(Color(0.85, 0.1, 0.1))
			_rect(img, 0.44, 0.2, 0.56, 0.8, WH)
			_rect(img, 0.3, 0.38, 0.7, 0.62, WH)
		"at":
			_bands(img, true, [Color(0.78, 0.07, 0.15), WH, Color(0.78, 0.07, 0.15)])
		"ie":
			_bands(img, false, [Color(0.08, 0.6, 0.35), WH, Color(1, 0.55, 0.1)])
		"hu":
			_bands(img, true, [Color(0.8, 0.18, 0.2), WH, Color(0.28, 0.55, 0.35)])
		"ro":
			_bands(img, false, [Color(0, 0.17, 0.5), Color(0.99, 0.82, 0.09), Color(0.81, 0.07, 0.17)])
		"jp":
			img.fill(WH)
			_disc(img, 60, 40, 24, Color(0.74, 0.0, 0.18))
		"br":
			img.fill(Color(0, 0.6, 0.23))
			_poly(img, [Vector2(60, 7), Vector2(112, 40), Vector2(60, 73), Vector2(8, 40)], Color(1, 0.87, 0))
			_disc(img, 60, 40, 17, Color(0, 0.15, 0.5))
			_line(img, Vector2(44, 37), Vector2(76, 45), WH, 2.5)
		"ar":
			_bands(img, true, [Color(0.46, 0.68, 0.87), WH, Color(0.46, 0.68, 0.87)])
			_disc(img, 60, 40, 6, Color(0.96, 0.7, 0.1))
		"cn":
			img.fill(Color(0.87, 0.1, 0.1))
			_star(img, 20, 20, 12, Color(1, 0.87, 0))
			_star(img, 40, 9, 4, Color(1, 0.87, 0))
			_star(img, 47, 18, 4, Color(1, 0.87, 0))
			_star(img, 47, 28, 4, Color(1, 0.87, 0))
			_star(img, 40, 36, 4, Color(1, 0.87, 0))
		"in":
			_bands(img, true, [Color(1, 0.6, 0.2), WH, Color(0.07, 0.53, 0.03)])
			_disc(img, 60, 40, 9, Color(0, 0, 0.5))
			_disc(img, 60, 40, 7.5, WH)
			for i in 12:
				var a := i * PI / 6.0
				_line(img, Vector2(60, 40), Vector2(60 + cos(a) * 7.5, 40 + sin(a) * 7.5), Color(0, 0, 0.5), 1.0)
		"gr":
			for i in 9:
				_rect(img, 0, i / 9.0, 1, (i + 1) / 9.0, Color(0.05, 0.37, 0.69) if i % 2 == 0 else WH)
			_rect(img, 0, 0, 5.0 / 9.0 * 80.0 / 120.0 * 1.0, 5.0 / 9.0, Color(0.05, 0.37, 0.69))
			_rect(img, 0.0, 2.0 / 9.0, 0.37, 3.0 / 9.0, WH)
			_rect(img, 0.15, 0, 0.22, 5.0 / 9.0, WH)
		"fi":
			img.fill(WH)
			_rect(img, 0.28, 0, 0.42, 1, Color(0, 0.21, 0.47))
			_rect(img, 0, 0.38, 1, 0.62, Color(0, 0.21, 0.47))
		"dk":
			img.fill(Color(0.78, 0.05, 0.18))
			_rect(img, 0.28, 0, 0.4, 1, WH)
			_rect(img, 0, 0.42, 1, 0.58, WH)
		"cz":
			_bands(img, true, [WH, Color(0.84, 0.08, 0.12)])
			_poly(img, [Vector2(0, 0), Vector2(60, 40), Vector2(0, H)], Color(0.07, 0.27, 0.54))
		"ng":
			_bands(img, false, [Color(0, 0.53, 0.32), WH, Color(0, 0.53, 0.32)])
		"ml":
			_bands(img, false, [Color(0.08, 0.7, 0.3), Color(0.99, 0.85, 0.07), Color(0.8, 0.1, 0.15)])
		_:
			img.fill(Color(0.5, 0.5, 0.5))


# ------------------------------------------------------------------ the waving flag on the car
const WAVE_SHADER := """
shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;
uniform sampler2D tex : source_color, filter_linear;
uniform float wind = 0.0;
varying float sh;
void vertex() {
	float u = UV.x;
	float ph = u * 7.5 - TIME * (3.0 + 12.0 * wind);
	float amp = (0.02 + 0.10 * wind) * u;
	VERTEX.x += sin(ph) * amp;
	VERTEX.y += cos(ph * 0.7 + 1.0) * amp * 0.3 - (1.0 - wind) * u * u * 0.34;
	VERTEX.z *= 1.0 - (1.0 - wind) * 0.22 * u;
	sh = cos(ph) * (0.25 + 0.75 * wind) * u;
}
void fragment() {
	vec3 c = texture(tex, UV).rgb;
	ALBEDO = c * (1.0 - sh * 0.16);
}
"""

static var _shader: Shader


## pole + waving flag, child of the car. Returns the material so the car can set "wind".
static func attach(car: Node3D, code: String, pole_mat: Material) -> ShaderMaterial:
	var t := tex(code)
	if t == null:
		return null
	var root := Node3D.new()
	root.name = "FlagMount"
	root.position = Vector3(0.78, 0.95, 1.86)
	root.rotation_degrees = Vector3(10.0, 0.0, 0.0)               # leans back a little
	car.add_child(root)
	CarStyle.box(root, Vector3(0.025, 1.25, 0.025), Vector3(0, 0.625, 0), pole_mat)
	CarStyle.box(root, Vector3(0.06, 0.04, 0.06), Vector3(0, 0.0, 0), pole_mat)
	CarStyle.box(root, Vector3(0.04, 0.04, 0.04), Vector3(0, 1.26, 0), pole_mat)
	if _shader == null:
		_shader = Shader.new()
		_shader.code = WAVE_SHADER
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("tex", t)
	m.set_shader_parameter("wind", 0.0)
	var mi := MeshInstance3D.new()
	mi.mesh = _grid(0.95, 0.62)
	mi.material_override = m
	mi.position = Vector3(0, 1.22, 0)
	mi.rotation_degrees = Vector3(0, 32.0, 0)                     # opens outward so it is seen from behind and the side
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	return m


static func _grid(length: float, height: float) -> ArrayMesh:
	var nx := 18
	var ny := 8
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in ny:
		for i in nx:
			var q := [[i, j], [i + 1, j], [i + 1, j + 1], [i, j], [i + 1, j + 1], [i, j + 1]]
			for p in q:
				var u := float(p[0]) / nx
				var v := float(p[1]) / ny
				st.set_uv(Vector2(u, v))
				st.set_normal(Vector3(1, 0, 0))
				st.add_vertex(Vector3(0, -v * height, u * length))
	return st.commit()
