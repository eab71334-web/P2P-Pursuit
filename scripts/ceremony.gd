class_name Ceremony
extends Node3D
## Victory ceremony after the race: a night stage with a real podium (1st in the middle, 2nd left, 3rd right),
## the cars parked behind, the winner lifts the cup with both hands, 2nd and 3rd wear their medals.
## Built locally on every device from the final order; the camera flies a short "TV broadcast" sequence.

signal skipped

const BLOCK_H := [1.75, 1.25, 0.85]          # 1st, 2nd, 3rd
const BLOCK_X := [0.0, -3.5, 3.5]
const BLOCK_W := 3.1
const BLOCK_D := 2.6
const GOLD := Color(1.0, 0.78, 0.2)
const SILVER := Color(0.78, 0.82, 0.9)
const BRONZE := Color(0.8, 0.5, 0.22)

var entries: Array = []        # rank order: {name, plate, players:[{name,outfit,role}], lo, time, fin, dnf, pct, color, place}
var squad_rows: Array = []     # team race: [{name, pts, color, members}] best first
var info_line := ""            # your reward etc.
var stage_name := ""
var on_again: Callable
var on_exit: Callable
var again_text := ""
var exit_text := ""

var cam: Camera3D
var t := 0.0
var _keys: Array = []
var _blocks: Array = []        # per podium rank: {root, h, riser(0..1), start, avatars[], entry}
var _cars: Array[Node3D] = []
var _events: Array = []        # [time, Callable, done]
var _layer: CanvasLayer
var _banner: Control
var _banner_tw: Tween
var _final_box: Control
var _skip_btn: Button
var _flash_nodes: Array = []
var _flash_t := 0.0
var _confetti: Array[CPUParticles3D] = []
var _applause: AudioStreamPlayer
var _crowd: MultiMeshInstance3D
var _crowd_base: Array[Vector3] = []
var _crowd_t := 0.0
var _final := false
var _beams: Array[Node3D] = []
var _spot_main: SpotLight3D


func _ready() -> void:
	_build_stage()
	_build_podium()
	_build_cars()
	_build_crowd()
	_build_camera_keys()
	_build_events()
	_build_overlay()
	_applause = AudioStreamPlayer.new()
	_applause.stream = Sfx.stream("applause", true)
	_applause.volume_db = -22.0
	add_child(_applause)
	_applause.play()
	cam.current = true


# ---------------------------------------------------------------- stage

func _mat(c: Color, emit := 0.0, metal := 0.0, rough := 0.7) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metal
	m.roughness = rough
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = emit
	return m


func _box(parent: Node, size: Vector3, pos: Vector3, m: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = m
	mi.position = pos
	mi.rotation_degrees = rot
	parent.add_child(mi)
	return mi


func _label(parent: Node, text: String, size: int, pos: Vector3, col := Color.WHITE, px := 0.01) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.pixel_size = px
	l.modulate = col
	l.outline_modulate = Color(0, 0, 0, 0.9)
	l.outline_size = 10
	l.position = pos
	parent.add_child(l)
	return l


func _build_stage() -> void:
	# dark dome so the day sky never shows
	var dome := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 90.0
	sm.height = 180.0
	sm.radial_segments = 24
	sm.rings = 12
	dome.mesh = sm
	var gt := GradientTexture2D.new()
	var gr := Gradient.new()
	gr.colors = PackedColorArray([Color(0.01, 0.012, 0.03), Color(0.03, 0.035, 0.08), Color(0.11, 0.07, 0.1), Color(0.02, 0.02, 0.04)])
	gr.offsets = PackedFloat32Array([0.0, 0.45, 0.5, 0.52])
	gt.gradient = gr
	gt.fill_from = Vector2(0, 0)
	gt.fill_to = Vector2(0, 1)
	gt.width = 8
	gt.height = 128
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.albedo_texture = gt
	dm.cull_mode = BaseMaterial3D.CULL_FRONT
	dome.material_override = dm
	add_child(dome)
	# floor: glossy dark disc + red carpet + glowing ring
	var floor_m := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 42.0
	cm.bottom_radius = 42.0
	cm.height = 0.4
	cm.radial_segments = 48
	floor_m.mesh = cm
	floor_m.material_override = _mat(Color(0.06, 0.065, 0.085), 0.0, 0.5, 0.35)
	floor_m.position.y = -0.2
	add_child(floor_m)
	_box(self, Vector3(4.0, 0.03, 22.0), Vector3(0, 0.015, 6.0), _mat(Color(0.5, 0.04, 0.08), 0.15))
	for sx in [-2.05, 2.05]:
		_box(self, Vector3(0.08, 0.04, 22.0), Vector3(sx, 0.02, 6.0), _mat(GOLD, 0.7, 0.6, 0.3))
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 17.6
	tm.outer_radius = 17.8
	tm.rings = 64
	tm.ring_segments = 4
	ring.mesh = tm
	ring.material_override = _mat(Color(1.0, 0.47, 0.1), 2.0)
	ring.position.y = 0.04
	add_child(ring)
	# LED wall behind the cars
	var wall := _box(self, Vector3(34.0, 9.0, 0.5), Vector3(0, 4.5, -17.0), _mat(Color(0.03, 0.035, 0.06), 0.0, 0.2, 0.3))
	var wg := GradientTexture2D.new()
	var wgr := Gradient.new()
	wgr.colors = PackedColorArray([Color(1.0, 0.45, 0.08), Color(0.55, 0.12, 0.25), Color(0.08, 0.08, 0.2)])
	wg.gradient = wgr
	wg.fill_from = Vector2(0.5, 1.0)
	wg.fill_to = Vector2(0.5, 0.0)
	wg.width = 64
	wg.height = 64
	var sm2 := StandardMaterial3D.new()
	sm2.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm2.albedo_texture = wg
	var screen := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(32.0, 7.6)
	screen.mesh = qm
	screen.material_override = sm2
	screen.position = Vector3(0, 4.5, -16.72)
	add_child(screen)
	_label(self, "CO-DRIVER RALLY", 220, Vector3(0, 6.3, -16.6), Color(1, 1, 1, 0.95), 0.009)
	if stage_name != "":
		_label(self, stage_name.to_upper(), 120, Vector3(0, 4.5, -16.6), Color(1.0, 0.85, 0.5), 0.0065)
	# LED stripes
	for k in 5:
		_box(self, Vector3(34.0, 0.12, 0.2), Vector3(0, 0.6 + k * 0.45, -16.6), _mat(Color(1.0, 0.47, 0.1), 1.2))
	# truss with spots
	_box(self, Vector3(30.0, 0.35, 0.35), Vector3(0, 11.0, 2.0), _mat(Color(0.12, 0.12, 0.15), 0.0, 0.7, 0.4))
	_box(self, Vector3(30.0, 0.35, 0.35), Vector3(0, 11.0, -8.0), _mat(Color(0.12, 0.12, 0.15), 0.0, 0.7, 0.4))
	for sx in [-15.0, 15.0]:
		_box(self, Vector3(0.35, 11.0, 0.35), Vector3(sx, 5.5, 2.0), _mat(Color(0.12, 0.12, 0.15), 0.0, 0.7, 0.4))
		_box(self, Vector3(0.35, 11.0, 0.35), Vector3(sx, 5.5, -8.0), _mat(Color(0.12, 0.12, 0.15), 0.0, 0.7, 0.4))
	var spot_cols := [Color(1.0, 0.95, 0.85), Color(0.5, 0.7, 1.0), Color(1.0, 0.5, 0.25), Color(0.4, 1.0, 0.7)]
	var targets := [Vector3(0, 2.5, 0), Vector3(-3.5, 2.0, 0), Vector3(3.5, 1.5, 0), Vector3(0, 1.0, -6.5)]
	for i in 4:
		var sp := SpotLight3D.new()
		sp.position = Vector3(-9 + i * 6.0, 10.8, 1.0)
		sp.look_at_from_position(sp.position, targets[i], Vector3.UP) if false else null
		add_child(sp)
		sp.look_at(to_global(targets[i]), Vector3.UP)
		sp.spot_range = 30.0
		sp.spot_angle = 24.0
		sp.light_energy = 3.0 if i == 0 else 2.0
		sp.light_color = spot_cols[i]
		if i == 0:
			_spot_main = sp
		if Gfx.fx >= 0.5:
			var beam := MeshInstance3D.new()
			var cone := CylinderMesh.new()
			cone.top_radius = 0.1
			cone.bottom_radius = 3.2
			cone.height = 10.5
			cone.radial_segments = 14
			beam.mesh = cone
			var bm := StandardMaterial3D.new()
			bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			bm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
			bm.albedo_color = Color(spot_cols[i].r, spot_cols[i].g, spot_cols[i].b, 0.07)
			bm.cull_mode = BaseMaterial3D.CULL_DISABLED
			beam.material_override = bm
			beam.position = sp.position.lerp(targets[i], 0.5)
			add_child(beam)
			beam.look_at(to_global(targets[i]), Vector3.UP)
			beam.rotate_object_local(Vector3.RIGHT, PI * 0.5)
			_beams.append(beam)
	var amb := OmniLight3D.new()
	amb.position = Vector3(0, 6.0, 8.0)
	amb.omni_range = 26.0
	amb.light_energy = 0.9
	amb.light_color = Color(0.7, 0.75, 1.0)
	add_child(amb)
	# camera
	cam = Camera3D.new()
	cam.fov = 55.0
	cam.near = 0.1
	cam.far = 250.0
	add_child(cam)


func _build_podium() -> void:
	var n := mini(3, entries.size())
	for r in n:
		var e: Dictionary = entries[r]
		var h: float = BLOCK_H[r]
		var x: float = BLOCK_X[r]
		var col: Color = [GOLD, SILVER, BRONZE][r]
		var root := Node3D.new()
		root.position = Vector3(x, 0.0, 0.0)
		root.scale = Vector3(1, 0.001, 1)
		add_child(root)
		var body := _box(root, Vector3(BLOCK_W, h, BLOCK_D), Vector3(0, h * 0.5, 0), _mat(col.darkened(0.55), 0.0, 0.5, 0.45))
		_box(root, Vector3(BLOCK_W + 0.1, 0.12, BLOCK_D + 0.1), Vector3(0, h + 0.06, 0), _mat(col, 0.35, 0.8, 0.25))
		_box(root, Vector3(BLOCK_W + 0.06, 0.1, BLOCK_D + 0.06), Vector3(0, 0.05, 0), _mat(col.darkened(0.2), 0.2))
		# front plate: big number + name
		_box(root, Vector3(BLOCK_W - 0.5, h - 0.45, 0.04), Vector3(0, h * 0.5 - 0.05, BLOCK_D * 0.5 + 0.02), _mat(Color(0.03, 0.03, 0.05), 0.0, 0.1, 0.4))
		var num := _label(root, str(r + 1), 200, Vector3(0, h * 0.5 - 0.02, BLOCK_D * 0.5 + 0.07), col.lightened(0.15), 0.0042)
		num.outline_size = 6
		var blk := {"root": root, "h": h, "riser": 0.0, "start": -1.0, "avatars": [], "entry": e, "kind": ["cup", "silver", "bronze"][r], "rank": r}
		# people on the block
		var ps: Array = e["players"]
		for i in ps.size():
			var p: Dictionary = ps[i]
			var av := Avatar.new()
			av.role = "podium"
			av.standing = true
			av.helmet_color = e["color"]
			av.shirt_color = (e["color"] as Color).darkened(0.2)
			av.outfit = p["outfit"]
			av.podium_kind = blk["kind"] if i == 0 else ("cheer" if r == 0 else blk["kind"])
			av.podium_phase = 0.0 if i == 0 else 1.3
			var ox := 0.0 if ps.size() == 1 else (-0.7 if i == 0 else 0.7)
			av.position = Vector3(x + ox, 0.98, 0.1)
			av.rotation.y = PI
			add_child(av)
			av.visible = false
			(blk["avatars"] as Array).append(av)
		_blocks.append(blk)


func _build_cars() -> void:
	# behind the podium: everybody's car, winners first, the rest in a second row
	var rows := [[], []]
	for i in entries.size():
		rows[0 if i < 3 else 1].append(i)
	for ri in 2:
		var arr: Array = rows[ri]
		for k in arr.size():
			var i: int = arr[k]
			var e: Dictionary = entries[i]
			var car := Car.new()
			car.setup(i, e["color"], false, e["lo"], true)
			var x := 0.0
			if ri == 0:
				x = BLOCK_X[i]
			else:
				x = (k - (arr.size() - 1) * 0.5) * 5.2
			var z := -8.8 if ri == 0 else -14.0
			car.position = Vector3(x * (1.25 if ri == 0 else 1.0), 0.0, z)
			car.rotation.y = PI + (0.0 if ri == 0 else 0.0) + (-x * 0.02)
			add_child(car)
			car.set_plate_text(str(e["plate"]))
			car.visible = false
			_cars.append(car)
			var fl := _label(car, "#%d" % (i + 1), 140, Vector3(0, 2.9, 0), Color(1, 1, 1), 0.012)
			fl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			if i >= 3:
				var s := _label(car, "%s" % e["plate"], 70, Vector3(0, 2.4, 0), Color(0.85, 0.88, 0.95), 0.008)
				s.billboard = BaseMaterial3D.BILLBOARD_ENABLED


func _build_crowd() -> void:
	if Gfx.fx < 0.5:
		return
	var n := 70
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var bm := BoxMesh.new()
	bm.size = Vector3(0.5, 1.2, 0.35)
	mm.mesh = bm
	mm.instance_count = n
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in n:
		var side := -1.0 if i % 2 == 0 else 1.0
		var row := (i / 2) % 7
		var col := (i / 14)
		var p := Vector3(side * (16.0 + row * 1.1), 0.5 + row * 0.5, 4.0 - col * 2.6 + rng.randf_range(-0.4, 0.4))
		_crowd_base.append(p)
		mm.set_instance_transform(i, Transform3D(Basis(), p))
		mm.set_instance_color(i, Color.from_hsv(rng.randf(), 0.5, rng.randf_range(0.25, 0.7)))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 1.0
	mi.material_override = m
	add_child(mi)
	_crowd = mi


# ---------------------------------------------------------------- timeline

var _t_third := 0.0
var _t_second := 0.0
var _t_first := 0.0
var _t_final := 0.0


func _build_camera_keys() -> void:
	var n := mini(3, entries.size())
	_keys.clear()
	var tt := 0.0
	_keys.append([0.0, Vector3(-14, 3.0, 18), Vector3(0, 2.0, -2), 58.0])
	tt = 2.4
	var t3 := -1.0
	var t2 := -1.0
	if n >= 3:
		_t_third = tt
		t3 = tt
		_keys.append([tt + 0.6, Vector3(8.2, 2.3, 8.5), Vector3(3.5, 1.9, 0), 40.0])
		tt += 5.0
	if n >= 2:
		_t_second = tt
		t2 = tt
		_keys.append([tt + 0.6, Vector3(-8.2, 2.5, 8.5), Vector3(-3.5, 2.2, 0), 40.0])
		tt += 5.0
	_t_first = tt
	_keys.append([tt + 0.6, Vector3(0.5, 2.9, 9.0), Vector3(0, 3.1, 0), 40.0])
	_keys.append([tt + 4.6, Vector3(-1.5, 4.4, 8.0), Vector3(0, 3.7, 0), 36.0])
	_t_final = tt + 7.5
	_keys.append([_t_final, Vector3(0, 4.3, 15.5), Vector3(0, 2.4, -2.0), 54.0])


func _build_events() -> void:
	_events.clear()
	var n := mini(3, entries.size())
	_ev(0.3, func(): Sfx.play("whoosh", -6.0))
	if n >= 3:
		_ev(_t_third, func(): _rise(2))
		_ev(_t_third + 1.4, func(): _award(2))
	if n >= 2:
		_ev(_t_second, func(): _rise(1))
		_ev(_t_second + 1.4, func(): _award(1))
	_ev(_t_first, func(): _rise(0))
	_ev(_t_first + 1.5, func(): _award(0))
	_ev(_t_first + 2.8, func(): _confetti_burst())
	_ev(_t_first + 3.4, func(): _confetti_burst())
	_ev(_t_final, func(): _show_final())


func _ev(at: float, f: Callable) -> void:
	_events.append([at, f, false])


func _rise(r: int) -> void:
	var b: Dictionary = _blocks[r]
	b["start"] = t
	Sfx.play("whoosh", -4.0)
	for av in b["avatars"]:
		(av as Avatar).visible = true
	if r < _cars.size():
		_cars[r].visible = true
	_say_banner(r)


func _award(r: int) -> void:
	var b: Dictionary = _blocks[r]
	var avs: Array = b["avatars"]
	for i in avs.size():
		var av: Avatar = avs[i]
		if r == 0:
			if i == 0:
				av.give_cup()
		else:
			av.give_medal("silver" if r == 1 else "bronze")
		av.start_podium()
	Sfx.play("ding", -2.0)
	if r == 0:
		Sfx.play("fanfare", 2.0)
		_applause.volume_db = -8.0
		_flash_burst(14)
	else:
		Sfx.play("cheer", -6.0)
		_applause.volume_db = -16.0
		_flash_burst(6)


func _confetti_burst() -> void:
	Sfx.play("pop", -2.0)
	for side in [-1.0, 1.0]:
		var p := CPUParticles3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.14, 0.2)
		var qm := StandardMaterial3D.new()
		qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		qm.vertex_color_use_as_albedo = true
		qm.cull_mode = BaseMaterial3D.CULL_DISABLED
		q.material = qm
		p.mesh = q
		p.amount = Gfx.particles(110)
		p.lifetime = 4.2
		p.one_shot = true
		p.explosiveness = 0.96
		p.position = Vector3(side * 6.5, 0.4, 3.0)
		p.direction = Vector3(-side * 0.5, 1.0, -0.25)
		p.spread = 28.0
		p.initial_velocity_min = 11.0
		p.initial_velocity_max = 17.0
		p.gravity = Vector3(0, -5.5, 0)
		p.angular_velocity_min = -360.0
		p.angular_velocity_max = 360.0
		p.damping_min = 0.8
		p.damping_max = 1.6
		var gr := Gradient.new()
		gr.colors = PackedColorArray([Color(1.0, 0.8, 0.2), Color(1.0, 0.3, 0.3), Color(0.3, 0.7, 1.0), Color(0.4, 1.0, 0.5), Color(1.0, 1.0, 1.0)])
		gr.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75, 1.0])
		p.color_initial_ramp = gr
		add_child(p)
		p.emitting = true
		_confetti.append(p)
		get_tree().create_timer(6.0).timeout.connect(func():
			if is_instance_valid(p):
				p.queue_free())


func _flash_burst(count: int) -> void:
	for i in count:
		var delay := randf_range(0.0, 2.2)
		get_tree().create_timer(delay).timeout.connect(_one_flash)


func _one_flash() -> void:
	if not is_inside_tree():
		return
	var s := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.9, 0.9)
	s.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var tex := GradientTexture2D.new()
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	var gr := Gradient.new()
	gr.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	tex.gradient = gr
	tex.width = 64
	tex.height = 64
	m.albedo_texture = tex
	s.material_override = m
	s.position = Vector3(randf_range(-13.0, 13.0), randf_range(0.8, 2.6), randf_range(9.0, 15.0))
	add_child(s)
	Sfx.play("shutter", -14.0, randf_range(0.9, 1.15))
	var tw := s.create_tween()
	tw.tween_property(s, "scale", Vector3.ONE * 2.6, 0.12)
	tw.tween_property(s, "scale", Vector3.ONE * 0.01, 0.18)
	tw.tween_callback(s.queue_free)


func _show_final() -> void:
	if _final:
		return
	_final = true
	for b in _blocks:
		if float(b["start"]) < 0.0:
			_rise(int(b["rank"]))
	for c in _cars:
		c.visible = true
	_build_final_overlay()


func skip() -> void:
	t = maxf(t, _t_final - 0.1)
	for ev in _events:
		if not ev[2] and float(ev[0]) < _t_final:
			ev[2] = true
	for b in _blocks:
		if float(b["start"]) < 0.0:
			b["start"] = t - 2.0
			for av in b["avatars"]:
				(av as Avatar).visible = true
	for c in _cars:
		c.visible = true
	for r in _blocks.size():
		for av in _blocks[r]["avatars"]:
			var a: Avatar = av
			if a.podium_t < 0.0:
				if r == 0:
					a.give_cup()
				else:
					a.give_medal("silver" if r == 1 else "bronze")
				a.start_podium()
				a.podium_t = 4.0
	if _skip_btn:
		_skip_btn.visible = false


# ---------------------------------------------------------------- overlay

func _build_overlay() -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 90
	add_child(_layer)
	_banner = Control.new()
	_banner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_banner)
	_skip_btn = Button.new()
	_skip_btn.text = UI.tx("Skip", "تخطي")
	_skip_btn.custom_minimum_size = Vector2(170, 60)
	_skip_btn.add_theme_font_size_override("font_size", 24)
	_skip_btn.add_theme_stylebox_override("normal", UI.sb(Color(0, 0, 0, 0.6), 10, UI.ACCENT, 2))
	_skip_btn.add_theme_stylebox_override("hover", UI.sb(Color(0.1, 0.1, 0.12, 0.8), 10, UI.ACCENT, 1))
	_skip_btn.add_theme_stylebox_override("pressed", UI.sb(Color(0.1, 0.1, 0.12, 0.8), 10, UI.ACCENT, 1))
	_skip_btn.add_theme_stylebox_override("focus", UI.sb(Color(0, 0, 0, 0.55), 10, UI.LINE, 1))
	_skip_btn.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_skip_btn.position = Vector2(-190, -84)
	_skip_btn.pressed.connect(skip)
	_layer.add_child(_skip_btn)


func _say_banner(r: int) -> void:
	var e: Dictionary = entries[r]
	if _banner_tw:
		_banner_tw.kill()
	for c in _banner.get_children():
		c.queue_free()
	var col: Color = [GOLD, SILVER, BRONZE][r]
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UI.sb(Color(0.03, 0.035, 0.05, 0.9), 14, col, 3))
	box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.position.y = 22
	box.custom_minimum_size = Vector2(430, 0)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 0)
	box.add_child(vb)
	var pl := UI.lbl(vb, str(e["place"]), 34, col.lightened(0.1), false)
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var nm := UI.lbl(vb, str(e["name"]), 26, UI.TXT, false)
	nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var tl := UI.lbl(vb, _time_text(e), 20, UI.TXT2, false)
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_child(box)
	box.modulate.a = 0.0
	box.position.y = -30
	_banner_tw = box.create_tween()
	_banner_tw.set_parallel(true)
	_banner_tw.tween_property(box, "modulate:a", 1.0, 0.35)
	_banner_tw.tween_property(box, "position:y", 22.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_banner_tw.chain().tween_interval(3.3)
	_banner_tw.chain().tween_property(box, "modulate:a", 0.0, 0.5)


func _time_text(e: Dictionary) -> String:
	if bool(e["fin"]):
		var tm: float = e["time"]
		return "%d:%04.1f" % [int(tm / 60.0), fmod(tm, 60.0)]
	if bool(e["dnf"]):
		return UI.tx("Did not finish", "لم يكمل")
	return UI.tx("%d%% of the stage", "%d%% من المرحلة") % int(e["pct"])


func _build_final_overlay() -> void:
	if _banner_tw:
		_banner_tw.kill()
	for c in _banner.get_children():
		c.queue_free()
	if _skip_btn:
		_skip_btn.visible = false
	_final_box = Control.new()
	_final_box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_final_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layer.add_child(_final_box)
	# standings (left)
	var left := PanelContainer.new()
	left.add_theme_stylebox_override("panel", UI.sb(Color(0.03, 0.035, 0.05, 0.88), 14, UI.LINE, 1))
	left.set_anchors_and_offsets_preset(Control.PRESET_CENTER_LEFT)
	left.position = Vector2(20, -200)
	left.grow_vertical = Control.GROW_DIRECTION_BOTH
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 4)
	left.add_child(lv)
	var head := UI.lbl(lv, UI.tx("FINAL STANDINGS", "الترتيب النهائي"), 16, UI.ACCENT, false)
	head.add_theme_constant_override("outline_size", 0)
	for i in entries.size():
		var e: Dictionary = entries[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		lv.add_child(row)
		var cols := [GOLD, SILVER, BRONZE]
		var nb := UI.lbl(row, str(i + 1), 22, cols[i] if i < 3 else UI.TXT2, false)
		nb.custom_minimum_size = Vector2(26, 0)
		var nl := UI.lbl(row, str(e["name"]), 20, UI.TXT, false)
		nl.custom_minimum_size = Vector2(190, 0)
		nl.clip_text = true
		UI.lbl(row, _time_text(e), 18, UI.TXT2, false)
	if not squad_rows.is_empty():
		var right := PanelContainer.new()
		right.add_theme_stylebox_override("panel", UI.sb(Color(0.03, 0.035, 0.05, 0.88), 14, GOLD, 2))
		right.set_anchors_and_offsets_preset(Control.PRESET_CENTER_RIGHT)
		right.position = Vector2(-20, -170)
		right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		right.grow_vertical = Control.GROW_DIRECTION_BOTH
		var rv := VBoxContainer.new()
		rv.add_theme_constant_override("separation", 6)
		right.add_child(rv)
		var rh := UI.lbl(rv, UI.tx("TEAM STANDINGS", "ترتيب الفرق"), 16, GOLD, false)
		rh.add_theme_constant_override("outline_size", 0)
		var win := UI.lbl(rv, UI.tx("%s WINS!", "%s يفوز!") % str(squad_rows[0]["name"]), 26, squad_rows[0]["color"], false)
		for k in squad_rows.size():
			var sr: Dictionary = squad_rows[k]
			var rr := HBoxContainer.new()
			rr.add_theme_constant_override("separation", 10)
			rv.add_child(rr)
			var sw := ColorRect.new()
			sw.color = sr["color"]
			sw.custom_minimum_size = Vector2(8, 28)
			rr.add_child(sw)
			var nm2 := UI.lbl(rr, str(sr["name"]), 22, UI.TXT if k > 0 else GOLD, false)
			nm2.custom_minimum_size = Vector2(110, 0)
			UI.lbl(rr, "%d %s" % [int(sr["pts"]), UI.tx("pts", "نقطة")], 20, UI.TXT2, false)
		_final_box.add_child(right)
	# reward + buttons (bottom)
	var bottom := VBoxContainer.new()
	bottom.add_theme_constant_override("separation", 8)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	bottom.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	bottom.position.y = -16
	_final_box.add_child(left)
	_final_box.add_child(bottom)
	# action bar: reward chips + two big buttons with icons
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", UI.sb(Color(0.035, 0.04, 0.055, 0.93), 16, Color(1, 1, 1, 0.12), 1))
	bottom.add_child(bar)
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 10)
	bar.add_child(bv)
	if info_line != "":
		var rl := UI.lbl(bv, info_line, 22, Color(1.0, 0.85, 0.3), false)
		rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var sep := ColorRect.new()
		sep.color = Color(1, 1, 1, 0.08)
		sep.custom_minimum_size = Vector2(0, 1)
		bv.add_child(sep)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	bv.add_child(row)
	var b1 := _action_btn(row, "replay", again_text, UI.tx("Same stage, new race", "نفس المرحلة من جديد") if false else "", true, func(): on_again.call())
	b1.name = "again"
	var b2 := _action_btn(row, "exit", exit_text, "", false, func(): on_exit.call())
	b2.name = "exit"
	_final_box.modulate.a = 0.0
	_final_box.create_tween().tween_property(_final_box, "modulate:a", 1.0, 0.6)


## icon drawn with code (no textures): "replay" = circular arrow, "exit" = door with arrow
class _Ic extends Control:
	var kind := "replay"
	var col := Color.WHITE

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.34
		if kind == "replay":
			draw_arc(c, r, deg_to_rad(-60), deg_to_rad(230), 28, col, 3.5, true)
			var a := deg_to_rad(230)
			var tip := c + Vector2(cos(a), sin(a)) * r
			draw_colored_polygon(PackedVector2Array([tip + Vector2(-7, -3), tip + Vector2(6, -6), tip + Vector2(2, 8)]), col)
		else:
			draw_rect(Rect2(c.x - r, c.y - r, r * 1.2, r * 2.0), col, false, 3.0)
			draw_line(Vector2(c.x - 1, c.y), Vector2(c.x + r + 4, c.y), col, 3.5, true)
			draw_colored_polygon(PackedVector2Array([Vector2(c.x + r + 8, c.y), Vector2(c.x + r - 2, c.y - 7), Vector2(c.x + r - 2, c.y + 7)]), col)


func _action_btn(parent: Control, icon: String, text: String, sub: String, primary: bool, cb: Callable) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(300, 68)
	b.focus_mode = Control.FOCUS_NONE
	var fill := UI.ACCENT if primary else Color(0.12, 0.13, 0.17)
	var border := UI.ACCENT.lightened(0.25) if primary else Color(1, 1, 1, 0.18)
	b.add_theme_stylebox_override("normal", UI.sb(fill, 14, border, 2))
	b.add_theme_stylebox_override("hover", UI.sb(fill.lightened(0.12), 14, Color.WHITE if primary else UI.ACCENT, 2))
	b.add_theme_stylebox_override("pressed", UI.sb(fill.darkened(0.15), 14, border, 2))
	b.add_theme_stylebox_override("focus", UI.sb(fill, 14, border, 2))
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 16
	h.offset_right = -16
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_theme_constant_override("separation", 12)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(h)
	var ic := _Ic.new()
	ic.kind = icon
	ic.col = Color(0.08, 0.05, 0.02) if primary else UI.TXT
	ic.custom_minimum_size = Vector2(40, 40)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(ic)
	var l := UI.lbl(h, text, 24, Color(0.08, 0.05, 0.02) if primary else UI.TXT, false)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.pressed.connect(cb)
	UI.pop(b, 1.03)
	parent.add_child(b)
	return b


# ---------------------------------------------------------------- per frame

func _process(d: float) -> void:
	t += d
	for ev in _events:
		if not ev[2] and t >= float(ev[0]):
			ev[2] = true
			(ev[1] as Callable).call()
	# blocks rise (ease out back)
	for b in _blocks:
		var st: float = b["start"]
		var k := 0.0
		if st >= 0.0:
			k = clampf((t - st) / 0.9, 0.0, 1.0)
		var e := 1.0 - pow(1.0 - k, 3.0)
		b["riser"] = e
		(b["root"] as Node3D).scale.y = maxf(e, 0.001)
		for av in b["avatars"]:
			(av as Avatar).podium_base_y = float(b["h"]) * e + 0.98 + (0.12 * sin(k * PI) if k < 1.0 else 0.0)
	# cars: fade in by scaling
	for c in _cars:
		if c.visible and c.scale.x < 1.0:
			c.scale = c.scale.lerp(Vector3.ONE, clampf(d * 6.0, 0.0, 1.0))
	_update_camera(d)
	if _crowd:
		_crowd_t += d
		if _crowd_t > 0.06:
			_crowd_t = 0.0
			var mm := _crowd.multimesh
			var cheer := 0.12 if t < _t_first + 1.5 else 0.45
			for i in mm.instance_count:
				var p: Vector3 = _crowd_base[i]
				var hop := absf(sin(t * (4.0 + (i % 5) * 0.6) + i)) * cheer
				mm.set_instance_transform(i, Transform3D(Basis(), p + Vector3(0, hop, 0)))
	# the main spot pulses a little on the winner
	if _spot_main:
		_spot_main.light_energy = 3.0 + (0.6 * sin(t * 3.0) if t > _t_first else 0.0)


func _update_camera(d: float) -> void:
	var pos := Vector3.ZERO
	var look := Vector3.ZERO
	var fov := 55.0
	if t >= _t_final:
		# final: slow orbit around the stage
		var last: Array = _keys[_keys.size() - 1]
		var a := (t - _t_final) * 0.12
		var base: Vector3 = last[1]
		pos = Vector3(sin(a) * 4.5 + base.x, base.y + sin(a * 1.7) * 0.5, base.z - (1.0 - cos(a)) * 2.0)
		look = last[2]
		fov = last[3]
	else:
		var a_key: Array = _keys[0]
		var b_key: Array = _keys[_keys.size() - 1]
		for i in range(_keys.size() - 1):
			if t >= float(_keys[i][0]) and t < float(_keys[i + 1][0]):
				a_key = _keys[i]
				b_key = _keys[i + 1]
				break
		if t < float(_keys[0][0]):
			b_key = _keys[0]
			a_key = _keys[0]
		var span := maxf(float(b_key[0]) - float(a_key[0]), 0.001)
		var k := clampf((t - float(a_key[0])) / span, 0.0, 1.0)
		k = k * k * (3.0 - 2.0 * k)
		pos = (a_key[1] as Vector3).lerp(b_key[1], k)
		look = (a_key[2] as Vector3).lerp(b_key[2], k)
		fov = lerpf(float(a_key[3]), float(b_key[3]), k)
	# gentle handheld sway
	pos += Vector3(sin(t * 0.9) * 0.05, sin(t * 1.3) * 0.04, 0)
	cam.position = pos
	cam.look_at(to_global(look), Vector3.UP)
	cam.fov = fov
