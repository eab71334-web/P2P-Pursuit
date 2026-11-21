# Copyright (c) 2026 KRG Studios. All rights reserved. See LICENSE.
class_name RealCar
extends RefCounted
## EXPERIMENT: realistic car bodies (SABAK Studio asset repo, glTF, used untouched: no decimation, no texture change).
## The only change is the unit scale (the files are authored in centimetres) and turning the nose to -Z.
## Wheel meshes are found by size/position, so the 4 wheels (tyre + rim + disc) spin and steer with the physics wheels.

const DIR := "res://assets/realistic/"
const CARS := {
	"hatch": {"f": "2015_jaguar_f-type_r_coupe.glb", "s": 100.0, "n": ["Jag F-Coupe", "جاغ F كوبيه"]},
	# "coupe" (Mercedes C-coupe) is parked: in that file the wheels are skinned to a bone and do not render, the body floats
	"m4": {"f": "2021_bmw_m4_competition.glb", "s": 0.73, "n": ["Bavaria M-400", "بافاريا M-400"]},
	"gt3": {"f": "2020_porsche_718_cayman_gt4.glb", "s": 100.0, "n": ["Stuttgart GT-4", "شتوتغارت GT-4"]},
	"hyper": {"f": "2019_nissan_gt-r_r35_varis_kamikaze_r_supersonic.glb", "s": 100.0, "n": ["Ryu GT-R", "ريو GT-R"]},
}
static var _info := {}


static func has(model: String) -> bool:
	return Gfx.realistic and CARS.has(model) and ResourceLoader.exists(DIR + str(CARS[model]["f"]))


static func _xf(model: String) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, PI).scaled(Vector3.ONE * float(CARS[model]["s"])), Vector3.ZERO)


static func _rel(n: Node3D, root: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var c: Node = n
	while c != null and c != root:
		t = (c as Node3D).transform * t
		c = c.get_parent()
	return t


## [mesh, aabb in car space, transform in car space]
static func _meshes(root: Node3D, xf: Transform3D) -> Array:
	var out: Array = []
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		var t := xf * _rel(m, root)
		out.append([m, t * m.get_aabb(), t])
	return out


## cached per model: wheel centres (car space, x right, -z forward), wheel radius, body box
static func info(model: String) -> Dictionary:
	if _info.has(model):
		return _info[model]
	var ps := load(DIR + str(CARS[model]["f"])) as PackedScene
	var root := ps.instantiate() as Node3D
	var tmp := Node3D.new()
	tmp.add_child(root)
	var ms := _meshes(root, _xf(model))
	var box := AABB()
	var first := true
	for e in ms:
		box = (e[1] as AABB) if first else box.merge(e[1])
		first = false
	var sum := {}
	var cnt := {}
	var rad := 0.0
	for e in ms:
		var a: AABB = e[1]
		var c := a.get_center()
		if a.size.x < 0.45 and a.size.y > 0.5 and a.size.y < 0.95 and absf(a.size.y - a.size.z) < 0.14 and a.position.y < 0.12 and absf(c.x) > 0.55:
			var key := (1 if c.x > 0.0 else 0) + (2 if c.z > 0.0 else 0)
			sum[key] = Vector3(sum.get(key, Vector3.ZERO)) + c
			cnt[key] = int(cnt.get(key, 0)) + 1
			rad = maxf(rad, a.size.y * 0.5)
	var wc := {}
	for k in cnt.keys():
		wc[k] = Vector3(sum[k]) / float(cnt[k])
	var d := {"box": box, "wheels": wc, "radius": rad, "ok": wc.size() == 4}
	if not d["ok"] and CARS[model].has("fb"):          # wheel meshes cannot be told apart in this file: fixed wheel layout, wheels stay part of the body
		var fb: Array = CARS[model]["fb"]
		wc = {0: Vector3(-fb[0], fb[2], -fb[1]), 1: Vector3(fb[0], fb[2], -fb[1]), 2: Vector3(-fb[0], fb[2], fb[1]), 3: Vector3(fb[0], fb[2], fb[1])}
		d = {"box": box, "wheels": wc, "radius": fb[2], "ok": true, "static_wheels": true}
	tmp.free()
	_info[model] = d
	return d


## wheel position for corner (sx = +1 right, sz = +1 rear), falls back to the stock layout
static func wheel_pos(model: String, sx: float, sz: float) -> Vector3:
	var d := info(model)
	if d["ok"]:
		var key := (1 if sx > 0.0 else 0) + (2 if sz > 0.0 else 0)
		var p: Vector3 = d["wheels"][key]
		return Vector3(p.x, p.y, p.z)
	return Vector3(0.95 * sx, 0.45, 1.3 * sz)


## adds the body to `car`; wheel meshes are moved under `wheel_nodes` ([fl, fr, rl, rr] sorted by position)
static func attach(car: Node3D, model: String, wheel_nodes: Dictionary) -> Node3D:
	var ps := load(DIR + str(CARS[model]["f"])) as PackedScene
	var root := ps.instantiate() as Node3D
	var holder := Node3D.new()
	holder.name = "RealBody"
	car.add_child(holder)
	holder.add_child(root)
	holder.position.y = float(CARS[model].get("lift", 0.0))
	root.transform = _xf(model)
	var ms := _meshes(root, _xf(model))
	var d := info(model)
	if d["ok"] and not d.get("static_wheels", false):
		for e in ms:
			var a: AABB = e[1]
			var c := a.get_center()
			if a.size.x < 0.45 and a.size.y > 0.5 and a.size.y < 0.95 and absf(a.size.y - a.size.z) < 0.14 and a.position.y < 0.12 and absf(c.x) > 0.55:
				var key := (1 if c.x > 0.0 else 0) + (2 if c.z > 0.0 else 0)
				var wn: Node3D = wheel_nodes.get(key)
				if wn == null:
					continue
				var m := e[0] as MeshInstance3D
				var t: Transform3D = e[2]
				m.get_parent().remove_child(m)
				wn.add_child(m)
				m.transform = Transform3D(t.basis, t.origin - (wn.get_meta("center") as Vector3))
	return holder
