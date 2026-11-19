extends Node3D
## OPEN WORLD (solo): a big city with a ring highway, suburbs, forest and mountains. Drive freely, get out and walk, get back in.
## Controls: touch (steer / gas / brake buttons, left stick + jump on foot) or keyboard (WASD / arrows, E exit-enter, V camera, R reset, Space jump).

const GRID := 220.0
const HALF_CELLS := 5                 # roads at -5..5 * GRID  -> 2.4 km square
const ROAD_W := 14.0
const MENU_SCENE := "res://scenes/main.tscn"
const WALK_SPEED := 5.2
const RUN_SPEED := 8.5

var car: Car
var driver_av: Avatar
var walker: CharacterBody3D
var walk_av: Avatar
var walk_cam: Camera3D
var chase_cam: Camera3D
var on_foot := false
var chase := false
var walk_yaw := 0.0
var walk_pitch := -0.15
var look_yaw := 0.0
var look_pitch := 0.0
var _vy := 0.0
var _flip_t := 0.0

var hud: CanvasLayer
var speed_lbl: Label
var info_lbl: Label
var hint_lbl: Label
var minimap: MiniMap
var btn_exit: Button
var btn_jump: Button
var drive_zones := {}                  # name -> Control (hold zones)
var touches := {}                      # finger index -> position
var stick_id := -1
var stick_origin := Vector2.ZERO
var stick_vec := Vector2.ZERO
var look_id := -1
var show_touch := false
var rng := RandomNumberGenerator.new()


class MiniMap extends Control:
	var ow: Node3D

	func _init() -> void:
		custom_minimum_size = Vector2(170, 170)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip_contents = true

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if ow == null:
			return
		var c := size * 0.5
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.07, 0.06, 0.78))
		var pos: Vector3 = ow.focus_pos()
		var yaw: float = ow.focus_yaw()
		var sc := 0.26                                          # px per metre
		var g: float = ow.GRID
		var span := int(size.x / sc / g) + 3
		var cx := roundi(pos.x / g)
		var cz := roundi(pos.z / g)
		var rot := Basis(Vector3.UP, -yaw)                      # heading up
		for k in range(-span, span + 1):
			var gx := float(cx + k) * g
			if absf(gx) <= g * ow.HALF_CELLS + 1.0:
				var a: Vector3 = rot * Vector3(gx - pos.x, 0, -g * ow.HALF_CELLS - pos.z)
				var b: Vector3 = rot * Vector3(gx - pos.x, 0, g * ow.HALF_CELLS - pos.z)
				draw_line(c + Vector2(a.x, a.z) * sc, c + Vector2(b.x, b.z) * sc, Color(0.62, 0.64, 0.68), 3.0)
			var gz := float(cz + k) * g
			if absf(gz) <= g * ow.HALF_CELLS + 1.0:
				var a2: Vector3 = rot * Vector3(-g * ow.HALF_CELLS - pos.x, 0, gz - pos.z)
				var b2: Vector3 = rot * Vector3(g * ow.HALF_CELLS - pos.x, 0, gz - pos.z)
				draw_line(c + Vector2(a2.x, a2.z) * sc, c + Vector2(b2.x, b2.z) * sc, Color(0.62, 0.64, 0.68), 3.0)
		if ow.on_foot:                                           # the car we left
			var cp: Vector3 = rot * (ow.car.global_position - pos)
			draw_rect(Rect2(c + Vector2(cp.x, cp.z) * sc - Vector2(4, 4), Vector2(8, 8)), Color(1.0, 0.47, 0.1))
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -9), c + Vector2(7, 8), c + Vector2(0, 4), c + Vector2(-7, 8)]), Color(0.2, 0.9, 0.5))
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.25), false, 2.0)


class HoldZone extends Control:
	var txt := ""
	var down := false

	func _init(t: String) -> void:
		txt = t
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var col := Color(1, 1, 1, 0.34 if down else 0.16)
		draw_rect(Rect2(Vector2.ZERO, size), col, true)
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.55), false, 2.0)
		var f := ThemeDB.fallback_font
		var s := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 22)
		draw_string(f, (size - s) * 0.5 + Vector2(0, s.y * 0.7), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1, 0.9))


func _ready() -> void:
	rng.seed = 20260
	show_touch = DisplayServer.is_touchscreen_available() or OS.get_environment("FORCE_TOUCH") != ""
	_build_environment()
	_build_ground()
	_build_roads()
	_build_city()
	_build_nature()
	_build_ramps()
	_build_car()
	_build_walker()
	_build_hud()
	_set_mode(false)


# ====================================================================== world

func _mat(c: Color, rough := 0.9) -> StandardMaterial3D:
	return Scenery.plain(c, rough, true)


func _build_environment() -> void:
	var env := Environment.new()
	var sky := ProceduralSkyMaterial.new()
	sky.sky_top_color = Color(0.28, 0.5, 0.85)
	sky.sky_horizon_color = Color(0.75, 0.84, 0.92)
	sky.ground_horizon_color = Color(0.7, 0.78, 0.75)
	sky.ground_bottom_color = Color(0.3, 0.38, 0.32)
	var s := Sky.new()
	s.sky_material = sky
	env.background_mode = Environment.BG_SKY
	env.sky = s
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.fog_enabled = true
	env.fog_light_color = Color(0.74, 0.82, 0.9)
	env.fog_density = 0.0009
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52, -35, 0)
	sun.light_energy = 1.15
	sun.shadow_enabled = false
	add_child(sun)


func _build_ground() -> void:
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(9000, 2, 9000)
	cs.shape = bs
	cs.position = Vector3(0, -1.0, 0)
	body.add_child(cs)
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(9000, 9000)
	mi.mesh = pm
	mi.material_override = _mat(Color(0.3, 0.5, 0.28))
	body.add_child(mi)
	add_child(body)


func _multimesh(mesh: Mesh, mat: Material, xf: Array[Transform3D], colors: PackedColorArray = PackedColorArray()) -> void:
	if xf.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = colors.size() == xf.size()
	mm.mesh = mesh
	mm.instance_count = xf.size()
	for i in xf.size():
		mm.set_instance_transform(i, xf[i])
		if mm.use_colors:
			mm.set_instance_color(i, colors[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


func _unit_box() -> BoxMesh:
	var b := BoxMesh.new()
	b.size = Vector3.ONE
	return b


func _build_roads() -> void:
	var ext := GRID * HALF_CELLS
	var road: Array[Transform3D] = []
	var dashes: Array[Transform3D] = []
	var walks: Array[Transform3D] = []
	for k in range(-HALF_CELLS, HALF_CELLS + 1):
		var p := float(k) * GRID
		# east-west road (along X) at z = p, north-south road (along Z) at x = p
		road.append(Transform3D(Basis.from_scale(Vector3(ext * 2.0 + ROAD_W, 0.06, ROAD_W)), Vector3(0, 0.03, p)))
		road.append(Transform3D(Basis.from_scale(Vector3(ROAD_W, 0.06, ext * 2.0 + ROAD_W)), Vector3(p, 0.035, 0)))
		var n := int(ext * 2.0 / 12.0)
		for i in n:
			var t := -ext + float(i) * 12.0 + 3.0
			if absf(fposmod(t + GRID * 0.5, GRID) - GRID * 0.5) < ROAD_W:      # none inside the junctions
				continue
			dashes.append(Transform3D(Basis.from_scale(Vector3(5.0, 0.02, 0.3)), Vector3(t + 2.5, 0.075, p)))
			dashes.append(Transform3D(Basis.from_scale(Vector3(0.3, 0.02, 5.0)), Vector3(p, 0.08, t + 2.5)))
	_multimesh(_unit_box(), Scenery.road_material(Color(0.2, 0.21, 0.23)), road)
	_multimesh(_unit_box(), _mat(Color(0.95, 0.93, 0.8)), dashes)
	# pavement strips along every block edge
	for i in range(-HALF_CELLS, HALF_CELLS):
		for j in range(-HALF_CELLS, HALF_CELLS):
			var c := Vector3((float(i) + 0.5) * GRID, 0, (float(j) + 0.5) * GRID)
			var inner := GRID - ROAD_W - 3.0
			walks.append(Transform3D(Basis.from_scale(Vector3(inner, 0.12, inner)), c + Vector3(0, 0.06, 0)))
	_multimesh(_unit_box(), _mat(Color(0.62, 0.62, 0.6)), walks)


func _build_city() -> void:
	var xf: Array[Transform3D] = []
	var cols := PackedColorArray()
	var roofs: Array[Transform3D] = []
	var palette := [Color(0.82, 0.78, 0.7), Color(0.7, 0.74, 0.8), Color(0.86, 0.6, 0.5), Color(0.6, 0.66, 0.62), Color(0.9, 0.86, 0.72), Color(0.55, 0.6, 0.7), Color(0.78, 0.5, 0.45)]
	for i in range(-HALF_CELLS, HALF_CELLS):
		for j in range(-HALF_CELLS, HALF_CELLS):
			var d := maxi(maxi(-i - 1, i), maxi(-j - 1, j))                  # ring distance from the centre block
			var c := Vector3((float(i) + 0.5) * GRID, 0, (float(j) + 0.5) * GRID)
			var half := GRID * 0.5 - ROAD_W * 0.5 - 6.0
			var count := 0
			var hmin := 0.0
			var hmax := 0.0
			var wmax := 0.0
			if d <= 1:
				count = 4
				hmin = 28.0
				hmax = 85.0
				wmax = 70.0
			elif d <= 3:
				count = 5
				hmin = 10.0
				hmax = 30.0
				wmax = 46.0
			else:
				count = 4
				hmin = 4.5
				hmax = 8.5
				wmax = 24.0
			if d >= 3 and rng.randf() < 0.22:                              # a park: trees only
				continue
			var slots := [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1), Vector2(0, 0)]
			for sidx in count:
				var sl: Vector2 = slots[sidx]
				var w := rng.randf_range(wmax * 0.55, wmax)
				var dd := rng.randf_range(wmax * 0.55, wmax)
				var h := rng.randf_range(hmin, hmax)
				var off := Vector2(sl.x * (half * 0.5), sl.y * (half * 0.5))
				if sl == Vector2(0, 0):
					if d > 3:
						continue
					off = Vector2.ZERO
					w *= 0.6
					dd *= 0.6
				var pos := c + Vector3(off.x + rng.randf_range(-4, 4), h * 0.5, off.y + rng.randf_range(-4, 4))
				w = minf(w, half * 0.9)
				dd = minf(dd, half * 0.9)
				var yaw := 0.0
				xf.append(Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(w, h, dd)), pos))
				cols.append(palette[rng.randi() % palette.size()])
				roofs.append(Transform3D(Basis.from_scale(Vector3(w * 1.04, 0.5, dd * 1.04)), pos + Vector3(0, h * 0.5 + 0.25, 0)))
				var body := StaticBody3D.new()
				body.position = pos
				var cs := CollisionShape3D.new()
				var bs := BoxShape3D.new()
				bs.size = Vector3(w, h, dd)
				cs.shape = bs
				body.add_child(cs)
				add_child(body)
	var m := _mat(Color.WHITE)
	m.vertex_color_use_as_albedo = true
	_multimesh(_unit_box(), m, xf, cols)
	_multimesh(_unit_box(), _mat(Color(0.25, 0.26, 0.3)), roofs)


func _build_nature() -> void:
	var trunks: Array[Transform3D] = []
	var crowns: Array[Transform3D] = []
	var ext := GRID * HALF_CELLS
	var placed := 0
	var tries := 0
	while placed < 700 and tries < 6000:
		tries += 1
		var x := rng.randf_range(-ext - 700.0, ext + 700.0)
		var z := rng.randf_range(-ext - 700.0, ext + 700.0)
		var inside := absf(x) < ext + 20.0 and absf(z) < ext + 20.0
		if inside:
			# only in the outer (suburb) blocks, and off the roads / pavement
			var cell := Vector2(fposmod(x + GRID * 0.5, GRID) - GRID * 0.5, fposmod(z + GRID * 0.5, GRID) - GRID * 0.5)
			if absf(cell.x) < ROAD_W + 6.0 or absf(cell.y) < ROAD_W + 6.0:
				continue
			if maxf(absf(x), absf(z)) < GRID * 3.0:
				continue
			if rng.randf() < 0.55:
				continue
		else:
			if absf(x) < ext + 30.0 and absf(z) < ext + 30.0:
				continue
		var h := rng.randf_range(5.0, 9.5)
		trunks.append(Transform3D(Basis.from_scale(Vector3(0.7, h * 0.4, 0.7)), Vector3(x, h * 0.2, z)))
		var cw := rng.randf_range(3.2, 5.2)
		crowns.append(Transform3D(Basis.from_scale(Vector3(cw, h * 0.75, cw)), Vector3(x, h * 0.4 + h * 0.37, z)))
		placed += 1
		# the trunk is solid (a small collider keeps cars from driving through trees)
		if placed % 2 == 0:
			var body := StaticBody3D.new()
			body.position = Vector3(x, 1.5, z)
			var cs := CollisionShape3D.new()
			var bs := BoxShape3D.new()
			bs.size = Vector3(0.8, 3.0, 0.8)
			cs.shape = bs
			body.add_child(cs)
			add_child(body)
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.5
	cyl.bottom_radius = 0.5
	cyl.height = 1.0
	cyl.radial_segments = 6
	_multimesh(cyl, _mat(Color(0.35, 0.24, 0.15)), trunks)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.5
	cone.height = 1.0
	cone.radial_segments = 7
	_multimesh(cone, _mat(Color(0.16, 0.42, 0.2)), crowns)
	# mountains on the horizon
	var variants: Array[ArrayMesh] = []
	for vi in 3:
		variants.append(Scenery.mountain_mesh(777 + vi * 7, Color(0.28, 0.38, 0.3), Color(0.45, 0.45, 0.48), Color(0.95, 0.97, 1.0), 0.68))
	var mats: Array[StandardMaterial3D] = []
	for vi in 3:
		var mt := Scenery.veg_material()
		mt.albedo_color = Color(1, 1, 1).lerp(Color(0.75, 0.82, 0.92), 0.3)
		mt.disable_fog = true
		mats.append(mt)
	var per: Array = [[], [], []]
	for i in 30:
		var a := TAU * float(i) / 30.0 + rng.randf_range(-0.05, 0.05)
		var dist := rng.randf_range(2900.0, 3300.0)
		var h := rng.randf_range(260.0, 520.0)
		var w := rng.randf_range(500.0, 900.0)
		var t := Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis.from_scale(Vector3(w, h, w)), Vector3(cos(a) * dist, 0.0, sin(a) * dist))
		per[i % 3].append(t)
	for vi in 3:
		var arr: Array[Transform3D] = []
		for t in per[vi]:
			arr.append(t)
		_multimesh(variants[vi], mats[vi], arr)


func _build_ramps() -> void:
	# a few stunt ramps on the long roads
	for spot in [Vector3(0, 0, -520), Vector3(0, 0, 640), Vector3(-660, 0, 0), Vector3(440, 0, 0)]:
		var along_x: bool = absf(spot.x) > 1.0
		var body := StaticBody3D.new()
		var yaw := PI * 0.5 if along_x else 0.0
		body.transform = Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, deg_to_rad(11.0)), spot + Vector3(0, 0.75, 0))
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(11.0, 0.5, 18.0)
		cs.shape = bs
		body.add_child(cs)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = bs.size
		mi.mesh = bm
		mi.material_override = _mat(Color(0.95, 0.55, 0.1))
		body.add_child(mi)
		add_child(body)


# ====================================================================== car + people

func _build_car() -> void:
	car = Car.new()
	car.setup(0, Color(0.95, 0.4, 0.1), false, Profile.loadout())
	car.transform = Transform3D(Basis(Vector3.UP, 0.0), Vector3(3.5, 1.0, 20.0))
	add_child(car)
	driver_av = Avatar.new()
	driver_av.name = "Driver"
	driver_av.peer_id = 1
	driver_av.role = "driver"
	driver_av.helmet_color = Color(0.1, 0.25, 0.9)
	driver_av.shirt_color = Color(0.7, 0.2, 0.25)
	driver_av.is_local = true
	driver_av.outfit = (Profile.loadout().get("outfit", {}) as Dictionary)
	driver_av.position = car.seat_origin("driver")
	car.add_child(driver_av)
	car.driver_avatar = driver_av
	chase_cam = Camera3D.new()
	chase_cam.fov = 70.0
	chase_cam.far = Gfx.far_clip()
	add_child(chase_cam)


func _build_walker() -> void:
	walker = CharacterBody3D.new()
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.75
	cs.shape = cap
	cs.position = Vector3(0, 0.875, 0)
	walker.add_child(cs)
	walker.collision_layer = 2
	walker.collision_mask = 1
	add_child(walker)
	walk_av = Avatar.new()
	walk_av.name = "Walker"
	walk_av.peer_id = 2
	walk_av.role = "driver"
	walk_av.helmet_color = Color(0.1, 0.25, 0.9)
	walk_av.shirt_color = Color(0.7, 0.2, 0.25)
	walk_av.is_local = false
	walk_av.standing = true
	walk_av.outfit = (Profile.loadout().get("outfit", {}) as Dictionary)
	walker.add_child(walk_av)
	walk_av.position = Vector3(0, 0.95, 0)
	walk_av.rotation.y = PI
	walk_cam = Camera3D.new()
	walk_cam.fov = 72.0
	walk_cam.far = Gfx.far_clip()
	add_child(walk_cam)
	walker.visible = false


func focus_pos() -> Vector3:
	return walker.global_position if on_foot else car.global_position


func focus_yaw() -> float:
	if on_foot:
		return walk_yaw
	return _heading(car)


func _heading(n: Node3D) -> float:
	var f := -n.global_basis.z
	return atan2(-f.x, -f.z)


func _set_mode(foot: bool) -> void:
	on_foot = foot
	walker.visible = foot
	if foot:
		# step out on the left side of the car
		var side: Vector3 = car.global_basis.x * -2.2
		walker.global_position = car.global_position + side + Vector3(0, 0.3, 0)
		walk_yaw = _heading(car)
		walk_pitch = -0.15
		walk_cam.current = true
		car.set_controls(0.0, 0.0, 1.0)
		car.hold = true
	else:
		car.hold = false
		if chase:
			chase_cam.current = true
		elif driver_av.cam != null:
			driver_av.cam.current = true
		else:
			chase_cam.current = true
	_refresh_buttons()


func _try_toggle_car() -> void:
	if on_foot:
		if walker.global_position.distance_to(car.global_position) < 5.0:
			_set_mode(false)
	else:
		if car.speed_kmh < 12.0:
			_set_mode(true)


# ====================================================================== HUD

func _build_hud() -> void:
	hud = CanvasLayer.new()
	hud.layer = 5
	add_child(hud)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.layout_direction = Control.LAYOUT_DIRECTION_LTR
	hud.add_child(root)
	speed_lbl = Label.new()
	speed_lbl.add_theme_font_size_override("font_size", 34)
	speed_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	speed_lbl.add_theme_constant_override("outline_size", 6)
	speed_lbl.position = Vector2(0, 0)
	root.add_child(speed_lbl)
	speed_lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	speed_lbl.position += Vector2(-60, -150)
	info_lbl = Label.new()
	info_lbl.add_theme_font_size_override("font_size", 16)
	info_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	info_lbl.add_theme_constant_override("outline_size", 4)
	info_lbl.position = Vector2(190, 12)
	root.add_child(info_lbl)
	hint_lbl = Label.new()
	hint_lbl.add_theme_font_size_override("font_size", 22)
	hint_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	hint_lbl.add_theme_constant_override("outline_size", 5)
	root.add_child(hint_lbl)
	hint_lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	hint_lbl.position += Vector2(-120, 70)
	minimap = MiniMap.new()
	minimap.ow = self
	minimap.position = Vector2(10, 10)
	minimap.size = Vector2(170, 170)
	root.add_child(minimap)
	# buttons (top right)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	root.add_child(col)
	col.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	col.position += Vector2(-150, 10)
	btn_exit = _btn(col, UI.tx("EXIT / ENTER (E)", "نزول / ركوب (E)"), func(): _try_toggle_car())
	_btn(col, UI.tx("CAMERA (V)", "الكاميرا (V)"), func(): _toggle_cam())
	_btn(col, UI.tx("RESET (R)", "إعادة (R)"), func(): _reset_car())
	_btn(col, UI.tx("MENU", "القائمة"), func(): get_tree().change_scene_to_file(MENU_SCENE))
	btn_jump = Button.new()
	btn_jump.text = UI.tx("JUMP", "قفز")
	btn_jump.custom_minimum_size = Vector2(110, 80)
	btn_jump.focus_mode = Control.FOCUS_NONE
	btn_jump.pressed.connect(func(): _jump())
	root.add_child(btn_jump)
	btn_jump.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	btn_jump.position += Vector2(-140, -120)
	var defs := [["left", "<", Vector2(0, 1), Vector2(30, -140)], ["right", ">", Vector2(0, 1), Vector2(180, -140)],
		["brake", "BRAKE", Vector2(1, 1), Vector2(-330, -140)], ["gas", "GAS", Vector2(1, 1), Vector2(-170, -140)]]
	for d in defs:
		var z := HoldZone.new(str(d[1]))
		z.size = Vector2(130, 110)
		root.add_child(z)
		z.anchor_left = (d[2] as Vector2).x
		z.anchor_right = (d[2] as Vector2).x
		z.anchor_top = (d[2] as Vector2).y
		z.anchor_bottom = (d[2] as Vector2).y
		z.offset_left = (d[3] as Vector2).x
		z.offset_top = (d[3] as Vector2).y
		z.offset_right = z.offset_left + 130.0
		z.offset_bottom = z.offset_top + 110.0
		drive_zones[str(d[0])] = z


func _btn(parent: Control, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(140, 44)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _refresh_buttons() -> void:
	if btn_jump == null:
		return
	btn_jump.visible = on_foot and show_touch
	for k in drive_zones:
		(drive_zones[k] as Control).visible = (not on_foot) and show_touch


func _toggle_cam() -> void:
	if on_foot:
		return
	chase = not chase
	if chase:
		chase_cam.current = true
	elif driver_av.cam != null:
		driver_av.cam.current = true


func _reset_car() -> void:
	var p := car.global_position
	var yaw := _heading(car)
	car.teleport(Transform3D(Basis(Vector3.UP, yaw), Vector3(p.x, 1.2, p.z)))
	car.linear_velocity = Vector3.ZERO
	car.angular_velocity = Vector3.ZERO


func _jump() -> void:
	if on_foot and walker.is_on_floor():
		_vy = 5.2


func _zone_down(n: String) -> bool:
	if not drive_zones.has(n) or not (drive_zones[n] as Control).visible:
		return false
	var r: Rect2 = (drive_zones[n] as Control).get_global_rect()
	for p in touches.values():
		if r.has_point(p):
			return true
	return false


# ====================================================================== input + frame loop

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			touches[event.index] = event.position
			if on_foot:
				var vw := get_viewport().get_visible_rect().size
				if event.position.x < vw.x * 0.4 and stick_id == -1:
					stick_id = event.index
					stick_origin = event.position
				elif event.position.x > vw.x * 0.45 and look_id == -1 and not _over_button(event.position):
					look_id = event.index
		else:
			touches.erase(event.index)
			if event.index == stick_id:
				stick_id = -1
				stick_vec = Vector2.ZERO
			if event.index == look_id:
				look_id = -1
	elif event is InputEventScreenDrag:
		touches[event.index] = event.position
		if event.index == stick_id:
			stick_vec = ((event.position - stick_origin) / 70.0).limit_length(1.0)
		elif event.index == look_id:
			walk_yaw -= event.relative.x * 0.006
			walk_pitch = clampf(walk_pitch - event.relative.y * 0.004, -0.9, 0.5)
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		if on_foot:
			walk_yaw -= event.relative.x * 0.004
			walk_pitch = clampf(walk_pitch - event.relative.y * 0.003, -0.9, 0.5)
		else:
			look_yaw = clampf(look_yaw - event.relative.x * 0.004, -1.3, 1.3)
			look_pitch = clampf(look_pitch - event.relative.y * 0.003, -0.5, 0.5)
	elif event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_E:
				_try_toggle_car()
			KEY_V:
				_toggle_cam()
			KEY_R:
				_reset_car()
			KEY_SPACE:
				_jump()
			KEY_ESCAPE:
				get_tree().change_scene_to_file(MENU_SCENE)


func _over_button(p: Vector2) -> bool:
	for b in [btn_exit, btn_jump]:
		if b != null and b.visible and (b as Control).get_global_rect().has_point(p):
			return true
	return false


func _physics_process(delta: float) -> void:
	if on_foot:
		_walk(delta)
	else:
		var steer := Input.get_axis("steer_left", "steer_right")
		var thr := Input.get_action_strength("accel")
		var brk := Input.get_action_strength("brake")
		if show_touch:
			if _zone_down("left"):
				steer -= 1.0
			if _zone_down("right"):
				steer += 1.0
			if _zone_down("gas"):
				thr = 1.0
			if _zone_down("brake"):
				brk = 1.0
		car.set_controls(clampf(steer, -1.0, 1.0), thr, brk)
		# flipped for a few seconds: put it back on its wheels
		if car.global_basis.y.y < 0.25:
			_flip_t += delta
			if _flip_t > 3.0:
				_flip_t = 0.0
				_reset_car()
		else:
			_flip_t = 0.0
	var lim := GRID * HALF_CELLS + 900.0                              # keep everyone inside the playable area
	for n in [car, walker]:
		var p: Vector3 = (n as Node3D).global_position
		if absf(p.x) > lim or absf(p.z) > lim or p.y < -20.0:
			if n == car:
				car.teleport(Transform3D(Basis(Vector3.UP, 0.0), Vector3(3.5, 1.0, 20.0)))
			else:
				walker.global_position = car.global_position + Vector3(2, 1, 2)
				_vy = 0.0


func _walk(delta: float) -> void:
	var mv := Vector2(Input.get_axis("steer_left", "steer_right"), Input.get_action_strength("brake") - Input.get_action_strength("accel"))
	mv += Vector2(stick_vec.x, stick_vec.y)
	mv = mv.limit_length(1.0)
	var run := Input.is_key_pressed(KEY_SHIFT) or stick_vec.length() > 0.85
	var spd := RUN_SPEED if run else WALK_SPEED
	var basis := Basis(Vector3.UP, walk_yaw)
	var dir := basis * Vector3(mv.x, 0.0, mv.y)
	_vy -= 14.0 * delta
	if walker.is_on_floor() and _vy < 0.0:
		_vy = -0.5
	walker.velocity = Vector3(dir.x * spd, _vy, dir.z * spd)
	walker.move_and_slide()
	_vy = walker.velocity.y
	if mv.length() > 0.1:
		var target := atan2(-dir.x, -dir.z)
		walk_av.global_rotation.y = lerp_angle(walk_av.global_rotation.y, target + PI, clampf(delta * 10.0, 0.0, 1.0))


func _process(delta: float) -> void:
	if on_foot:
		var head := walker.global_position + Vector3(0, 1.6, 0)
		var back := Basis(Vector3.UP, walk_yaw) * Basis(Vector3.RIGHT, walk_pitch) * Vector3(0, 0, 4.2)
		var want := head + back
		walk_cam.global_position = walk_cam.global_position.lerp(want, clampf(delta * 14.0, 0.0, 1.0)) if walk_cam.global_position.distance_to(want) < 12.0 else want
		walk_cam.look_at(head, Vector3.UP)
		if walker.global_position.distance_to(car.global_position) < 5.0:
			hint_lbl.text = UI.tx("Press E / EXIT to get in", "اضغط E أو زر النزول للركوب")
		else:
			hint_lbl.text = ""
	else:
		hint_lbl.text = UI.tx("Slow down to get out (E)", "خفّف السرعة للنزول (E)") if car.speed_kmh < 12.0 else ""
		if chase:
			var f := -car.global_basis.z
			f.y = 0.0
			f = f.normalized()
			var want := car.global_position - f * 7.0 + Vector3(0, 2.8, 0)
			chase_cam.global_position = chase_cam.global_position.lerp(want, clampf(delta * 6.0, 0.0, 1.0))
			chase_cam.look_at(car.global_position + Vector3(0, 1.1, 0) + f * 4.0, Vector3.UP)
		# cockpit look: drag with the right mouse button, springs back to centre
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
			look_yaw = move_toward(look_yaw, 0.0, delta * 2.5)
			look_pitch = move_toward(look_pitch, 0.0, delta * 2.5)
		driver_av.set_look(look_yaw, look_pitch)
	speed_lbl.text = ("%d km/h" % int(car.speed_kmh)) if not on_foot else ""
	var p := focus_pos()
	info_lbl.text = "X %d   Z %d" % [int(p.x), int(p.z)]
	for k in drive_zones:
		var z: HoldZone = drive_zones[k]
		var dn := _zone_down(k)
		if z.down != dn:
			z.down = dn
			z.queue_redraw()
