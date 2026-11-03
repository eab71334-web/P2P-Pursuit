# Copyright (c) 2026 Sabak Studios. All rights reserved. See LICENSE.
class_name FxEffekseer
extends RefCounted
## Safe bridge to the Effekseer plugin (experiment branch). If the plugin is not in the build, every call is a no-op,
## so the game runs the same with or without it. Effects (.efkefc) are made in the Effekseer editor on a computer
## and put in res://effects/.

static func available() -> bool:
	return ClassDB.class_exists("EffekseerEmitter3D")


## play res://effects/<name>.efkefc once at a world position
static func play(world: Node, name: String, pos: Vector3, scale := 1.0) -> void:
	if not available() or world == null:
		return
	var path := "res://effects/%s.efkefc" % name
	if not ResourceLoader.exists(path):
		return
	var e = ClassDB.instantiate("EffekseerEmitter3D")
	e.effect = load(path)
	e.scale = Vector3(scale, scale, scale)
	world.add_child(e)
	e.global_position = pos
	e.play()
	e.finished.connect(e.queue_free)
