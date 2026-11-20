extends Node3D
## OPEN WORLD (solo): a big city with a ring highway, suburbs, forest and mountains. Drive freely, get out and walk, get back in.
## Controls: touch (steer / gas / brake buttons, left stick + jump on foot) or keyboard (WASD / arrows, E exit-enter, V camera, R reset, Space jump).

const GRID := 220.0
const HALF_CELLS := 5                 # roads at -5..5 * GRID  -> 2.4 km square
const ROAD_W := 14.0
const MENU_SCENE := "res://scenes/main.tscn"
const WALK_SPEED := 5.2
const RUN_SPEED := 8.5
const IGNITION := Vector3(-0.38, 1.12, -0.5)      # car-local: the key slot on the steering column
const DOOR_SPOT := Vector3(-2.0, 0.0, 0.25)       # car-local: where you stand to use the driver's door
# the key fob's back button does something different on every car: [kind, name EN, name AR, (colour)]
const SPECIAL := {
	"hatch": ["panic", "Panic alarm", "إنذار الذعر"],
	"sierra": ["hazard", "Hazard lights", "أضواء الطوارئ"],
	"buggy": ["lights", "Roof light bar", "أضواء السقف"],
	"pickup": ["glow", "Bed lights", "إضاءة الصندوق", Color(1.0, 0.7, 0.3)],
	"muscle": ["rev", "Engine rev", "تزمير المحرك"],
	"charger": ["rev", "Remote start", "تشغيل عن بعد"],
	"coupe": ["lights", "Welcome lights", "أضواء الترحيب"],
	"m4": ["lights", "Headlights", "المصابيح الأمامية"],
	"gt3": ["rev", "Throttle blip", "نفخة المحرك"],
	"hyper": ["glow", "Underglow", "إضاءة سفلية", Color(0.1, 0.9, 1.0)],
}

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
var seq := false
var door_amt := 0.0
var hand_k := 0.0
var hand_side := "L"
var _swing_t := 0.0
var hand_av: Avatar = null
var hand_mode := ""
var car_locked := false
var car_stolen := false
var key_out := false
var trunk_open := false
var lights_on := false
var glow_on := false
var thief: Avatar = null
var thief_state := ""
var thief_cd := 14.0
var thief_alerted := false
var _thief_t := 0.0
var ai_on := false
var ai_wp := Vector3.ZERO
var ai_t := 0.0
var ai_stuck := 0.0
var toast_lbl: Label
var toast_t := 0.0
var fob_panel: PanelContainer
var fob_front: Control
var fob_rear: Control
var fob_status: Label
var fob_back := false
var cine_cam: Camera3D
var cine_on := false
var cine_a := Vector3.ZERO
var cine_b := Vector3.ZERO
var cine_look := Vector3.ZERO
var cine_k := 0.0
var fade: ColorRect

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
		if ow.on_foot or ow.ai_on:                               # the car we left (red while somebody drives it away)
			var cp: Vector3 = rot * (ow.car.global_position - pos)
			var cv := Vector2(cp.x, cp.z) * sc
			var lim := size.x * 0.5 - 8.0
			if absf(cv.x) > lim or absf(cv.y) > lim:
				cv = cv * (lim / maxf(absf(cv.x), absf(cv.y)))
			draw_rect(Rect2(c + cv - Vector2(5, 5), Vector2(10, 10)), Color(1.0, 0.15, 0.15) if ow.ai_on else Color(1.0, 0.47, 0.1))
		draw_colored_polygon(PackedVector2Array([c + Vector2(0, -9), c + Vector2(7, 8), c + Vector2(0, 4), c + Vector2(-7, 8)]), Color(0.2, 0.9, 0.5))
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 1, 1, 0.25), false, 2.0)


class FobButton extends Button:
	var kind := ""

	func _init(k: String, cap: String) -> void:
		kind = k
		text = "\n\n" + cap
		add_theme_font_size_override("font_size", 14)
		custom_minimum_size = Vector2(96, 88)
		focus_mode = Control.FOCUS_NONE
		var n := StyleBoxFlat.new()
		n.bg_color = Color(0.17, 0.18, 0.22)
		n.set_corner_radius_all(18)
		n.border_color = Color(1, 1, 1, 0.2)
		n.set_border_width_all(2)
		var h := n.duplicate() as StyleBoxFlat
		h.bg_color = Color(0.32, 0.34, 0.4)
		for st in ["normal", "focus"]:
			add_theme_stylebox_override(st, n)
		for st in ["hover", "pressed"]:
			add_theme_stylebox_override(st, h)

	func _draw() -> void:
		var c := Vector2(size.x * 0.5, size.y * 0.34)
		var col := Color(0.96, 0.96, 0.98)
		match kind:
			"lock":
				draw_rect(Rect2(c + Vector2(-13, -1), Vector2(26, 19)), col)
				draw_arc(c + Vector2(0, -1), 8.0, PI, TAU, 14, col, 3.5)
				draw_line(c + Vector2(-8, -1), c + Vector2(-8, 3), col, 3.5)
				draw_line(c + Vector2(8, -1), c + Vector2(8, 3), col, 3.5)
			"unlock":
				draw_rect(Rect2(c + Vector2(-13, -1), Vector2(26, 19)), col)
				draw_arc(c + Vector2(6, -6), 8.0, PI, TAU, 14, col, 3.5)
				draw_line(c + Vector2(-2, -6), c + Vector2(-2, -1), col, 3.5)
			"trunk":
				draw_rect(Rect2(c + Vector2(-19, 1), Vector2(38, 15)), col)
				draw_line(c + Vector2(-15, 1), c + Vector2(-11, -13), col, 3.5)
				draw_line(c + Vector2(-11, -13), c + Vector2(13, -13), col, 3.5)
				draw_line(c + Vector2(13, -13), c + Vector2(15, 1), col, 3.5)
			"special":
				draw_arc(c + Vector2(0, 5), 14.0, 0, TAU, 24, col, 3.5)
				draw_circle(c + Vector2(0, 5), 4.5, col)
			"flip":
				draw_arc(c + Vector2(0, 5), 11.0, 0.4, 4.6, 16, col, 3.5)
				draw_colored_polygon(PackedVector2Array([c + Vector2(9, -2), c + Vector2(17, 5), c + Vector2(5, 7)]), col)


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
	cine_cam = Camera3D.new()
	cine_cam.fov = 55.0
	cine_cam.far = Gfx.far_clip()
	add_child(cine_cam)
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
	walk_av.role = "preview"                                          # arms hang by the sides
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
	car.hold = foot and not ai_on
	if foot:
		walk_cam.current = true
	elif chase:
		chase_cam.current = true
	elif driver_av.cam != null:
		driver_av.cam.current = true
	else:
		chase_cam.current = true
	_refresh_buttons()


func _toast(text: String, sec := 3.0) -> void:
	toast_lbl.text = text
	toast_t = sec


func _try_toggle_car() -> void:
	if seq:
		return
	if on_foot:
		if walker.global_position.distance_to(car.global_position) > 5.0 or ai_on:
			return
		if car_locked:
			_rattle(walk_av)
			_toast(UI.tx("The car is locked - unlock it with the key", "السيارة مقفولة - افتحها بالمفتاح"))
			return
		_enter_seq()
	elif car.speed_kmh < 12.0:
		_exit_seq()


func _fade(to_a: float, dur: float) -> void:
	var tw := create_tween()
	tw.tween_property(fade, "color:a", to_a, dur)
	await tw.finished


func _wait(sec: float) -> void:
	await get_tree().create_timer(sec).timeout


## cinematic camera: glides from a to b (car-local points) while looking at `look` (car-local)
func _cine_start(a: Vector3, b: Vector3, look: Vector3, dur: float) -> void:
	cine_a = a
	cine_b = b
	cine_look = look
	cine_k = 0.0
	cine_on = true
	cine_cam.current = true
	_apply_cine()
	var tw := create_tween()
	tw.tween_property(self, "cine_k", 1.0, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _apply_cine() -> void:
	cine_cam.global_position = car.to_global(cine_a.lerp(cine_b, cine_k))
	cine_cam.look_at(car.to_global(cine_look), Vector3.UP)


func _tween_prop(obj: Object, prop: String, to: Variant, dur: float, ease_type := Tween.EASE_IN_OUT) -> void:
	var tw := create_tween()
	tw.tween_property(obj, prop, to, dur).set_trans(Tween.TRANS_SINE).set_ease(ease_type)
	await tw.finished


func _door_to(a: float, dur: float, ease_type := Tween.EASE_IN_OUT) -> void:
	var opening := a > door_amt
	if opening:
		Sfx.play3d("click", car, -2.0, 0.9)                              # the latch
	var tw := create_tween()
	tw.tween_method(func(v: float): car.set_door(v), door_amt, a, dur).set_trans(Tween.TRANS_SINE).set_ease(ease_type)
	door_amt = a
	await tw.finished
	if a < 0.05:
		Sfx.play3d("thud", car, -1.0, 1.25)                              # the door shuts
	elif opening:
		Sfx.play3d("gear_clunk", car, -8.0, 0.8)                         # the stop at full swing


## a hand goes to the door handle ("door") or to the ignition ("key"); "" lets it go
func _hand(av: Avatar, side: String, mode: String) -> void:
	hand_av = av
	hand_side = side
	hand_mode = mode


func _rattle(av: Avatar) -> void:                                      # somebody pulls at a locked handle
	var tw := create_tween()
	for i in 2:
		tw.tween_callback(func(): Sfx.play3d("click", car, -2.0, 0.7))
		tw.tween_method(func(v: float): car.set_door(v), 0.0, 0.05, 0.08)
		tw.tween_method(func(v: float): car.set_door(v), 0.05, 0.0, 0.1)
		tw.tween_interval(0.15)


## sitting in the car: stop -> turn the key off and pull it -> hand on the handle -> pull the door -> push it wide -> swing out of the seat -> stand up -> shut the door
func _exit_seq() -> void:
	seq = true
	car.set_controls(0.0, 0.0, 1.0)
	car.hold = true
	await _fade(1.0, 0.18)
	driver_av.visible = false
	walker.remove_child(walk_av)
	car.add_child(walk_av)
	walk_av.position = car.seat_origin("driver")
	walk_av.rotation = Vector3.ZERO
	walk_av.role = "driver"
	walk_av.standing = false
	walk_av.outside = false
	walker.visible = false
	walk_av.visible = true
	_cine_start(Vector3(-4.6, 1.9, -2.4), Vector3(-3.4, 1.55, -1.3), Vector3(-0.7, 1.0, 0.2), 6.4)
	await _fade(0.0, 0.25)
	await _wait(0.5)
	_hand(walk_av, "R", "key")                                         # right hand to the ignition
	await _wait(0.7)
	Sfx.play3d("click", car, -2.0, 0.8)
	car.engine_on = false                                              # turn the key: the engine dies
	await _wait(0.45)
	_hand(walk_av, "R", "")                                            # key out
	await _wait(0.4)
	key_out = true
	_hand(walk_av, "L", "door")                                        # left hand reaches for the handle
	await _wait(0.8)
	await _door_to(0.4, 0.6)                                           # pull the latch: the door cracks open
	await _door_to(1.0, 0.7)                                           # push it wide
	_hand(walk_av, "L", "")
	await _wait(0.25)
	walk_av.standing = true                                            # push up out of the seat: the legs straighten
	var tw := create_tween().set_parallel(true)
	tw.tween_property(walk_av, "position:x", -1.85, 1.0).set_delay(0.3).set_trans(Tween.TRANS_SINE)
	tw.tween_property(walk_av, "position:y", walk_av.position.y + 0.18, 0.45).set_delay(0.3).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(walk_av, "position:y", 0.95, 0.5).set_delay(0.8)
	tw.tween_property(walk_av, "rotation:y", PI * 0.5, 0.9).set_delay(0.3)
	await _wait(1.5)
	# now he stands next to the car: hand him over to the free-walking character
	var gp := walk_av.global_position
	var gy := walk_av.global_rotation.y
	car.remove_child(walk_av)
	walker.add_child(walk_av)
	walker.global_position = Vector3(gp.x, 0.05, gp.z)
	walker.velocity = Vector3.ZERO
	walk_av.position = Vector3(0, 0.95, 0)
	walk_av.global_rotation = Vector3(0, gy, 0)
	walk_av.standing = true
	walker.visible = true
	await _wait(0.3)
	await _tween_prop(walk_av, "rotation:y", -PI * 0.5, 0.45)           # turn round to face the door
	_hand(walk_av, "R", "door")                                        # right hand on the door
	await _wait(0.35)
	await _door_to(0.0, 0.6, Tween.EASE_IN)                            # push it shut
	_hand(walk_av, "R", "")
	await _wait(0.4)
	walk_av.role = "preview"
	walk_yaw = _heading(car)
	walk_pitch = -0.15
	walk_cam.global_position = walker.global_position + Vector3(0, 2.6, 4.2)
	_set_mode(true)
	cine_on = false
	seq = false
	thief_cd = 14.0 if not car_locked else 26.0
	_toast(UI.tx("Key in your pocket. Lock the car with the key fob below.", "المفتاح معك. اقفل السيارة بالمفتاح بالأسفل."), 4.5)


## `av` stands outside the driver's door facing the car: opens the door, climbs in, turns the key, shuts the door.
func _board(av: Avatar) -> void:
	av.role = "driver"
	_hand(av, "R", "door")
	await _wait(0.55)
	await _door_to(0.4, 0.5)
	await _door_to(1.0, 0.6)
	_hand(av, "R", "")
	await _wait(0.2)
	var seat := car.seat_origin("driver")
	var gp := av.global_position
	av.get_parent().remove_child(av)
	car.add_child(av)
	av.global_position = gp
	av.position = Vector3(-1.85, seat.y, seat.z)
	av.rotation = Vector3(0, -PI * 0.5, 0)
	av.standing = false                                                # sit down: the legs fold
	var tw := create_tween().set_parallel(true)
	tw.tween_property(av, "position:x", seat.x, 1.0).set_delay(0.2).set_trans(Tween.TRANS_SINE)
	tw.tween_property(av, "position:y", seat.y + 0.12, 0.5).set_delay(0.2).set_ease(Tween.EASE_OUT)
	tw.tween_property(av, "position:y", seat.y, 0.6).set_delay(0.7)
	tw.tween_property(av, "rotation:y", 0.0, 0.8).set_delay(0.3)
	await _wait(1.5)
	_hand(av, "R", "key")                                              # key into the ignition
	await _wait(0.55)
	car.engine_on = true
	Sfx.play3d("click", car, -2.0, 0.8)
	car.throttle_in = 0.9                                              # the engine fires and revs
	await _wait(0.35)
	car.throttle_in = 0.0
	_hand(av, "R", "")
	await _wait(0.2)
	_hand(av, "L", "door")                                             # pull the door shut
	await _door_to(0.0, 0.6, Tween.EASE_IN)
	_hand(av, "L", "")
	await _wait(0.25)


func _enter_seq() -> void:
	seq = true
	walker.velocity = Vector3.ZERO
	await _fade(1.0, 0.18)
	var spot := car.to_global(DOOR_SPOT)
	walker.global_position = Vector3(spot.x, 0.05, spot.z)
	walk_av.global_rotation = Vector3(0, _heading(car) - PI * 0.5, 0)       # faces the car (towards +x of the car)
	_cine_start(Vector3(-5.2, 1.8, -1.6), Vector3(-4.0, 1.5, -0.6), Vector3(-0.9, 1.0, 0.3), 7.0)
	await _fade(0.0, 0.25)
	await _wait(0.3)
	await _board(walk_av)
	await _fade(1.0, 0.2)
	car.remove_child(walk_av)
	walker.add_child(walk_av)
	walk_av.visible = false
	walk_av.position = Vector3(0, 0.95, 0)
	driver_av.visible = true
	key_out = false
	car.hold = false
	cine_on = false
	_set_mode(false)
	await _fade(0.0, 0.25)
	seq = false


# ====================================================================== key fob, lock, thief

func _special() -> Array:
	return SPECIAL.get(car.model, SPECIAL["hatch"])


func _in_range() -> bool:
	if not on_foot:
		return false
	if walker.global_position.distance_to(car.global_position) > 45.0:
		_toast(UI.tx("Out of key range", "خارج نطاق المفتاح"))
		return false
	return true


func _fob_lock() -> void:
	if not _in_range():
		return
	car_locked = true
	car.flash(2)
	Sfx.play3d("beep", car, -2.0, 1.6)
	await _wait(0.3)
	Sfx.play3d("beep", car, -2.0, 1.6)
	_update_fob()


func _fob_unlock() -> void:
	if not _in_range():
		return
	car_locked = false
	car.flash(1)
	Sfx.play3d("click", car, 0.0, 1.0)
	Sfx.play3d("beep", car, -4.0, 1.1)
	_update_fob()


func _fob_trunk() -> void:
	if not _in_range():
		return
	trunk_open = not trunk_open
	car.set_trunk(trunk_open)
	Sfx.play3d("click", car, 0.0, 0.8)
	await _wait(0.45)
	Sfx.play3d("thud", car, -4.0, 0.9)


func _fob_special() -> void:
	if not _in_range() or ai_on:
		return
	var sp := _special()
	match str(sp[0]):
		"panic":
			car.hazard = true
			for i in 6:
				Sfx.play3d("horn_short", car, 2.0)
				await _wait(0.55)
			car.hazard = false
		"hazard":
			car.hazard = not car.hazard
			Sfx.play3d("beep", car, -4.0, 1.2)
		"lights":
			lights_on = not lights_on
			car.set_headlights(lights_on)
			Sfx.play3d("click", car, -2.0, 1.2)
		"glow":
			glow_on = not glow_on
			car.set_underglow(glow_on, sp[3] as Color)
			Sfx.play3d("click", car, -2.0, 1.2)
		"rev":
			car.engine_on = true
			for i in 3:
				car.throttle_in = 1.0
				await _wait(0.4)
				car.throttle_in = 0.0
				await _wait(0.25)
			if on_foot:
				car.engine_on = false


func _update_fob() -> void:
	if fob_status == null:
		return
	fob_status.text = UI.tx("LOCKED", "مقفولة") if car_locked else UI.tx("UNLOCKED", "مفتوحة")
	fob_status.add_theme_color_override("font_color", Color(1.0, 0.45, 0.35) if car_locked else Color(0.45, 1.0, 0.55))


func _flip_fob() -> void:
	fob_back = not fob_back
	fob_front.visible = not fob_back
	fob_rear.visible = fob_back
	Sfx.play("click", -10.0, 1.3)


# --- the thief: walks up to an unattended car, tries the door (alarm if locked), or gets in and drives it away
func _thief_spawn() -> void:
	var left := -car.global_basis.x
	var space := get_world_3d().direct_space_state
	var picks: Array = []
	for k in 9:
		var a := deg_to_rad(-60.0 + 15.0 * k)
		var d := (Basis(Vector3.UP, a) * left).normalized()
		var p := car.global_position + d * 42.0
		var q := PhysicsRayQueryParameters3D.create(car.global_position + Vector3(0, 1.2, 0), p + Vector3(0, 1.2, 0))
		q.collision_mask = 1
		if space.intersect_ray(q).is_empty() and absf(p.x) < GRID * HALF_CELLS and absf(p.z) < GRID * HALF_CELLS:
			picks.append(p)
	if picks.is_empty():
		thief_cd = 6.0
		return
	var pos: Vector3 = picks[rng.randi() % picks.size()]
	thief = Avatar.new()
	thief.name = "Thief"
	thief.peer_id = 3
	thief.role = "preview"
	thief.helmet_color = Color(0.05, 0.05, 0.06)
	thief.shirt_color = Color(0.12, 0.35, 0.2)
	thief.is_local = false
	thief.standing = true
	add_child(thief)
	thief.global_position = Vector3(pos.x, 0.95, pos.z)
	thief_state = "walk"
	thief_alerted = false


func _thief_step(delta: float) -> void:
	if thief == null or thief_state != "walk":
		return
	var spot := car.to_global(DOOR_SPOT)
	var to := Vector3(spot.x - thief.global_position.x, 0.0, spot.z - thief.global_position.z)
	var dist := to.length()
	if dist < 0.3:
		thief_state = "act"
		_thief_act()
		return
	var dir := to / dist
	thief.global_position += dir * minf(dist, 3.1 * delta)
	thief.global_rotation.y = lerp_angle(thief.global_rotation.y, atan2(-dir.x, -dir.z), clampf(delta * 9.0, 0.0, 1.0))
	_thief_t += delta * 9.0
	thief.walk_swing = sin(_thief_t) * 0.5


func _thief_act() -> void:
	thief.walk_swing = 0.0
	thief.global_rotation = Vector3(0, _heading(car) - PI * 0.5, 0)
	await _wait(0.4)
	if car_locked:
		# locked: he pulls at the handle, the alarm goes off, he runs
		_rattle(thief)
		await _wait(0.5)
		car.hazard = true
		for i in 5:
			Sfx.play3d("horn_short", car, 2.0)
			await _wait(0.45)
		car.hazard = false
		thief_state = "flee"
		for i in 40:
			var away := (thief.global_position - car.global_position)
			away.y = 0.0
			thief.global_position += away.normalized() * 5.5 * 0.06
			thief.walk_swing = sin(i * 0.9) * 0.7
			await _wait(0.06)
		thief.queue_free()
		thief = null
		thief_cd = 22.0
		return
	_toast(UI.tx("Someone is stealing your car!", "أحد يسرق سيارتك!"), 4.0)
	Sfx.play("warn", -4.0)
	await _board(thief)
	car.hold = false
	car_stolen = true
	ai_on = true
	ai_t = 0.0
	ai_wp = Vector3.ZERO
	car.engine_on = true
	_set_mode(on_foot)


func _ai_next_wp() -> void:
	var f := -car.global_basis.z
	f.y = 0.0
	f = f.normalized()
	var p := car.global_position
	if ai_wp == Vector3.ZERO:
		# first waypoint: the next junction ahead along the road we are on
		if absf(f.x) > absf(f.z):
			var sx := signf(f.x)
			var nx := (floorf(p.x / GRID) + 1.0) * GRID if sx > 0.0 else (ceilf(p.x / GRID) - 1.0) * GRID
			ai_wp = Vector3(nx, 0.0, roundf(p.z / GRID) * GRID)
		else:
			var sz := signf(f.z)
			var nz := (floorf(p.z / GRID) + 1.0) * GRID if sz > 0.0 else (ceilf(p.z / GRID) - 1.0) * GRID
			ai_wp = Vector3(roundf(p.x / GRID) * GRID, 0.0, nz)
		return
	# at a junction: mostly straight on, sometimes turn
	var cur := ai_wp
	var dirs: Array[Vector3] = [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]
	var heading := Vector3(roundf(f.x), 0.0, roundf(f.z)) if absf(f.x) > absf(f.z) else Vector3(0.0, 0.0, roundf(f.z))
	if absf(f.x) > absf(f.z):
		heading = Vector3(signf(f.x), 0, 0)
	else:
		heading = Vector3(0, 0, signf(f.z))
	var best: Vector3 = cur + heading * GRID
	var r := rng.randf()
	if r > 0.55:
		var side := Vector3(-heading.z, 0, heading.x) * (1.0 if r > 0.78 else -1.0)
		best = cur + side * GRID
	var lim := GRID * HALF_CELLS
	if absf(best.x) > lim or absf(best.z) > lim:
		best = cur - heading * GRID
		var side2 := Vector3(-heading.z, 0, heading.x)
		best = cur + side2 * GRID
		if absf(best.x) > lim or absf(best.z) > lim:
			best = cur - side2 * GRID
	ai_wp = best


func _ai_drive(delta: float) -> void:
	ai_t += delta
	if ai_wp == Vector3.ZERO:
		_ai_next_wp()
	var p := car.global_position
	var d2 := Vector2(ai_wp.x - p.x, ai_wp.z - p.z).length()
	if d2 < 16.0:
		_ai_next_wp()
		d2 = Vector2(ai_wp.x - p.x, ai_wp.z - p.z).length()
	var loc := car.to_local(Vector3(ai_wp.x, p.y, ai_wp.z))
	var ang := atan2(loc.x, -loc.z)
	var steer := clampf(ang * 1.8, -1.0, 1.0)
	var target_kmh := 48.0 if (absf(ang) < 0.35 and d2 > 35.0) else 22.0
	var thr := 0.8 if car.speed_kmh < target_kmh else 0.0
	var brk := 0.35 if car.speed_kmh > target_kmh + 12.0 else 0.0
	car.set_controls(steer, thr, brk)
	if car.speed_kmh < 4.0 and ai_t > 3.0:
		ai_stuck += delta
		if ai_stuck > 3.0:
			ai_stuck = 0.0
			var q := Vector3(roundf(p.x / GRID) * GRID, 1.0, roundf(p.z / GRID) * GRID)
			car.teleport(Transform3D(Basis(Vector3.UP, _heading(car)), q))
			ai_wp = Vector3.ZERO
	else:
		ai_stuck = 0.0
	if ai_t > 75.0 and car.speed_kmh < 30.0:
		_ai_park()


func _ai_park() -> void:
	ai_on = false
	car.set_controls(0.0, 0.0, 1.0)
	car.hold = true
	car.engine_on = false
	car_locked = false
	_update_fob()
	# the thief steps out and walks off
	if thief != null:
		var av := thief
		var gp := av.global_position
		car.remove_child(av)
		add_child(av)
		av.global_position = Vector3(car.to_global(DOOR_SPOT).x, 0.95, car.to_global(DOOR_SPOT).z)
		av.standing = true
		av.role = "preview"
		thief = null
		thief_state = ""
		for i in 50:
			var away := av.global_position - car.global_position
			away.y = 0.0
			av.global_position += away.normalized() * 4.0 * 0.06
			av.global_rotation.y = atan2(-away.x, -away.z)
			av.walk_swing = sin(i * 0.8) * 0.6
			await _wait(0.06)
		av.queue_free()
	car_stolen = false
	_toast(UI.tx("Your car was abandoned - check the minimap", "تم ترك سيارتك - شوف الخريطة"), 5.0)


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
	fade = ColorRect.new()
	fade.color = Color(0, 0, 0, 0)
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(fade)
	fade.z_index = 100
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
	toast_lbl = Label.new()
	toast_lbl.add_theme_font_size_override("font_size", 24)
	toast_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	toast_lbl.add_theme_constant_override("outline_size", 6)
	toast_lbl.add_theme_color_override("font_color", Color(1.0, 0.93, 0.55))
	root.add_child(toast_lbl)
	toast_lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	toast_lbl.position += Vector2(-200, 120)
	toast_lbl.visible = false
	_build_fob(root)
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


func _build_fob(root: Control) -> void:
	fob_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.07, 0.09, 0.93)
	sb.set_corner_radius_all(30)
	sb.border_color = Color(1.0, 0.47, 0.1)
	sb.set_border_width_all(3)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 10
	fob_panel.add_theme_stylebox_override("panel", sb)
	root.add_child(fob_panel)
	fob_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	fob_panel.position += Vector2(-250, -128)
	fob_panel.visible = false
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	fob_panel.add_child(vb)
	fob_status = Label.new()
	fob_status.add_theme_font_size_override("font_size", 15)
	fob_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(fob_status)
	fob_front = HBoxContainer.new()
	fob_front.add_theme_constant_override("separation", 8)
	vb.add_child(fob_front)
	var b1 := FobButton.new("unlock", UI.tx("UNLOCK (1)", "فتح (1)"))
	b1.pressed.connect(func(): _fob_unlock())
	fob_front.add_child(b1)
	var b2 := FobButton.new("lock", UI.tx("LOCK (2)", "قفل (2)"))
	b2.pressed.connect(func(): _fob_lock())
	fob_front.add_child(b2)
	var b3 := FobButton.new("trunk", UI.tx("TRUNK (3)", "الشنطة (3)"))
	b3.pressed.connect(func(): _fob_trunk())
	fob_front.add_child(b3)
	var bf := FobButton.new("flip", UI.tx("BACK", "الخلف"))
	bf.custom_minimum_size = Vector2(70, 88)
	bf.pressed.connect(func(): _flip_fob())
	fob_front.add_child(bf)
	fob_rear = HBoxContainer.new()
	fob_rear.add_theme_constant_override("separation", 8)
	fob_rear.visible = false
	vb.add_child(fob_rear)
	var sp := _special()
	var b4 := FobButton.new("special", str(UI.tx(str(sp[1]), str(sp[2]))) + " (4)")
	b4.custom_minimum_size = Vector2(300, 88)
	b4.pressed.connect(func(): _fob_special())
	fob_rear.add_child(b4)
	var bf2 := FobButton.new("flip", UI.tx("FRONT", "الأمام"))
	bf2.custom_minimum_size = Vector2(70, 88)
	bf2.pressed.connect(func(): _flip_fob())
	fob_rear.add_child(bf2)
	_update_fob()


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
			KEY_1:
				if on_foot and not seq:
					_fob_unlock()
			KEY_2:
				if on_foot and not seq:
					_fob_lock()
			KEY_3:
				if on_foot and not seq:
					_fob_trunk()
			KEY_4:
				if on_foot and not seq:
					_fob_special()
			KEY_ESCAPE:
				get_tree().change_scene_to_file(MENU_SCENE)


func _over_button(p: Vector2) -> bool:
	for b in [btn_exit, btn_jump]:
		if b != null and b.visible and (b as Control).get_global_rect().has_point(p):
			return true
	return false


func _physics_process(delta: float) -> void:
	if seq:
		car.set_controls(0.0, 0.0, 1.0)
		return
	if on_foot:
		_walk(delta)
	if ai_on:
		_ai_drive(delta)
	elif not on_foot:
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
	var moving := mv.length() > 0.1
	if moving:
		var target := atan2(-dir.x, -dir.z)
		walk_av.global_rotation.y = lerp_angle(walk_av.global_rotation.y, target, clampf(delta * 10.0, 0.0, 1.0))
	_swing_t += delta * (13.0 if run else 9.0)
	walk_av.walk_swing = sin(_swing_t) * (0.75 if run else 0.5) if (moving and walker.is_on_floor()) else 0.0


func _process(delta: float) -> void:
	if cine_on:
		_apply_cine()
	if hand_av != null and is_instance_valid(hand_av):
		var want_k := 1.0 if hand_mode != "" else 0.0
		hand_k = move_toward(hand_k, want_k, delta * 3.0)
		var tp := car.door_handle.global_position if hand_mode == "door" else car.to_global(IGNITION)
		hand_av._aux[hand_side] = hand_av.to_local(tp)
		hand_av._aux_k[hand_side] = hand_k
		if hand_mode == "" and hand_k <= 0.001:
			hand_av._aux_k[hand_side] = 0.0
			hand_av = null
	if toast_t > 0.0:
		toast_t -= delta
	toast_lbl.visible = toast_t > 0.0
	fob_panel.visible = on_foot and not seq and key_out
	_thief_step(delta)
	if on_foot and not seq and not ai_on and thief == null and key_out and walker.global_position.distance_to(car.global_position) > 8.0:
		thief_cd -= delta
		if thief_cd <= 0.0:
			_thief_spawn()
	if seq:
		speed_lbl.text = ""
		return
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
