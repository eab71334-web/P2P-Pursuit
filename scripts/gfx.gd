# Copyright (c) 2026 AVF. All rights reserved. See LICENSE.
extends Node
## Autoload "Gfx": performance + quality settings (frame rate cap, presets, weak-device mode, dynamic resolution)
## and audio levels. Every heavy feature of the game asks this node how much it may spend.

signal changed

const FPS_OPTIONS := [30, 45, 60, 90, 120, 0]            # 0 = unlimited
const PRESET_ORDER := ["weak", "low", "medium", "high"]
## per-preset values. dist = view distance factor, fx = particle amount factor, mirrors: 0 off / 1 side / 2 full,
## map_fps = refresh rate of the map screen, trees = scenery density, hero = animated 3D showroom in menus
const PRESETS := {
	"weak": {"scale": 0.55, "msaa": 0, "dist": 0.35, "fx": 0.25, "mirrors": 0, "map_fps": 8, "trees": 0.3, "hero": false, "fps": 30, "auto": true, "mirror_fps": 10},
	"low": {"scale": 0.7, "msaa": 0, "dist": 0.55, "fx": 0.5, "mirrors": 1, "map_fps": 15, "trees": 0.55, "hero": true, "fps": 30, "auto": true, "mirror_fps": 15},
	"medium": {"scale": 0.85, "msaa": 0, "dist": 0.8, "fx": 0.8, "mirrors": 2, "map_fps": 24, "trees": 0.85, "hero": true, "fps": 60, "auto": false, "mirror_fps": 24},
	"high": {"scale": 1.0, "msaa": 2, "dist": 1.0, "fx": 1.0, "mirrors": 2, "map_fps": 60, "trees": 1.0, "hero": true, "fps": 60, "auto": false, "mirror_fps": 30},
}
const KEYS := ["scale", "msaa", "dist", "fx", "mirrors", "map_fps", "trees", "hero", "fps", "auto", "mirror_fps"]
const SAVE := "user://gfx.cfg"

var preset := "auto"          # auto | weak | low | medium | high | custom
var fps := 60
var scale := 1.0              # 3D resolution scale
var msaa := 0                 # 0 / 2 / 4
var dist := 1.0
var fx := 1.0
var mirrors := 2
var map_fps := 30
var mirror_fps := 30
var trees := 1.0
var hero := true
var auto := false             # dynamic resolution
var show_fps := false
var vsync := true
var haptics := true
var vol_master := 1.0
var vol_radio := 0.7
var racing := false           # set by the world while a race is on (dynamic resolution only works then)

var _cur_scale := 1.0
var _acc := 0.0
var _frames := 0
var _good := 0.0
var _fps_label: Label
var _fps_layer: CanvasLayer
var shown_fps := 60.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load()
	if preset == "auto":
		_apply_preset(detect())
	apply()
	get_tree().root.size_changed.connect(apply_viewport)


## best guess for this device (first start)
func detect() -> String:
	var gpu := RenderingServer.get_video_adapter_name().to_lower()
	var cores := OS.get_processor_count()
	var weak_gpu := false
	for w in ["mali-4", "mali-t", "mali-g31", "mali-g51", "mali-g52", "adreno (tm) 3", "adreno (tm) 4", "adreno (tm) 5", "powervr", "videocore", "llvmpipe", "swiftshader", "intel(r) hd"]:
		if gpu.contains(w):
			weak_gpu = true
	if weak_gpu or cores <= 3:
		return "weak" if (cores <= 4 and weak_gpu) else "low"
	var mobile := OS.has_feature("mobile") or OS.get_name() in ["Android", "iOS"]
	if mobile:
		return "low" if cores <= 4 else "medium"
	return "high"


func preset_label(p: String) -> String:
	match p:
		"weak": return UI.tx("Weak device", "جهاز ضعيف")
		"low": return UI.tx("Low", "منخفض")
		"medium": return UI.tx("Medium", "متوسط")
		"high": return UI.tx("High", "عالي")
		"auto": return UI.tx("Auto", "تلقائي")
	return UI.tx("Custom", "مخصص")


func set_preset(p: String) -> void:
	preset = p
	if p == "auto":
		_apply_preset(detect())
	elif PRESETS.has(p):
		_apply_preset(p)
	apply()
	save()


func _apply_preset(p: String) -> void:
	var d: Dictionary = PRESETS[p]
	for k in KEYS:
		set(k, d[k])


## change one advanced value; the preset becomes "custom"
func set_value(key: String, v) -> void:
	set(key, v)
	preset = "custom"
	apply()
	save()


func apply() -> void:
	Engine.max_fps = fps
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if (vsync and fps != 0 and fps <= 60) else DisplayServer.VSYNC_DISABLED)
	_cur_scale = scale
	apply_viewport()
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(vol_master, 0.0001)))
	_update_fps_overlay()
	changed.emit()


func apply_viewport() -> void:
	var vp := get_tree().root
	vp.msaa_3d = {0: Viewport.MSAA_DISABLED, 2: Viewport.MSAA_2X, 4: Viewport.MSAA_4X}.get(msaa, Viewport.MSAA_DISABLED)
	vp.scaling_3d_scale = clampf(_cur_scale, 0.35, 1.0)
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR


## helpers for the rest of the game
func particles(n: int) -> int:
	return maxi(3, int(round(n * fx)))


func far_clip() -> float:
	return 2500.0 if dist >= 0.99 else 900.0 * dist + 120.0


func fog_mul() -> float:
	return 1.0 / maxf(dist, 0.25)


func subviewport_msaa() -> int:
	return Viewport.MSAA_2X if msaa >= 2 else Viewport.MSAA_DISABLED


func _process(d: float) -> void:
	_acc += d
	_frames += 1
	if _acc >= 0.5:
		shown_fps = _frames / _acc
		if _fps_label:
			_fps_label.text = "%d FPS" % int(round(shown_fps))
		# dynamic resolution: only while racing
		if auto and racing:
			var target := float(fps) if fps > 0 else 60.0
			target = minf(target, 60.0)
			if shown_fps < target * 0.86:
				_good = 0.0
				_cur_scale = maxf(0.5, _cur_scale - 0.06)
				apply_viewport()
			elif shown_fps > target * 0.96:
				_good += _acc
				if _good > 4.0 and _cur_scale < scale:
					_good = 0.0
					_cur_scale = minf(scale, _cur_scale + 0.04)
					apply_viewport()
		elif _cur_scale != scale:
			_cur_scale = scale
			apply_viewport()
		_acc = 0.0
		_frames = 0


func _update_fps_overlay() -> void:
	if show_fps and _fps_layer == null:
		_fps_layer = CanvasLayer.new()
		_fps_layer.layer = 120
		add_child(_fps_layer)
		_fps_label = Label.new()
		_fps_label.add_theme_font_size_override("font_size", 16)
		_fps_label.add_theme_color_override("font_color", Color(0.4, 1.0, 0.5))
		_fps_label.add_theme_color_override("font_outline_color", Color.BLACK)
		_fps_label.add_theme_constant_override("outline_size", 5)
		_fps_label.position = Vector2(8, 4)
		_fps_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_fps_layer.add_child(_fps_label)
	elif not show_fps and _fps_layer != null:
		_fps_layer.queue_free()
		_fps_layer = null
		_fps_label = null


func save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("gfx", "preset", preset)
	cf.set_value("gfx", "show_fps", show_fps)
	cf.set_value("gfx", "vsync", vsync)
	cf.set_value("gfx", "haptics", haptics)
	cf.set_value("gfx", "vol_master", vol_master)
	cf.set_value("gfx", "vol_radio", vol_radio)
	for k in KEYS:
		cf.set_value("gfx", k, get(k))
	cf.save(SAVE)


func _load() -> void:
	var cf := ConfigFile.new()
	if cf.load(SAVE) != OK:
		return
	preset = cf.get_value("gfx", "preset", "auto")
	show_fps = cf.get_value("gfx", "show_fps", false)
	vsync = cf.get_value("gfx", "vsync", true)
	haptics = cf.get_value("gfx", "haptics", true)
	vol_master = cf.get_value("gfx", "vol_master", 1.0)
	vol_radio = cf.get_value("gfx", "vol_radio", 0.7)
	if preset != "auto":
		for k in KEYS:
			if cf.has_section_key("gfx", k):
				set(k, cf.get_value("gfx", k))
