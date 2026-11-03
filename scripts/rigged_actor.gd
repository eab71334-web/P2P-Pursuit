# Copyright (c) 2026 Sabak Studios. All rights reserved. See LICENSE.
class_name RiggedActor
extends Node3D
## A skinned human mannequin (Quaternius Universal Animation Library, CC0, res://assets/ual) with 45 real animations
## (Dance, Idle_Talking, Driving, Sitting_Idle, Sprint, Hit_Chest, Death01 ...). Cross-fades between them.
## Used for the ceremony spectators; any scene can add one and call play().

const SRC := "res://assets/ual/UAL1.glb"
const ANIMS_LOOP := ["Dance", "Idle", "Idle_Talking", "Walk", "Walk_Formal", "Jog_Fwd", "Sprint", "Driving", "Sitting_Idle", "Sitting_Talking", "Crouch_Idle", "Swim_Idle", "Sword_Idle", "Pistol_Idle", "Spell_Simple_Idle"]

var player: AnimationPlayer
var _root: Node
var _mats: Array = []     # [material, is_joint]


static func available() -> bool:
	return ResourceLoader.exists(SRC)


## main = body colour, joint = joints colour
func setup(main: Color, joint: Color) -> bool:
	var ps := load(SRC) as PackedScene
	if ps == null:
		return false
	_root = ps.instantiate()
	add_child(_root)
	player = _root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	for mi in _root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for s in m.mesh.get_surface_count():
			var base := m.mesh.surface_get_material(s)
			var mat: StandardMaterial3D = (base as StandardMaterial3D).duplicate() if base is StandardMaterial3D else StandardMaterial3D.new()
			var nm := str(base.resource_name) if base != null else ""
			mat.albedo_color = joint if nm.contains("Joint") else main
			mat.emission_enabled = true
			mat.emission = mat.albedo_color * 0.35
			m.set_surface_override_material(s, mat)
			_mats.append([mat, nm.contains("Joint")])
	return player != null


func play(anim: String, speed := 1.0, offset := 0.0, blend := 0.3) -> void:
	if player == null or not player.has_animation(anim):
		return
	var a := player.get_animation(anim)
	if ANIMS_LOOP.has(anim):
		a.loop_mode = Animation.LOOP_LINEAR
	player.play(anim, blend)
	player.speed_scale = speed
	if offset > 0.0:
		player.seek(offset * a.length, true)


func recolor(main: Color, joint: Color) -> void:
	for e in _mats:
		var m := e[0] as StandardMaterial3D
		m.albedo_color = joint if e[1] else main
		m.emission = m.albedo_color * 0.35


# ------------------------------------------------------------------ clothing
## Real garments: layers cut from the skinned body (by bone weights), pushed out a little along the normals, so they follow
## every animation / IK pose exactly. shirt (torso + sleeves), pants (hips + legs), shoes (feet). Skin stays visible elsewhere.
var _cloth_nodes: Array = []
var _bone_group: Dictionary = {}


func _group_of(bone: String, long_sleeve: bool) -> String:
	if bone in ["spine_01", "spine_02", "spine_03", "clavicle_l", "clavicle_r"]:
		return "shirt"
	if bone.begins_with("upperarm"):
		return "shirt"
	if bone.begins_with("lowerarm"):
		return "shirt" if long_sleeve else ""
	if bone == "pelvis" or bone.begins_with("thigh") or bone.begins_with("calf"):
		return "pants"
	if bone.begins_with("foot") or bone.begins_with("ball"):
		return "shoes"
	return ""


func dress(shirt: Color, pants: Color, shoes: Color, skin: Color, long_sleeve: bool, shirt_stripe := Color.TRANSPARENT) -> void:
	for n in _cloth_nodes:
		(n as Node).queue_free()
	_cloth_nodes.clear()
	recolor(skin, skin.darkened(0.15))
	if _root == null:
		return
	var cols := {"shirt": shirt, "pants": pants, "shoes": shoes}
	var push := {"shirt": 0.016, "pants": 0.014, "shoes": 0.02}
	for mi in _root.find_children("*", "MeshInstance3D", true, false):
		var src := mi as MeshInstance3D
		if src.skin == null or src.mesh == null or src in _cloth_nodes:
			continue
		var sk := src.get_node_or_null(src.skeleton) as Skeleton3D
		if sk == null:
			continue
		for s in src.mesh.get_surface_count():
			var arr: Array = src.mesh.surface_get_arrays(s)
			var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			var ns: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
			var bs: PackedInt32Array = arr[Mesh.ARRAY_BONES]
			var ws: PackedFloat32Array = arr[Mesh.ARRAY_WEIGHTS]
			var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
			if idx.is_empty() or bs.is_empty():
				continue
			var per := bs.size() / vs.size()            # 4 or 8 influences per vertex
			var grp: Array = []
			for v in vs.size():
				var best := -1.0
				var bi := 0
				for j in per:
					if ws[v * per + j] > best:
						best = ws[v * per + j]
						bi = bs[v * per + j]
				var nm := src.skin.get_bind_name(bi)
				if nm == "":
					nm = sk.get_bone_name(src.skin.get_bind_bone(bi))
				grp.append(_group_of(nm, long_sleeve))
			for g in ["shirt", "pants", "shoes"]:
				var keep := PackedInt32Array()
				for t in range(0, idx.size(), 3):
					if grp[idx[t]] == g and grp[idx[t + 1]] == g and grp[idx[t + 2]] == g:
						keep.append_array([idx[t], idx[t + 1], idx[t + 2]])
				if keep.is_empty():
					continue
				var a2 := arr.duplicate()
				var nv := vs.duplicate()
				for v in nv.size():
					nv[v] += ns[v] * float(push[g])
				a2[Mesh.ARRAY_VERTEX] = nv
				a2[Mesh.ARRAY_INDEX] = keep
				var am := ArrayMesh.new()
				am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a2)
				var cm := MeshInstance3D.new()
				cm.mesh = am
				cm.skin = src.skin
				src.get_parent().add_child(cm)
				cm.skeleton = cm.get_path_to(sk)
				var m := StandardMaterial3D.new()
				m.albedo_color = cols[g]
				m.roughness = 0.85 if g != "shoes" else 0.55
				m.emission_enabled = true
				m.emission = (cols[g] as Color) * 0.3
				cm.material_override = m
				_cloth_nodes.append(cm)
