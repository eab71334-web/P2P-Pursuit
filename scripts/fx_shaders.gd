# Copyright (c) 2026 Sabak Studios. All rights reserved. See LICENSE.
class_name FxShaders
extends RefCounted
## Small 3D / screen shader library (written for this game, works in the Compatibility renderer):
##  - rain_glass(): droplets on the windshield glass; the wipers clear them (wet 0..1)
##  - speed_lines(): streaks at the screen edges at high speed (canvas shader)
##  - disc material helper for glowing brake discs (heat 0..1)

const RAIN_GLASS := """
shader_type spatial;
render_mode blend_mix, cull_back, specular_schlick_ggx;
uniform vec4 tint : source_color = vec4(0.35, 0.55, 0.75, 0.22);
uniform float wet : hint_range(0.0, 1.0) = 0.0;
varying vec3 lp;
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
void vertex() { lp = VERTEX; }
void fragment() {
	vec2 g = lp.xy * 15.0;
	vec2 id = floor(g);
	vec2 f = fract(g) - 0.5;
	float h = hash(id);
	float h2 = hash(id + 7.3);
	float present = step(h, wet);
	vec2 c = (vec2(h2, fract(h * 13.7)) - 0.5) * 0.45;
	float r = 0.1 + 0.14 * fract(h * 5.1);
	float d = length((f - c) * vec2(1.0, 0.8));
	float drop = smoothstep(r, r * 0.45, d) * present;
	// a faint streak under the bigger drops
	float streak = smoothstep(0.05, 0.0, abs(f.x - c.x)) * step(c.y, f.y) * step(f.y, c.y + 0.35) * step(0.62, fract(h * 9.3)) * present * 0.5;
	float k = clamp(drop + streak * 0.4, 0.0, 1.0);
	ALBEDO = mix(tint.rgb, vec3(0.85, 0.93, 1.0), k);
	ALPHA = mix(tint.a, 0.6, k);
	ROUGHNESS = mix(0.1, 0.02, k);
}
"""

const SPEED_LINES := """
shader_type canvas_item;
uniform float amount : hint_range(0.0, 1.0) = 0.0;
float hash(vec2 p) { return fract(sin(dot(p, vec2(41.7, 289.3))) * 43758.5453); }
void fragment() {
	vec2 uv = UV - 0.5;
	uv.x *= 1.7;
	float a = atan(uv.y, uv.x);
	float r = length(uv) * 1.7;
	float slot = floor(a * 70.0);
	float t = floor(TIME * 16.0);
	float s = hash(vec2(slot, t));
	float edge = smoothstep(0.6, 1.25, r);
	float line = step(0.82, s) * edge * smoothstep(0.0, 0.5, fract(a * 70.0)) * (1.0 - smoothstep(0.5, 1.0, fract(a * 70.0)));
	COLOR = vec4(1.0, 1.0, 1.0, line * amount * 0.5);
}
"""


static func rain_glass() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = RAIN_GLASS
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


static func speed_lines() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = SPEED_LINES
	var m := ShaderMaterial.new()
	m.shader = sh
	return m


## glowing brake disc material (emission follows `heat`)
static func disc_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.35, 0.35, 0.38)
	m.metallic = 0.7
	m.roughness = 0.4
	m.emission_enabled = true
	m.emission = Color(1.0, 0.35, 0.05)
	m.emission_energy_multiplier = 0.0
	return m
