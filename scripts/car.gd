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
var _hood_ang := 0.0
var _cover_ang := 0.0
var _lever_ang := 0.0
var _prev_vel := Vector3.ZERO
var _last_pos := Vector3.ZERO
var _vel_est := Vector3.ZERO
var _wheel_pivot: Node3D
var _wheel_mesh: Node3D


func setup(p_team: int, color: Color, remote: bool) -> void:
	team = p_team
	body_color = color
	is_remote = remote


func seat_origin(role: String) -> Vector3:
	return Vector3(-0.45, 1.0, 0.3) if role == "driver" else Vector3(0.45, 1.0, 0.3)


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
	_build_audio()


func _add_wheels() -> void:
	for x in [-0.95, 0.95]:
		for z in [-1.3, 1.3]:
			if is_remote:
				# clients only display the car: plain meshes, no vehicle physics (avoids NaNs on a frozen body)
				var holder := Node3D.new()
				holder.position = Vector3(x, 0.4, z)
				add_child(holder)
				_box(holder, Vector3(0.32, 0.8, 0.8), Vector3.ZERO, Color(0.05, 0.05, 0.06))
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
			w.wheel_friction_slip = 3.2
			w.wheel_roll_influence = 0.25
			w.use_as_traction = true
			w.use_as_steering = z < 0.0
			add_child(w)
			_box(w, Vector3(0.32, 0.8, 0.8), Vector3.ZERO, Color(0.05, 0.05, 0.06))


# ------------------------------------------------------------------ controls

func set_controls(steer: float, throttle: float, brk: float) -> void:
	var fs := -global_transform.basis.z.dot(linear_velocity)
	speed_kmh = absf(fs) * 3.6
	var lim := lerpf(0.42, 0.08, clampf(speed_kmh / 120.0, 0.0, 1.0))
	steer_target = steer
	throttle_in = throttle
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
		engine_force = -throttle * ENGINE * power if speed_kmh < TOP_SPEED_KMH else 0.0
		brake = brk * BRAKE_FORCE


## 1 = normal, ~0.25 = ice
func set_grip(f: float) -> void:
	if absf(f - _grip) < 0.01:
		return
	_grip = f
	for w in wheel_list:
		w.wheel_friction_slip = 3.2 * f


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
	cab.position = Vector3(0, 1.7, 0.2)
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
	mi.material_override = _mat(c)
	mi.position = pos
	parent.add_child(mi)
	return mi


func _build_visuals() -> void:
	var c := body_color
	_box(self, Vector3(1.9, 0.5, 4.0), Vector3(0, 0.62, 0), c)                  # body
	_box(self, Vector3(1.8, 0.08, 3.8), Vector3(0, 0.88, 0.0), NAVY)            # floor
	_box(self, Vector3(1.9, 0.12, 2.0), Vector3(0, 1.95, 0.35), c)              # roof
	_box(self, Vector3(0.1, 0.42, 2.0), Vector3(-0.95, 1.12, 0.35), c)          # doors
	_box(self, Vector3(0.1, 0.42, 2.0), Vector3(0.95, 1.12, 0.35), c)
	_box(self, Vector3(1.9, 0.42, 0.1), Vector3(0, 1.12, 1.35), c)              # rear wall
	_box(self, Vector3(0.14, 1.0, 0.14), Vector3(-0.9, 1.42, -0.65), c)         # A pillars
	_box(self, Vector3(0.14, 1.0, 0.14), Vector3(0.9, 1.42, -0.65), c)
	_box(self, Vector3(1.9, 0.14, 0.14), Vector3(0, 1.9, -0.65), c)             # windshield top
	_box(self, Vector3(1.9, 0.3, 0.9), Vector3(0, 1.0, -1.2), DARK.lightened(0.15))  # dashboard
	_box(self, Vector3(0.35, 0.08, 0.06), Vector3(0, 1.78, -0.6), DARK)         # rear-view mirror
	_build_engine_bay(c)
	_box(self, Vector3(1.9, 0.3, 0.2), Vector3(0, 0.5, -2.05), DARK)            # bumpers
	_box(self, Vector3(1.9, 0.3, 0.2), Vector3(0, 0.5, 2.05), DARK)
	for x in [-0.45, 0.45]:                                                     # front seats
		_box(self, Vector3(0.5, 0.12, 0.55), Vector3(x, 0.98, 0.3), DARK)
		_box(self, Vector3(0.5, 0.75, 0.12), Vector3(x, 1.3, 0.66), DARK)
	_box(self, Vector3(1.6, 0.12, 0.55), Vector3(0, 0.98, 1.0), DARK)           # back seat
	_box(self, Vector3(1.8, 0.06, 0.06), Vector3(0, 1.8, 0.2), DARK)            # roll-cage bar

	# team letter on the roof and on the back
	for spec in [[Vector3(0, 2.03, 0.35), Vector3(-90, 0, 0)], [Vector3(0, 1.3, 1.42), Vector3(0, 0, 0)]]:
		var lab := Label3D.new()
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
	_wheel_pivot.position = Vector3(-0.45, 1.3, -0.42)
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
	p.amount = amount
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


func _vol(db: float, on: bool) -> float:
	return db if on else -60.0


func _process(delta: float) -> void:
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
