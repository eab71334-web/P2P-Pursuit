# Copyright (c) 2026 KRG Studios. All rights reserved. See LICENSE.
class_name Cloth
extends Node3D
## Light real-time cloth (position-based / verlet): a hanging band (scarf, cape) pinned to an anchor node.
## World-space simulation so the cloth lags behind the moving car and streams back in the wind. ~50 particles: cheap on phones.

var anchor: Node3D                 # the pinned top edge follows this node (local x = across, -z = outward)
var cols := 4
var rows := 10
var width := 0.16
var length := 0.8
var color := Color(0.8, 0.15, 0.2)
var wind := Vector3.ZERO           # world-space air velocity felt by the cloth
var gravity := Vector3(0, -6.0, 0)
var stiffness_iters := 5
var _p: PackedVector3Array
var _o: PackedVector3Array
var _rest_u := 0.0
var _rest_v := 0.0
var _mi: MeshInstance3D
var _first := true
var colliders: Array = []          # [[Node3D, radius], ...] spheres the cloth cannot enter


func _ready() -> void:
	top_level = true
	_rest_u = width / (cols - 1)
	_rest_v = length / (rows - 1)
	_p.resize(cols * rows)
	_o.resize(cols * rows)
	_mi = MeshInstance3D.new()
	_mi.top_level = true
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	m.emission_enabled = true
	m.emission = color * 0.45
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mi.material_override = m
	add_child(_mi)
	_mi.global_transform = Transform3D.IDENTITY


func _pin(c: int) -> Vector3:
	var u := (float(c) / (cols - 1) - 0.5) * width
	return anchor.global_transform * Vector3(u, 0, 0)


func _reset() -> void:
	for r in rows:
		for c in cols:
			var i := r * cols + c
			var q := _pin(c) + Vector3(0, -_rest_v * r, 0)
			_p[i] = q
			_o[i] = q
	_first = false


func _physics_process(dt: float) -> void:
	if anchor == null or not anchor.is_inside_tree():
		return
	if _first:
		_reset()
	dt = minf(dt, 1.0 / 30.0)
	var t := Time.get_ticks_msec() * 0.001
	for r in range(1, rows):
		var k := float(r) / (rows - 1)
		for c in cols:
			var i := r * cols + c
			var v := (_p[i] - _o[i]) * 0.985
			_o[i] = _p[i]
			var flutter := Vector3(sin(t * 7.0 + r * 0.9 + c), sin(t * 5.0 + r * 0.6) * 0.5, cos(t * 6.0 + r * 0.8)) * 0.35 * k
			_p[i] += v + (gravity + (wind + flutter) * 4.0 * k) * dt * dt
	for c in cols:
		_p[c] = _pin(c)
		_o[c] = _p[c]
	for it in stiffness_iters:
		for r in rows:
			for c in cols:
				var i := r * cols + c
				if c + 1 < cols:
					_link(i, i + 1, _rest_u)
				if r + 1 < rows:
					_link(i, i + cols, _rest_v)
					if c + 1 < cols:
						_link(i, i + cols + 1, sqrt(_rest_u * _rest_u + _rest_v * _rest_v))
					if c > 0:
						_link(i, i + cols - 1, sqrt(_rest_u * _rest_u + _rest_v * _rest_v))
		for c in cols:
			_p[c] = _pin(c)
		for col in colliders:
			var n: Node3D = col[0]
			var rad: float = col[1]
			var ctr := n.global_position
			for i in range(cols, _p.size()):
				var d := _p[i] - ctr
				var l := d.length()
				if l < rad and l > 0.0001:
					_p[i] = ctr + d / l * rad
	_draw()


func _link(a: int, b: int, rest: float) -> void:
	var d := _p[b] - _p[a]
	var l := d.length()
	if l < 0.00001:
		return
	var diff := (l - rest) / l * 0.5
	var pa := a < cols            # pinned particles never move
	var pb := b < cols
	if pa and pb:
		return
	if pa:
		_p[b] -= d * diff * 2.0
	elif pb:
		_p[a] += d * diff * 2.0
	else:
		_p[a] += d * diff
		_p[b] -= d * diff


func _draw() -> void:
	var nrm := PackedVector3Array()
	nrm.resize(_p.size())
	var idx := PackedInt32Array()
	for r in rows - 1:
		for c in cols - 1:
			var i := r * cols + c
			idx.append_array([i, i + 1, i + cols, i + 1, i + cols + 1, i + cols])
	for r in rows:
		for c in cols:
			var i := r * cols + c
			var du := _p[mini(i + 1, r * cols + cols - 1)] - _p[maxi(i - 1, r * cols)]
			var dv := _p[mini(i + cols, _p.size() - 1)] - _p[maxi(i - cols, 0)]
			var n := du.cross(dv)
			nrm[i] = n.normalized() if n.length() > 0.00001 else Vector3.BACK
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = _p
	arr[Mesh.ARRAY_NORMAL] = nrm
	arr[Mesh.ARRAY_INDEX] = idx
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	_mi.mesh = am
