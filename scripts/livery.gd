class_name Livery
extends RefCounted
## Hand-sprayed paint jobs. The studio paints two flat images per car (side view and top view);
## here they are projected onto the body by a shader that works on the car's own coordinates,
## so it needs no UV maps and fits every model.

const W := 1040            # canvas width: the car is 5.2 m long, 0.005 m per pixel
const SIDE_H := 400        # side view: 2.0 m tall, starting 0.1 m below the ground
const TOP_H := 520         # top view: 2.6 m wide
const Y0 := -0.1
const LEN := 5.2
const HEI := 2.0
const WID := 2.6

const SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back;
uniform sampler2D side_tex : filter_linear, repeat_disable;
uniform sampler2D top_tex : filter_linear, repeat_disable;
uniform mat4 car_inv;
varying vec3 cp;
varying vec3 cn;
void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	cp = (car_inv * vec4(w, 1.0)).xyz;
	cn = normalize(mat3(car_inv) * (mat3(MODEL_MATRIX) * NORMAL));
}
void fragment() {
	float sw = smoothstep(0.3, 0.6, abs(cn.x));
	float tw = smoothstep(0.3, 0.6, cn.y);
	float s = cn.x >= 0.0 ? 1.0 : -1.0;
	vec2 us = vec2(0.5 - s * cp.z / 5.2, 1.0 - (cp.y + 0.1) / 2.0);
	vec2 ut = vec2(0.5 - cp.z / 5.2, 0.5 + cp.x / 2.6);
	vec4 a = texture(side_tex, us);
	vec4 b = texture(top_tex, ut);
	float ia = (us.x > 0.0 && us.x < 1.0 && us.y > 0.0 && us.y < 1.0) ? 1.0 : 0.0;
	float ib = (ut.x > 0.0 && ut.x < 1.0 && ut.y > 0.0 && ut.y < 1.0) ? 1.0 : 0.0;
	float aa = a.a * sw * ia;
	float ab = b.a * tw * ib;
	float al = aa + ab * (1.0 - aa);
	vec3 col = al > 0.001 ? (a.rgb * aa + b.rgb * ab * (1.0 - aa)) / al : vec3(0.0);
	ALBEDO = col;
	ALPHA = al;
	ROUGHNESS = 0.35;
	METALLIC = 0.0;
}
"""

static var _shader: Shader


static func path(car_id: String, view: String) -> String:
	return "user://livery_%s_%s.png" % [car_id, view]


static func exists(car_id: String) -> bool:
	return FileAccess.file_exists(path(car_id, "side")) or FileAccess.file_exists(path(car_id, "top"))


static func load_img(car_id: String, view: String) -> Image:
	var h := SIDE_H if view == "side" else TOP_H
	var p := path(car_id, view)
	if FileAccess.file_exists(p):
		var im := Image.load_from_file(p)
		if im != null and im.get_width() == W and im.get_height() == h:
			im.convert(Image.FORMAT_RGBA8)
			return im
	var blank := Image.create(W, h, false, Image.FORMAT_RGBA8)
	return blank


static func save_img(car_id: String, view: String, im: Image) -> void:
	im.save_png(path(car_id, view))


static func clear(car_id: String) -> void:
	for v in ["side", "top"]:
		if FileAccess.file_exists(path(car_id, v)):
			DirAccess.remove_absolute(path(car_id, v))


## add the livery to a car body (body_mat must exist). Safe to call again after repainting.
static func apply(car: Node3D, body_mat: StandardMaterial3D, car_id: String) -> void:
	if body_mat == null or not exists(car_id):
		return
	if _shader == null:
		_shader = Shader.new()
		_shader.code = SHADER
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("side_tex", ImageTexture.create_from_image(load_img(car_id, "side")))
	m.set_shader_parameter("top_tex", ImageTexture.create_from_image(load_img(car_id, "top")))
	m.set_shader_parameter("car_inv", Transform3D.IDENTITY)
	body_mat.next_pass = m
	var up := LiveryUpdater.new()
	up.car = car
	up.mat = m
	car.add_child(up)


class LiveryUpdater extends Node:
	var car: Node3D
	var mat: ShaderMaterial

	func _process(_d: float) -> void:
		if car and is_instance_valid(car) and car.is_inside_tree():
			mat.set_shader_parameter("car_inv", Transform3D(car.global_transform.affine_inverse()))
