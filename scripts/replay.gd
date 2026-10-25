# Copyright (c) 2026 Sabak Studios. All rights reserved. See LICENSE.
class_name ReplayDirector
extends Node
## Instant replay: the world records the last seconds of every car (30 Hz). When a car blows up the player gets a
## REPLAY button: ghost cars replay the moment in slow motion with three cinematic cameras and letterbox bars.

const KEEP := 9.0           # seconds of history
const STEP := 1.0 / 30.0
const SLOW := 0.4            # playback speed
const AVAIL := 12.0          # the button stays this long after the explosion

var frames: Array = []       # {t, tf: Array[Transform3D]}
var boom_t := -100.0         # recorder clock at the explosion
var boom_team := -1
var _clock := 0.0
var _acc := 0.0

var playing := false
var _world: Node
var _ghosts: Array = []
var _cam: Camera3D
var _layer: CanvasLayer
var _prev_cam: Camera3D
var _hidden: Array = []
var _p := 0.0                # playback position (recorder clock)
var _end := 0.0
var _flash: MeshInstance3D
var _boomed := false
var _label: Label
var _shake := 0.0


func record(delta: float, cars: Array) -> void:
	if playing:
		return
	_clock += delta
	_acc += delta
	if _acc < STEP:
		return
	_acc = 0.0
	var tf: Array = []
	for c in cars:
		tf.append((c as Node3D).global_transform if is_instance_valid(c) else Transform3D.IDENTITY)
	frames.append({"t": _clock, "tf": tf})
	while frames.size() > 2 and float(frames[0]["t"]) < _clock - KEEP:
		frames.pop_front()


func mark_boom(team: int) -> void:
	boom_t = _clock
	boom_team = team


func available() -> bool:
	return not playing and boom_team >= 0 and _clock - boom_t < AVAIL and frames.size() > 20


func _pose(i: int, t: float) -> Transform3D:
	# interpolated transform of car i at recorder time t
	var lo := 0
	var hi := frames.size() - 1
	while lo < hi - 1:
		var mid := (lo + hi) / 2
		if float(frames[mid]["t"]) <= t:
			lo = mid
		else:
			hi = mid
	var a: Dictionary = frames[lo]
	var b: Dictionary = frames[hi]
	var span := maxf(float(b["t"]) - float(a["t"]), 0.0001)
	var k := clampf((t - float(a["t"])) / span, 0.0, 1.0)
	return (a["tf"][i] as Transform3D).interpolate_with(b["tf"][i] as Transform3D, k)


func play(world: Node, teams: Array) -> void:
	if playing or not available():
		return
	_world = world
	playing = true
	_boomed = false
	_hidden.clear()
	_prev_cam = world.get_viewport().get_camera_3d()
	for ts in teams:
		var real: Node3D = ts.car
		if real.visible:
			real.visible = false
			_hidden.append(real)
		var g := Car.new()
		var lo: Dictionary = Net.loadouts.get(ts.driver_id, {})
		g.setup(ts.idx, ts.color, true, lo, true)
		g.freeze = true
		world.add_child(g)
		g.global_transform = real.global_transform
		_ghosts.append(g)
	_p = maxf(boom_t - 4.2, float(frames[0]["t"]))
	_end = minf(boom_t + 3.0, float(frames[frames.size() - 1]["t"]))
	_cam = Camera3D.new()
	_cam.fov = 55.0
	_cam.far = 900.0
	world.add_child(_cam)
	_cam.make_current()
	if world.get("hud"):
		(world.hud as CanvasLayer).visible = false
	_build_overlay(world)


func _build_overlay(world: Node) -> void:
	_layer = CanvasLayer.new()
	_layer.layer = 90
	world.add_child(_layer)
	for top in [true, false]:
		var bar := ColorRect.new()
		bar.color = Color.BLACK
		bar.anchor_right = 1.0
		bar.anchor_top = 0.0 if top else 1.0
		bar.anchor_bottom = 0.0 if top else 1.0
		bar.offset_top = 0.0 if top else -64.0
		bar.offset_bottom = 64.0 if top else 0.0
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_layer.add_child(bar)
	_label = Label.new()
	_label.text = "●  " + UI.tx("REPLAY", "إعادة")
	_label.add_theme_font_size_override("font_size", 28)
	_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.25))
	_label.position = Vector2(34, 82)
	_layer.add_child(_label)
	var photo := UI.btn(_layer, UI.tx("PHOTO", "صورة"), UI.ACCENT, func(): Share.snap(world, "replay", UI.tx("Replay", "إعادة سينمائية"), [_layer]), 20, Vector2(150, 48))
	photo.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	photo.offset_left = -340
	photo.offset_top = -58
	photo.offset_right = -190
	photo.offset_bottom = -10
	var close := UI.btn(_layer, UI.tx("Skip", "تخطي"), UI.CARD2, stop, 20, Vector2(150, 48))
	close.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	close.offset_left = -170
	close.offset_top = -58
	close.offset_right = -20
	close.offset_bottom = -10


func stop() -> void:
	if not playing:
		return
	playing = false
	for g in _ghosts:
		if is_instance_valid(g):
			g.queue_free()
	_ghosts.clear()
	for r in _hidden:
		if is_instance_valid(r):
			r.visible = true
	_hidden.clear()
	if _flash and is_instance_valid(_flash):
		_flash.queue_free()
	if _layer and is_instance_valid(_layer):
		_layer.queue_free()
	if _cam and is_instance_valid(_cam):
		_cam.queue_free()
	if _prev_cam and is_instance_valid(_prev_cam):
		_prev_cam.make_current()
	if _world and is_instance_valid(_world) and _world.get("hud"):
		(_world.hud as CanvasLayer).visible = true
	boom_team = -1       # one replay per explosion


func _process(delta: float) -> void:
	if not playing:
		return
	var focus := maxi(boom_team, 0)
	_p += delta * SLOW
	if _p >= _end:
		stop()
		return
	for i in _ghosts.size():
		(_ghosts[i] as Node3D).global_transform = _pose(i, _p)
	var f: Transform3D = _pose(focus, _p)
	var fp := f.origin + Vector3(0, 0.8, 0)
	var to_boom := boom_t - _p
	var tt := _p - (boom_t - 4.2)
	if to_boom > 2.0:
		# 1. tracking shot from the side, ahead of the car
		var fwd := -f.basis.z
		var side := f.basis.x
		_cam.global_position = fp + fwd * 9.0 + side * 6.0 + Vector3(0, 1.4, 0)
		_cam.fov = 50.0
	elif to_boom > -0.4:
		# 2. low and close at the moment of the explosion
		var back := f.basis.z
		_cam.global_position = fp + back * 6.0 - f.basis.x * 3.2 + Vector3(0, 0.5, 0)
		_cam.fov = 70.0
	else:
		# 3. slow orbit that rises over the wreck
		var a := (_p - boom_t) * 1.1
		_cam.global_position = fp + Vector3(cos(a) * 9.0, 2.5 + (_p - boom_t) * 1.2, sin(a) * 9.0)
		_cam.fov = 55.0
	_shake = maxf(0.0, _shake - delta * 2.0)
	if _shake > 0.0:
		_cam.global_position += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * _shake * 0.25
	_cam.look_at(fp, Vector3.UP)
	if not _boomed and _p >= boom_t:
		_boomed = true
		_shake = 1.0
		Sfx.play("boom", -2.0, 0.8)
		_flash = MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 1.0
		sm.height = 2.0
		_flash.mesh = sm
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(1.0, 0.6, 0.15, 0.85)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_flash.material_override = m
		_world.add_child(_flash)
		_flash.global_position = fp
	if _flash and is_instance_valid(_flash):
		var k := clampf((_p - boom_t) / 0.45, 0.0, 1.0)
		_flash.scale = Vector3.ONE * lerpf(0.6, 5.5, k)
		(_flash.material_override as StandardMaterial3D).albedo_color.a = (1.0 - k) * 0.85
		if k >= 1.0:
			_flash.queue_free()
			_flash = null
