class_name Car
extends VehicleBody3D
## Blocky rally car, one per team. Physics only runs on the server;
## clients get a frozen copy that follows the network state.

const ENGINE := 1150.0
const BRAKE_FORCE := 40.0
const TOP_SPEED_KMH := 165.0

const DARK := Color(0.12, 0.12, 0.16)
const NAVY := Color(0.1, 0.12, 0.25)

var team := 0
var plate_labels: Array = []
var body_color := Color(0.78, 0.08, 0.08)
var speed_kmh := 0.0
var steer_target := 0.0
var steer_visual := 0.0
var is_remote := false
var hold := false      # handbrake (before the start / after the finish)
var driver_avatar: Avatar

# --- damage / fire (synced from the server)
var damage := 0.0          # 0..100 : >=40 smoke, >=80 fire
var fire := 0.0            # flames on top of the engine 0..1
var inner := 0.0           # flames under the engine cover 0..1
var latched := false       # hood popped by the release lever
var hood_up := false
var cover_up := false
var spraying := false
var power := 1.0
var throttle_in := 0.0
var impact_acc := 0.0

var team_color := Color(0.78, 0.08, 0.08)
var lo := {}                 # loadout: car model, paint, stripe, rim, glow, upgrades
var model := "hatch"
var drop := 0.0     # how much lower the roof sits than the standard cabin (sleek cars)
var sd := 0.0       # matching seat drop
var preview := false         # garage preview: no sound, no physics
var power_mult := 1.0
var top_speed := TOP_SPEED_KMH
var grip_base := 1.0
var armor := 1.0             # damage taken multiplier (lower = tougher)
var overheat_kmh := 145.0
var burn_time := 45.0
var ext_mult := 1.0
var body_mat: StandardMaterial3D
var _holders: Array[Node3D] = []
var _spin := 0.0
var charred := false

var wheel_list: Array[VehicleWheel3D] = []
var _grip := 1.0
var _hood_pivot: Node3D
var _cover_pivot: Node3D
var _lever_pivot: Node3D
var _smoke: CPUParticles3D
var _fire_top: CPUParticles3D
var _fire_in: CPUParticles3D
var _foam: CPUParticles3D
var _fire_light: OmniLight3D
var _snd := {}
var _rpm := 0.2
var brake_in := 0.0
var _hood_ang := 0.0
var _cover_ang := 0.0
var _lever_ang := 0.0
var _prev_vel := Vector3.ZERO
var _last_pos := Vector3.ZERO
var _vel_est := Vector3.ZERO
var _wheel_pivot: Node3D
var _wheel_mesh: Node3D
var _mirror_nodes := {}          # "rear" / "left" / "right" -> Node3D (housing, glass child "glass")
var _mirror_vps: Array[SubViewport] = []
var _mirror_t := 0.0


func setup(p_team: int, color: Color, remote: bool, p_lo := {}, p_preview := false) -> void:
	team = p_team
	team_color = color
	body_color = color
	is_remote = remote or p_preview
	preview = p_preview
	lo = p_lo
	model = str(lo.get("car", "hatch"))
	if not Catalog.CARS.has(model):
		model = "hatch"
	var m: Dictionary = Catalog.CARS[model]
	drop = float(m.get("drop", 0.0))
	sd = drop * 0.85
	var up: Dictionary = lo.get("up", {})
	var eng := int(up.get("engine", 0))
	var fm := Catalog.fit_mods(up)
	power_mult = float(m["power"]) * (1.0 + 0.06 * eng) * float(fm["power"])
	top_speed = float(m["top"]) * (1.0 + 0.03 * eng) * float(fm["top"])
	grip_base = float(m["grip"]) * (1.0 + 0.05 * int(up.get("tires", 0))) * float(fm["grip"])
	armor = float(m["armor"]) * (1.0 - 0.08 * int(up.get("armor", 0))) * float(fm["armor"])
	overheat_kmh = float(m["top"]) * 0.88 + 6.0 * int(up.get("cooling", 0))
	burn_time = 45.0 + 5.0 * int(up.get("cooling", 0))
	ext_mult = 1.0 + 0.15 * int(up.get("extinguisher", 0))
	if lo.has("paint") and Catalog.PAINTS.has(lo["paint"]):
		body_color = Catalog.PAINTS[lo["paint"]]["c"]


func seat_origin(role: String) -> Vector3:
	return Vector3(-0.45, 1.0 - sd, 0.3) if role == "driver" else Vector3(0.45, 1.0 - sd, 0.3)


func _ready() -> void:
	mass = 450.0
	linear_damp = 0.12
	angular_damp = 1.5
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3(0, 0.15, 0)
	if is_remote:
		freeze = true
		freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.9, 0.8, 3.9)
	shape.shape = box
	shape.position = Vector3(0, 0.75, 0)
	add_child(shape)
	_add_wheels()
	_build_visuals()
	_build_fx()
	if not preview:
		_build_audio()


func rim_color() -> Color:
	var r: Dictionary = Catalog.RIMS.get(lo.get("rim", "steel"), Catalog.RIMS["steel"])
	return r["c"]


func _add_wheels() -> void:
	for x in [-0.95, 0.95]:
		for z in [-1.3, 1.3]:
			if is_remote:
				# clients only display the car: plain meshes, no vehicle physics (avoids NaNs on a frozen body)
				var holder := Node3D.new()
				holder.position = Vector3(x, 0.45, z)
				holder.set_meta("front", z < 0.0)
				add_child(holder)
				CarStyle.make_wheel(holder, rim_color(), model)
				_holders.append(holder)
				continue
			var w := VehicleWheel3D.new()
			w.position = Vector3(x, 0.45, z)
			w.wheel_radius = 0.4
			w.wheel_rest_length = 0.2
			w.suspension_travel = 0.3
			w.suspension_stiffness = 38.0
			w.suspension_max_force = 7000.0
			w.damping_compression = 1.0
			w.damping_relaxation = 1.3
			w.wheel_friction_slip = 3.2 * grip_base
			w.wheel_roll_influence = 0.25
			w.use_as_traction = true
			w.use_as_steering = z < 0.0
			add_child(w)
			CarStyle.make_wheel(w, rim_color(), model)


# ------------------------------------------------------------------ controls

func set_controls(steer: float, throttle: float, brk: float) -> void:
	var fs := -global_transform.basis.z.dot(linear_velocity)
	speed_kmh = absf(fs) * 3.6
	var lim := lerpf(0.42, 0.08, clampf(speed_kmh / 120.0, 0.0, 1.0))
	steer_target = steer
	throttle_in = throttle
	brake_in = brk
	if hold:
		engine_force = 0.0
		brake = BRAKE_FORCE
		steering = move_toward(steering, 0.0, get_physics_process_delta_time() * 3.5)
		return
	steering = move_toward(steering, -steer * lim, get_physics_process_delta_time() * 2.2)
	if brk > 0.0 and fs < 0.5:
		engine_force = brk * 600.0
		brake = 0.0
	else:
		engine_force = -throttle * ENGINE * power * power_mult if speed_kmh < top_speed * (1.0 if power >= 1.0 else 0.8) else 0.0
		brake = brk * BRAKE_FORCE


## 1 = normal, ~0.25 = ice
func set_grip(f: float) -> void:
	if absf(f - _grip) < 0.01:
		return
	_grip = f
	for w in wheel_list:
		w.wheel_friction_slip = 3.2 * f * grip_base


## dark-mode lights: headlights + a dim cabin light so the blind driver can see the co-driver
func add_lights() -> void:
	for x in [-0.6, 0.6]:
		var sp := SpotLight3D.new()
		sp.position = Vector3(x, 0.9, -2.0)
		sp.spot_range = 55.0
		sp.spot_angle = 32.0
		sp.light_energy = 1.6
		sp.light_color = Color(1.0, 0.95, 0.8)
		add_child(sp)
	var cab := OmniLight3D.new()
	cab.position = Vector3(0, 1.7 - drop, 0.2)
	cab.omni_range = 3.2
	cab.light_energy = 0.7
	cab.light_color = Color(1.0, 0.85, 0.6)
	add_child(cab)


func teleport(t: Transform3D) -> void:
	var rid := get_rid()
	PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_TRANSFORM, t)
	PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, Vector3.ZERO)
	PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY, Vector3.ZERO)
	steering = 0.0
	_prev_vel = Vector3.ZERO
	impact_acc = 0.0


# ------------------------------------------------------------------ visuals

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 1.0
	return m


func _box(parent: Node, size: Vector3, pos: Vector3, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = body_mat if (body_mat != null and c == body_color) else _mat(c)
	mi.position = pos
	parent.add_child(mi)
	return mi


func _build_visuals() -> void:
	var c := body_color
	var pd: Dictionary = Catalog.PAINTS.get(lo.get("paint", ""), {})
	body_mat = StandardMaterial3D.new()
	body_mat.albedo_color = c
	body_mat.metallic = minf(0.55, float(pd.get("m", 0.0)))     # no reflections in the compatibility renderer: keep it light
	if float(pd.get("m", 0.0)) >= 0.9:
		body_mat.emission_enabled = true
		body_mat.emission = c
		body_mat.emission_energy_multiplier = 0.25
	body_mat.roughness = float(pd.get("ro", 0.9))
	if float(pd.get("m", 0.0)) > 0.0:
		body_mat.clearcoat_enabled = true
		body_mat.clearcoat = 0.6
	_box(self, Vector3(1.9, 0.5, 4.0), Vector3(0, 0.62, 0), c)                  # body
	_box(self, Vector3(1.8, 0.08, 3.8), Vector3(0, 0.88, 0.0), CarInterior.theme(model)["carpet"])            # floor
	_box(self, Vector3(0.1, 0.42, 2.0), Vector3(-0.95, 1.12, 0.35), c)          # doors
	_box(self, Vector3(0.1, 0.42, 2.0), Vector3(0.95, 1.12, 0.35), c)
	_box(self, Vector3(1.9, 0.42, 0.1), Vector3(0, 1.12, 1.35), c)              # rear wall
	_box(self, Vector3(1.9, 0.3, 0.9), Vector3(0, 1.0, -1.2), DARK.lightened(0.15))  # dashboard
	_build_mirrors()
	_build_radio_unit()
	_build_cluster()
	_build_engine_bay(c)
	CarStyle.decorate(self, model, lo, body_mat, team_color)
	_box(self, Vector3(1.9, 0.3, 0.2), Vector3(0, 0.5, -2.05), DARK)            # bumpers
	_box(self, Vector3(1.9, 0.3, 0.2), Vector3(0, 0.5, 2.05), DARK)
	CarInterior.build(self, model, sd, drop)                                   # dash, console, seats, door cards, liner

	# team letter on the roof and on the back
	for spec in [[Vector3(0, 2.0 - drop, (float(CarStyle.GREENHOUSE.get(model, CarStyle.GREENHOUSE["hatch"])["zf1"]) + float(CarStyle.GREENHOUSE.get(model, CarStyle.GREENHOUSE["hatch"])["zr1"])) * 0.5), Vector3(-90, 0, 0)], [Vector3(0, 1.3, 1.42), Vector3(0, 0, 0)]]:
		var lab := Label3D.new()
		plate_labels.append(lab)
		lab.text = char(65 + team)
		lab.font_size = 160
		lab.pixel_size = 0.006
		lab.modulate = Color.WHITE
		lab.outline_modulate = Color.BLACK
		lab.position = spec[0]
		lab.rotation_degrees = spec[1]
		add_child(lab)
	# back label must face backwards (+Z)
	var back := get_child(get_child_count() - 1) as Label3D
	back.rotation_degrees = Vector3(0, 0, 0)

	# steering wheel (driver side)
	_wheel_pivot = Node3D.new()
	_wheel_pivot.position = Vector3(-0.45, 1.3 - sd * 0.8, -0.42)
	_wheel_pivot.rotation.x = deg_to_rad(62.0)
	add_child(_wheel_pivot)
	_wheel_mesh = Node3D.new()
	_wheel_pivot.add_child(_wheel_mesh)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.12
	torus.outer_radius = 0.18
	torus.rings = 8
	torus.ring_segments = 6
	ring.mesh = torus
	ring.material_override = _mat(Color(0.03, 0.03, 0.04))
	_wheel_mesh.add_child(ring)
	_box(_wheel_mesh, Vector3(0.3, 0.04, 0.05), Vector3.ZERO, Color(0.03, 0.03, 0.04))
	_box(_wheel_mesh, Vector3(0.05, 0.04, 0.3), Vector3.ZERO, Color(0.03, 0.03, 0.04))
	CarInterior.wheel(_wheel_mesh, model)




# ------------------------------------------------------------------ engine bay, damage fx, audio

func _build_engine_bay(c: Color) -> void:
	var metal := Color(0.22, 0.23, 0.27)
	_box(self, Vector3(0.1, 0.45, 0.95), Vector3(-0.8, 0.97, -1.6), c)          # bay side walls
	_box(self, Vector3(0.1, 0.45, 0.95), Vector3(0.8, 0.97, -1.6), c)
	_box(self, Vector3(1.7, 0.4, 0.1), Vector3(0, 0.95, -2.0), c)               # front fascia
	_box(self, Vector3(1.5, 0.05, 0.9), Vector3(0, 0.75, -1.6), DARK)           # bay floor
	_box(self, Vector3(0.9, 0.42, 0.55), Vector3(0, 0.98, -1.7), metal)         # engine block
	for x in [-0.28, 0.0, 0.28]:                                                # cylinders / intake pipes
		_box(self, Vector3(0.12, 0.1, 0.45), Vector3(x, 1.22, -1.7), metal.lightened(0.15))
	_box(self, Vector3(0.28, 0.22, 0.2), Vector3(0.55, 0.92, -1.9), Color(0.05, 0.1, 0.35))   # battery
	_box(self, Vector3(1.2, 0.3, 0.06), Vector3(0, 0.88, -1.92), DARK.lightened(0.1))          # radiator
	# hood: hinged at the windshield side, front edge swings up
	_hood_pivot = Node3D.new()
	_hood_pivot.position = Vector3(0, 1.2, -1.15)
	add_child(_hood_pivot)
	_box(_hood_pivot, Vector3(1.78, 0.1, 0.98), Vector3(0, -0.04, -0.49), c)
	_box(_hood_pivot, Vector3(0.5, 0.04, 0.3), Vector3(0, 0.02, -0.5), c.darkened(0.35))   # hood scoop
	# engine cover (air box): small lid hinged at the rear edge, a second thing to open
	_cover_pivot = Node3D.new()
	_cover_pivot.position = Vector3(0, 1.3, -1.45)
	add_child(_cover_pivot)
	var cov := _box(_cover_pivot, Vector3(0.62, 0.05, 0.46), Vector3(0, 0, -0.23), Color(0.9, 0.55, 0.1))
	cov.name = "cover"
	# hood release lever inside the cabin (pulled by the player)
	_lever_pivot = Node3D.new()
	_lever_pivot.position = Vector3(-0.8, 0.95, -0.3)
	add_child(_lever_pivot)
	_box(_lever_pivot, Vector3(0.04, 0.04, 0.2), Vector3(0, 0, -0.1), Color(0.95, 0.8, 0.1))
	_box(_lever_pivot, Vector3(0.06, 0.06, 0.05), Vector3(0, 0, -0.2), Color(0.85, 0.1, 0.1))


func _quad_mat(additive: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES if false else BaseMaterial3D.BILLBOARD_ENABLED
	m.vertex_color_use_as_albedo = true
	m.albedo_color = Color.WHITE
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	return m


func _particles(pos: Vector3, amount: int, life: float, size: float, additive: bool, ramp: Gradient) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	p.position = pos
	p.amount = Gfx.particles(amount)
	p.lifetime = life
	p.emitting = false
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = _quad_mat(additive)
	p.mesh = q
	p.color_ramp = ramp
	p.local_coords = false
	add_child(p)
	return p


func _build_fx() -> void:
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(0.45, 0.45, 0.48, 0.0), Color(0.4, 0.4, 0.43, 0.75), Color(0.2, 0.2, 0.22, 0.0)])
	g.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
	_smoke = _particles(Vector3(0, 1.45, -1.6), 40, 2.6, 0.6, false, g)
	_smoke.direction = Vector3(0, 1, 0.5)
	_smoke.spread = 22.0
	_smoke.initial_velocity_min = 1.2
	_smoke.initial_velocity_max = 2.4
	_smoke.gravity = Vector3(0, 0.6, 0)
	_smoke.scale_amount_min = 0.7
	_smoke.scale_amount_max = 1.8
	var f := Gradient.new()
	f.colors = PackedColorArray([Color(1.0, 0.8, 0.25, 0.5), Color(1.0, 0.4, 0.08, 0.4), Color(0.7, 0.1, 0.05, 0.0)])
	f.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	_fire_top = _particles(Vector3(0, 1.4, -1.65), 45, 0.7, 0.28, true, f)
	_fire_top.direction = Vector3(0, 1, 0)
	_fire_top.spread = 18.0
	_fire_top.initial_velocity_min = 1.0
	_fire_top.initial_velocity_max = 2.4
	_fire_top.gravity = Vector3(0, 1.5, 0)
	_fire_top.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_fire_top.emission_sphere_radius = 0.3
	_fire_in = _particles(Vector3(0, 1.15, -1.7), 30, 0.6, 0.22, true, f)
	_fire_in.direction = Vector3(0, 1, 0)
	_fire_in.spread = 25.0
	_fire_in.initial_velocity_min = 0.8
	_fire_in.initial_velocity_max = 1.8
	_fire_in.gravity = Vector3(0, 1.2, 0)
	_fire_in.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	_fire_in.emission_sphere_radius = 0.2
	var w := Gradient.new()
	w.colors = PackedColorArray([Color(1, 1, 1, 0.7), Color(0.95, 0.97, 1.0, 0.45), Color(1, 1, 1, 0.0)])
	w.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	_foam = _particles(Vector3(-0.05, 1.2, -2.15), 60, 0.4, 0.12, false, w)
	_foam.direction = Vector3(0.05, -0.08, 1.0)
	_foam.spread = 8.0
	_foam.initial_velocity_min = 3.0
	_foam.initial_velocity_max = 4.5
	_foam.gravity = Vector3(0, -3.0, 0)
	_foam.scale_amount_min = 0.6
	_foam.scale_amount_max = 1.5
	_fire_light = OmniLight3D.new()
	_fire_light.position = Vector3(0, 1.5, -1.7)
	_fire_light.light_color = Color(1.0, 0.55, 0.15)
	_fire_light.omni_range = 7.0
	_fire_light.light_energy = 0.0
	add_child(_fire_light)


func _build_audio() -> void:
	_snd["engine"] = Sfx.loop3d("engine_loop", self, -8.0)
	_snd["intake"] = Sfx.loop3d("intake_loop", self, -40.0)
	_snd["road"] = Sfx.loop3d("road_loop", self, -40.0)
	_snd["skid"] = Sfx.loop3d("skid_loop", self, -40.0)
	_snd["fire"] = Sfx.loop3d("fire_loop", self, -40.0)
	_snd["hiss"] = Sfx.loop3d("smoke_hiss", self, -40.0)
	_snd["spray"] = Sfx.loop3d("spray_loop", self, -40.0)
	for k in _snd:
		(_snd[k] as AudioStreamPlayer3D).position = Vector3(0, 1.0, -1.4)
		(_snd[k] as AudioStreamPlayer3D).stream.resource_local_to_scene = false


const GEARS := [0.0, 36.0, 68.0, 100.0, 133.0, 170.0]


func _physics_process(delta: float) -> void:
	if is_remote:
		return
	var dv := (_prev_vel - linear_velocity).length()
	if dv > 3.5:
		impact_acc = maxf(impact_acc, dv)
	_prev_vel = linear_velocity


## server: returns and clears the strongest impact since the last call
func take_impact() -> float:
	var v := impact_acc
	impact_acc = 0.0
	return v


func apply_state(dmg: float, fr: float, inr: float, flags: int, thr: float) -> void:
	damage = dmg
	fire = fr
	inner = inr
	latched = (flags & 64) != 0
	hood_up = (flags & 4) != 0
	cover_up = (flags & 8) != 0
	spraying = (flags & 32) != 0
	throttle_in = thr
	power = 1.0 if damage < 40.0 else (0.75 if damage < 80.0 else 0.45)
	if charred and damage < 50.0 and fr < 0.03 and body_mat:
		charred = false
		body_mat.albedo_color = body_color


func _vol(db: float, on: bool) -> float:
	return db if on else -60.0


func _process(delta: float) -> void:
	if not _holders.is_empty():
		_spin -= (speed_kmh / 3.6) * delta / 0.4
		if preview:
			_spin -= delta * 1.5
		for h in _holders:
			h.rotation = Vector3(_spin, -steer_visual * 0.4 if h.get_meta("front") else 0.0, 0.0)
	if not is_remote:
		steer_visual = move_toward(steer_visual, steer_target, delta * 5.0)
	var phi := -steer_visual * 1.6
	if _wheel_mesh:
		_wheel_mesh.rotation.y = phi
	if driver_avatar and _wheel_pivot:
		var r := 0.15
		var left_hand := _wheel_pivot.transform * (Vector3(-cos(phi), 0.0, sin(phi)) * r)
		var right_hand := _wheel_pivot.transform * (Vector3(cos(phi), 0.0, -sin(phi)) * r)
		driver_avatar.set_wheel_hands(left_hand, right_hand)
	_update_motion_audio(delta)
	_update_damage_fx(delta)
	_tick_mirrors(delta)
	_update_gear(delta)
	_update_cluster(delta)


func _update_motion_audio(delta: float) -> void:
	if _snd.is_empty():
		return
	var pos := global_position
	if delta > 0.0:
		var v := (pos - _last_pos) / delta
		_vel_est = _vel_est.lerp(v, clampf(delta * 8.0, 0.0, 1.0))
	_last_pos = pos
	var spd := speed_kmh
	var g := 0
	for i in GEARS.size() - 1:
		if spd >= GEARS[i]:
			g = i
	var ratio := clampf((spd - GEARS[g]) / (GEARS[g + 1] - GEARS[g]), 0.0, 1.0)
	var target := lerpf(0.34, 0.95, ratio) if spd > 3.0 else 0.16 + throttle_in * 0.55
	target += (throttle_in - 0.4) * 0.12
	if damage >= 80.0:
		target += sin(Time.get_ticks_msec() * 0.03) * 0.04      # misfiring engine
	_rpm = lerpf(_rpm, clampf(target, 0.1, 1.0), clampf(delta * 5.5, 0.0, 1.0))
	var eng: AudioStreamPlayer3D = _snd["engine"]
	eng.pitch_scale = 0.55 + _rpm * 1.55
	eng.volume_db = -10.0 + throttle_in * 5.0 + _rpm * 3.0
	var inta: AudioStreamPlayer3D = _snd["intake"]
	inta.pitch_scale = 0.7 + _rpm * 0.9
	inta.volume_db = -38.0 + throttle_in * _rpm * 26.0
	var rd: AudioStreamPlayer3D = _snd["road"]
	rd.pitch_scale = 0.8 + spd / 160.0
	rd.volume_db = -42.0 + clampf(spd / 120.0, 0.0, 1.0) * 30.0
	var lat := absf(_vel_est.dot(global_basis.x))
	var sk: AudioStreamPlayer3D = _snd["skid"]
	sk.volume_db = -60.0 if lat < 3.0 else -26.0 + clampf((lat - 3.0) / 8.0, 0.0, 1.0) * 16.0
	sk.pitch_scale = 0.9 + clampf(spd / 200.0, 0.0, 0.4)


func _update_damage_fx(delta: float) -> void:
	# hood / cover / lever animation
	var hood_t := 62.0 if hood_up else (7.0 if latched else 0.0)
	_hood_ang = lerpf(_hood_ang, hood_t, clampf(delta * 5.0, 0.0, 1.0))
	_hood_pivot.rotation.x = deg_to_rad(_hood_ang)
	_cover_ang = lerpf(_cover_ang, 85.0 if cover_up else 0.0, clampf(delta * 6.0, 0.0, 1.0))
	_cover_pivot.rotation.x = deg_to_rad(_cover_ang)
	_lever_ang = lerpf(_lever_ang, -38.0 if latched else 0.0, clampf(delta * 8.0, 0.0, 1.0))
	_lever_pivot.rotation.x = deg_to_rad(_lever_ang)
	# smoke
	var smoking := damage >= 40.0
	_smoke.emitting = smoking
	if smoking:
		var heavy := clampf((damage - 40.0) / 60.0, 0.0, 1.0)
		var tone := lerpf(0.5, 0.12, maxf(heavy, minf(1.0, fire * 1.5)))
		var mat := (_smoke.mesh as QuadMesh).material as StandardMaterial3D
		mat.albedo_color = Color(tone, tone, tone * 1.05, 1.0)
		_smoke.scale_amount_min = 0.7 + heavy * 0.7
		_smoke.scale_amount_max = 1.6 + heavy * 1.4
		# smoke is blown backwards when driving
		var back := global_basis.z
		var drift := clampf(speed_kmh / 80.0, 0.0, 1.5)
		_smoke.gravity = Vector3(0, 0.6, 0) + back * drift * 2.5
	# fire
	_fire_top.emitting = fire > 0.03
	_fire_top.scale_amount_min = 0.3 + fire * 0.7
	_fire_top.scale_amount_max = 0.6 + fire * 1.6
	_fire_in.emitting = inner > 0.03
	_fire_in.scale_amount_min = 0.3 + inner * 0.6
	_fire_in.scale_amount_max = 0.5 + inner * 1.3
	var burning := maxf(fire, inner)
	_fire_light.light_energy = burning * (2.2 + sin(Time.get_ticks_msec() * 0.05) * 0.6) if burning > 0.03 else 0.0
	_foam.emitting = spraying
	if _snd.is_empty():
		return
	(_snd["fire"] as AudioStreamPlayer3D).volume_db = _vol(-14.0 + burning * 10.0, burning > 0.03)
	(_snd["hiss"] as AudioStreamPlayer3D).volume_db = _vol(-24.0, smoking and burning < 0.03)
	(_snd["spray"] as AudioStreamPlayer3D).volume_db = _vol(-8.0, spraying)


# ------------------------------------------------------------------ explosion (every peer plays this)

func _burst(pos: Vector3, amount: int, life: float, size: float, additive: bool, ramp: Gradient, vmin: float, vmax: float, grav: Vector3, smin := 1.0, smax := 2.0) -> void:
	var p := _particles(pos, amount, life, size, additive, ramp)
	p.one_shot = true
	p.explosiveness = 0.92
	p.direction = Vector3(0, 1, 0)
	p.spread = 180.0
	p.initial_velocity_min = vmin
	p.initial_velocity_max = vmax
	p.gravity = grav
	p.scale_amount_min = smin
	p.scale_amount_max = smax
	p.emitting = true
	get_tree().create_timer(life + 1.0).timeout.connect(p.queue_free)


func explode_fx() -> void:
	var fb := Gradient.new()
	fb.colors = PackedColorArray([Color(1.0, 0.95, 0.6, 0.9), Color(1.0, 0.5, 0.1, 0.7), Color(0.3, 0.08, 0.02, 0.0)])
	fb.offsets = PackedFloat32Array([0.0, 0.35, 1.0])
	var sm := Gradient.new()
	sm.colors = PackedColorArray([Color(0.2, 0.2, 0.22, 0.0), Color(0.12, 0.12, 0.14, 0.6), Color(0.05, 0.05, 0.06, 0.0)])
	sm.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	var sp := Gradient.new()
	sp.colors = PackedColorArray([Color(1.0, 0.9, 0.5, 1.0), Color(1.0, 0.4, 0.05, 0.0)])
	_burst(Vector3(0, 1.0, 0), 60, 1.0, 2.0, true, fb, 5.0, 13.0, Vector3(0, 1.0, 0), 0.7, 1.7)
	_burst(Vector3(0, 1.0, 0), 45, 4.5, 2.0, false, sm, 2.0, 6.0, Vector3(0, 2.0, 0), 0.8, 1.7)
	_burst(Vector3(0, 1.0, 0), 90, 1.6, 0.16, true, sp, 8.0, 20.0, Vector3(0, -10.0, 0), 0.6, 1.6)
	# a second fireball in the air
	get_tree().create_timer(0.5).timeout.connect(func():
		if is_instance_valid(self):
			_burst(Vector3(0, 1.0, 0), 30, 0.9, 1.8, true, fb, 3.0, 8.0, Vector3(0, 1.0, 0), 0.8, 1.6))
	# shock ring (world space)
	var world := get_parent()
	var ring := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 1.0
	sph.height = 2.0
	sph.radial_segments = 16
	sph.rings = 8
	ring.mesh = sph
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.albedo_color = Color(1.0, 0.8, 0.5, 0.45)
	rm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	rm.cull_mode = BaseMaterial3D.CULL_FRONT
	ring.material_override = rm
	world.add_child(ring)
	ring.global_position = global_position + Vector3(0, 1.0, 0)
	var tw := ring.create_tween().set_parallel(true)
	tw.tween_property(ring, "scale", Vector3(16, 16, 16), 0.55).from(Vector3(1, 1, 1))
	tw.tween_property(rm, "albedo_color:a", 0.0, 0.55)
	tw.chain().tween_callback(ring.queue_free)
	# flash light
	var fl := OmniLight3D.new()
	fl.light_color = Color(1.0, 0.7, 0.3)
	fl.omni_range = 30.0
	fl.light_energy = 9.0
	world.add_child(fl)
	fl.global_position = global_position + Vector3(0, 2.0, 0)
	var tl := fl.create_tween()
	tl.tween_property(fl, "light_energy", 0.0, 0.9)
	tl.tween_callback(fl.queue_free)
	# flying debris: hood, doors, bumpers, wheels
	var rng := RandomNumberGenerator.new()
	rng.seed = 7 + team
	var parts := [[Vector3(1.7, 0.1, 1.0), body_color], [Vector3(0.1, 0.5, 1.8), body_color], [Vector3(0.1, 0.5, 1.8), body_color],
		[Vector3(1.8, 0.3, 0.2), DARK], [Vector3(0.5, 0.8, 0.8), Color(0.05, 0.05, 0.06)], [Vector3(0.5, 0.8, 0.8), Color(0.05, 0.05, 0.06)],
		[Vector3(0.9, 0.2, 0.9), Color(0.15, 0.15, 0.18)], [Vector3(0.4, 0.4, 0.4), Color(1.0, 0.5, 0.1)]]
	for pd in parts:
		var rb := RigidBody3D.new()
		rb.collision_layer = 2
		rb.collision_mask = 1
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = pd[0]
		cs.shape = bs
		rb.add_child(cs)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = pd[0]
		mi.mesh = bm
		mi.material_override = _mat(Color(pd[1]).darkened(0.35))
		rb.add_child(mi)
		world.add_child(rb)
		rb.global_position = global_position + Vector3(rng.randf_range(-1, 1), 1.2, rng.randf_range(-1.5, 1.5))
		rb.linear_velocity = Vector3(rng.randf_range(-9, 9), rng.randf_range(7, 15), rng.randf_range(-9, 9))
		rb.angular_velocity = Vector3(rng.randf_range(-8, 8), rng.randf_range(-8, 8), rng.randf_range(-8, 8))
		get_tree().create_timer(7.0).timeout.connect(rb.queue_free)
	# charred paint
	if body_mat:
		charred = true
		body_mat.albedo_color = body_color.darkened(0.75)


## the roof / back plate shows the driver's name instead of the team letter
func set_plate_text(txt: String) -> void:
	var n := txt.length()
	for l in plate_labels:
		var lab := l as Label3D
		lab.text = txt
		lab.font_size = 150 if n <= 1 else int(clampf(190.0 - 16.0 * n, 40.0, 120.0))
		lab.width = 900.0


# ------------------------------------------------------------------ mirrors
## Rear-view mirror (top of the windshield) + two wing mirrors. Everybody sees the mirror bodies; only the car of
## the local player renders real reflections (enable_mirrors) - see Gfx.mirrors for the quality setting.

func _mirror_glass_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.2, 0.26, 0.33)
	return m


func _build_mirrors() -> void:
	var shell := body_mat if body_mat != null else _mat(body_color)
	var dark := CarStyle.mat(Color(0.05, 0.05, 0.07), 0.2, 0.5)
	# rear-view: fixed to the roof header above the driver (stalk + base plate screwed into the headliner)
	var gh: Dictionary = CarStyle.GREENHOUSE.get(model, CarStyle.GREENHOUSE["hatch"])
	var roof_y := 1.95 - drop
	var rv := Node3D.new()
	rv.position = Vector3(-0.22, roof_y - 0.13, float(gh["zf1"]) - drop * 0.3 + 0.12)
	rv.scale = Vector3(0.55, 0.55, 0.55)
	add_child(rv)
	CarStyle.box(rv, Vector3(0.14, 0.014, 0.09), Vector3(0, 0.236, -0.01), dark)                 # base plate on the roof
	CarStyle.box(rv, Vector3(0.035, 0.236, 0.035), Vector3(0, 0.118, -0.02), dark)                 # stalk up to the roof
	CarStyle.box(rv, Vector3(0.5, 0.15, 0.06), Vector3.ZERO, dark)
	_mirror_quad(rv, Vector2(0.45, 0.115), Vector3(0, 0, 0.034))
	_mirror_nodes["rear"] = rv
	# wing mirrors (stalk + housing in body colour, glass faces back and inwards)
	for side in ["left", "right"]:
		var sx := -1.0 if side == "left" else 1.0
		var wm := Node3D.new()
		wm.position = Vector3(sx * 1.13, 1.44 - drop * 0.3, -0.8)
		wm.rotation_degrees.y = -sx * 24.0
		add_child(wm)
		CarStyle.box(wm, Vector3(0.2, 0.05, 0.05), Vector3(-sx * 0.12, -0.04, -0.02), dark)
		CarStyle.box(wm, Vector3(0.24, 0.17, 0.09), Vector3.ZERO, shell)
		_mirror_quad(wm, Vector2(0.2, 0.135), Vector3(0, 0, 0.047))
		_mirror_nodes[side] = wm


func _mirror_quad(parent: Node3D, sz: Vector2, pos: Vector3) -> void:
	var g := MeshInstance3D.new()
	g.name = "glass"
	var q := QuadMesh.new()
	q.size = sz
	g.mesh = q
	g.material_override = _mirror_glass_mat()
	g.position = pos
	parent.add_child(g)


## local player's car only: turn the glass into live cameras. role = "driver" | "navigator"
func enable_mirrors(role: String) -> void:
	if preview or Gfx.mirrors <= 0 or not _mirror_vps.is_empty():
		return
	var rv: Node3D = _mirror_nodes["rear"]
	rv.rotation_degrees.y = (-15.0 if role == "driver" else 15.0)
	rv.rotation_degrees.x = 4.0
	# rear view: camera at the tail looking back
	_mirror_cam("rear", Vector3(0, 1.55, 2.0), Vector3(0, 0, 0), 62.0, Vector2i(288, 76), true)
	if Gfx.mirrors >= 2:
		_mirror_cam("left", Vector3(-1.2, 1.44, -0.7), Vector3(0, -12.0, 0), 58.0, Vector2i(140, 96), false)
		_mirror_cam("right", Vector3(1.2, 1.44, -0.7), Vector3(0, 12.0, 0), 58.0, Vector2i(140, 96), false)


func _mirror_cam(which: String, pos: Vector3, rot_deg: Vector3, fov: float, px: Vector2i, wide_rear: bool) -> void:
	var vp := SubViewport.new()
	vp.size = px
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	vp.gui_disable_input = true
	vp.audio_listener_enable_3d = false
	add_child(vp)
	var cam := Camera3D.new()
	cam.fov = fov
	cam.near = 0.15
	cam.far = clampf(Gfx.far_clip() * 0.45, 120.0, 700.0)
	vp.add_child(cam)
	# the camera copies a marker that rides on the car
	var mark := RemoteTransform3D.new()
	mark.position = pos
	# a camera looks down -Z: turn it round to look backwards (+Z)
	mark.rotation_degrees = Vector3(rot_deg.x, 180.0 + rot_deg.y, rot_deg.z)
	mark.use_global_coordinates = true
	add_child(mark)
	mark.remote_path = mark.get_path_to(cam)
	_mirror_vps.append(vp)
	var glass := (_mirror_nodes[which] as Node3D).get_node("glass") as MeshInstance3D
	var m := glass.material_override as StandardMaterial3D
	m.albedo_color = Color(0.95, 0.97, 1.0)
	m.albedo_texture = vp.get_texture()
	m.uv1_scale = Vector3(-1, 1, 1)      # a mirror image is flipped left <-> right
	m.uv1_offset = Vector3(1, 0, 0)


func _tick_mirrors(delta: float) -> void:
	if _mirror_vps.is_empty():
		return
	_mirror_t += delta
	var step := 1.0 / float(maxi(Gfx.mirror_fps, 5))
	if _mirror_t >= step:
		_mirror_t = 0.0
		for vp in _mirror_vps:
			vp.render_target_update_mode = SubViewport.UPDATE_ONCE


# ------------------------------------------------------------------ dashboard radio unit
var _radio_label: Label3D
var _radio_sub: Label3D


func _build_radio_unit() -> void:
	var labs := CarInterior.radio(self, model)
	_radio_label = labs[0]
	_radio_sub = labs[1]


## local player's car: show the live station on the unit
func bind_radio() -> void:
	if _radio_label == null:
		return
	if not Radio.changed.is_connected(_update_radio_unit):
		Radio.changed.connect(_update_radio_unit)
	_update_radio_unit()


func _update_radio_unit() -> void:
	if _radio_label == null or not is_instance_valid(_radio_label):
		return
	_radio_label.text = Radio.label()
	_radio_label.modulate = Color(1.0, 0.55, 0.12) if Radio.on else Color(0.5, 0.3, 0.15)
	_radio_sub.text = Radio.sub_label()


func _exit_tree() -> void:
	if Radio.changed.is_connected(_update_radio_unit):
		Radio.changed.disconnect(_update_radio_unit)


# ------------------------------------------------------------------ instrument cluster (every model has its own)
# style: "classic" = two round dials, "single" = one big dial + small gauges, "digital" = LCD + rev bar,
#        "race" = shift-light bar + big digital gear/speed (GT3), "hyper" = round central speedo + arc of LEDs
const CLUSTERS := {
	"hatch": {"style": "classic", "face": Color(0.93, 0.93, 0.9), "ink": Color(0.08, 0.08, 0.1), "needle": Color(1.0, 0.3, 0.1), "ring": Color(0.1, 0.1, 0.12), "max": 220},
	"buggy": {"style": "single", "face": Color(0.12, 0.13, 0.1), "ink": Color(0.9, 0.95, 0.8), "needle": Color(1.0, 0.8, 0.1), "ring": Color(0.55, 0.55, 0.5), "max": 200},
	"muscle": {"style": "classic", "face": Color(0.05, 0.05, 0.06), "ink": Color(0.95, 0.95, 0.95), "needle": Color(1.0, 0.45, 0.05), "ring": Color(0.85, 0.87, 0.9), "max": 260},
	"sierra": {"style": "classic", "face": Color(0.12, 0.12, 0.14), "ink": Color(0.95, 0.9, 0.7), "needle": Color(0.95, 0.9, 0.7), "ring": Color(0.04, 0.04, 0.05), "max": 240},
	"pickup": {"style": "single", "face": Color(0.9, 0.88, 0.8), "ink": Color(0.1, 0.1, 0.1), "needle": Color(0.85, 0.15, 0.1), "ring": Color(0.25, 0.25, 0.27), "max": 200},
	"charger": {"style": "single", "face": Color(0.03, 0.03, 0.04), "ink": Color(1.0, 1.0, 1.0), "needle": Color(1.0, 0.1, 0.1), "ring": Color(0.5, 0.52, 0.56), "max": 280},
	"m4": {"style": "digital", "face": Color(0.02, 0.03, 0.06), "ink": Color(0.9, 0.95, 1.0), "needle": Color(0.3, 0.55, 1.0), "ring": Color(0.05, 0.05, 0.07), "max": 300},
	"coupe": {"style": "digital", "face": Color(0.02, 0.03, 0.05), "ink": Color(0.55, 0.8, 1.0), "needle": Color(0.2, 0.6, 1.0), "ring": Color(0.05, 0.05, 0.07), "max": 300},
	"gt3": {"style": "race", "face": Color(0.01, 0.01, 0.02), "ink": Color(1.0, 0.75, 0.1), "needle": Color(0.1, 1.0, 0.3), "ring": Color(0.05, 0.05, 0.07), "max": 320},
	"hyper": {"style": "hyper", "face": Color(0.02, 0.02, 0.03), "ink": Color(1.0, 0.55, 0.1), "needle": Color(1.0, 0.5, 0.05), "ring": Color(0.9, 0.75, 0.3), "max": 440},
}
var _cl_needles: Array = []      # [{node, kind}]
var _cl_text: Label3D
var _cl_gear: Label3D
var _cl_leds: Array = []
var _cl_spec: Dictionary = {}
var _cl_gear_now := 1
var _cl_rpm := 0.2


func _cl_mat(c: Color, emit := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if emit > 0.0:
		m.albedo_color = c * emit
	return m


func _cl_dial(parent: Node3D, pos: Vector3, r: float, spec: Dictionary, kind: String, ticks: int, labels: bool) -> void:
	var holder := Node3D.new()
	holder.position = pos
	parent.add_child(holder)
	var axis := Vector3(90, 0, 0)
	CarStyle.cyl(holder, r * 1.1, 0.012, Vector3(0, 0, -0.004), CarStyle.mat(spec["ring"], 0.8, 0.3), axis)
	CarStyle.cyl(holder, r, 0.014, Vector3.ZERO, _cl_mat(spec["face"]), axis)
	var ink: Color = spec["ink"]
	for k in ticks + 1:
		var a := deg_to_rad(-135.0 + 270.0 * k / float(ticks))
		var major := k % 2 == 0
		var tk := CarStyle.box(holder, Vector3(0.006, r * (0.16 if major else 0.09), 0.004), Vector3(sin(a) * r * 0.84, cos(a) * r * 0.84, 0.009), _cl_mat(ink))
		tk.rotation.z = -a
		if labels and major and r > 0.06:
			var lab := Label3D.new()
			lab.text = str(int(float(spec["max"]) * (1.0 if kind == "speed" else 0.04) * k / float(ticks)))
			lab.pixel_size = 0.00045
			lab.font_size = 44
			lab.modulate = ink
			lab.shaded = false
			lab.position = Vector3(sin(a) * r * 0.62, cos(a) * r * 0.62, 0.011)
			holder.add_child(lab)
	var piv := Node3D.new()
	piv.position = Vector3(0, 0, 0.014)
	holder.add_child(piv)
	var nd := CarStyle.box(piv, Vector3(0.007, r * 0.85, 0.004), Vector3(0, r * 0.3, 0), _cl_mat(spec["needle"]))
	CarStyle.cyl(holder, r * 0.12, 0.012, Vector3(0, 0, 0.016), _cl_mat(Color(0.05, 0.05, 0.06)), axis)
	_cl_needles.append({"node": piv, "kind": kind})
	nd.name = "needle"


func _build_cluster() -> void:
	_cl_spec = CLUSTERS.get(model, CLUSTERS["hatch"])
	var style: String = _cl_spec["style"]
	var root := Node3D.new()
	root.position = Vector3(-0.45, 1.3 - sd * 0.8 + 0.1, -0.77)
	root.scale = Vector3(1.25, 1.25, 1.25)
	root.rotation_degrees.x = -10.0
	add_child(root)
	# hood / binnacle
	CarStyle.box(root, Vector3(0.5, 0.2, 0.02), Vector3(0, 0, -0.016), CarStyle.mat(Color(0.03, 0.03, 0.04), 0.2, 0.6))
	var vis := not preview or true
	match style:
		"classic":
			_cl_dial(root, Vector3(-0.1, 0, 0), 0.085, _cl_spec, "speed", 11, true)
			_cl_dial(root, Vector3(0.1, 0, 0), 0.085, _cl_spec, "rpm", 8, true)
		"single":
			_cl_dial(root, Vector3(-0.04, 0, 0), 0.098, _cl_spec, "speed", 10, true)
			_cl_dial(root, Vector3(0.17, 0.045, 0), 0.04, _cl_spec, "rpm", 8, false)
			_cl_dial(root, Vector3(0.17, -0.055, 0), 0.04, _cl_spec, "fuel", 4, false)
		"digital", "race", "hyper":
			CarStyle.box(root, Vector3(0.44, 0.15, 0.006), Vector3(0, 0, 0.004), _cl_mat(_cl_spec["face"]))
			_cl_text = Label3D.new()
			_cl_text.pixel_size = 0.0009 if style != "hyper" else 0.0011
			_cl_text.font_size = 60
			_cl_text.modulate = _cl_spec["ink"]
			_cl_text.shaded = false
			_cl_text.pixel_size = 0.0019 if style != "hyper" else 0.0016
			_cl_text.position = Vector3(-0.05 if style != "hyper" else 0.0, 0.012, 0.01)
			root.add_child(_cl_text)
			var unit := Label3D.new()
			unit.text = "KM/H"
			unit.pixel_size = 0.00055
			unit.font_size = 60
			unit.modulate = (_cl_spec["ink"] as Color) * 0.7
			unit.shaded = false
			unit.position = Vector3(-0.05 if style != "hyper" else 0.0, -0.035, 0.01)
			root.add_child(unit)
			# gear in its own window
			CarStyle.box(root, Vector3(0.085, 0.11, 0.004), Vector3(0.165, -0.005, 0.007), _cl_mat(Color(0.14, 0.15, 0.18)))
			CarStyle.box(root, Vector3(0.075, 0.1, 0.004), Vector3(0.165, -0.005, 0.0085), _cl_mat(Color(0.01, 0.01, 0.015)))
			_cl_gear = Label3D.new()
			_cl_gear.pixel_size = 0.0021
			_cl_gear.font_size = 60
			_cl_gear.modulate = Color(1, 1, 1)
			_cl_gear.shaded = false
			_cl_gear.position = Vector3(0.165, -0.005, 0.012)
			root.add_child(_cl_gear)
			var n := 14 if style == "digital" else 18
			for i in n:
				var x := lerpf(-0.2, 0.2, i / float(n - 1))
				var c: Color = _cl_spec["needle"]
				if i > n * 0.7:
					c = Color(1.0, 0.7, 0.1)
				if i > n * 0.88:
					c = Color(1.0, 0.1, 0.1)
				var y := 0.065 if style != "hyper" else 0.065 + sin(PI * i / float(n - 1)) * 0.02
				var led := CarStyle.box(root, Vector3(0.016, 0.012, 0.004), Vector3(x, y, 0.009), _cl_mat(c * 0.15))
				_cl_leds.append({"mesh": led, "col": c})
			if style == "hyper":
				_cl_dial(root, Vector3(-0.14, -0.01, 0.01), 0.055, _cl_spec, "speed", 8, false)
			if style == "race":
				CarStyle.box(root, Vector3(0.44, 0.012, 0.006), Vector3(0, 0.09, 0.006), _cl_mat(Color(0.9, 0.1, 0.1)))


func _update_cluster(delta: float) -> void:
	if _cl_spec.is_empty():
		return
	var mx: float = float(_cl_spec["max"])
	var spd := speed_kmh
	# simulated gearbox: 6 gears spread over the top speed
	var span := maxf(top_speed, 100.0) / 6.0
	var g := clampi(int(spd / span) + 1, 1, 6)
	if gear_sel.is_valid_int():
		g = int(gear_sel)
	var in_gear := clampf((spd - (g - 1) * span) / span, 0.0, 1.0)
	var target := 0.22 + in_gear * 0.72 if spd > 2.0 else 0.18 + throttle_in * 0.5
	_cl_rpm = lerpf(_cl_rpm, clampf(target, 0.1, 1.0), clampf(delta * 8.0, 0.0, 1.0))
	_cl_gear_now = g
	for n in _cl_needles:
		var f := 0.0
		match n["kind"]:
			"speed":
				f = clampf(spd / mx, 0.0, 1.0)
			"rpm":
				f = _cl_rpm
			_:
				f = 0.7
		(n["node"] as Node3D).rotation.z = deg_to_rad(135.0 - 270.0 * f)
	if _cl_text:
		_cl_text.text = "%d" % int(spd)
	if _cl_gear:
		_cl_gear.text = gear_sel if gear_sel != "" else "N"
		_cl_gear.modulate = Color(1.0, 0.75, 0.2) if gear_sel in ["R", "P"] else Color(1, 1, 1)
	var lit := int(_cl_rpm * _cl_leds.size())
	for i in _cl_leds.size():
		var d: Dictionary = _cl_leds[i]
		((d["mesh"] as MeshInstance3D).material_override as StandardMaterial3D).albedo_color = (d["col"] as Color) * (1.0 if i < lit else 0.12)


# ------------------------------------------------------------------ gearbox: state, lever, driver's hand
var gear_sel := "N"
var _gear_style := "h5"
var _gear_map: Dictionary = {}
var _gear_base := Vector3.ZERO
var _gear_pivot: Node3D
var _gear_buttons: Dictionary = {}
var _gear_letters: Dictionary = {}
var _gear_len := 0.2
var _gear_tip_extra := 0.04
var _gprev := Vector3.ZERO
var _gprev_ok := false
var _fs := 0.0
var _g_pending := ""
var _g_hold := 0.0
var _g_idle := 0.0
var _shift_t := -1.0
var _shift_dur := 0.7
var _shift_from := Vector2.ZERO
var _shift_to := Vector2.ZERO
var _lever_now := Vector2.ZERO
var _shift_snd := true
var _shift_heavy := true


func _gear_target() -> String:
	var auto := _gear_style == "auto"
	var n := CarInterior.gear_count(_gear_style)
	if _fs < -0.8:
		return "R"
	if _fs > 0.8:
		if auto or n == 0:
			return "D"
		return str(clampi(int(speed_kmh / maxf(top_speed / float(n), 1.0)) + 1, 1, n))
	# standing still
	if brake_in > 0.1:
		return "R"
	if throttle_in > 0.1:
		return "D" if (auto or n == 0) else "1"
	if auto and _g_idle > 1.6:
		return "P"
	return "N"


func _update_gear(delta: float) -> void:
	if _gear_map.is_empty():
		return
	if preview or delta <= 0.0:
		if preview and speed_kmh > 1.0 and not _gear_map.is_empty():
			var pg := "D" if (_gear_style == "auto" or _gear_style == "buttons") else str(clampi(int(speed_kmh / maxf(top_speed / maxf(float(CarInterior.gear_count(_gear_style)), 1.0), 1.0)) + 1, 1, maxi(CarInterior.gear_count(_gear_style), 1)))
			if _gear_map.has(pg):
				gear_sel = pg
		_apply_lever(delta)
		return
	var pos := global_position
	if _gprev_ok:
		var v := (pos - _gprev) / delta
		var f := clampf(-global_transform.basis.z.dot(v), -60.0, 90.0)
		_fs = lerpf(_fs, f, clampf(delta * 10.0, 0.0, 1.0))
	_gprev = pos
	_gprev_ok = true
	if absf(_fs) < 0.8 and throttle_in < 0.1 and brake_in < 0.1:
		_g_idle += delta
	else:
		_g_idle = 0.0
	var want := _gear_target()
	if not _gear_map.has(want):
		want = "N"
	if want != gear_sel:
		if want == _g_pending:
			_g_hold += delta
		else:
			_g_pending = want
			_g_hold = 0.0
		if _g_hold >= 0.12:
			_begin_shift(gear_sel, want)
			gear_sel = want
			_g_pending = ""
	else:
		_g_pending = ""
	_apply_lever(delta)


func _begin_shift(from_g: String, to_g: String) -> void:
	_shift_from = _lever_now
	_shift_to = _gear_map.get(to_g, Vector2.ZERO)
	var numeric := to_g.is_valid_int() and from_g.is_valid_int()
	_shift_dur = 0.45 if numeric else 0.8
	_shift_t = 0.0
	_shift_snd = false
	_shift_heavy = not numeric
	# the lights on the gate follow the lever
	for g in _gear_letters:
		(_gear_letters[g] as Label3D).modulate = Color(1.0, 0.75, 0.2) if g == to_g else Color(0.55, 0.58, 0.65)
	if _gear_buttons.has(to_g):
		for g in _gear_buttons:
			var m := ((_gear_buttons[g] as MeshInstance3D).material_override as StandardMaterial3D)
			m.emission_enabled = g == to_g
			m.emission = Color(1.0, 0.6, 0.15)


## moves the lever / pushes the button and tells the driver where his right hand has to go
func _apply_lever(delta: float) -> void:
	var k := 0.0
	var ease_t := 1.0
	if _shift_t >= 0.0:
		_shift_t += delta
		var u := clampf(_shift_t / _shift_dur, 0.0, 1.0)
		k = smoothstep(0.0, 0.3, u) * (1.0 - smoothstep(0.7, 1.0, u))
		ease_t = smoothstep(0.3, 0.7, u)
		if not _shift_snd and u >= 0.62:
			_shift_snd = true
			if not preview and DisplayServer.get_name() != "headless":
				Sfx.play3d("gear_clunk" if _shift_heavy else "gear_tick", self, -2.0 if _shift_heavy else -4.0, randf_range(0.94, 1.06))
		_lever_now = _shift_from.lerp(_shift_to, ease_t)
		if u >= 1.0:
			_shift_t = -1.0
			_lever_now = _shift_to
	elif not _gear_map.is_empty() and _lever_now == Vector2.ZERO and gear_sel != "":
		_lever_now = _gear_map.get(gear_sel, Vector2.ZERO)
	var hand := Vector3.ZERO
	if _gear_pivot:
		var ox := _lever_now.x
		var oz := _lever_now.y
		_gear_pivot.rotation = Vector3(atan2(oz, _gear_len), 0.0, -atan2(ox, _gear_len))
		hand = _gear_pivot.position + _gear_pivot.transform.basis * Vector3(0, _gear_len + _gear_tip_extra, 0)
	else:
		hand = _gear_base + Vector3(_lever_now.x, 0.09, 0.0)
	if driver_avatar:
		driver_avatar.set_shift_hand(hand, k)
