class_name RealMod
extends SkeletonModifier3D
## Procedural layer over the clips: one arm reaches a world target (door handle) and the head ducks (leaving a low car).

var target: Node3D = null
var reach := 0.0
var side := "L"
var duck := 0.0
var duck_axis := Vector3.RIGHT


func _swing(sk: Skeleton3D, bone: int, from_dir: Vector3, to_dir: Vector3, k: float) -> void:
	if from_dir.length() < 0.001 or to_dir.length() < 0.001:
		return
	var q := Quaternion(from_dir.normalized(), to_dir.normalized())
	q = Quaternion.IDENTITY.slerp(q, k)
	var par := sk.get_bone_parent(bone)
	var pg := sk.get_bone_global_pose(par).basis.get_rotation_quaternion() if par >= 0 else Quaternion.IDENTITY
	var gg := sk.get_bone_global_pose(bone).basis.get_rotation_quaternion()
	var ng := q * gg
	sk.set_bone_pose_rotation(bone, (pg.inverse() * ng).normalized())


func _process_modification() -> void:
	var sk := get_skeleton()
	if sk == null:
		return
	if duck > 0.001:
		for e in [["spine01", 0.35], ["neck01", 0.8], ["head", 0.9]]:
			var b := sk.find_bone(str(e[0]))
			if b >= 0:
				var q := Quaternion(duck_axis, duck * float(e[1]) * 0.55)
				sk.set_bone_pose_rotation(b, sk.get_bone_pose_rotation(b) * q)
	if reach > 0.001 and target != null and target.is_inside_tree():
		var ub := sk.find_bone("upperarm01." + side)
		var lb := sk.find_bone("lowerarm01." + side)
		var hb := sk.find_bone("wrist." + side)
		if ub < 0 or lb < 0 or hb < 0:
			return
		var inv := sk.global_transform.affine_inverse()
		var tp: Vector3 = inv * target.global_position
		var sh := sk.get_bone_global_pose(ub).origin
		var el := sk.get_bone_global_pose(lb).origin
		var wr := sk.get_bone_global_pose(hb).origin
		var l1 := sh.distance_to(el)
		var l2 := el.distance_to(wr)
		var to_t := tp - sh
		var d := clampf(to_t.length(), 0.05, (l1 + l2) * 0.995)
		var dir := to_t.normalized()
		# elbow: law of cosines, bent away from the body (down / outwards)
		var a := (l1 * l1 - l2 * l2 + d * d) / (2.0 * d)
		var h := sqrt(maxf(l1 * l1 - a * a, 0.0))
		var pole := Vector3(-1.0 if side == "L" else 1.0, -0.7, 0.2).normalized()
		pole = (pole - dir * pole.dot(dir)).normalized()
		var el_new := sh + dir * a + pole * h
		_swing(sk, ub, el - sh, el_new - sh, reach)
		# the lower arm moves with its parent: recompute its current direction
		var el2 := sk.get_bone_global_pose(lb).origin
		var wr2 := sk.get_bone_global_pose(hb).origin
		_swing(sk, lb, wr2 - el2, (sh + dir * d) - el2, reach)
