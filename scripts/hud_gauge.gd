# Copyright (c) 2026 KRG Studios. All rights reserved. See LICENSE.
class_name HudGauge
extends Control
## Round racing gauge: speed arc (fills as you go faster), RPM segments with a red zone, big speed number, gear box.

var _spd := 0.0
var _rpm := 0.2
var _shown_spd := 0.0
var _shown_rpm := 0.2
var _gear := "N"
var _top := 220.0
const A0 := 2.356            # 135 deg
const SWEEP := 4.712         # 270 deg


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(170, 170)


func set_values(spd: float, rpm: float, gear: String, top: float) -> void:
	_spd = spd
	_rpm = rpm
	_gear = gear
	_top = maxf(top * 1.05, 120.0)


func _process(delta: float) -> void:
	_shown_spd = lerpf(_shown_spd, _spd, clampf(delta * 9.0, 0.0, 1.0))
	_shown_rpm = lerpf(_shown_rpm, _rpm, clampf(delta * 10.0, 0.0, 1.0))
	queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5 - 4.0
	var f := ThemeDB.fallback_font
	# body
	draw_circle(c, r, Color(0.03, 0.045, 0.075, 0.74))
	draw_arc(c, r - 1.0, 0.0, TAU, 48, Color(1, 1, 1, 0.3), 2.0, true)
	# speed track + fill
	var rs := r * 0.8
	draw_arc(c, rs, A0, A0 + SWEEP, 40, Color(1, 1, 1, 0.12), 7.0, true)
	var k := clampf(_shown_spd / _top, 0.0, 1.0)
	if k > 0.002:
		var n := maxi(2, int(k * 48.0))
		for i in n:
			var t0 := float(i) / float(n)
			var t1 := float(i + 1) / float(n)
			var col := Color(0.2, 0.85, 1.0).lerp(Color(1.0, 0.65, 0.1), clampf(t0 * k * 1.6, 0.0, 1.0)).lerp(Color(1.0, 0.2, 0.15), clampf((t0 * k - 0.65) * 3.0, 0.0, 1.0))
			draw_arc(c, rs, A0 + SWEEP * k * t0, A0 + SWEEP * k * t1 + 0.01, 3, col, 7.0, true)
	# ticks every 20 % of the scale
	for i in 11:
		var a := A0 + SWEEP * float(i) / 10.0
		var d := Vector2.from_angle(a)
		draw_line(c + d * (rs - 11.0), c + d * (rs - (17.0 if i % 5 == 0 else 13.0)), Color(1, 1, 1, 0.55), 2.0 if i % 5 == 0 else 1.2, true)
	# rpm segments on the inner ring
	var rr := r * 0.58
	var segs := 14
	for i in segs:
		var t := float(i) / float(segs)
		var a0 := A0 + SWEEP * t + 0.02
		var a1 := A0 + SWEEP * (t + 1.0 / float(segs)) - 0.02
		var lit := _shown_rpm >= t + 0.02
		var base := Color(1.0, 0.25, 0.2) if t >= 0.78 else (Color(1.0, 0.8, 0.2) if t >= 0.55 else Color(0.5, 0.9, 1.0))
		draw_arc(c, rr, a0, a1, 4, base if lit else Color(base.r, base.g, base.b, 0.16), 5.0, true)
	# numbers
	var s := str(int(roundf(_shown_spd)))
	var fs := int(r * 0.5)
	var w := f.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string_outline(f, Vector2(c.x - w * 0.5, c.y + fs * 0.28), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 5, Color(0, 0, 0, 0.8))
	draw_string(f, Vector2(c.x - w * 0.5, c.y + fs * 0.28), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
	var u := "km/h"
	var uw := f.get_string_size(u, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	draw_string(f, Vector2(c.x - uw * 0.5, c.y + fs * 0.28 + 18.0), u, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1, 0.7))
	# gear box
	var gb := Rect2(c + Vector2(-17, r * 0.46), Vector2(34, 26))
	var gcol := Color(1.0, 0.7, 0.2) if _gear in ["R", "P"] else Color.WHITE
	draw_rect(gb, Color(0, 0, 0, 0.55))
	draw_rect(gb, Color(gcol.r, gcol.g, gcol.b, 0.7), false, 2.0)
	var gw := f.get_string_size(_gear, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	draw_string(f, Vector2(c.x - gw * 0.5, gb.position.y + 20.0), _gear, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, gcol)
