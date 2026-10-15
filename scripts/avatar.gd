class_name Avatar
extends Node3D
## A blocky player character sitting in a car seat (long cream arms like in the video).
## - the driver keeps both hands on the wheel, the right hand can punch
## - the co-driver holds the map clipboard in the LEFT hand and points / warns with the RIGHT hand
## The origin of this node is the seat position (car space). -Z is forward.

enum Gesture { REST, LEFT, FORWARD, RIGHT, STOP }

const UPPER := 0.42
const FORE := 0.46
const SKIN := Color(0.93, 0.84, 0.7)
const WOOD := Color(0.62, 0.4, 0.17)
const SHOULDER := {"L": Vector3(-0.3, 0.5, 0.1), "R": Vector3(0.3, 0.5, 0.1)}
const POLE := {"L": Vector3(-0.5, -1.0, 0.25), "R": Vector3(0.5, -1.0, 0.25)}
const CLIP_POS := Vector3(0.0, 0.12, -0.42)
const CLIP_HAND := Vector3(-0.34, 0.05, -0.3)

var peer_id := 0
var role := "driver"
var shirt_color := Color(0.8, 0.2, 0.25)
var helmet_color := Color(0.1, 0.25, 0.9)
var is_local := false
var seat_dx := 0.0        # x offset of the teammate's seat relative to mine (0 = no teammate)
var look_yaw := 0.0
var look_pitch := 0.0
var gesture: int = Gesture.REST
var punch_t := -1.0
var hit_kick := 0.0
var cam: Camera3D
# working outside the car (putting out an engine fire)
var outside := false
var work := 0              # 0 none, 1 reaching for the hood, 2 holding the extinguisher
var reach_t := 0.0         # 0 hood closed .. 1 hood fully up
var cover_hand := false    # left hand on the engine cover
var _ext: Node3D
var _seat_pos := Vector3.ZERO
var ipad_tex: Texture2D     # live map texture (local co-driver only)

var _head: Node3D
var _torso: MeshInstance3D
var _helmet: MeshInstance3D
var _visor: MeshInstance3D
var _palm: MeshInstance3D
var _finger: MeshInstance3D
var _limbs := {}
var _cur := {"L": Vector3(-0.3, 0.1, -0.3), "R": Vector3(0.3, 0.1, -0.3)}
var _wheel_l := Vector3(-0.2, 0.1, -0.6)
var _wheel_r := Vector3(0.2, 0.1, -0.6)


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


func _ready() -> void:
	_torso = _box(self, Vector3(0.52, 0.56, 0.3), Vector3(0, 0.25, 0.12), shirt_color)
	_head = Node3D.new()
	_head.position = Vector3(0, 0.7, 0.05)
	add_child(_head)
	_helmet = _box(_head, Vector3(0.36, 0.36, 0.36), Vector3.ZERO, helmet_color)
	_visor = _box(_head, Vector3(0.3, 0.12, 0.04), Vector3(0, 0.03, -0.19), Color(0.03, 0.03, 0.05))
	for s in ["L", "R"]:
		_limbs[s] = {
			"up": _box(self, Vector3(0.14, 0.14, 1.0), Vector3.ZERO, SKIN),
			"fore": _box(self, Vector3(0.14, 0.14, 1.0), Vector3.ZERO, SKIN),
			"hand": _box(self, Vector3(0.17, 0.17, 0.17), Vector3.ZERO, SKIN.darkened(0.08)),
		}
	_palm = _box(self, Vector3(0.3, 0.3, 0.05), Vector3.ZERO, Color(0.92, 0.15, 0.15))
	_palm.visible = false
	_finger = _box(self, Vector3(0.05, 0.05, 1.0), Vector3.ZERO, SKIN)
	_finger.visible = false
	if role == "navigator":
		_build_clipboard()
	if is_local:
		_torso.visible = false
		_helmet.visible = false
		_visor.visible = false
		cam = Camera3D.new()
		cam.fov = 82.0
		cam.near = 0.05
		cam.far = 2500.0
		_head.add_child(cam)
		cam.position = Vector3(0, 0, -0.12)
		cam.current = true


func _build_clipboard() -> void:
	# an iPad resting in the lap: the co-driver has to look DOWN to read the map
	var root := Node3D.new()
	root.position = CLIP_POS
	root.rotation.x = deg_to_rad(-55.0)
	add_child(root)
	_box(root, Vector3(0.44, 0.32, 0.025), Vector3.ZERO, Color(0.75, 0.76, 0.8))
	var screen := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.38, 0.26)
	screen.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if ipad_tex:
		m.albedo_texture = ipad_tex
	else:
		m.albedo_color = Color(0.12, 0.2, 0.3)
	screen.material_override = m
	screen.position = Vector3(0, 0, 0.0135)
	root.add_child(screen)
	if ipad_tex == null:
		for p in [Vector3(-0.08, -0.07, 0.016), Vector3(0.05, -0.03, 0.016), Vector3(-0.04, 0.02, 0.016), Vector3(0.07, 0.06, 0.016)]:
			var dot := _box(root, Vector3(0.05, 0.05, 0.004), p, Color(0.98, 0.93, 0.6))
			(dot.material_override as StandardMaterial3D).shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED


## Car space -> avatar space (the avatar only has a translation).
func set_wheel_hands(left_car: Vector3, right_car: Vector3) -> void:
	_wheel_l = left_car - position
	_wheel_r = right_car - position


func go_outside(pos: Vector3) -> void:
	if not outside:
		_seat_pos = position
	outside = true
	position = pos
	rotation.y = PI
	if _ext == null:
		_ext = Node3D.new()
		add_child(_ext)
		_box(_ext, Vector3(0.13, 0.4, 0.13), Vector3(0, 0, 0), Color(0.85, 0.08, 0.08))
		_box(_ext, Vector3(0.1, 0.06, 0.1), Vector3(0, 0.23, 0), Color(0.1, 0.1, 0.1))
		_box(_ext, Vector3(0.04, 0.04, 0.22), Vector3(0, 0.2, -0.1), Color(0.1, 0.1, 0.1))
	_ext.visible = false


func go_inside() -> void:
	if outside:
		outside = false
		position = _seat_pos
		rotation.y = 0.0
		work = 0
		if _ext:
			_ext.visible = false


func set_look(yaw: float, pitch: float) -> void:
	look_yaw = yaw
	look_pitch = pitch


func punch() -> void:
	punch_t = 0.0


func play_hit() -> void:
	hit_kick = 1.0


func _gesture_target() -> Vector3:
	var s: Vector3 = SHOULDER["R"]
	match gesture:
		Gesture.LEFT:
			return s + Vector3(-0.88, 0.1, -0.3)
		Gesture.RIGHT:
			return s + Vector3(0.88, 0.1, -0.3)
		Gesture.FORWARD:
			return s + Vector3(0.05, 0.12, -0.88)
		Gesture.STOP:
			return s + Vector3(0.1, 0.45, -0.7)
	return Vector3(0.32, 0.12, -0.2)


func _process(delta: float) -> void:
	if _head == null:
		return
	hit_kick = move_toward(hit_kick, 0.0, delta * 2.5)
	_head.rotation = Vector3(look_pitch, look_yaw, hit_kick * 0.35 * sin(Time.get_ticks_msec() * 0.06))

	var dl := Vector3(-0.3, 0.1, -0.15)
	var dr := Vector3(0.3, 0.1, -0.15)
	match role:
		"driver":
			dl = _wheel_l
			dr = _wheel_r
		"navigator":
			dl = CLIP_HAND
			dr = _gesture_target()
	if outside:
		var a := Vector3(0.3, -0.25, -0.8)
		var b := Vector3(0.3, 0.6, -0.55)
		if work == 2:
			dr = Vector3(0.22, 0.12, -0.6)
			dl = Vector3(-0.1, -0.2, -0.65) if cover_hand else Vector3(-0.3, -0.05, -0.4)
		else:
			dr = a.lerp(b, reach_t)
			dl = Vector3(-a.x, a.y, a.z).lerp(Vector3(-b.x, b.y, b.z), reach_t)
	var k := 12.0
	if punch_t >= 0.0:
		punch_t += delta / 0.4
		var f := sin(PI * clampf(punch_t, 0.0, 1.0))
		var tgt := Vector3(0.35, 0.55, -0.75)
		if seat_dx != 0.0:
			tgt = Vector3(seat_dx * 0.74, 0.72, -0.08)
		dr = dr.lerp(tgt, f)
		k = 34.0
		if punch_t >= 1.0:
			punch_t = -1.0
	_cur["L"] = (_cur["L"] as Vector3).lerp(dl, clampf(delta * k, 0.0, 1.0))
	_cur["R"] = (_cur["R"] as Vector3).lerp(dr, clampf(delta * k, 0.0, 1.0))
	_solve("L")
	var elbow_r := _solve("R")
	# pointing finger / stop palm on the right hand
	var h: Vector3 = _limbs["R"]["hand"].position
	var dir := (h - elbow_r).normalized()
	var pointing := role == "navigator" and punch_t < 0.0 and gesture in [Gesture.LEFT, Gesture.RIGHT, Gesture.FORWARD]
	pointing = pointing and not outside
	_finger.visible = pointing
	if _ext:
		_ext.visible = outside and work == 2
		_ext.position = h + Vector3(0.0, 0.1, 0.0)
		_ext.rotation.x = deg_to_rad(-75.0)
	if pointing:
		_place(_finger, h, h + dir * 0.24)
	_palm.visible = role == "navigator" and punch_t < 0.0 and gesture == Gesture.STOP and not outside
	if _palm.visible:
		_palm.position = h + Vector3(0, 0.1, -0.06)


## 2-bone IK. Returns the elbow position.
func _solve(side: String) -> Vector3:
	var s: Vector3 = SHOULDER[side]
	var v: Vector3 = (_cur[side] as Vector3) - s
	var d := clampf(v.length(), 0.08, UPPER + FORE - 0.01)
	var u := v.normalized() if v.length() > 0.001 else Vector3(0, 0, -1)
	var x := (UPPER * UPPER + d * d - FORE * FORE) / (2.0 * UPPER * d)
	var hgt := UPPER * sqrt(maxf(0.0, 1.0 - x * x))
	var pole: Vector3 = POLE[side]
	var perp := pole - u * pole.dot(u)
	if perp.length() < 0.01:
		perp = Vector3.DOWN
	perp = perp.normalized()
	var elbow := s + u * (UPPER * x) + perp * hgt
	var hand := s + u * d
	_place(_limbs[side]["up"], s, elbow)
	_place(_limbs[side]["fore"], elbow, hand)
	(_limbs[side]["hand"] as MeshInstance3D).position = hand
	return elbow


func _place(mi: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var d := b - a
	var len_m := d.length()
	if len_m < 0.001:
		return
	var up := Vector3.UP
	if absf(d.normalized().dot(Vector3.UP)) > 0.97:
		up = Vector3.RIGHT
	var basis := Basis.looking_at(d, up)
	mi.transform = Transform3D(basis * Basis.from_scale(Vector3(1, 1, len_m)), (a + b) * 0.5)
