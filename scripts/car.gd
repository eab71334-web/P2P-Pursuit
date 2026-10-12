class_name Car
extends VehicleBody3D
## Blocky red rally car with a first-person cockpit (steering wheel, dashboard, arms).
## Physics only runs on the server; clients get a frozen copy that follows the network state.

const ENGINE := 1150.0
const BRAKE_FORCE := 40.0
const TOP_SPEED_KMH := 165.0

const RED := Color(0.78, 0.08, 0.08)
const DARK := Color(0.12, 0.12, 0.16)
const NAVY := Color(0.1, 0.12, 0.25)
const SKIN := Color(0.93, 0.84, 0.7)
const BLUE := Color(0.1, 0.25, 0.9)
const SHIRT := Color(0.92, 0.28, 0.32)

var speed_kmh := 0.0
var steer_target := 0.0
var steer_visual := 0.0
var local_role := ""
var is_remote := false
var hold := false      # handbrake (before the start / after the finish)

var _wheel_pivot: Node3D
var _wheel_mesh: Node3D
var _arms: Array[MeshInstance3D] = []
var _chars := {}


func setup(role: String, remote: bool) -> void:
	local_role = role
	is_remote = remote


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


func teleport(t: Transform3D) -> void:
	var rid := get_rid()
	PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_TRANSFORM, t)
	PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, Vector3.ZERO)
	PhysicsServer3D.body_set_state(rid, PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY, Vector3.ZERO)
	steering = 0.0


func seat_camera_position(role: String) -> Vector3:
	match role:
		"driver":
			return Vector3(-0.45, 1.45, 0.35)
		"navigator":
			return Vector3(0.45, 1.45, 0.35)
	return Vector3(0.0, 1.42, 1.0)


func show_character(role: String, on: bool) -> void:
	if _chars.has(role):
		_chars[role].visible = on


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
	# body shell
	_box(self, Vector3(1.9, 0.5, 4.0), Vector3(0, 0.62, 0), RED)
	_box(self, Vector3(1.8, 0.08, 3.8), Vector3(0, 0.88, 0.0), NAVY)          # floor
	_box(self, Vector3(1.9, 0.12, 2.0), Vector3(0, 1.88, 0.35), RED)          # roof
	_box(self, Vector3(0.1, 0.42, 2.0), Vector3(-0.95, 1.12, 0.35), RED)        # left door
	_box(self, Vector3(0.1, 0.42, 2.0), Vector3(0.95, 1.12, 0.35), RED)         # right door
	_box(self, Vector3(1.9, 0.42, 0.1), Vector3(0, 1.12, 1.35), RED)            # rear wall
	_box(self, Vector3(0.14, 0.95, 0.14), Vector3(-0.9, 1.4, -0.65), RED)     # A pillars
	_box(self, Vector3(0.14, 0.95, 0.14), Vector3(0.9, 1.4, -0.65), RED)
	_box(self, Vector3(1.9, 0.14, 0.14), Vector3(0, 1.85, -0.65), RED)        # windshield top
	_box(self, Vector3(1.9, 0.3, 0.9), Vector3(0, 1.0, -1.2), DARK.lightened(0.15))  # dashboard
	_box(self, Vector3(0.35, 0.08, 0.06), Vector3(0, 1.7, -0.6), DARK)        # rear-view mirror
	_box(self, Vector3(1.7, 0.5, 0.9), Vector3(0, 0.95, -1.6), RED)           # hood
	_box(self, Vector3(1.9, 0.3, 0.2), Vector3(0, 0.5, -2.05), DARK)          # bumpers
	_box(self, Vector3(1.9, 0.3, 0.2), Vector3(0, 0.5, 2.05), DARK)
	for x in [-0.45, 0.45]:                                                   # front seats
		_box(self, Vector3(0.5, 0.12, 0.55), Vector3(x, 0.98, 0.3), DARK)
		_box(self, Vector3(0.5, 0.75, 0.12), Vector3(x, 1.35, 0.62), DARK)
	_box(self, Vector3(1.6, 0.12, 0.55), Vector3(0, 0.98, 1.0), DARK)         # back seat
	# roll cage bar (the thin dark bars seen in the video)
	_box(self, Vector3(1.8, 0.06, 0.06), Vector3(0, 1.75, 0.2), DARK)

	# steering wheel (driver side)
	_wheel_pivot = Node3D.new()
	_wheel_pivot.position = Vector3(-0.45, 1.12, -0.55)
	_wheel_pivot.rotation.x = deg_to_rad(68.0)
	add_child(_wheel_pivot)
	_wheel_mesh = Node3D.new()
	_wheel_pivot.add_child(_wheel_mesh)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.12
	torus.outer_radius = 0.19
	torus.rings = 8
	torus.ring_segments = 6
	ring.mesh = torus
	ring.material_override = _mat(Color(0.03, 0.03, 0.04))
	_wheel_mesh.add_child(ring)
	_box(_wheel_mesh, Vector3(0.3, 0.04, 0.05), Vector3.ZERO, Color(0.03, 0.03, 0.04))
	_box(_wheel_mesh, Vector3(0.05, 0.04, 0.3), Vector3.ZERO, Color(0.03, 0.03, 0.04))

	# arms for the driver's own view (updated every frame to follow the wheel)
	for i in 2:
		var arm := _box(self, Vector3(0.13, 0.13, 1.0), Vector3.ZERO, SKIN)
		arm.visible = (local_role == "driver")
		_arms.append(arm)

	# blocky characters, seen by the OTHER player
	_make_character("driver", Vector3(-0.45, 0, 0.3))
	_make_character("navigator", Vector3(0.45, 0, 0.3))
	show_character("driver", false)
	show_character("navigator", false)


func _make_character(role: String, at: Vector3) -> void:
	var root := Node3D.new()
	root.position = at
	add_child(root)
	_box(root, Vector3(0.5, 0.6, 0.3), Vector3(0, 1.4, 0), SHIRT)           # torso
	_box(root, Vector3(0.38, 0.38, 0.38), Vector3(0, 1.85, -0.02), BLUE)    # helmet
	_box(root, Vector3(0.3, 0.14, 0.05), Vector3(0, 1.85, -0.23), Color.BLACK)  # visor
	_box(root, Vector3(0.14, 0.14, 0.5), Vector3(-0.32, 1.35, -0.25), SKIN)  # arms
	_box(root, Vector3(0.14, 0.14, 0.5), Vector3(0.32, 1.35, -0.25), SKIN)
	_chars[role] = root


func _place_limb(mi: MeshInstance3D, from: Vector3, to: Vector3) -> void:
	var d := to - from
	var b := Basis.looking_at(d, Vector3.UP)
	mi.transform = Transform3D((b * Basis.from_scale(Vector3(1, 1, d.length()))), (from + to) * 0.5)


func _process(delta: float) -> void:
	if not is_remote:
		steer_visual = move_toward(steer_visual, steer_target, delta * 5.0)
	var phi := -steer_visual * 1.6
	if _wheel_mesh:
		_wheel_mesh.rotation.y = phi
	if local_role == "driver" and _arms.size() == 2 and _wheel_pivot:
		var r := 0.155
		var left_hand := _wheel_pivot.transform * Vector3(-cos(phi), 0.0, sin(phi)) * r
		var right_hand := _wheel_pivot.transform * Vector3(cos(phi), 0.0, -sin(phi)) * r
		_place_limb(_arms[0], Vector3(-0.7, 1.0, 0.75), left_hand)
		_place_limb(_arms[1], Vector3(-0.2, 1.0, 0.75), right_hand)
