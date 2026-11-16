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
