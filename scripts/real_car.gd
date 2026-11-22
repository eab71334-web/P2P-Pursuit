# Copyright (c) 2026 KRG Studios. All rights reserved. See LICENSE.
class_name RealCar
extends RefCounted
## EXPERIMENT: realistic car bodies (SABAK Studio asset repo, glTF, used untouched: no decimation, no texture change).
## The only change is the unit scale (the files are authored in centimetres) and turning the nose to -Z.
## Wheel meshes are found by size/position, so the 4 wheels (tyre + rim + disc) spin and steer with the physics wheels.

const DIR := "res://assets/realistic/"
const CARS := {
	"hatch": {"f": "2015_jaguar_f-type_r_coupe.glb", "s": 100.0, "door": "doorl", "n": ["Jag F-Coupe", "جاغ F كوبيه"]},
	# "coupe" (Mercedes C-coupe) is parked: in that file the wheels are skinned to a bone and do not render, the body floats
	"m4": {"f": "2021_bmw_m4_competition.glb", "s": 0.73, "door": "driver_door", "n": ["Bavaria M-400", "بافاريا M-400"]},
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
				m.set_meta("real", true)
	_split_door(car, model, ms)
	return holder


## the driver's door meshes (found by name, left side) move under the car's hinged door pivot, so the door really swings open
static func _split_door(car: Node3D, model: String, ms: Array) -> void:
	var key := str(CARS[model].get("door", ""))
	var pivot := car.get("door_pivot") as Node3D
	var handle := car.get("door_handle") as Node3D
	if pivot == null or handle == null:
		return
	if key == "":
		handle.position = Vector3(-0.06, 0.95, 0.5)
		return
	var parts: Array = []
	var box := AABB()
	for e in ms:
		var nm := String((e[0] as Node).name).to_lower()
		var a: AABB = e[1]
		if nm.contains(key) and a.get_center().x < -0.3:
			box = a if parts.is_empty() else box.merge(a)
			parts.append(e)
	if parts.is_empty():
		return
	var hinge := Vector3(box.get_center().x, 0.0, box.position.z + 0.05)
	pivot.position = hinge + Vector3(0, float(CARS[model].get("lift", 0.0)), 0)
	for e in parts:
		var m := e[0] as MeshInstance3D
		var t: Transform3D = e[2]
		m.get_parent().remove_child(m)
		pivot.add_child(m)
		m.transform = Transform3D(t.basis, t.origin - hinge)
		m.set_meta("real", true)
	handle.position = Vector3(box.position.x - hinge.x - 0.03, 0.98, box.end.z - 0.3 - hinge.z)



# ---------------------------------------------------------------- garage card thumbnails (real renders, cached)
static var _thumbs := {}
static var _pending := {}


## fills `rect` with a render of the car (3/4 view); rendered once per model, then cached
static func thumb_into(rect: TextureRect, model: String) -> void:
	if _thumbs.has(model):
		rect.texture = _thumbs[model]
		return
	if not _pending.has(model):
		_pending[model] = []
		_render_thumb(model)
	(_pending[model] as Array).append(weakref(rect))


static func _render_thumb(model: String) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var vp := SubViewport.new()
	vp.size = Vector2i(512, 256)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var ps := load(DIR + str(CARS[model]["f"])) as PackedScene
	var root := ps.instantiate() as Node3D
	root.transform = _xf(model)
	vp.add_child(root)
	var d := info(model)
	var bb: AABB = d["box"]
	var c := bb.get_center()
	var cam := Camera3D.new()
	cam.fov = 28.0
	cam.near = 0.5
	cam.far = 60.0
	vp.add_child(cam)
	cam.position = c + Vector3(-3.7, 0.8, -5.4)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-38, -145, 0)
	sun.light_energy = 1.4
	vp.add_child(sun)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.78, 0.85)
	env.ambient_light_energy = 0.9
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	tree.root.add_child(vp)
	cam.look_at(c + Vector3(0, -0.1, 0))
	cam.make_current()
	for i in 6:
		await tree.process_frame
	var img := vp.get_texture().get_image()
	var tex := ImageTexture.create_from_image(img)
	_thumbs[model] = tex
	for w in _pending[model]:
		var r = (w as WeakRef).get_ref()
		if r != null:
			(r as TextureRect).texture = tex
	_pending.erase(model)
	vp.queue_free()
