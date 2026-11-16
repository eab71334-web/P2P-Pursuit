# Copyright (c) 2026 KRG Studios. All rights reserved. See LICENSE.
class_name Scenery
extends RefCounted
## Looks of the 3D world: asphalt texture, low-poly peaks and clouds, sun glare. Pure code, no image files.

static var _asphalt: ImageTexture
static var _glare: GradientTexture2D


## grainy asphalt with a few lighter and darker blotches; tiled by world position (triplanar), so every road piece matches
static func road_material(base: Color) -> StandardMaterial3D:
	if _asphalt == null:
		var n := FastNoiseLite.new()
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		n.frequency = 0.07
		n.seed = 11
		var fine := FastNoiseLite.new()
		fine.noise_type = FastNoiseLite.TYPE_CELLULAR
		fine.frequency = 0.5
		fine.seed = 5
		var a := n.get_seamless_image(128, 128, false, false)
		var b := fine.get_seamless_image(128, 128, false, false)
		var img := Image.create(128, 128, false, Image.FORMAT_RGB8)
		for y in 128:
			for x in 128:
				var v := 0.84 + 0.12 * (a.get_pixel(x, y).r - 0.5) * 2.0 + 0.08 * (b.get_pixel(x, y).r - 0.5)
				v = clampf(v, 0.55, 1.0)
				img.set_pixel(x, y, Color(v, v, v))
		img.generate_mipmaps()
		_asphalt = ImageTexture.create_from_image(img)
	var m := StandardMaterial3D.new()
	m.albedo_color = base
	m.albedo_texture = _asphalt
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(0.22, 0.22, 0.22)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	m.roughness = 0.92
	return m


static func plain(c: Color, rough := 0.9, fog := true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.disable_fog = not fog
	return m


static func emissive(c: Color, energy := 2.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m


## a low-poly peak: 5-sided cone, base radius 0.5, height 1, sitting on y = 0
static func peak_mesh() -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = 0.0
	m.bottom_radius = 0.5
	m.height = 1.0
	m.radial_segments = 5
	m.rings = 1
	m.cap_bottom = false
	return m


static func tire_mesh() -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = 0.45
	m.bottom_radius = 0.45
	m.height = 0.32
	m.radial_segments = 8
	m.rings = 1
	return m


static func cloud_mesh() -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = 0.5
	m.height = 1.0
	m.radial_segments = 8
	m.rings = 4
	return m


## soft round glow for the sun
static func glare_texture() -> GradientTexture2D:
	if _glare == null:
		var g := Gradient.new()
		g.set_offset(0, 0.0)
		g.set_color(0, Color(1.0, 0.97, 0.85, 0.95))
		g.add_point(0.12, Color(1.0, 0.93, 0.75, 0.7))
		g.add_point(0.4, Color(1.0, 0.85, 0.6, 0.18))
		g.set_offset(g.get_point_count() - 1, 1.0)
		g.set_color(g.get_point_count() - 1, Color(1.0, 0.8, 0.5, 0.0))
		_glare = GradientTexture2D.new()
		_glare.gradient = g
		_glare.fill = GradientTexture2D.FILL_RADIAL
		_glare.fill_from = Vector2(0.5, 0.5)
		_glare.fill_to = Vector2(1.0, 0.5)
		_glare.width = 256
		_glare.height = 256
	return _glare


## sea: layered waves (normals from summed sines), depth colour from the shore, fresnel sky reflection, sun glitter, lapping foam at the shore
const SEA_SHADER := """
shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_always;
uniform vec3 shore_dir = vec3(0.0, 0.0, 1.0);
uniform vec3 origin = vec3(0.0);
uniform float shore_d = 100.0;
uniform vec3 sun_dir = vec3(0.4, 0.8, 0.4);
uniform vec3 shallow : source_color = vec3(0.16, 0.8, 0.76);
uniform vec3 deep : source_color = vec3(0.02, 0.26, 0.5);
uniform vec3 sky_h : source_color = vec3(0.8, 0.93, 0.98);
uniform vec3 sky_t : source_color = vec3(0.15, 0.55, 0.9);
varying vec3 wp;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = wp.xz;
	float t = TIME;
	float sd = dot(p - origin.xz, shore_dir.xz) - shore_d;
	vec2 g = vec2(0.0);
	g += vec2(0.8, 0.6) * cos(dot(vec2(0.8, 0.6), p) * 0.35 + t * 1.3) * 0.35 * 0.35;
	g += vec2(-0.5, 0.86) * cos(dot(vec2(-0.5, 0.86), p) * 0.7 + t * 1.9) * 0.7 * 0.12;
	g += vec2(0.95, -0.3) * cos(dot(vec2(0.95, -0.3), p) * 1.6 + t * 2.7) * 1.6 * 0.04;
	g += (vec2(vnoise(p * 0.9 + t * 0.4), vnoise(p * 0.9 - t * 0.35 + 7.0)) - 0.5) * 0.25;
	vec3 N = normalize(vec3(-g.x, 1.0, -g.y));
	vec3 V = normalize(CAMERA_POSITION_WORLD - wp);
	float fres = pow(1.0 - clamp(dot(N, V), 0.0, 1.0), 4.0);
	float depth = smoothstep(0.0, 140.0, sd);
	vec3 col = mix(shallow, deep, depth);
	col = mix(col, mix(sky_h, sky_t, 0.4), clamp(fres * 0.8 + 0.08, 0.0, 0.9));
	vec3 H = normalize(normalize(sun_dir) + V);
	float spec = pow(max(dot(N, H), 0.0), 220.0) * 2.0 + pow(max(dot(N, H), 0.0), 40.0) * 0.12;
	float sparkle = step(0.93, vnoise(p * 3.0 + t * 1.5)) * smoothstep(0.55, 1.0, vnoise(p * 0.15)) * 0.5;
	col += vec3(1.0, 0.95, 0.85) * (spec + sparkle * 0.5);
	float lap = 2.5 + sin(t * 0.9 - sd * 0.12) * 2.0;
	float fo = smoothstep(lap + 1.8, lap - 0.8, sd) * smoothstep(-5.0, 0.0, sd) * (0.55 + 0.45 * vnoise(p * 1.4 + t * 0.6));
	float far_fo = smoothstep(0.7, 0.95, vnoise(p * 0.5 + t * 0.2)) * 0.12 * smoothstep(10.0, 60.0, sd);
	col = mix(col, vec3(1.0), clamp(fo + far_fo, 0.0, 1.0));
	ALBEDO = col;
	ALPHA = clamp(max(smoothstep(-6.0, 3.0, sd) * mix(0.62, 0.97, smoothstep(0.0, 40.0, sd)), fo), 0.0, 1.0);
}
"""

static func sea_material(shore_dir: Vector3, origin: Vector3, shore_d: float, sun_dir: Vector3, sky_h: Color, sky_t: Color) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = SEA_SHADER
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("shore_dir", shore_dir)
	m.set_shader_parameter("origin", origin)
	m.set_shader_parameter("shore_d", shore_d)
	m.set_shader_parameter("sun_dir", sun_dir)
	m.set_shader_parameter("sky_h", Vector3(sky_h.r, sky_h.g, sky_h.b))
	m.set_shader_parameter("sky_t", Vector3(sky_t.r, sky_t.g, sky_t.b))
	return m


static var _windows: ImageTexture

## tower facade: dark glass with a grid of windows, about a third of them lit (warm or cool), same pattern used as emission
static func window_material() -> StandardMaterial3D:
	if _windows == null:
		var r := RandomNumberGenerator.new()
		r.seed = 77
		var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
		img.fill(Color(0.05, 0.06, 0.09))
		for gy in 16:
			for gx in 8:
				if r.randf() < 0.38:
					var warm := r.randf() < 0.65
					var c := Color(1.0, 0.82, 0.5) if warm else Color(0.6, 0.85, 1.0)
					c *= r.randf_range(0.6, 1.0)
					for yy in 3:
						for xx in 5:
							img.set_pixel(gx * 8 + 1 + xx, gy * 4 + yy, c)
		_windows = ImageTexture.create_from_image(img)
	var m := StandardMaterial3D.new()
	m.albedo_texture = _windows
	m.emission_enabled = true
	m.emission_texture = _windows
	m.emission_energy_multiplier = 1.6
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(0.1, 0.12, 0.1)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.roughness = 0.6
	return m


static var _rb_cache := {}

## a box with softly rounded edges and smooth shading: 4x4 vertices per face, cached per size. Used for the car parts.
static func rounded_box(size: Vector3, radius := 0.05) -> ArrayMesh:
	var r := minf(radius, minf(size.x, minf(size.y, size.z)) * 0.3)
	if r < 0.008:
		r = 0.0
	var key := Vector4(snappedf(size.x, 0.005), snappedf(size.y, 0.005), snappedf(size.z, 0.005), snappedf(r, 0.005))
	if _rb_cache.has(key):
		return _rb_cache[key]
	var h := size * 0.5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var offs := [-h, -h + Vector3(r, r, r), h - Vector3(r, r, r), h]
	for face in 6:
		var axis := face / 2
		var sgn := 1.0 if face % 2 == 0 else -1.0
		var u := (axis + 1) % 3
		var v := (axis + 2) % 3
		var grid: Array = []
		for j in 4:
			var row: Array = []
			for i in 4:
				var p := Vector3.ZERO
				p[axis] = h[axis] * sgn
				p[u] = (offs[i] as Vector3)[u]
				p[v] = (offs[j] as Vector3)[v]
				var c := Vector3(clampf(p.x, -h.x + r, h.x - r), clampf(p.y, -h.y + r, h.y - r), clampf(p.z, -h.z + r, h.z - r))
				var d := p - c
				var nrm := Vector3.ZERO
				if r > 0.0 and d.length() > 0.00001:
					nrm = d.normalized()
					p = c + nrm * r
				else:
					nrm[axis] = sgn
				row.append([p, nrm])
			grid.append(row)
		for j in 3:
			for i in 3:
				var a: Array = grid[j][i]
				var b: Array = grid[j][i + 1]
				var c2: Array = grid[j + 1][i + 1]
				var d2: Array = grid[j + 1][i]
				var order := [a, b, c2, a, c2, d2]
				var tri_n: Vector3 = ((b[0] as Vector3) - (a[0] as Vector3)).cross((c2[0] as Vector3) - (a[0] as Vector3))
				var outward := Vector3.ZERO
				outward[axis] = sgn
				if tri_n.dot(outward) < 0.0:
					order = [a, c2, b, a, d2, c2]
				for q in order:
					st.set_normal(q[1])
					st.set_uv(Vector2(0.0, 0.0))
					st.add_vertex(q[0])
	var m := st.commit()
	_rb_cache[key] = m
	return m


# ------------------------------------------------------------------ vegetation + mountains (low-poly, flat shaded, vertex coloured)

static var _veg_cache := {}


static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color, centre: Vector3) -> void:
	var n := (b - a).cross(c - a)
	if n.length() < 0.000001:
		return
	n = n.normalized()
	if n.dot((a + b + c) / 3.0 - centre) < 0.0:
		var t := b
		b = c
		c = t
		var tc := cb
		cb = cc
		cc = tc
		n = -n
	st.set_normal(n)
	st.set_color(ca)
	st.add_vertex(a)
	st.set_normal(n)
	st.set_color(cb)
	st.add_vertex(b)
	st.set_normal(n)
	st.set_color(cc)
	st.add_vertex(c)


## cone / frustum around the y axis: radius r0 at y0, r1 at y0+h
static func _frustum(st: SurfaceTool, base: Vector3, r0: float, r1: float, h: float, segs: int, c0: Color, c1: Color, centre: Vector3, bend := Vector3.ZERO) -> void:
	for i in segs:
		var a0 := TAU * float(i) / float(segs)
		var a1 := TAU * float(i + 1) / float(segs)
		var p00 := base + Vector3(cos(a0) * r0, 0, sin(a0) * r0)
		var p01 := base + Vector3(cos(a1) * r0, 0, sin(a1) * r0)
		var p10 := base + bend + Vector3(cos(a0) * r1, h, sin(a0) * r1)
		var p11 := base + bend + Vector3(cos(a1) * r1, h, sin(a1) * r1)
		_tri(st, p00, p01, p11, c0, c0, c1, centre)
		if r1 > 0.0001:
			_tri(st, p00, p11, p10, c0, c1, c1, centre)


static func _blob(st: SurfaceTool, c: Vector3, rad: float, segs: int, rings: int, cb: Color, ct: Color, squash := 0.85) -> void:
	for j in rings:
		var v0 := PI * float(j) / float(rings)
		var v1 := PI * float(j + 1) / float(rings)
		for i in segs:
			var a0 := TAU * float(i) / float(segs)
			var a1 := TAU * float(i + 1) / float(segs)
			var p := func(v: float, a: float) -> Vector3:
				return c + Vector3(sin(v) * cos(a) * rad, cos(v) * rad * squash, sin(v) * sin(a) * rad)
			var q00: Vector3 = p.call(v0, a0)
			var q01: Vector3 = p.call(v0, a1)
			var q10: Vector3 = p.call(v1, a0)
			var q11: Vector3 = p.call(v1, a1)
			var col0 := cb.lerp(ct, clampf(0.5 + cos(v0) * 0.5, 0.0, 1.0))
			var col1 := cb.lerp(ct, clampf(0.5 + cos(v1) * 0.5, 0.0, 1.0))
			_tri(st, q00, q10, q11, col0, col1, col1, c)
			_tri(st, q00, q11, q01, col0, col1, col0, c)


## kind: conifer | round | palm | cactus. About 6 m tall at scale 1.
static func tree_mesh(kind: String, trunk: Color, l1: Color, l2: Color) -> ArrayMesh:
	var key := "%s%s%s%s" % [kind, trunk.to_html(), l1.to_html(), l2.to_html()]
	if _veg_cache.has(key):
		return _veg_cache[key]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	match kind:
		"conifer":
			_frustum(st, Vector3(0, 0, 0), 0.26, 0.2, 1.4, 6, trunk.darkened(0.15), trunk, Vector3(0, 0.7, 0))
			var tiers := [[0.9, 1.75, 2.3], [2.3, 1.4, 2.1], [3.6, 0.98, 1.9], [4.7, 0.62, 1.5]]
			for k in tiers.size():
				var t: Array = tiers[k]
				var f := float(k) / 3.0
				_frustum(st, Vector3(0, t[0], 0), t[1], 0.0, t[2], 9, l1.lerp(l2, f * 0.7).darkened(0.12), l1.lerp(l2, 0.35 + f * 0.65), Vector3(0, float(t[0]) + 0.4, 0))
		"round":
			_frustum(st, Vector3(0, 0, 0), 0.34, 0.22, 2.6, 6, trunk.darkened(0.15), trunk, Vector3(0, 1.3, 0))
			_blob(st, Vector3(0, 3.6, 0), 1.9, 8, 5, l1, l2)
			_blob(st, Vector3(1.0, 3.0, 0.5), 1.2, 7, 4, l1.darkened(0.1), l2.darkened(0.05))
			_blob(st, Vector3(-0.9, 3.3, -0.4), 1.3, 7, 4, l1, l2.lightened(0.05))
		"palm":
			var bend := Vector3(0.7, 0, 0.3)
			var p := Vector3.ZERO
			for k in 5:
				var f0 := float(k) / 5.0
				var seg_bend := bend * 0.2 * (1.0 + f0)
				_frustum(st, p, 0.3 - f0 * 0.1, 0.3 - (f0 + 0.2) * 0.1, 1.05, 6, trunk.darkened(0.2 - f0 * 0.2), trunk, p + Vector3(0, 0.5, 0), seg_bend)
				p += Vector3(seg_bend.x, 1.05, seg_bend.z)
			for k in 8:
				var a := TAU * float(k) / 8.0
				var d := Vector3(cos(a), 0, sin(a))
				var s := Vector3(-d.z, 0, d.x) * 0.38
				var p0 := p
				var p1 := p + d * 1.4 + Vector3(0, 0.55, 0)
				var p2 := p + d * 2.6 + Vector3(0, -0.15, 0)
				var cc := l1.lerp(l2, float(k % 3) / 2.0)
				_tri(st, p0 + s * 0.3, p0 - s * 0.3, p1 + s, cc.darkened(0.1), cc.darkened(0.1), cc, p + Vector3(0, -1, 0) + d * 0.1)
				_tri(st, p0 - s * 0.3, p1 - s, p1 + s, cc.darkened(0.1), cc, cc, p + Vector3(0, -1, 0))
				_tri(st, p1 + s, p1 - s, p2, cc, cc, cc.lightened(0.1), p + Vector3(0, -1, 0))
		"cactus":
			var g := Color(0.22, 0.5, 0.26).lerp(l1, 0.2)
			_frustum(st, Vector3.ZERO, 0.36, 0.3, 3.4, 7, g.darkened(0.15), g, Vector3(0, 1.7, 0))
			_frustum(st, Vector3(0, 3.4, 0), 0.3, 0.0, 0.35, 7, g, g.lightened(0.1), Vector3(0, 3.5, 0))
			_frustum(st, Vector3(0.3, 1.5, 0), 0.2, 0.2, 0.7, 6, g.darkened(0.1), g, Vector3(0.6, 1.8, 0), Vector3(0.5, 0, 0))
			_frustum(st, Vector3(1.0, 1.9, 0), 0.2, 0.17, 1.1, 6, g.darkened(0.05), g.lightened(0.05), Vector3(1.0, 2.4, 0))
			_frustum(st, Vector3(-0.3, 1.0, 0), 0.19, 0.19, 0.6, 6, g.darkened(0.1), g, Vector3(-0.6, 1.3, 0), Vector3(-0.45, 0, 0))
			_frustum(st, Vector3(-0.9, 1.3, 0), 0.19, 0.16, 0.9, 6, g.darkened(0.05), g.lightened(0.05), Vector3(-0.9, 1.7, 0))
	var m := st.commit()
	_veg_cache[key] = m
	return m


## foliage material: vertex colours carry all the colour
static func veg_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 1.0
	return m


## a faceted mountain: ridged noise on a cone, colours by height (ground -> rock -> snow). Base radius 0.5, height 1.
static func mountain_mesh(seed_v: int, low: Color, rock: Color, snow: Color, snow_line: float) -> ArrayMesh:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX
	n.seed = seed_v
	n.frequency = 1.6
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var R := 9
	var S := 20
	var grid: Array = []
	for r in R + 1:
		var t := float(r) / float(R)
		var row: Array = []
		for s in S:
			var a := TAU * float(s) / float(S)
			var base_r := 0.5 * pow(1.0 - t, 0.9)
			var ridge := 1.0 - absf(n.get_noise_3d(cos(a) * 1.3, t * 2.2, sin(a) * 1.3))
			var wob := 1.0 + (ridge - 0.6) * 0.5 * (1.0 - t * 0.5)
			var rad := base_r * wob
			var hy := pow(t, 0.8) + (ridge - 0.6) * 0.1 * sin(t * PI)
			row.append(Vector3(cos(a) * rad, hy, sin(a) * rad))
		grid.append(row)
	var colour_at := func(p: Vector3, i: int) -> Color:
		var jit := n.get_noise_2d(p.x * 6.0 + float(i), p.z * 6.0) * 0.07
		var y: float = p.y + jit
		var c := low.lerp(rock, smoothstep(0.12, 0.42, y))
		c = c.lerp(snow, smoothstep(snow_line - 0.03, snow_line + 0.05, y))
		return c * (0.9 + 0.1 * n.get_noise_3d(p.x * 9.0, p.y * 9.0, p.z * 9.0))
	var centre := Vector3(0, 0.3, 0)
	for r in R:
		for s in S:
			var s2 := (s + 1) % S
			var a: Vector3 = grid[r][s]
			var b: Vector3 = grid[r][s2]
			var c: Vector3 = grid[r + 1][s2]
			var d: Vector3 = grid[r + 1][s]
			_tri(st, a, b, c, colour_at.call(a, s), colour_at.call(b, s), colour_at.call(c, s), centre)
			if r + 1 < R:
				_tri(st, a, c, d, colour_at.call(a, s), colour_at.call(c, s), colour_at.call(d, s), centre)
	return st.commit()
