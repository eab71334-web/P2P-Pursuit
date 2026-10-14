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

var wheel_list: Array[VehicleWheel3D] = []
var _grip := 1.0
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
		engine_force = -throttle * ENGINE if speed_kmh < TOP_SPEED_KMH else 0.0
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
	_box(self, Vector3(1.7, 0.5, 0.9), Vector3(0, 0.95, -1.6), c)               # hood
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
