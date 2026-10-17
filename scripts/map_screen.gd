class_name MapScreen
extends Node3D
## The map "TV": a tablet that folds open with a flip animation, can be small / medium / large and can be
## pulled close to the face. Shows the live map texture (a SubViewport texture).

const SIZES := [0.72, 1.0, 1.5]
var tex: Texture2D
var open_angle := -25.0      # hinge angle when open (degrees)
var closed_angle := 85.0     # hinge angle when folded away
var near_offset := Vector3(0, 0.1, 0.3)
var is_open := false
var size_idx := 1
var near := false
var _hinge: Node3D
var _body: Node3D
var _tw: Tween
var _spin := 0.0
var _near_t := 0.0
var _size_s := 1.0
var _base_pos := Vector3.ZERO


func _ready() -> void:
	_base_pos = position
	_hinge = Node3D.new()
	_hinge.rotation.x = deg_to_rad(closed_angle)
	add_child(_hinge)
	_body = Node3D.new()
	_body.position.y = 0.16          # hinge is the bottom edge
	_hinge.add_child(_body)
	_box(Vector3(0.46, 0.34, 0.03), Vector3.ZERO, Color(0.08, 0.09, 0.11))
	_box(Vector3(0.4, 0.04, 0.034), Vector3(0, -0.15, 0), Color(0.9, 0.4, 0.1))
	var s := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(0.4, 0.27)
	s.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if tex:
		m.albedo_texture = tex
	else:
		m.albedo_color = Color(0.12, 0.2, 0.3)
	s.material_override = m
	s.position = Vector3(0, 0.015, 0.0165)
	_body.add_child(s)
	visible = false


func _box(sz: Vector3, p: Vector3, c: Color) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = sz
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.5
	mi.material_override = m
	mi.position = p
	_body.add_child(mi)


func set_open(v: bool) -> void:
	if v == is_open:
		return
	is_open = v
	if _tw:
		_tw.kill()
	_tw = create_tween().set_parallel(true)
	if v:
		visible = true
		_tw.tween_property(_hinge, "rotation:x", deg_to_rad(open_angle), 0.65).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		_tw.tween_property(self, "_spin", 0.0, 0.65).from(PI * 2.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		_tw.tween_property(_hinge, "rotation:x", deg_to_rad(closed_angle), 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		_tw.chain().tween_callback(func(): visible = is_open)


func cycle_size() -> void:
	size_idx = (size_idx + 1) % SIZES.size()


func toggle_near() -> void:
	near = not near


func _process(d: float) -> void:
	_size_s = lerpf(_size_s, SIZES[size_idx], clampf(d * 8.0, 0.0, 1.0))
	_near_t = move_toward(_near_t, 1.0 if near else 0.0, d * 2.5)
	scale = Vector3.ONE * _size_s
	position = _base_pos + near_offset * ease(_near_t, -2.0)
	if _hinge:
		_hinge.rotation.y = _spin
