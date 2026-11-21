# Copyright (c) 2026 KRG Studios. All rights reserved. See LICENSE.
class_name RealActor
extends Node3D
## EXPERIMENTAL realistic human (Sabak-Engine character, assets/realistic/driver.glb) with its own clips:
## idle walk run sit_drive reach_handle key_pocket exit_car enter_car close_door. Faces -Z, origin at the feet.

const SRC := "res://assets/realistic/driver.glb"
const LOOPS := ["idle", "walk", "run", "sit_drive", "turn_L", "turn_R"]
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
	for a in LOOPS:
		if player.has_animation(a):
			player.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	play("idle")
	return true


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
