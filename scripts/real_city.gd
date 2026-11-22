class_name RealCity
extends RefCounted
## Realistic look for the open world: asphalt, pavement, grass and facade materials (all generated, no downloads), plus a tuned sky / light.

static var _noise_a: ImageTexture
static var _noise_b: ImageTexture


static func _noises() -> void:
	if _noise_a != null:
		return
	var a := FastNoiseLite.new()
	a.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	a.frequency = 0.03
	a.fractal_octaves = 4
	a.seed = 21
	var ia := a.get_seamless_image(256, 256, false)
	ia.generate_mipmaps()
	_noise_a = ImageTexture.create_from_image(ia)
	var b := FastNoiseLite.new()
	b.noise_type = FastNoiseLite.TYPE_CELLULAR
	b.frequency = 0.09
	b.seed = 8
	var ib := b.get_seamless_image(256, 256, false)
	ib.generate_mipmaps()
	_noise_b = ImageTexture.create_from_image(ib)


static func _shader(code: String) -> ShaderMaterial:
	_noises()
	var sh := Shader.new()
	sh.code = code
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("noise_a", _noise_a)
	m.set_shader_parameter("noise_b", _noise_b)
	return m


const ASPHALT := """
shader_type spatial;
uniform sampler2D noise_a : repeat_enable, filter_linear_mipmap;
uniform sampler2D noise_b : repeat_enable, filter_linear_mipmap;
uniform float grid = 220.0;
uniform float road_w = 14.0;
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = wp.xz;
	float big = texture(noise_a, p * 0.011).r;
	float mid = texture(noise_a, p * 0.09 + vec2(3.1, 1.7)).r;
	float grain = texture(noise_b, p * 2.2).r;
	float grain2 = texture(noise_b, p * 4.7 + vec2(7.0, 2.0)).r;
	vec2 gl = mod(p + grid * 0.5, grid) - grid * 0.5;
	bool xroad = abs(gl.y) < abs(gl.x);
	float s = xroad ? gl.y : gl.x;
	float junction = step(abs(gl.x), road_w * 0.5) * step(abs(gl.y), road_w * 0.5);
	float lane_c = (floor(abs(s) / 3.5) + 0.5) * 3.5;
	float d = abs(abs(s) - lane_c);
	float tracks = (1.0 - smoothstep(0.18, 0.55, abs(d - 0.8))) * (1.0 - junction);
	vec3 col = mix(vec3(0.15), vec3(0.22), big);
	col *= 0.78 + 0.4 * grain;
	col += vec3(0.07) * step(0.9, grain2) * (0.6 + 0.4 * grain);
	col *= 1.0 - 0.2 * tracks * (0.55 + 0.45 * mid);
	float patch_m = smoothstep(0.62, 0.66, big);
	col = mix(col, col * 0.7, patch_m);
	float crack = (1.0 - smoothstep(0.0, 0.01, abs(mid - 0.5))) * smoothstep(0.3, 0.5, big);
	col *= 1.0 - 0.55 * crack;
	float oil = smoothstep(0.55, 0.9, texture(noise_a, p * 0.33 + 9.0).r) * junction;
	col *= 1.0 - 0.25 * oil;
	ALBEDO = col;
	ROUGHNESS = clamp(0.9 - 0.12 * tracks + 0.05 * patch_m - 0.15 * oil, 0.55, 0.97);
	SPECULAR = 0.35;
	float gx = texture(noise_b, p * 2.2 + vec2(0.012, 0.0)).r - grain;
	float gy = texture(noise_b, p * 2.2 + vec2(0.0, 0.012)).r - grain;
	NORMAL_MAP = vec3(0.5 - gx * 6.0, 0.5 - gy * 6.0, 1.0);
	NORMAL_MAP_DEPTH = 0.25;
}
"""

const PAVEMENT := """
shader_type spatial;
uniform sampler2D noise_a : repeat_enable, filter_linear_mipmap;
uniform sampler2D noise_b : repeat_enable, filter_linear_mipmap;
varying vec3 wp;
varying vec3 wn;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}
void fragment() {
	vec2 p = wp.xz;
	float grain = texture(noise_b, p * 2.0).r;
	float big = texture(noise_a, p * 0.02).r;
	vec3 col;
	float rough = 0.88;
	if (wn.y > 0.6) {
		vec2 q = p / 0.55;
		vec2 f = fract(q);
		vec2 id = floor(q);
		float h = hash(id);
		float edge = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y));
		float grout = 1.0 - smoothstep(0.02, 0.06, edge);
		float aa = clamp(1.0 - (fwidth(q.x) + fwidth(q.y)) * 1.6, 0.0, 1.0);
		grout *= aa;
		col = mix(vec3(0.5, 0.49, 0.47), vec3(0.64, 0.63, 0.6), h);
		col *= mix(1.0, 0.88 + 0.22 * grain, aa);
		col *= 0.9 + 0.2 * big;
		col = mix(col, vec3(0.2, 0.2, 0.2), grout * 0.7);
		rough = 0.85 - 0.1 * h;
	} else {
		col = vec3(0.6, 0.6, 0.58) * (0.85 + 0.2 * grain);
		col *= mix(0.65, 1.0, smoothstep(0.0, 0.12, wp.y));
		rough = 0.92;
	}
	ALBEDO = col;
	ROUGHNESS = rough;
}
"""

const GRASS := """
shader_type spatial;
uniform sampler2D noise_a : repeat_enable, filter_linear_mipmap;
uniform sampler2D noise_b : repeat_enable, filter_linear_mipmap;
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = wp.xz;
	float big = texture(noise_a, p * 0.004).r;
	float mid = texture(noise_a, p * 0.04 + 2.0).r;
	float fine = texture(noise_b, p * 0.9).r;
	vec3 a = vec3(0.17, 0.30, 0.10);
	vec3 b = vec3(0.30, 0.40, 0.14);
	vec3 dry = vec3(0.42, 0.38, 0.2);
	vec3 col = mix(a, b, mid);
	col = mix(col, dry, smoothstep(0.55, 0.8, big) * 0.6);
	col *= 0.8 + 0.4 * fine;
	ALBEDO = col;
	ROUGHNESS = 0.95;
	SPECULAR = 0.1;
}
"""


static func asphalt(grid: float, road_w: float) -> ShaderMaterial:
	var m := _shader(ASPHALT)
	m.set_shader_parameter("grid", grid)
	m.set_shader_parameter("road_w", road_w)
	return m


static func pavement() -> ShaderMaterial:
	return _shader(PAVEMENT)


static func grass() -> ShaderMaterial:
	return _shader(GRASS)


static func _noise_img(freq: float, seed_v: int, w: int, h: int, ty := FastNoiseLite.TYPE_SIMPLEX_SMOOTH) -> Image:
	var n := FastNoiseLite.new()
	n.noise_type = ty
	n.frequency = freq
	n.seed = seed_v
	n.fractal_octaves = 3
	return n.get_seamless_image(w, h, false)


## multiplies a soft dirt / streak layer over the texture (native blends, cheap)
static func _dirt(img: Image, strength: float, seed_v: int) -> void:
	var S := img.get_width()
	var D := 128                                              # computed small (fast on a phone), then stretched over the texture
	var n := _noise_img(0.02, seed_v, D, D)
	var streak := FastNoiseLite.new()
	streak.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	streak.frequency = 0.03
	streak.seed = seed_v + 5
	var st := streak.get_seamless_image(D, D, false)
	st.resize(D / 6, D, Image.INTERPOLATE_BILINEAR)         # squash horizontally, stretch back: vertical rain streaks
	st.resize(D, D, Image.INTERPOLATE_BILINEAR)
	var layer := Image.create(D, D, false, Image.FORMAT_RGBA8)
	for y in D:
		for x in D:
			var v := n.get_pixel(x, y).r * 0.5 + st.get_pixel(x, y).r * 0.5
			layer.set_pixel(x, y, Color(0.12, 0.1, 0.08, clampf((0.6 - v) * 2.2, 0.0, 1.0) * strength))
	layer.resize(S, S, Image.INTERPOLATE_BILINEAR)
	img.blend_rect(layer, Rect2i(0, 0, S, S), Vector2i.ZERO)


## facade textures (world-space triplanar): 0 glass curtain wall, 1 apartments / offices with balconies, 2 plastered houses, 3 shop fronts
static func facade(kind: int) -> ImageTexture:
	var S := 512
	var img := Image.create(S, S, false, Image.FORMAT_RGBA8)
	var rnd := RandomNumberGenerator.new()
	rnd.seed = 100 + kind
	match kind:
		0:
			img.fill(Color(0.34, 0.37, 0.41))                                            # aluminium frame colour
			var cols := 4
			var rows := 3
			var cw := S / cols
			var ch := S / rows
			for cx in cols:
				for cy in rows:
					var x0 := cx * cw + 3
					var y0 := cy * ch + 3
					var w := cw - 6
					var spand := int(ch * 0.2)
					var tone := rnd.randf_range(-0.05, 0.05)
					var g1 := Color(0.52 + tone, 0.63 + tone, 0.74 + tone)               # sky reflected in the glass
					var g2 := Color(0.2 + tone, 0.28 + tone, 0.37 + tone)
					for yy in range(ch - 6 - spand):
						img.fill_rect(Rect2i(x0, y0 + yy, w, 1), g1.lerp(g2, float(yy) / float(ch - 6 - spand)))
					var sx := x0 + rnd.randi_range(6, w - 30)
					for k in 14:
						img.fill_rect(Rect2i(sx + k, y0, 2, ch - 6 - spand), Color(1, 1, 1, 0.0))
					img.fill_rect(Rect2i(x0, y0 + ch - 6 - spand, w, spand), Color(0.22, 0.25, 0.28))     # spandrel panel behind the slab
					if rnd.randf() < 0.18:
						img.fill_rect(Rect2i(x0, y0, w, ch - 6 - spand), Color(0.9, 0.8, 0.55).lerp(g2, 0.35))   # lit office
					img.fill_rect(Rect2i(x0 + w / 2, y0, 2, ch - 6 - spand), Color(0.28, 0.3, 0.34))
		1:
			img.fill(Color(0.8, 0.76, 0.69))                                              # concrete / stucco
			var cols := 3
			var rows := 4
			var cw := S / cols
			var ch := S / rows
			for cx in cols:
				for cy in rows:
					var x0 := cx * cw + 34
					var y0 := cy * ch + 22
					var w := cw - 68
					var h := ch - 66
					img.fill_rect(Rect2i(x0 - 6, y0 - 6, w + 12, h + 12), Color(0.9, 0.89, 0.86))     # frame
					var lit := rnd.randf() < 0.14
					var glass := Color(0.9, 0.76, 0.46) if lit else Color(0.2, 0.28, 0.35).lerp(Color(0.38, 0.48, 0.58), rnd.randf() * 0.6)
					for yy in h:
						img.fill_rect(Rect2i(x0, y0 + yy, w, 1), glass.lerp(glass.darkened(0.35), float(yy) / float(h)))
					if rnd.randf() < 0.5:
						img.fill_rect(Rect2i(x0, y0, w, int(h * rnd.randf_range(0.25, 0.6))), Color(0.85, 0.82, 0.74, 0.9))   # a blind
					img.fill_rect(Rect2i(x0 + w / 2 - 1, y0, 3, h), Color(0.9, 0.89, 0.86))                     # mullion
					img.fill_rect(Rect2i(x0 - 8, y0 + h + 6, w + 16, 5), Color(0.62, 0.6, 0.56))               # sill
					if cx != 1 and rnd.randf() < 0.55:                                                          # balcony railing
						img.fill_rect(Rect2i(x0 - 14, y0 + h + 12, w + 28, 3), Color(0.25, 0.25, 0.27))
						for k in range(0, w + 28, 8):
							img.fill_rect(Rect2i(x0 - 14 + k, y0 + h + 12, 2, 28), Color(0.25, 0.25, 0.27))
			for cy in rows:
				img.fill_rect(Rect2i(0, cy * ch + ch - 8, S, 8), Color(0.6, 0.58, 0.54))                        # floor slab edge
		2:
			img.fill(Color(0.92, 0.88, 0.8))
			var hw := S / 2
			for cx in 2:
				for cy in 2:
					var x0 := cx * hw + 70
					var y0 := cy * hw + 70
					img.fill_rect(Rect2i(x0 - 8, y0 - 8, 100, 130), Color(0.98, 0.97, 0.94))
					img.fill_rect(Rect2i(x0, y0, 84, 114), Color(0.26, 0.36, 0.46))
					img.fill_rect(Rect2i(x0 + 40, y0, 4, 114), Color(0.98, 0.97, 0.94))
					img.fill_rect(Rect2i(x0 - 28, y0 - 6, 20, 126), Color(0.36, 0.46, 0.38))
					img.fill_rect(Rect2i(x0 + 92, y0 - 6, 20, 126), Color(0.36, 0.46, 0.38))
					img.fill_rect(Rect2i(x0 - 14, y0 + 120, 112, 8), Color(0.7, 0.66, 0.6))
		_:
			img.fill(Color(0.12, 0.13, 0.15))                                                    # shop fronts: dark glass between pilasters
			var panes := 4
			var pw := S / panes
			for k in panes:
				var x0 := k * pw + 10
				for yy in range(S - 160):
					img.fill_rect(Rect2i(x0, 150 + yy, pw - 20, 1), Color(0.3, 0.4, 0.46).lerp(Color(0.1, 0.14, 0.18), float(yy) / float(S - 160)))
				img.fill_rect(Rect2i(x0 + (pw - 20) / 2, 150, 3, S - 160), Color(0.5, 0.5, 0.52))
				var lit := rnd.randf() < 0.5
				if lit:
					img.fill_rect(Rect2i(x0 + 8, 190, pw - 36, 140), Color(0.95, 0.85, 0.6, 0.55))
			img.fill_rect(Rect2i(0, 40, S, 90), Color(0.2, 0.22, 0.26))                             # sign band
			img.fill_rect(Rect2i(0, 130, S, 14), Color(0.55, 0.55, 0.57))                            # awning edge
	_dirt(img, 0.55 if kind != 3 else 0.3, 40 + kind)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


static func facade_material(kind: int, tile_m: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = facade(kind)
	m.vertex_color_use_as_albedo = true
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / tile_m
	m.roughness = 0.3 if kind == 0 else 0.8
	m.metallic = 0.25 if kind == 0 else 0.0
	m.metallic_specular = 0.7 if kind == 0 else 0.35
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m


## sky, light and tone mapping for a believable daytime street
static func tune(env: Environment, sun: DirectionalLight3D) -> void:
	var sky := (env.sky.sky_material as ProceduralSkyMaterial) if env.sky != null else null
	if sky != null:
		sky.sky_top_color = Color(0.22, 0.43, 0.78)
		sky.sky_horizon_color = Color(0.66, 0.76, 0.88)
		sky.ground_horizon_color = Color(0.62, 0.68, 0.7)
		sky.ground_bottom_color = Color(0.25, 0.3, 0.28)
		sky.sky_curve = 0.18
		sky.sun_angle_max = 28.0
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.15
	env.tonemap_white = 6.0
	env.ambient_light_energy = 1.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.08
	env.adjustment_contrast = 1.06
	env.fog_density = 0.0007
	env.fog_light_color = Color(0.7, 0.78, 0.88)
	env.fog_sun_scatter = 0.15
	if sun != null:
		sun.light_color = Color(1.0, 0.95, 0.86)
		sun.light_energy = 1.35
		sun.shadow_blur = 1.4
