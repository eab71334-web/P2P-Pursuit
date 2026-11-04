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
var human := false
var _body_mat: StandardMaterial3D
const BASE_M := "res://assets/ubc/base/Superhero_Male_FullBody.gltf"
const BASE_F := "res://assets/ubc/base/Superhero_Female_FullBody.gltf"


static func available() -> bool:
	return ResourceLoader.exists(SRC)


## High-detail human (Quaternius Universal Base Characters, CC0: face, eyes, fingers) driven by the UAL animation clips.
## Same 65-bone skeleton as the mannequin, so every clip plays on it.
func setup_human(female: bool, skin: Color) -> bool:
	var base := load(BASE_F if female else BASE_M) as PackedScene
	var ual := load(SRC) as PackedScene
	if base == null or ual == null:
		return false
	_root = base.instantiate()
	add_child(_root)
	var u := ual.instantiate()
	var uap := u.find_child("AnimationPlayer", true, false) as AnimationPlayer
	player = AnimationPlayer.new()
	_root.add_child(player)
	player.root_node = player.get_path_to(_root)
	var lib := AnimationLibrary.new()
	for a in uap.get_animation_list():
		lib.add_animation(a, uap.get_animation(a))
	player.add_animation_library("", lib)
	u.free()
	human = true
	for mi in _root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.name.begins_with("Eye"):
			continue
		var base_mat := m.mesh.surface_get_material(0)
		if m.name.to_lower().begins_with("super") and base_mat is StandardMaterial3D:
			_body_mat = (base_mat as StandardMaterial3D).duplicate()
			m.set_surface_override_material(0, _body_mat)
	recolor(skin, skin)
	return true


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
	if human:
		if _body_mat:
			var c := main
			_body_mat.albedo_color = Color(clampf(c.r * 1.25, 0, 1), clampf(c.g * 1.25, 0, 1), clampf(c.b * 1.25, 0, 1))
		return
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
				for ci in range(Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM3 + 1):
					a2[ci] = null                  # custom channels need format flags; the garment does not use them
				var am := ArrayMesh.new()
				var fl := Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if per == 8 else 0
				am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a2, [], {}, fl)
				if am.get_surface_count() == 0:
					continue
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


# ------------------------------------------------------------------ hair
var _hair: BoneAttachment3D
const HAIR_DIR := "res://assets/ubc/hair/Origin/"


## style: "SimpleParted" | "Buzzed" | "Long" | "Buns" | "BuzzedFemale" | "" (none); beard adds the beard model.
## Hair is authored in body space; it hangs on the Head bone so it follows every animation.
func set_hair(style: String, color: Color, beard := false) -> void:
	if _hair:
		_hair.queue_free()
		_hair = null
	if not human or (style == "" and not beard):
		return
	var sk := _root.find_child("Skeleton3D", true, false) as Skeleton3D
	var hb := sk.find_bone("Head")
	_hair = BoneAttachment3D.new()
	_hair.bone_name = "Head"
	sk.add_child(_hair)
	var inv := sk.get_bone_global_rest(hb).affine_inverse()
	for part in [style, "Beard" if beard else ""]:
		if part == "":
			continue
		var ps := load(HAIR_DIR + ("Hair_" + part) + ".gltf") as PackedScene
		if ps == null:
			continue
		var n := ps.instantiate() as Node3D
		_hair.add_child(n)
		n.transform = inv
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			var bm := m.mesh.surface_get_material(0)
			if bm is StandardMaterial3D:
				var mat := (bm as StandardMaterial3D).duplicate() as StandardMaterial3D
				mat.albedo_color = color
				m.set_surface_override_material(0, mat)
