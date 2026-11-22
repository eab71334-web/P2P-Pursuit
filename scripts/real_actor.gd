# Copyright (c) 2026 KRG Studios. All rights reserved. See LICENSE.
class_name RealActor
extends Node3D
## EXPERIMENTAL realistic human (Sabak-Engine character, assets/realistic/driver.glb) with its own clips:
## idle walk run sit_drive reach_handle key_pocket exit_car enter_car close_door. Faces -Z, origin at the feet.

const SRC := "res://assets/realistic/driver.glb"
const LOOPS := ["idle", "walk", "jog", "run", "sit_drive", "turn_L", "turn_R"]
var player: AnimationPlayer
var cur := ""


static func available() -> bool:
	return ResourceLoader.exists(SRC)


func setup() -> bool:
	var ps := load(SRC) as PackedScene
	if ps == null:
		return false
	var root := ps.instantiate()
	add_child(root)
	root.rotation.y = PI
	player = root.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if player == null:
		return false
	_retarget_ual(root)
	for a in LOOPS:
		if player.has_animation(a):
			player.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	play("idle")
	return true


## Professional clips from the Universal Animation Library replace the hand-keyed ones (same names), retargeted onto this skeleton
const UAL_MAP := {"idle": "Idle", "walk": "Walk", "jog": "Jog_Fwd", "run": "Sprint", "sit_drive": "Driving", "enter_car": "Sitting_Enter",
	"exit_car": "Sitting_Exit", "reach_handle": "Interact", "close_door": "Push"}
var retargeted := false
var seat_offset := Vector3(0, -0.56, -0.19)


func _retarget_ual(root: Node) -> void:
	var ps := load("res://assets/ual/UAL1.glb") as PackedScene
	var dst_sk := root.find_child("Skeleton3D", true, false) as Skeleton3D
	if ps == null or dst_sk == null:
		return
	var u := ps.instantiate()
	var uap := u.find_child("AnimationPlayer", true, false) as AnimationPlayer
	var src_sk := u.find_child("Skeleton3D", true, false) as Skeleton3D
	if uap == null or src_sk == null:
		u.free()
		return
	var lib := player.get_animation_library("")
	var dst_path := str(root.get_path_to(dst_sk))
	var ok := 0
	for mine in UAL_MAP:
		var sa := uap.get_animation(UAL_MAP[mine]) if uap.has_animation(UAL_MAP[mine]) else null
		if sa == null:
			continue
		var an := Retarget.run(sa, src_sk, dst_sk, dst_path)
		if an == null:
			continue
		if lib.has_animation(mine):
			lib.remove_animation(mine)
		lib.add_animation(mine, an)
		ok += 1
	u.free()
	retargeted = ok > 0
	if retargeted and player.has_animation("sit_drive"):
		var a := player.get_animation("sit_drive")
		for t in a.get_track_count():
			if a.track_get_type(t) == Animation.TYPE_POSITION_3D:
				var p: Vector3 = a.position_track_interpolate(t, 0.0)
				seat_offset = Vector3(0, -p.y, 0.0)


func play(anim: String, speed := 1.0, blend := 0.25) -> void:
	if player == null or not player.has_animation(anim):
		return
	player.speed_scale = speed
	if anim == cur:
		return
	cur = anim
	player.play(anim, blend)


func progress() -> float:
	if player == null or player.current_animation == "":
		return 0.0
	return clampf(player.current_animation_position / maxf(0.01, player.current_animation_length), 0.0, 1.0)


func length_of(anim: String) -> float:
	return player.get_animation(anim).length if player != null and player.has_animation(anim) else 0.0
