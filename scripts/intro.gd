# Copyright (c) 2026 Sabak Studios. All rights reserved. See LICENSE.
extends Node
## Start-up film: studio logo with a light sweep, then a cinematic car reveal, then the main menu.
## Any tap / key skips it.

const MENU_SCENE := "res://scenes/main.tscn"
const LOGO_END := 3.7
const END_T := 8.4

const SWEEP_SHADER := """
shader_type canvas_item;
render_mode blend_add;
uniform float sweep = -1.0;
uniform float alpha = 1.0;
void fragment() {
	vec4 t = texture(TEXTURE, UV);
	float band = exp(-pow((UV.x * 0.85 + UV.y * 0.35 - sweep) * 7.0, 2.0));
	float lum = max(t.r, max(t.g, t.b));
	COLOR = vec4(t.rgb * alpha + vec3(1.0) * band * lum * 1.6 * alpha, 1.0);
}
"""

var t := 0.0
var _done := false
var _cam: Camera3D
var _car: Car
var _logo: TextureRect
var _logo_mat: ShaderMaterial
var _black: ColorRect
var _bars: Array[ColorRect] = []
var _title: VBoxContainer
var _eng: AudioStreamPlayer
var _flash := 0.0
var _boomed := false
var _roared := false


func _ready() -> void:
	RenderingServer.set_default_clear_color(Color.BLACK)
	_build_world()
	_build_ui()
	set_process(true)


func _build_world() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.035, 0.04, 0.055)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.5, 0.55, 0.7)
	e.ambient_light_energy = 0.55
	e.glow_enabled = true
	e.glow_intensity = 0.9
	e.glow_bloom = 0.15
	env.environment = e
	add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-30, -50, 0)
	key.light_energy = 1.25
	add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-15, 140, 0)
	rim.light_color = Color(1.0, 0.55, 0.2)
	rim.light_energy = 1.6
	add_child(rim)
	var fl := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(120, 120)
	fl.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.09, 0.1, 0.13)
	fm.metallic = 0.1
	fm.roughness = 0.6
	fl.material_override = fm
	add_child(fl)
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 30:
		var b := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.05 + rng.randf() * 0.05, 0.05, 6.0 + rng.randf() * 16.0)
		b.mesh = bm
		var mm := StandardMaterial3D.new()
		mm.albedo_color = Color(1, 0.5, 0.12)
		mm.emission_enabled = true
		mm.emission = Color(1, 0.5, 0.12)
		mm.emission_energy_multiplier = 3.0
		b.material_override = mm
		var x := rng.randf_range(-9, 9)
		if absf(x) < 2.4:
			x += signf(x + 0.01) * 3.0
		b.position = Vector3(x, rng.randf_range(0.2, 4.0), rng.randf_range(6, 34))
		add_child(b)
	var lo := {"car": "gt3", "paint": "orange", "stripe": "white", "rim": "black", "glow": "none", "decal": "none", "spoiler": "gt", "front": "splitter", "hood": "none", "skirts": "none", "wheel": "centre"}
	_car = Car.new()
	_car.setup(0, Color(1, 0.55, 0.12), false, lo, true)
	_car.rotation_degrees.y = 18.0
	_car.position = Vector3(0, 0, 26)
	add_child(_car)
	_car.set_plate_text("")
	_cam = Camera3D.new()
	_cam.fov = 36.0
	_cam.position = Vector3(-5.9, 1.35, -8.0)
	add_child(_cam)
	_cam.look_at(Vector3(0.25, 0.95, 0.0), Vector3.UP)
	_cam.current = true
	_eng = AudioStreamPlayer.new()
	var st = load("res://audio/engine_loop.wav")
	if st:
		_eng.stream = st
	_eng.volume_db = -80.0
	add_child(_eng)


func _build_ui() -> void:
	var cl := CanvasLayer.new()
	cl.layer = 20
	add_child(cl)
	_black = ColorRect.new()
	_black.color = Color.BLACK
	_black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cl.add_child(_black)
	_logo = TextureRect.new()
	_logo.texture = load("res://art/sabak_logo.png")
	_logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_logo.anchor_left = 0.5
	_logo.anchor_right = 0.5
	_logo.anchor_top = 0.5
	_logo.anchor_bottom = 0.5
	_logo.offset_left = -300
	_logo.offset_right = 300
	_logo.offset_top = -143
	_logo.offset_bottom = 142
	_logo.pivot_offset = Vector2(300, 142)
	var sh := Shader.new()
	sh.code = SWEEP_SHADER
	_logo_mat = ShaderMaterial.new()
	_logo_mat.shader = sh
	_logo.material = _logo_mat
	_logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(_logo)
	for k in 2:
		var b := ColorRect.new()
		b.color = Color.BLACK
		b.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE if k == 0 else Control.PRESET_BOTTOM_WIDE)
		cl.add_child(b)
		_bars.append(b)
	_title = VBoxContainer.new()
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.anchor_left = 0.58
	_title.anchor_right = 0.97
	_title.anchor_top = 0.3
	_title.anchor_bottom = 0.75
	_title.alignment = BoxContainer.ALIGNMENT_CENTER
	_title.add_theme_constant_override("separation", 4)
	cl.add_child(_title)
	for e2 in [["هيربن راش", 50, Color(1, 0.58, 0.14)], ["HAIRPIN RUSH", 28, Color(0.9, 0.92, 0.97)], ["© 2026 Sabak Studios", 18, Color(0.55, 0.6, 0.68)]]:
		var l := Label.new()
		l.text = e2[0]
		l.add_theme_font_size_override("font_size", e2[1])
		l.add_theme_color_override("font_color", e2[2])
		l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		l.add_theme_constant_override("outline_size", 8)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_title.add_child(l)
	_title.modulate.a = 0.0


func _ease(x: float) -> float:
	x = clampf(x, 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)


func _process(d: float) -> void:
	if _done:
		return
	t += d
	var vp := get_viewport().get_visible_rect().size
	# --- logo phase
	if t < LOGO_END:
		var fin := _ease((t - 0.5) / 0.9)
		var fout := 1.0 - _ease((t - 3.0) / 0.6)
		var a := fin * fout
		_logo_mat.set_shader_parameter("alpha", a)
		_logo_mat.set_shader_parameter("sweep", lerpf(-0.4, 1.6, _ease((t - 1.3) / 1.3)))
		_logo.scale = Vector2.ONE * lerpf(0.92, 1.0, _ease((t - 0.5) / 3.0))
		_black.color.a = 1.0
		for b in _bars:
			b.size.y = 0.0
		if t > 0.5 and not _boomed:
			_boomed = true
			Sfx.play("boom", -9.0, 0.7)
	else:
		_logo.visible = false
		var u := t - LOGO_END
		_black.color.a = 1.0 - _ease(u / 0.7)
		var bh := 62.0 * _ease(u / 0.8)
		_bars[0].offset_top = 0
		_bars[0].offset_bottom = bh
		_bars[1].offset_top = -bh
		_bars[1].offset_bottom = 0
		# the car rolls in from the distance and settles
		var drive := _ease(u / 3.4)
		var z := lerpf(26.0, 0.0, 1.0 - pow(1.0 - clampf(u / 3.6, 0.0, 1.0), 2.4))
		_car.position = Vector3(0, 0, z)
		_car.rotation_degrees.y = lerpf(14.0, 18.0, drive)
		_car.speed_kmh = clampf((1.0 - drive) * 95.0, 0.0, 95.0)
		var push := _ease(u / 4.6)
		_cam.fov = lerpf(40.0, 30.0, push)
		_cam.position = Vector3(lerpf(-7.5, -5.8, push), lerpf(0.75, 1.15, push), lerpf(-9.5, -7.4, push))
		_cam.look_at(Vector3(lerpf(0.9, -1.4, push), 0.9, 0.0), Vector3.UP)
		if not _roared and u > 0.1:
			_roared = true
			if _eng.stream:
				_eng.play()
		if _eng.playing:
			_eng.volume_db = lerpf(-30.0, -9.0, _ease(u / 1.2)) - 28.0 * _ease((u - 3.0) / 1.5)
			_eng.pitch_scale = lerpf(1.5, 0.8, _ease(u / 3.4))
		_title.modulate.a = _ease((u - 2.4) / 0.9) * (1.0 - _ease((t - (END_T - 0.8)) / 0.6))
		if t > END_T - 0.7:
			_black.color.a = _ease((t - (END_T - 0.7)) / 0.7)
	if t >= END_T:
		_finish()


func _input(event: InputEvent) -> void:
	if _done or t < 0.4:
		return
	var press := false
	if event is InputEventKey and event.pressed:
		press = true
	elif event is InputEventMouseButton and event.pressed:
		press = true
	elif event is InputEventScreenTouch and event.pressed:
		press = true
	if press:
		_finish()


func _finish() -> void:
	if _done:
		return
	_done = true
	if _eng:
		_eng.stop()
	get_tree().change_scene_to_file(MENU_SCENE)
