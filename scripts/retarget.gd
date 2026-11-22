# Copyright (c) 2026 KRG Studios. All rights reserved. See LICENSE.
class_name Retarget
extends RefCounted
## Runtime animation retargeting between two humanoid skeletons with different rest poses (world-space delta transfer).
## Used to play the Quaternius Universal Animation Library clips (CC0, assets/ual) on the realistic Sabak human.

const MAP := {
	"pelvis": "root", "spine_01": "spine05", "spine_02": "spine03", "spine_03": "spine01", "neck_01": "neck01", "Head": "head",
	"clavicle_l": "clavicle.L", "upperarm_l": "upperarm01.L", "lowerarm_l": "lowerarm01.L", "hand_l": "wrist.L",
	"clavicle_r": "clavicle.R", "upperarm_r": "upperarm01.R", "lowerarm_r": "lowerarm01.R", "hand_r": "wrist.R",
	"thigh_l": "upperleg01.L", "calf_l": "lowerleg01.L", "foot_l": "foot.L",
	"thigh_r": "upperleg01.R", "calf_r": "lowerleg01.R", "foot_r": "foot.R",
}
## bone -> the bone it points at (used to align the target rest pose to the source rest pose, e.g. T-pose arms vs A-pose arms)
const POINTS := {
	"pelvis": "spine_01", "spine_01": "spine_02", "spine_02": "spine_03", "spine_03": "neck_01", "neck_01": "Head",
	"clavicle_l": "upperarm_l", "upperarm_l": "lowerarm_l", "lowerarm_l": "hand_l", "hand_l": "middle_01_l",
	"clavicle_r": "upperarm_r", "upperarm_r": "lowerarm_r", "lowerarm_r": "hand_r", "hand_r": "middle_01_r",
	"thigh_l": "calf_l", "calf_l": "foot_l", "foot_l": "ball_l", "thigh_r": "calf_r", "calf_r": "foot_r", "foot_r": "ball_r",
}
const FINGERS := {"thumb": "1", "index": "2", "middle": "3", "ring": "4", "pinky": "5"}


static func bone_map() -> Dictionary:
	var m := MAP.duplicate()
	for side in ["l", "r"]:
		for f in FINGERS:
			for k in [1, 2, 3]:
				m["%s_0%d_%s" % [f, k, side]] = "finger%s-%d.%s" % [FINGERS[f], k, side.to_upper()]
	return m


static func _grest(sk: Skeleton3D) -> Array:
	var g: Array = []
	for i in sk.get_bone_count():
		var p := sk.get_bone_parent(i)
		var q: Quaternion = sk.get_bone_rest(i).basis.get_rotation_quaternion()
		g.append((g[p] as Quaternion) * q if p >= 0 else q)
	return g


## returns the retargeted Animation (tracks "<dst_path>:<bone>") or null
static func run(src: Animation, src_sk: Skeleton3D, dst_sk: Skeleton3D, dst_path: String, fps := 30) -> Animation:
	var map := bone_map()
	var ns := src_sk.get_bone_count()
	var nd := dst_sk.get_bone_count()
	var rot_tr := {}                 # src bone -> track index
	var pos_tr := {}
	for t in src.get_track_count():
		var path := str(src.track_get_path(t))
		var nm := path.get_slice(":", 1) if path.contains(":") else ""
		var bi := src_sk.find_bone(nm)
		if bi < 0:
			continue
		match src.track_get_type(t):
			Animation.TYPE_ROTATION_3D:
				rot_tr[bi] = t
			Animation.TYPE_POSITION_3D:
				pos_tr[bi] = t
	var gs_rest := _grest(src_sk)
	var gd_rest := _grest(dst_sk)
	var inv := {}                    # dst bone -> src bone
	for sb in ns:
		var dn: String = map.get(src_sk.get_bone_name(sb), "")
		if dn != "":
			var di := dst_sk.find_bone(dn)
			if di >= 0:
				inv[di] = sb
	if not inv.has(0) and not inv.has(dst_sk.find_bone("root")):
		return null
	# the target's rest pose is rotated, bone by bone, so every limb points the same way as in the source rest pose
	var gd_ref: Array = gd_rest.duplicate()
	var sp_rest: Array = []
	for i in ns:
		sp_rest.append(src_sk.get_bone_global_rest(i).origin)
	var dp_rest: Array = []
	for i in nd:
		dp_rest.append(dst_sk.get_bone_global_rest(i).origin)
	for di in inv:
		var sb: int = inv[di]
		var pt: String = POINTS.get(src_sk.get_bone_name(sb), "")
		if pt == "":
			continue
		var sc := src_sk.find_bone(pt)
		var dc := dst_sk.find_bone(map.get(pt, ""))
		if sc < 0 or dc < 0:
			continue
		var ds: Vector3 = ((sp_rest[sc] as Vector3) - (sp_rest[sb] as Vector3)).normalized()
		var dd: Vector3 = ((dp_rest[dc] as Vector3) - (dp_rest[di] as Vector3)).normalized()
		if ds.length() < 0.5 or dd.length() < 0.5:
			continue
		var r := Quaternion(dd, ds)
		gd_ref[di] = r * (gd_rest[di] as Quaternion)
	var out := Animation.new()
	out.length = src.length
	out.loop_mode = src.loop_mode
	var otr := {}
	for di in inv:
		var t := out.add_track(Animation.TYPE_ROTATION_3D)
		out.track_set_path(t, NodePath("%s:%s" % [dst_path, dst_sk.get_bone_name(di)]))
		otr[di] = t
	var root_i := dst_sk.find_bone("root")
	var root_t := out.add_track(Animation.TYPE_POSITION_3D)
	out.track_set_path(root_t, NodePath("%s:%s" % [dst_path, "root"]))
	var src_hips := src_sk.find_bone("pelvis")
	var hip_scale := 1.0
	var sh := src_sk.get_bone_global_rest(src_hips).origin.y
	var dh := dst_sk.get_bone_global_rest(root_i).origin.y
	if sh > 0.01:
		hip_scale = dh / sh
	var frames := int(ceil(src.length * fps)) + 1
	for f in frames:
		var t := minf(f / float(fps), src.length)
		var gs: Array = []
		for i in ns:
			var q: Quaternion = src_sk.get_bone_rest(i).basis.get_rotation_quaternion()
			if rot_tr.has(i):
				q = src.rotation_track_interpolate(rot_tr[i], t)
			var p := src_sk.get_bone_parent(i)
			gs.append((gs[p] as Quaternion) * q if p >= 0 else q)
		var gd: Array = []
		for i in nd:
			var p := dst_sk.get_bone_parent(i)
			var local: Quaternion
			var glob: Quaternion
			if inv.has(i):
				var sb: int = inv[i]
				var delta: Quaternion = (gs[sb] as Quaternion) * (gs_rest[sb] as Quaternion).inverse()
				glob = delta * (gd_ref[i] as Quaternion)
				local = (gd[p] as Quaternion).inverse() * glob if p >= 0 else glob
				out.rotation_track_insert_key(otr[i], t, local)
			else:
				local = dst_sk.get_bone_rest(i).basis.get_rotation_quaternion()
				glob = (gd[p] as Quaternion) * local if p >= 0 else local
			gd.append(glob)
		var rp: Vector3 = dst_sk.get_bone_rest(root_i).origin
		if pos_tr.has(src_hips):
			var sp: Vector3 = src.position_track_interpolate(pos_tr[src_hips], t)
			var srest: Vector3 = src_sk.get_bone_rest(src_hips).origin
			var d := sp - srest
			rp += Vector3(0, d.y, 0) * hip_scale + Vector3(0, 0, d.z) * hip_scale * 0.0
		out.position_track_insert_key(root_t, t, rp)
	return out
