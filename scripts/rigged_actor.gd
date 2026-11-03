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
