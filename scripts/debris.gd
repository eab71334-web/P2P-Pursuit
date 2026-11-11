# Copyright (c) 2026 KRG Studios. All rights reserved. See LICENSE.
class_name Debris
extends RefCounted
## Voronoi fracture, in script (no add-on): a box of body panel is cut into convex shards - each shard is the
## Voronoi cell of a random seed, built from half-space planes - and thrown as little rigid bodies.
## Used for hard crashes and for the car explosion. Amount follows the graphics quality (Gfx.fx), total shards are capped.

const MAX_LIVE := 36
static var _live := 0


## convex cells of a Voronoi diagram inside a box (half size `half`). Returns [{points: PackedVector3Array, planes: Array}]
static func cells(seeds: Array, half: Vector3) -> Array:
	var out: Array = []
	for i in seeds.size():
		var planes: Array = [[Vector3(1, 0, 0), half.x], [Vector3(-1, 0, 0), half.x], [Vector3(0, 1, 0), half.y],
			[Vector3(0, -1, 0), half.y], [Vector3(0, 0, 1), half.z], [Vector3(0, 0, -1), half.z]]
		var si: Vector3 = seeds[i]
		for j in seeds.size():
			if j == i:
				continue
			var n: Vector3 = (seeds[j] as Vector3) - si
			var m: Vector3 = (si + (seeds[j] as Vector3)) * 0.5
			var nl := n.length()
			if nl < 0.0001:
				continue
			n /= nl
			planes.append([n, n.dot(m)])
		var pts: Array = []
		var np := planes.size()
		for a in np:
			for b in range(a + 1, np):
				for c in range(b + 1, np):
					var na: Vector3 = planes[a][0]
					var nb: Vector3 = planes[b][0]
					var nc: Vector3 = planes[c][0]
					var det := na.dot(nb.cross(nc))
					if absf(det) < 0.00001:
						continue
					var x: Vector3 = (nb.cross(nc) * float(planes[a][1]) + nc.cross(na) * float(planes[b][1]) + na.cross(nb) * float(planes[c][1])) / det
					var ok := true
					for pl in planes:
						if (pl[0] as Vector3).dot(x) > float(pl[1]) + 0.0002:
							ok = false
							break
					if ok:
						var dup := false
						for q in pts:
							if (q as Vector3).distance_squared_to(x) < 0.000001:
								dup = true
								break
						if not dup:
							pts.append(x)
		if pts.size() >= 4:
			out.append({"points": PackedVector3Array(pts), "planes": planes})
	return out


## flat-shaded mesh of one convex cell (every plane that has >= 3 points becomes a fan), centred on the cell centre
static func cell_mesh(cell: Dictionary, centre: Vector3) -> ArrayMesh:
	var pts: PackedVector3Array = cell["points"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for pl in cell["planes"]:
		var n: Vector3 = pl[0]
		var d: float = pl[1]
		var face: Array = []
		for p in pts:
			if absf(n.dot(p) - d) < 0.0015:
				face.append(p)
		if face.size() < 3:
			continue
		var c := Vector3.ZERO
		for p in face:
			c += p as Vector3
		c /= float(face.size())
		var u: Vector3 = ((face[0] as Vector3) - c).normalized()
		var v: Vector3 = n.cross(u)
		face.sort_custom(func(a, b): return atan2(((a as Vector3) - c).dot(v), ((a as Vector3) - c).dot(u)) < atan2(((b as Vector3) - c).dot(v), ((b as Vector3) - c).dot(u)))
		st.set_normal(n)
		for k in range(1, face.size() - 1):
			st.add_vertex(face[0] - centre)
			st.add_vertex(face[k] - centre)
			st.add_vertex(face[k + 1] - centre)
	return st.commit()


## throw shards of a body panel from `origin`. force = how hard (1 = a crash, 2 = explosion)
static func burst(world: Node, origin: Vector3, color: Color, force := 1.0, dir := Vector3.UP, amount := 8) -> int:
	if world == null or not is_instance_valid(world):
		return 0
	var fx := clampf(Gfx.fx, 0.0, 1.0)
	var n := int(round(float(amount) * fx))
	n = mini(n, MAX_LIVE - _live)
	if n < 3 and fx > 0.2 and _live < MAX_LIVE:
		n = 3
	if n < 3:
		return 0
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var half := Vector3(0.45, 0.3, 0.6)
	var seeds: Array = []
	for i in n:
		seeds.append(Vector3(rng.randf_range(-half.x, half.x), rng.randf_range(-half.y, half.y), rng.randf_range(-half.z, half.z)))
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.metallic = 0.3
	mat.roughness = 0.6
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var made := 0
	for cell in cells(seeds, half):
		var pts: PackedVector3Array = cell["points"]
		var c := Vector3.ZERO
		for p in pts:
			c += p
		c /= float(pts.size())
		var local := PackedVector3Array()
		for p in pts:
			local.append(p - c)
		var rb := RigidBody3D.new()
		rb.collision_layer = 2
		rb.collision_mask = 1
		rb.mass = 6.0
		var cs := CollisionShape3D.new()
		var sh := ConvexPolygonShape3D.new()
		sh.points = local
		cs.shape = sh
		rb.add_child(cs)
		var mi := MeshInstance3D.new()
		mi.mesh = cell_mesh(cell, c)
		mi.material_override = mat
		rb.add_child(mi)
		world.add_child(rb)
		rb.global_position = origin + Vector3(c.x, c.y, c.z) * 1.2
		var out := (c.normalized() + dir).normalized()
		rb.linear_velocity = out * rng.randf_range(3.0, 7.0) * force + Vector3(0, rng.randf_range(2.0, 6.0) * force, 0)
		rb.angular_velocity = Vector3(rng.randf_range(-9, 9), rng.randf_range(-9, 9), rng.randf_range(-9, 9))
		_live += 1
		made += 1
		var tw := rb.create_tween()
		tw.tween_interval(5.0)
		tw.tween_property(rb, "scale", Vector3(0.01, 0.01, 0.01), 1.0)      # shrink away instead of popping out
		tw.tween_callback(func():
			_live = maxi(_live - 1, 0)
			rb.queue_free())
	return made
