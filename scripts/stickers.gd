# Copyright (c) 2026 Sabak Studios. All rights reserved. See LICENSE.
class_name Stickers
extends RefCounted
## In-race stickers: 12 flat badges drawn in code. A sticker floats above the sender's car for everybody
## (also seen in the mirrors) and some of them play a positional sound, so people in front / behind hear it too.

## anim: pop (static after the pop-in) | bounce | pulse | shake | spin | float
const LIST := [
	{"id": "gg", "n": ["GG", "جيجي"], "anim": "pop", "snd": "success", "pitch": 1.0},
	{"id": "wow", "n": ["WOW", "واو"], "anim": "bounce", "snd": "", "pitch": 1.0},
	{"id": "fire", "n": ["Fire", "نار"], "anim": "pulse", "snd": "whoosh", "pitch": 0.8},
	{"id": "heart", "n": ["Love", "حب"], "anim": "pulse", "snd": "ding", "pitch": 1.0},
	{"id": "laugh", "n": ["LOL", "هههه"], "anim": "shake", "snd": "", "pitch": 1.0},
	{"id": "angry", "n": ["Angry", "غضبان"], "anim": "shake", "snd": "warn", "pitch": 1.0},
	{"id": "crown", "n": ["King", "ملك"], "anim": "float", "snd": "fanfare", "pitch": 1.0},
	{"id": "skull", "n": ["Dead", "ميت"], "anim": "pop", "snd": "", "pitch": 1.0},
	{"id": "bolt", "n": ["Nitro", "نيترو"], "anim": "spin", "snd": "whoosh", "pitch": 1.5},
	{"id": "star", "n": ["Star", "نجمة"], "anim": "spin", "snd": "ding", "pitch": 1.4},
	{"id": "sorry", "n": ["Sorry", "آسف"], "anim": "pop", "snd": "", "pitch": 1.0},
	{"id": "cup", "n": ["Win", "فوز"], "anim": "bounce", "snd": "cheer", "pitch": 1.0},
]
const LIFE := 3.6
const COOLDOWN := 2.5


## the artwork (256 x 256), used in the picker and as the texture of the 3D badge
class Face extends Control:
	var id := "gg"

	func _init(p_id := "gg") -> void:
		id = p_id
		custom_minimum_size = Vector2(256, 256)
		size = Vector2(256, 256)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _ov(c: Vector2, rx: float, ry: float, col: Color) -> void:
		var pts := PackedVector2Array()
		for i in 28:
			var a := TAU * i / 28.0
			pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
		draw_colored_polygon(pts, col)

	func _face(col: Color) -> void:
		draw_circle(Vector2(128, 130), 74, col.darkened(0.45))
		draw_circle(Vector2(128, 130), 68, col)

	func _draw() -> void:
		draw_circle(Vector2(128, 128), 122, Color(0.06, 0.07, 0.1, 0.94))
		draw_arc(Vector2(128, 128), 118, 0, TAU, 64, Color(1, 1, 1, 0.92), 7.0)
		var c := Vector2(128, 128)
		var ink := Color(0.1, 0.08, 0.06)
		var yellow := Color(1.0, 0.8, 0.2)
		match id:
			"gg":
				var f := ThemeDB.fallback_font
				draw_string(f, Vector2(34, 168), "GG", HORIZONTAL_ALIGNMENT_CENTER, 190, 118, Color(1.0, 0.78, 0.2))
			"wow":
				_face(yellow)
				_ov(Vector2(100, 112), 14, 18, Color.WHITE)
				_ov(Vector2(156, 112), 14, 18, Color.WHITE)
				draw_circle(Vector2(100, 114), 7, ink)
				draw_circle(Vector2(156, 114), 7, ink)
				draw_line(Vector2(84, 84), Vector2(112, 78), ink, 6)
				draw_line(Vector2(144, 78), Vector2(172, 84), ink, 6)
				_ov(Vector2(128, 166), 16, 22, ink)
			"fire":
				draw_colored_polygon(PackedVector2Array([Vector2(128, 30), Vector2(160, 80), Vector2(190, 110), Vector2(192, 160), Vector2(168, 206), Vector2(128, 222), Vector2(88, 206), Vector2(64, 160), Vector2(72, 112), Vector2(100, 134), Vector2(108, 80)]), Color(1.0, 0.42, 0.1))
				draw_colored_polygon(PackedVector2Array([Vector2(128, 104), Vector2(152, 140), Vector2(158, 176), Vector2(138, 206), Vector2(118, 206), Vector2(98, 176), Vector2(104, 142)]), Color(1.0, 0.85, 0.25))
			"heart":
				var pts := PackedVector2Array()
				for i in 40:
					var t := TAU * i / 40.0
					var x := 16.0 * pow(sin(t), 3.0)
					var y := 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)
					pts.append(Vector2(128 + x * 5.6, 124 - y * 5.6))
				draw_colored_polygon(pts, Color(0.95, 0.2, 0.3))
				_ov(Vector2(98, 96), 14, 9, Color(1, 1, 1, 0.45))
			"laugh":
				_face(yellow)
				draw_arc(Vector2(100, 112), 14, PI * 1.1, PI * 1.9, 12, ink, 6)
				draw_arc(Vector2(156, 112), 14, PI * 1.1, PI * 1.9, 12, ink, 6)
				draw_colored_polygon(PackedVector2Array([Vector2(88, 140), Vector2(168, 140), Vector2(158, 176), Vector2(128, 190), Vector2(98, 176)]), ink)
				draw_colored_polygon(PackedVector2Array([Vector2(94, 142), Vector2(162, 142), Vector2(158, 154), Vector2(98, 154)]), Color.WHITE)
				_ov(Vector2(78, 138), 7, 11, Color(0.4, 0.75, 1.0))
				_ov(Vector2(178, 138), 7, 11, Color(0.4, 0.75, 1.0))
			"angry":
				_face(Color(0.92, 0.25, 0.2))
				draw_line(Vector2(78, 90), Vector2(116, 108), ink, 9)
				draw_line(Vector2(178, 90), Vector2(140, 108), ink, 9)
				_ov(Vector2(100, 122), 11, 11, Color.WHITE)
				_ov(Vector2(156, 122), 11, 11, Color.WHITE)
				draw_circle(Vector2(102, 124), 5, ink)
				draw_circle(Vector2(154, 124), 5, ink)
				draw_arc(Vector2(128, 186), 26, PI * 1.15, PI * 1.85, 16, ink, 8)
			"crown":
				draw_colored_polygon(PackedVector2Array([Vector2(52, 190), Vector2(52, 96), Vector2(92, 140), Vector2(128, 70), Vector2(164, 140), Vector2(204, 96), Vector2(204, 190)]), Color(1.0, 0.78, 0.2))
				draw_rect(Rect2(52, 190, 152, 20), Color(0.85, 0.6, 0.12))
				draw_circle(Vector2(128, 66), 11, Color(0.9, 0.2, 0.3))
				draw_circle(Vector2(52, 92), 9, Color(0.3, 0.7, 1.0))
				draw_circle(Vector2(204, 92), 9, Color(0.3, 0.7, 1.0))
				draw_circle(Vector2(128, 160), 10, Color(0.9, 0.2, 0.3))
			"skull":
				draw_circle(Vector2(128, 112), 66, Color(0.94, 0.94, 0.92))
				draw_rect(Rect2(92, 150, 72, 50), Color(0.94, 0.94, 0.92))
				_ov(Vector2(102, 116), 17, 20, ink)
				_ov(Vector2(154, 116), 17, 20, ink)
				draw_colored_polygon(PackedVector2Array([Vector2(128, 136), Vector2(118, 158), Vector2(138, 158)]), ink)
				for i in 4:
					draw_line(Vector2(104 + i * 16, 172), Vector2(104 + i * 16, 200), ink, 4)
			"bolt":
				draw_colored_polygon(PackedVector2Array([Vector2(150, 30), Vector2(78, 136), Vector2(120, 136), Vector2(100, 224), Vector2(184, 108), Vector2(138, 108), Vector2(164, 30)]), Color(1.0, 0.9, 0.2))
				draw_polyline(PackedVector2Array([Vector2(150, 30), Vector2(78, 136), Vector2(120, 136), Vector2(100, 224), Vector2(184, 108), Vector2(138, 108), Vector2(164, 30), Vector2(150, 30)]), Color(1.0, 0.6, 0.1), 5)
			"star":
				var pts2 := PackedVector2Array()
				for i in 10:
					var r := 86.0 if i % 2 == 0 else 38.0
					var a := -PI / 2.0 + TAU * i / 10.0
					pts2.append(c + Vector2(cos(a) * r, sin(a) * r + 6))
				draw_colored_polygon(pts2, Color(1.0, 0.82, 0.25))
				draw_circle(c + Vector2(0, 6), 20, Color(1.0, 0.95, 0.6))
			"sorry":
				_face(yellow)
				draw_circle(Vector2(100, 120), 8, ink)
				draw_circle(Vector2(156, 120), 8, ink)
				draw_line(Vector2(84, 100), Vector2(116, 108), ink, 6)
				draw_line(Vector2(172, 100), Vector2(140, 108), ink, 6)
				draw_line(Vector2(104, 174), Vector2(152, 168), ink, 7)
				draw_colored_polygon(PackedVector2Array([Vector2(186, 78), Vector2(200, 110), Vector2(186, 124), Vector2(172, 110)]), Color(0.4, 0.75, 1.0))
			"cup":
				draw_colored_polygon(PackedVector2Array([Vector2(76, 60), Vector2(180, 60), Vector2(168, 130), Vector2(146, 156), Vector2(110, 156), Vector2(88, 130)]), Color(1.0, 0.78, 0.2))
				draw_arc(Vector2(72, 92), 24, PI * 0.5, PI * 1.5, 12, Color(1.0, 0.78, 0.2), 9)
				draw_arc(Vector2(184, 92), 24, -PI * 0.5, PI * 0.5, 12, Color(1.0, 0.78, 0.2), 9)
				draw_rect(Rect2(118, 156, 20, 30), Color(0.85, 0.6, 0.12))
				draw_rect(Rect2(94, 186, 68, 18), Color(0.85, 0.6, 0.12))
				draw_circle(Vector2(128, 100), 14, Color(1.0, 0.95, 0.6))


static func index_of(id: String) -> int:
	for i in LIST.size():
		if LIST[i]["id"] == id:
			return i
	return 0


## 3D badge that floats above a car. Free-standing node: add it to the car.
class Badge extends Node3D:
	var idx := 0
	var _t := 0.0
	var _spr: Sprite3D
	var _anim := "pop"

	func _init(p_idx := 0) -> void:
		idx = p_idx
		name = "Sticker"
		_anim = str(Stickers.LIST[idx]["anim"])
		var vp := SubViewport.new()
		vp.size = Vector2i(256, 256)
		vp.transparent_bg = true
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		vp.gui_disable_input = true
		vp.add_child(Face.new(str(Stickers.LIST[idx]["id"])))
		add_child(vp)
		_spr = Sprite3D.new()
		_spr.texture = vp.get_texture()
		_spr.pixel_size = 2.0 / 256.0
		_spr.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_spr.shaded = false
		_spr.double_sided = true
		_spr.alpha_cut = SpriteBase3D.ALPHA_CUT_DISABLED
		_spr.transparent = true
		add_child(_spr)
		position = Vector3(0, 2.9, 0)
		_spr.scale = Vector3.ZERO

	func _process(delta: float) -> void:
		_t += delta
		if _t >= Stickers.LIFE:
			queue_free()
			return
		var pop := clampf(_t / 0.32, 0.0, 1.0)
		var s := 1.0
		if pop < 1.0:
			s = pop * (1.0 + 0.35 * sin(pop * PI))
		var off := Vector3.ZERO
		var sx := 1.0
		match _anim:
			"bounce":
				off.y = absf(sin(_t * 5.0)) * 0.4
			"pulse":
				s *= 1.0 + 0.12 * sin(_t * 9.0)
			"shake":
				off.x = sin(_t * 38.0) * 0.1
			"spin":
				sx = maxf(0.2, absf(cos(_t * 3.2)))
			"float":
				off.y = sin(_t * 2.2) * 0.14
		_spr.position = off
		_spr.scale = Vector3(s * sx, s, s)
		var left := Stickers.LIFE - _t
		_spr.modulate.a = clampf(left / 0.5, 0.0, 1.0)


## replaces an older sticker on the same car, floats the new one, and plays its sound from the car
static func show_on(car: Node3D, idx: int, with_sound := true) -> void:
	if car == null or not is_instance_valid(car):
		return
	var old := car.get_node_or_null("Sticker")
	if old:
		old.free()
	car.add_child(Badge.new(idx))
	var snd: String = LIST[idx]["snd"]
	if with_sound and snd != "":
		Sfx.play3d(snd, car, -3.0, float(LIST[idx]["pitch"]))


## the 12-sticker window. `picked(idx)` when one is chosen.
class Picker extends PanelContainer:
	signal picked(idx: int)

	func _init() -> void:
		add_theme_stylebox_override("panel", UI.sb(Color(0.06, 0.065, 0.085, 0.96), 16, Color(1, 1, 1, 0.16), 1))
		var m := MarginContainer.new()
		for s in ["left", "right", "top", "bottom"]:
			m.add_theme_constant_override("margin_" + s, 12)
		add_child(m)
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 8)
		m.add_child(vb)
		UI.lbl(vb, UI.tx("STICKERS", "الملصقات"), 18, UI.ACCENT, false)
		var g := GridContainer.new()
		g.columns = 4
		g.add_theme_constant_override("h_separation", 8)
		g.add_theme_constant_override("v_separation", 8)
		vb.add_child(g)
		for i in Stickers.LIST.size():
			var idx := i
			var b := Button.new()
			b.custom_minimum_size = Vector2(86, 98)
			b.focus_mode = Control.FOCUS_NONE
			var n := UI.sb(Color(1, 1, 1, 0.05), 12, Color(1, 1, 1, 0.1), 1)
			var hv := UI.sb(Color(1, 1, 1, 0.12), 12, UI.ACCENT, 2)
			b.add_theme_stylebox_override("normal", n)
			b.add_theme_stylebox_override("hover", hv)
			b.add_theme_stylebox_override("pressed", hv)
			b.add_theme_stylebox_override("focus", n)
			b.pressed.connect(func(): picked.emit(idx))
			var holder := Control.new()
			holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_child(holder)
			var f := Face.new(str(Stickers.LIST[i]["id"]))
			f.scale = Vector2(0.27, 0.27)
			f.position = Vector2(8, 4)
			holder.add_child(f)
			var lb := Label.new()
			lb.text = ("%s" % UI.tx(Stickers.LIST[i]["n"][0], Stickers.LIST[i]["n"][1])) + ("  ♪" if str(Stickers.LIST[i]["snd"]) != "" else "")
			lb.add_theme_font_size_override("font_size", 13)
			lb.position = Vector2(0, 74)
			lb.size = Vector2(86, 20)
			lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
			holder.add_child(lb)
			g.add_child(b)
