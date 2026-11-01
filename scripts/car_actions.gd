# Copyright (c) 2026 Sabak Studios. All rights reserved. See LICENSE.
class_name CarActions
extends Node
## Cabin controls the driver works with his own hands: horn, headlights, wipers, wing mirrors, radio.
## Every action sends ONE hand off the wheel (the other keeps steering), does the movement and puts it back.
## Each car has its own way of doing it (see STYLE): wheel press / thumb button / double slam, stalk / rotary knob /
## rocker switch, electric joystick / manual lever, tuning knob / preset buttons.

signal changed                       # lights / wipers state changed (HUD buttons refresh)

# horn: press | thumb | double | hold      lights: stalk | knob | switch      wipers: stalk | knob | switch
# radio: knob | button                     mirror: joy | lever
const STYLE := {
	"hatch":   {"sig": "sig_relay", "sp": 1.00, "horn": "press",  "lights": "stalk",  "wipers": "knob",   "radio": "knob",   "mirror": "lever", "pitch": 1.00},
	"buggy":   {"sig": "sig_relay", "sp": 1.25, "horn": "thumb",  "lights": "switch", "wipers": "switch", "radio": "knob",   "mirror": "lever", "pitch": 1.12},
	"muscle":  {"sig": "sig_heavy", "sp": 1.05, "horn": "double", "lights": "knob",   "wipers": "switch", "radio": "knob",   "mirror": "lever", "pitch": 0.80},
	"sierra":  {"sig": "sig_relay", "sp": 0.80, "horn": "press",  "lights": "knob",   "wipers": "stalk",  "radio": "knob",   "mirror": "lever", "pitch": 0.95},
	"pickup":  {"sig": "sig_heavy", "sp": 0.80, "horn": "hold",   "lights": "knob",   "wipers": "knob",   "radio": "knob",   "mirror": "lever", "pitch": 0.72},
	"charger": {"sig": "sig_heavy", "sp": 1.30, "horn": "double", "lights": "stalk",  "wipers": "switch", "radio": "button", "mirror": "joy",   "pitch": 0.78},
	"coupe":   {"sig": "sig_soft", "sp": 1.00, "horn": "thumb",  "lights": "stalk",  "wipers": "stalk",  "radio": "button", "mirror": "joy",   "pitch": 1.05},
	"m4":      {"sig": "sig_soft", "sp": 0.85, "horn": "thumb",  "lights": "stalk",  "wipers": "stalk",  "radio": "button", "mirror": "joy",   "pitch": 1.00},
	"gt3":     {"sig": "sig_beep", "sp": 1.00, "horn": "thumb",  "lights": "switch", "wipers": "stalk",  "radio": "button", "mirror": "joy",   "pitch": 1.25},
	"hyper":   {"sig": "sig_beep", "sp": 0.80, "horn": "thumb",  "lights": "switch", "wipers": "switch", "radio": "button", "mirror": "joy",   "pitch": 1.18},
}
const MIRROR_STEPS := [0.0, 6.0, 12.0, -6.0, -12.0]
const APPROACH := 0.3

var car: Car
var st: Dictionary = STYLE["hatch"]
var lights_on := false
var wipers_on := false

var _busy := false
var _queue: Array = []
var _a := {}                 # running action: side, dur, pose (Callable t -> car-space Vector3), lean, events [{t, fn, done}]
var _t := 0.0
var _mir := {"left": 0, "right": 0}

var _pv: Node3D              # wheel pivot (reference frame)
var _stalk_l: Node3D
var _stalk_r: Node3D
var _stalk_l_tip: Node3D
var _stalk_r_tip: Node3D
var _knob_l: Node3D          # lights knob / switch on the left of the wheel
var _knob_w: Node3D          # wiper knob / switch on the right of the wheel
var _joy: Node3D
var _joy_pos := Vector3.ZERO
var signal_dir := 0              # -1 left, 0 off, 1 right
var _sig_t := 0.0
var _sig_age := 0.0
var _sig_seen := false
var _sig_on := false
var _sig_stalk: Node3D
var _sig_tip: Node3D
var _sig_lamps := {"left": [], "right": []}
var _sig_mat_on: StandardMaterial3D
var _sig_mat_off: StandardMaterial3D
var drink_kind := "juice"        # juice | energy
var _can: Node3D
var _can_body: MeshInstance3D
var _can_band: MeshInstance3D
var _can_held := false
var _can_tilt := 0.0
var _beams: Array = []
var _wipers: Array[Node3D] = []
var _wp_t := -1.0
var _wp_phase := 0.0


func setup(p_car: Car) -> void:
	car = p_car
	st = STYLE.get(car.model, STYLE["hatch"])
	_pv = car._wheel_pivot
	if _pv == null:
		return
	_build_controls()
	_build_wipers()
	_build_can()
	_build_signals()


# ------------------------------------------------------------------ public
func do(name: String) -> void:
	if car == null or _pv == null or car.driver_avatar == null:
		return
	if _busy:
		if _queue.size() < 2 and not _queue.has(name):
			_queue.append(name)
		return
	_start(name)


func is_busy() -> bool:
	return _busy


# ------------------------------------------------------------------ geometry (car space)
func _w(v: Vector3) -> Vector3:
	return _pv.transform * v


func _hub() -> Vector3:
	return _w(Vector3(0, 0.03, 0))


func _panel_l() -> Vector3:
	return _pv.position + Vector3(-0.40, -0.17, -0.20)


func _panel_r() -> Vector3:
	return _pv.position + Vector3(0.42, -0.17, -0.22)


func _radio_at(frac: float) -> Vector3:
	# frac: 0 = left (prev) .. 1 = right (next); knob style uses the two knobs, button style the preset row
	if st["radio"] == "knob":
		return Vector3(lerpf(0.005, 0.235, frac), 1.075, -0.74)
	return Vector3(lerpf(0.0575, 0.1825, frac), 1.075, -0.69)


# ------------------------------------------------------------------ build the little controls
func _mat(c: Color, metal := 0.0, rough := 0.6, emit := 0.0) -> StandardMaterial3D:
	return CarStyle.mat(c, metal, rough, emit)


func _build_controls() -> void:
	var dark := _mat(Color(0.03, 0.03, 0.04), 0.2, 0.5)
	var chrome := _mat(Color(0.78, 0.8, 0.86), 0.9, 0.25)
	var amb := _mat(Color(1.0, 0.6, 0.15), 0.0, 0.5, 1.0)
	# --- steering column stalks (always there on stalk cars)
	if st["lights"] == "stalk":
		var p := _make_stalk(-1.0, dark)
		_stalk_l = p[0]
		_stalk_l_tip = p[1]
	if st["wipers"] == "stalk":
		var p := _make_stalk(1.0, dark)
		_stalk_r = p[0]
		_stalk_r_tip = p[1]
	# --- left panel: lights knob / switch
	if st["lights"] != "stalk":
		_knob_l = _make_knob(_panel_l(), st["lights"], dark, chrome, amb)
	if st["wipers"] != "stalk":
		_knob_w = _make_knob(_panel_r(), st["wipers"], dark, chrome, amb)
	# --- mirror control: electric joystick or manual lever by the left door
	_joy_pos = _pv.position + Vector3(-0.44, -0.30, 0.18)
	_joy = Node3D.new()
	_joy.position = _joy_pos
	car.add_child(_joy)
	CarStyle.box(_joy, Vector3(0.1, 0.012, 0.1), Vector3(0, -0.006, 0), dark)
	if st["mirror"] == "joy":
		CarStyle.cyl(_joy, 0.028, 0.012, Vector3(0, 0.004, 0), chrome)
		CarStyle.cyl(_joy, 0.012, 0.05, Vector3(0, 0.03, 0), dark)
	else:
		CarStyle.box(_joy, Vector3(0.016, 0.07, 0.016), Vector3(0, 0.035, 0), chrome)
		CarStyle.cyl(_joy, 0.02, 0.025, Vector3(0, 0.075, 0), dark)


func _make_stalk(sx: float, m: Material) -> Array:
	var pivot := Node3D.new()
	pivot.transform = Transform3D(_pv.basis, _w(Vector3(sx * 0.06, -0.075, 0.03)))
	car.add_child(pivot)
	CarStyle.box(pivot, Vector3(0.15, 0.018, 0.018), Vector3(sx * 0.075, 0, 0), m)
	CarStyle.cyl(pivot, 0.016, 0.03, Vector3(sx * 0.15, 0, 0), m)
	var tip := Node3D.new()
	tip.position = Vector3(sx * 0.15, 0, 0)
	pivot.add_child(tip)
	return [pivot, tip]


func _make_knob(pos: Vector3, kind: String, dark: Material, chrome: Material, amb: Material) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	car.add_child(n)
	CarStyle.box(n, Vector3(0.09, 0.012, 0.07), Vector3(0, -0.006, 0), dark)
	var mv := Node3D.new()
	n.add_child(mv)
	if kind == "knob":
		CarStyle.cyl(mv, 0.03, 0.025, Vector3(0, 0.012, 0), chrome)
		CarStyle.box(mv, Vector3(0.004, 0.004, 0.022), Vector3(0, 0.027, -0.01), amb)
	else:
		CarStyle.box(mv, Vector3(0.045, 0.014, 0.03), Vector3(0, 0.012, 0), chrome)
		CarStyle.box(mv, Vector3(0.045, 0.004, 0.006), Vector3(0, 0.021, -0.01), amb)
	n.set_meta("mv", mv)
	return n


func _build_wipers() -> void:
	var gh: Dictionary = CarStyle.GREENHOUSE.get(car.model, CarStyle.GREENHOUSE["hatch"])
	var rt := 1.95 - car.drop
	var zf1: float = float(gh["zf1"]) - car.drop * 0.3
	var up := Vector3(0, rt - 1.2, zf1 + 1.15).normalized()
	var xb := Vector3(1, 0, 0)
	var zb := xb.cross(up)
	var basis := Basis(xb, up, zb)
	var blade := _mat(Color(0.02, 0.02, 0.025), 0.1, 0.8)
	for sx in [-0.62, 0.05]:
		var piv := Node3D.new()
		piv.transform = Transform3D(basis, Vector3(sx, 1.205, -1.13) + zb * -0.02)
		car.add_child(piv)
		var arm := Node3D.new()                       # rotates around the glass normal (local Z)
		piv.add_child(arm)
		CarStyle.box(arm, Vector3(0.5, 0.012, 0.012), Vector3(0.25, 0, 0), blade)
		CarStyle.box(arm, Vector3(0.42, 0.018, 0.008), Vector3(0.27, 0.02, 0.006), blade)
		_wipers.append(arm)


# ------------------------------------------------------------------ turn signals
func _build_signals() -> void:
	_sig_mat_on = _mat(Color(1.0, 0.55, 0.0), 0.0, 0.3, 4.0)
	_sig_mat_off = _mat(Color(0.45, 0.22, 0.02), 0.0, 0.5, 0.0)
	var spots := [Vector3(0.72, 0.62, -2.2), Vector3(0.78, 0.72, 2.18), Vector3(0.99, 0.95, -0.95)]
	for side in ["left", "right"]:
		var sx := -1.0 if side == "left" else 1.0
		for sp in spots:
			var sz := Vector3(0.24, 0.1, 0.05) if absf(sp.z) > 1.5 else Vector3(0.03, 0.06, 0.16)
			var m := CarStyle.box(car, sz, Vector3(sp.x * sx, sp.y, sp.z), _sig_mat_off)
			_sig_lamps[side].append(m)
	# its own stalk under the lights stalk (left of the column)
	var piv := Node3D.new()
	piv.transform = Transform3D(_pv.basis, _w(Vector3(-0.06, -0.11, 0.03)))
	car.add_child(piv)
	var dark := _mat(Color(0.03, 0.03, 0.04), 0.2, 0.5)
	CarStyle.box(piv, Vector3(0.14, 0.016, 0.016), Vector3(-0.07, 0, 0), dark)
	CarStyle.cyl(piv, 0.015, 0.028, Vector3(-0.14, 0, 0), dark)
	var tip := Node3D.new()
	tip.position = Vector3(-0.14, 0, 0)
	piv.add_child(tip)
	_sig_stalk = piv
	_sig_tip = tip


## dir: -1 left, +1 right. Pressing the same side again switches it off.
func _signal_act(dir: int) -> Dictionary:
	var sp := _sig_stalk
	var tip := _sig_tip
	var fire := func():
		signal_dir = 0 if signal_dir == dir else dir
		_sig_age = 0.0
		_sig_seen = false
		_sig_t = 0.0
		_sig_on = false
		if signal_dir != 0:
			_sig_on = true
			_sig_sound(true)
		_sig_lights()
		changed.emit()
	var base := _pv.basis
	var sgn := float(dir)
	return {"side": "L", "dur": 0.7, "lean": 0.0, "events": [_ev(0.28, fire)],
		"pose": func(t: float) -> Vector3:
			var f := smoothstep(0.15, 0.28, t) * (1.0 - smoothstep(0.45, 0.6, t))
			sp.transform = Transform3D(base * Basis(Vector3(1, 0, 0), deg_to_rad(-13.0 * sgn * f)), sp.position)
			return car.to_local(tip.global_position)}


func _sig_sound(tick: bool) -> void:
	Sfx.play3d(str(st["sig"]), car, -4.0, float(st["sp"]) * (1.0 if tick else 0.82))


func _sig_lights() -> void:
	for side in ["left", "right"]:
		var on: bool = _sig_on and ((side == "left" and signal_dir < 0) or (side == "right" and signal_dir > 0))
		for m in _sig_lamps[side]:
			(m as MeshInstance3D).material_override = _sig_mat_on if on else _sig_mat_off


func _tick_signal(delta: float) -> void:
	if signal_dir == 0:
		return
	_sig_age += delta
	_sig_t += delta
	if _sig_t >= 0.36:
		_sig_t = 0.0
		_sig_on = not _sig_on
		_sig_sound(_sig_on)
		_sig_lights()
	# like a real car it cancels itself after the turn (wheel turned the way of the signal, then straight again)
	var s: float = car.steer_target * float(-signal_dir)
	if s < -0.45:
		_sig_seen = true
	elif _sig_seen and absf(s) < 0.12:
		_cancel_signal()
	elif _sig_age > 25.0:
		_cancel_signal()


func _cancel_signal() -> void:
	signal_dir = 0
	_sig_on = false
	_sig_lights()
	changed.emit()


func _cup_holder() -> Vector3:
	return Vector3(0.0, 0.93, 0.42)


func _mouth() -> Vector3:
	return Vector3(-0.45, 1.72 - car.sd, 0.16)


func _build_can() -> void:
	_can = Node3D.new()
	_can.scale = Vector3(1.6, 1.6, 1.6)
	car.add_child(_can)
	var bm := CylinderMesh.new()
	bm.top_radius = 0.034
	bm.bottom_radius = 0.034
	bm.height = 0.13
	_can_body = MeshInstance3D.new()
	_can_body.mesh = bm
	_can.add_child(_can_body)
	var bd := CylinderMesh.new()
	bd.top_radius = 0.0355
	bd.bottom_radius = 0.0355
	bd.height = 0.04
	_can_band = MeshInstance3D.new()
	_can_band.mesh = bd
	_can_band.position = Vector3(0, 0.01, 0)
	_can.add_child(_can_band)
	var top := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.03
	tm.bottom_radius = 0.034
	tm.height = 0.012
	top.mesh = tm
	top.position = Vector3(0, 0.07, 0)
	top.material_override = _mat(Color(0.8, 0.82, 0.86), 0.9, 0.25)
	_can.add_child(top)
	_paint_can()
	_can.position = _cup_holder() + Vector3(0, 0.1, 0)
	# the holder ring in the console
	var ring := Node3D.new()
	ring.position = _cup_holder()
	car.add_child(ring)
	CarStyle.cyl(ring, 0.046, 0.04, Vector3(0, 0.0, 0), _mat(Color(0.03, 0.03, 0.04), 0.2, 0.5))


func _paint_can() -> void:
	if _can_body == null:
		return
	if drink_kind == "energy":
		_can_body.material_override = _mat(Color(0.04, 0.04, 0.05), 0.5, 0.35)
		_can_band.material_override = _mat(Color(0.35, 1.0, 0.1), 0.2, 0.4, 0.8)
	else:
		_can_body.material_override = _mat(Color(1.0, 0.55, 0.08), 0.1, 0.5)
		_can_band.material_override = _mat(Color(1.0, 0.95, 0.85), 0.0, 0.6)


func set_drink(kind: String) -> void:
	drink_kind = kind
	_paint_can()
	changed.emit()


func toggle_drink() -> void:
	if not _busy:
		set_drink("energy" if drink_kind == "juice" else "juice")


func _drink() -> Dictionary:
	var h := _cup_holder() + Vector3(0, 0.17, 0)
	var m := _mouth() + Vector3(0, 0.0, -0.02)
	var grab := func():
		_can_held = true
		Sfx.play3d("click", car, -6.0, 1.3)
	var open := func(): Sfx.play3d("fizz", car, -4.0, 1.0)
	var sip := func(): Sfx.play3d("sip", car, -2.0, 1.0 if drink_kind == "juice" else 0.9)
	var release := func():
		_can_held = false
		_can_tilt = 0.0
		_can.position = _cup_holder() + Vector3(0, 0.1, 0)
		_can.rotation = Vector3.ZERO
		Sfx.play3d("click", car, -6.0, 1.0)
	return {"side": "R", "dur": 3.6, "lean": 0.04,
		"events": [_ev(0.5, grab), _ev(1.35, open), _ev(1.7, sip), _ev(3.2, release)],
		"pose": func(t: float) -> Vector3:
			var lift := smoothstep(0.55, 1.35, t)
			var lower := smoothstep(2.55, 3.2, t)
			var p := h.lerp(m, lift * (1.0 - lower))
			p.y += sin(lift * PI * (1.0 - lower)) * 0.05
			_can_tilt = -1.15 * smoothstep(1.4, 1.8, t) * (1.0 - smoothstep(2.3, 2.6, t))
			return p}


# ------------------------------------------------------------------ action definitions
func _start(name: String) -> void:
	_busy = true
	_t = 0.0
	var w := car.driver_avatar
	match name:
		"horn":
			_a = _horn()
		"lights":
			_a = _lights()
		"wipers":
			_a = _wipers_act()
		"radio_next":
			_a = _radio(1.0)
		"radio_prev":
			_a = _radio(0.0)
		"signal_left":
			_a = _signal_act(-1)
		"signal_right":
			_a = _signal_act(1)
		"drink":
			_a = _drink()
		"mirror_left":
			_a = _mirror("left")
		"mirror_right":
			_a = _mirror("right")
		_:
			_busy = false
			return
	_a["name"] = name
	if w == null:
		_busy = false


func _ev(t: float, fn: Callable) -> Dictionary:
	return {"t": t, "fn": fn, "done": false}


func _horn() -> Dictionary:
	var kind: String = st["horn"]
	var pitch: float = st["pitch"]
	var play := func(): Sfx.play3d("horn", car, 2.0, pitch)
	var hub := _hub()
	var press_dir := (_pv.basis * Vector3(0, -1, 0)).normalized()        # into the dash
	var hover := (_pv.basis * Vector3(0, 1, 0)).normalized() * 0.07
	match kind:
		"thumb":
			var spot := _w(Vector3(0.1, 0.03, -0.1))
			return {"side": "R", "dur": 0.55, "lean": 0.0, "events": [_ev(0.15, play)],
				"pose": func(t: float) -> Vector3:
					var d := smoothstep(0.08, 0.16, t) * (1.0 - smoothstep(0.4, 0.48, t))
					return spot + hover * 0.6 + press_dir * (0.07 * d)}
		"double":
			return {"side": "R", "dur": 0.85, "lean": 0.05, "events": [_ev(0.12, play), _ev(0.45, play)],
				"pose": func(t: float) -> Vector3:
					var d1 := smoothstep(0.05, 0.12, t) * (1.0 - smoothstep(0.22, 0.3, t))
					var d2 := smoothstep(0.38, 0.45, t) * (1.0 - smoothstep(0.58, 0.66, t))
					return hub + hover * 1.3 + press_dir * (0.1 * maxf(d1, d2))}
		"hold":
			return {"side": "R", "dur": 1.5, "lean": 0.05, "events": [_ev(0.15, play), _ev(0.7, play)],
				"pose": func(t: float) -> Vector3:
					var d := smoothstep(0.08, 0.16, t) * (1.0 - smoothstep(1.25, 1.4, t))
					return hub + hover + press_dir * (0.09 * d)}
	return {"side": "R", "dur": 0.8, "lean": 0.05, "events": [_ev(0.18, play)],
		"pose": func(t: float) -> Vector3:
			var d := smoothstep(0.1, 0.18, t) * (1.0 - smoothstep(0.55, 0.65, t))
			return hub + hover + press_dir * (0.08 * d)}


func _lights() -> Dictionary:
	var kind: String = st["lights"]
	var fire := func():
		lights_on = not lights_on
		_apply_lights()
		Sfx.play3d("click", car, -2.0, 0.9)
		changed.emit()
	if kind == "stalk":
		var sp := _stalk_l
		var tip := _stalk_l_tip
		var dirn := -1.0 if lights_on else 1.0
		return {"side": "L", "dur": 0.75, "lean": 0.0, "events": [_ev(0.3, fire)],
			"pose": func(t: float) -> Vector3:
				var f := smoothstep(0.15, 0.3, t) * (1.0 - smoothstep(0.5, 0.65, t))
				sp.transform = Transform3D(_pv.basis * Basis(Vector3(1, 0, 0), deg_to_rad(14.0 * dirn * f)), sp.position)
				return car.to_local(tip.global_position)}
	return _knob_action(_knob_l, kind, "L", fire, lights_on)


func _wipers_act() -> Dictionary:
	var kind: String = st["wipers"]
	var fire := func():
		wipers_on = not wipers_on
		if wipers_on:
			_wp_t = 0.0
		Sfx.play3d("click", car, -2.0, 1.1)
		changed.emit()
	if kind == "stalk":
		var sp := _stalk_r
		var tip := _stalk_r_tip
		var dirn := -1.0 if wipers_on else 1.0
		return {"side": "R", "dur": 0.75, "lean": 0.0, "events": [_ev(0.3, fire)],
			"pose": func(t: float) -> Vector3:
				var f := smoothstep(0.15, 0.3, t) * (1.0 - smoothstep(0.5, 0.65, t))
				sp.transform = Transform3D(_pv.basis * Basis(Vector3(1, 0, 0), deg_to_rad(-12.0 * dirn * f)), sp.position)
				return car.to_local(tip.global_position)}
	return _knob_action(_knob_w, kind, "R", fire, wipers_on)


## rotary knob (hand circles around it) or rocker switch (hand presses one end)
func _knob_action(node: Node3D, kind: String, side: String, fire: Callable, is_on: bool) -> Dictionary:
	var base := node.position + Vector3(0, 0.03, 0)
	var mv: Node3D = node.get_meta("mv")
	var sgn := -1.0 if is_on else 1.0
	if kind == "knob":
		return {"side": side, "dur": 0.9, "lean": 0.0, "events": [_ev(0.45, fire)],
			"pose": func(t: float) -> Vector3:
				var f := smoothstep(0.2, 0.55, t)
				var ang := sgn * f * 1.3
				mv.rotation.y = ang
				var down := smoothstep(0.1, 0.2, t) * (1.0 - smoothstep(0.65, 0.78, t))
				return base + Vector3(sin(ang) * 0.025, 0.0, cos(ang) * 0.025 - 0.02) + Vector3(0, 0.05 * (1.0 - down), 0)}
	return {"side": side, "dur": 0.65, "lean": 0.0, "events": [_ev(0.3, fire)],
		"pose": func(t: float) -> Vector3:
			var d := smoothstep(0.12, 0.28, t) * (1.0 - smoothstep(0.38, 0.5, t))
			mv.rotation.x = sgn * 0.35 * smoothstep(0.28, 0.34, t)
			return base + Vector3(0, 0.06 - 0.05 * d, 0.012 * sgn)}


func _radio(frac: float) -> Dictionary:
	var kind: String = st["radio"]
	var at := _radio_at(frac) + Vector3(0, 0.05, 0.0)
	var fire := func():
		if frac > 0.5:
			Radio.next()
		else:
			Radio.prev()
	if kind == "knob":
		return {"side": "R", "dur": 1.05, "lean": 0.36, "events": [_ev(0.55, fire)],
			"pose": func(t: float) -> Vector3:
				var f := smoothstep(0.25, 0.6, t)
				var ang := f * (1.4 if frac > 0.5 else -1.4)
				return at + Vector3(sin(ang) * 0.025, -0.03 * smoothstep(0.15, 0.25, t), cos(ang) * 0.025 - 0.02)}
	return {"side": "R", "dur": 0.95, "lean": 0.36, "events": [_ev(0.5, fire)],
		"pose": func(t: float) -> Vector3:
			var d := smoothstep(0.3, 0.46, t) * (1.0 - smoothstep(0.55, 0.7, t))
			return at + Vector3(0, 0.02 - 0.05 * d, 0)}


func _mirror(which: String) -> Dictionary:
	var sx := -1.0 if which == "left" else 1.0
	var fire := func():
		_mir[which] = (int(_mir[which]) + 1) % MIRROR_STEPS.size()
		car.set_mirror_offset(which, MIRROR_STEPS[int(_mir[which])])
		Sfx.play3d("gear_tick", car, -6.0, 1.4)
	var base := _joy_pos + Vector3(0, 0.08, 0)
	var joy := _joy
	# the joystick leans toward the mirror that is being moved (left = to the left, right = to the right)
	if st["mirror"] == "joy":
		return {"side": "L", "dur": 1.0, "lean": 0.05, "events": [_ev(0.45, fire)],
			"pose": func(t: float) -> Vector3:
				var f := smoothstep(0.25, 0.4, t) * (1.0 - smoothstep(0.55, 0.7, t))
				joy.rotation.z = -sx * 0.4 * f
				return base + Vector3(sx * 0.035 * f, 0, 0)}
	return {"side": "L", "dur": 1.0, "lean": 0.05, "events": [_ev(0.45, fire)],
		"pose": func(t: float) -> Vector3:
			var f := smoothstep(0.25, 0.4, t) * (1.0 - smoothstep(0.55, 0.7, t))
			joy.rotation.x = sx * 0.45 * f
			return base + Vector3(0, 0, sx * 0.04 * f)}


# ------------------------------------------------------------------ effects
func _apply_lights() -> void:
	if _beams.is_empty():
		for x in [-0.6, 0.6]:
			var sp := SpotLight3D.new()
			sp.position = Vector3(x, 0.85, -2.0)
			sp.spot_range = 45.0
			sp.spot_angle = 30.0
			sp.light_energy = 1.3
			sp.light_color = Color(1.0, 0.95, 0.82)
			car.add_child(sp)
			_beams.append(sp)
	for b in _beams:
		(b as SpotLight3D).visible = lights_on


# ------------------------------------------------------------------ per frame
func _process(delta: float) -> void:
	if car == null:
		return
	_tick_wipers(delta)
	_tick_can()
	_tick_signal(delta)
	if not _busy:
		return
	var w := car.driver_avatar
	if w == null or not is_instance_valid(w):
		_busy = false
		return
	_t += delta
	var dur: float = float(_a["dur"])
	var total := dur + APPROACH * 2.0
	var t_in := clampf(_t - APPROACH, 0.0, dur)
	var k := smoothstep(0.0, APPROACH, _t) * (1.0 - smoothstep(dur + APPROACH, total, _t))
	var pose: Callable = _a["pose"]
	var pos: Vector3 = pose.call(t_in)
	w.set_aux_hand(str(_a["side"]), pos, k)
	w.lean = float(_a["lean"]) * k
	for e in _a["events"]:
		if not e["done"] and t_in >= float(e["t"]) and _t >= APPROACH:
			e["done"] = true
			(e["fn"] as Callable).call()
	if _t >= total:
		w.set_aux_hand(str(_a["side"]), pos, 0.0)
		w.lean = 0.0
		_busy = false
		if not _queue.is_empty():
			_start(str(_queue.pop_front()))


## the can follows the hand while it is held (a little in front of the palm), tilts to drink
func _tick_can() -> void:
	if _can == null or not _can_held or car.driver_avatar == null:
		return
	var hp: Vector3 = car.driver_avatar.hand_car("R")
	_can.position = hp + Vector3(0.0, 0.1, -0.085)
	_can.rotation = Vector3(_can_tilt, 0.0, 0.0)


func _tick_wipers(delta: float) -> void:
	if _wipers.is_empty():
		return
	if _wp_t >= 0.0:
		_wp_t += delta
		var cyc := 1.1
		var u := fmod(_wp_t, cyc) / cyc
		var ang := sin(u * PI) * 1.25
		for a in _wipers:
			a.rotation.z = ang
		var ph := int(_wp_t / cyc)
		if ph != _wp_phase:
			_wp_phase = ph
			if wipers_on:
				Sfx.play3d("wiper", car, -12.0, randf_range(0.95, 1.05))
		if not wipers_on and u > 0.97:                          # finish the sweep, then park
			_wp_t = -1.0
			for a in _wipers:
				a.rotation.z = 0.0
