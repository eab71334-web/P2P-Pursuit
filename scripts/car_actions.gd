# Copyright (c) 2026 Sabak Studios. All rights reserved. See LICENSE.
class_name CarActions
extends Node
## Cabin controls the driver works with his own hands: horn, headlights, wipers, wing mirrors, radio.
## Every action sends ONE hand off the wheel (the other keeps steering), does the movement and puts it back.
## Each car has its own way of doing it (see STYLE): wheel press / thumb button / double slam, stalk / rotary knob /
## rocker switch, electric joystick / manual lever, tuning knob / preset buttons.

signal changed                       # lights / wipers state changed (HUD buttons refresh)
signal net_event(what: String, val: int)   # the local driver did something the other players should see / hear

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
# --- v3 cabin extras
const CRANK_CARS := ["hatch", "buggy", "sierra", "pickup", "muscle"]    # old cars: hand cranks the window; modern: electric switch
var win_target := 0.0            # 0 closed .. 1 open (all windows)
var win_avg := 0.0
var _panes: Array = []
var _pane_v: Array = []
var _win_node: Node3D
var _win_pos := Vector3.ZERO
var hazard := false
var fan_level := 0
var dome_on := false
var hb_on := false
var _hb_t := 0.0
var _hb_lever: Node3D
var _hb_tip: Node3D
var _hb_ang := 0.1
var _hb_style := "lever"
var _hb_off := 0.0
var _hb_up := 0.5
var _hb_btn: MeshInstance3D
var _hb_led_off: StandardMaterial3D = StandardMaterial3D.new()
var _hb_led_on: StandardMaterial3D = StandardMaterial3D.new()
var _dome_light: OmniLight3D
var _dome_mat: StandardMaterial3D
var _ac_node: Node3D
var _haz_node: Node3D
var _haz_mat_on: StandardMaterial3D
var _haz_mat_off: StandardMaterial3D
var _haz_btn: MeshInstance3D
var _fan_snd: AudioStreamPlayer3D
var _flash_spots: Array = []
var _flash_t := 0.0
var _greet_opened := false
var rain := 0.0                  # how wet the weather keeps the windshield (0 dry .. 1 storm); the wipers clear it
var _wet := 0.0


func setup(p_car: Car) -> void:
	car = p_car
	st = STYLE.get(car.model, STYLE["hatch"])
	_pv = car._wheel_pivot
	if _pv == null:
		return
	_hb_led_off.albedo_color = Color(0.25, 0.04, 0.03)
	_hb_led_on.albedo_color = Color(1.0, 0.1, 0.05)
	_hb_led_on.emission_enabled = true
	_hb_led_on.emission = Color(1.0, 0.1, 0.05)
	_hb_led_on.emission_energy_multiplier = 3.0
	_build_controls()
	_build_wipers()
	_build_can()
	_build_signals()
	_build_extras()


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
	for kn in [_knob_l, _knob_w]:
		if kn != null:
			kn.rotation = Vector3(deg_to_rad(72.0), 0, 0)   # face the driver like the dash does
	# --- mirror control: electric joystick or manual lever by the left door
	_joy_pos = Vector3(-0.835, 1.18, -0.14)
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
		net_event.emit("signal", signal_dir)
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
		var on: bool = _sig_on and (hazard or (side == "left" and signal_dir < 0) or (side == "right" and signal_dir > 0))
		for m in _sig_lamps[side]:
			(m as MeshInstance3D).material_override = _sig_mat_on if on else _sig_mat_off


func _tick_signal(delta: float) -> void:
	if signal_dir == 0 and not hazard:
		return
	_sig_age += delta
	_sig_t += delta
	if _sig_t >= 0.36:
		_sig_t = 0.0
		_sig_on = not _sig_on
		_sig_sound(_sig_on)
		_sig_lights()
	if hazard:
		return
	# like a real car it cancels itself after the turn (wheel turned the way of the signal, then straight again)
	if car.is_remote:
		if _sig_age > 25.0:
			_cancel_signal()
		return
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
	net_event.emit("signal", 0)


## what another player did in HIS car (sent by the server): the sound plays from his car, so near rivals hear it
func remote(what: String, val: int) -> void:
	match what:
		"horn":
			Sfx.play3d("horn", car, 4.0, float(st["pitch"]))
		"lights":
			lights_on = val == 1
			_apply_lights()
		"wipers":
			wipers_on = val == 1
			if wipers_on:
				_wp_t = 0.0
		"window":
			win_target = float(val)
			Sfx.play3d("window", car, -8.0, 1.0)
		"dome":
			_set_dome(val == 1)
		"ac":
			_set_fan(val)
		"hazard":
			_set_hazard(val == 1)
		"flash":
			_do_flash()
		"hbrake":
			_set_hb(val == 1, false)
		"greet":
			do("greet")
		"signal":
			signal_dir = val
			_sig_age = 0.0
			_sig_seen = false
			_sig_t = 0.0
			_sig_on = val != 0
			if val != 0:
				_sig_sound(true)
			_sig_lights()


func _cup_holder() -> Vector3:
	return Vector3(0.0, 0.93, 0.42)


func _mouth() -> Vector3:
	return Vector3(-0.43, 1.49 - car.sd, 0.15)   # hand position that puts the can top on the mouth, below the visor


func _build_can() -> void:
	_can = Node3D.new()
	_can.scale = Vector3(1.1, 1.1, 1.1)
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
	var m := _mouth()
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
			_can_tilt = 1.0 * smoothstep(1.4, 1.8, t) * (1.0 - smoothstep(2.3, 2.6, t))
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
		"window":
			_a = _window_act()
		"dome":
			_a = _dome_act()
		"ac":
			_a = _ac_act()
		"hazard":
			_a = _hazard_act()
		"flash":
			_a = _flash_act()
		"hbrake":
			_a = _hbrake_act()
		"greet":
			_a = _greet_act()
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
	var play := func():
		Sfx.play3d("horn", car, 2.0, pitch)
		net_event.emit("horn", 0)
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
		net_event.emit("lights", 1 if lights_on else 0)
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
		net_event.emit("wipers", 1 if wipers_on else 0)
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
	_tick_extras(delta)
	if not _busy:
		return
	var w := car.driver_avatar
	if w == null or not is_instance_valid(w):
		_finish_stuck()
		return
	_t += delta
	if _t > float(_a.get("dur", 1.0)) + APPROACH * 2.0 + 1.5:       # watchdog: never stay stuck
		_finish_stuck()
		return
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
	if _can == null or not _can_held or car.driver_avatar == null or not is_instance_valid(car.driver_avatar):
		return
	var hp: Vector3 = car.driver_avatar.hand_car("R")
	_can.position = hp + Vector3(0.0, 0.07, -0.07)
	_can.rotation = Vector3(_can_tilt, 0.0, 0.0)


func _finish_stuck() -> void:
	_busy = false
	_greet_opened = false
	_queue.clear()
	_can_held = false
	if _can != null:
		_can.position = _cup_holder() + Vector3(0, 0.1, 0)
		_can.rotation = Vector3.ZERO
	var w := car.driver_avatar
	if w != null and is_instance_valid(w):
		w.set_aux_hand("L", Vector3.ZERO, 0.0)
		w.set_aux_hand("R", Vector3.ZERO, 0.0)
		w.lean = 0.0


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
			_wet = maxf(_wet - 0.6, 0.0)                         # every sweep wipes the droplets away
			if wipers_on:
				Sfx.play3d("wiper", car, -12.0, randf_range(0.95, 1.05))
		if not wipers_on and u > 0.97:                          # finish the sweep, then park
			_wp_t = -1.0
			for a in _wipers:
				a.rotation.z = 0.0


# ================================================================== v3: windows, cabin light, fan, hazard, high beam, handbrake, greeting
func _emit(what: String, val: int) -> void:
	if not car.is_remote:
		net_event.emit(what, val)


func _build_extras() -> void:
	var dark := _mat(Color(0.03, 0.03, 0.04), 0.2, 0.5)
	var chrome := _mat(Color(0.78, 0.8, 0.86), 0.9, 0.25)
	var amb := _mat(Color(1.0, 0.6, 0.15), 0.0, 0.5, 1.0)
	# --- driver window control: crank (old cars) or electric rocker switch on the door
	_win_pos = Vector3(-0.835, 1.18, 0.16)   # on the door-card armrest
	if car.model in CRANK_CARS:
		_win_node = Node3D.new()
		_win_node.position = _win_pos + Vector3(0, 0.04, 0)
		car.add_child(_win_node)
		CarStyle.cyl(_win_node, 0.035, 0.012, Vector3(0.006, 0, 0), dark, Vector3(0, 0, 90))
		var mv := Node3D.new()
		_win_node.add_child(mv)
		CarStyle.box(mv, Vector3(0.012, 0.07, 0.012), Vector3(0.02, 0.035, 0), chrome)
		CarStyle.cyl(mv, 0.014, 0.04, Vector3(0.04, 0.07, 0), dark, Vector3(0, 0, 90))
		_win_node.set_meta("mv", mv)
	else:
		_win_node = _make_knob(_win_pos, "switch", dark, chrome, amb)
	# --- cabin dome light on the roof lining
	var rt := 1.95 - car.drop
	var lamp_pos := Vector3(-0.12, rt - 0.03, 0.02)
	_dome_mat = _mat(Color(0.35, 0.33, 0.28), 0.0, 0.4)
	CarStyle.box(car, Vector3(0.22, 0.025, 0.12), lamp_pos, _dome_mat)
	_dome_light = OmniLight3D.new()
	_dome_light.position = lamp_pos + Vector3(0, -0.15, 0.1)
	_dome_light.omni_range = 3.0
	_dome_light.light_energy = 0.9
	_dome_light.light_color = Color(1.0, 0.92, 0.75)
	_dome_light.visible = false
	car.add_child(_dome_light)
	# --- air-conditioning knob + vents under the radio
	# console cluster under the radio, tilted like the radio face so the hazard button and the A/C knob sit flush on it
	var tilt := deg_to_rad(72.0)
	var ydir := Vector3(0, cos(tilt), sin(tilt))
	var zdir := Vector3(0, -sin(tilt), cos(tilt))
	var sport := car.model in ["charger", "coupe", "m4", "gt3", "hyper"]
	var heavy := car.model in ["muscle", "pickup", "sierra"]
	var cl_c := Vector3(0.12, 1.04, -0.725) + zdir * 0.138
	var cl_w := 0.30 if not sport else 0.26
	var cl := Node3D.new()
	cl.position = cl_c
	cl.rotation = Vector3(tilt, 0, 0)
	car.add_child(cl)
	var accent: Color = CarInterior.theme(car.model)["stitch"]
	CarStyle.box(cl, Vector3(cl_w, 0.06, 0.07), Vector3.ZERO, dark)
	CarStyle.box(cl, Vector3(cl_w + 0.01, 0.008, 0.078), Vector3(0, 0.032, 0), chrome if not heavy else _mat(Color(0.25, 0.25, 0.28), 0.6, 0.4))
	if sport:
		CarStyle.box(cl, Vector3(cl_w * 0.9, 0.003, 0.0015), Vector3(0, 0.0365, 0.028), _mat(accent, 0.0, 0.5, 1.0))
	var hx := -cl_w * 0.32
	var kx := cl_w * 0.30
	_ac_node = _make_knob(cl_c + ydir * 0.036 + Vector3(kx, 0, 0), "knob", dark, chrome, amb)
	_ac_node.rotation = Vector3(tilt, 0, 0)
	if sport:
		(_ac_node.get_meta("mv") as Node3D).scale = Vector3(0.8, 0.8, 0.8)
	_fan_snd = Sfx.loop3d("fan_loop", car, -60.0)
	_fan_snd.position = Vector3(0, 1.0, -0.6)
	# --- hazard button (red triangle) left of the radio
	_haz_mat_off = _mat(Color(0.5, 0.05, 0.04), 0.0, 0.5, 0.0)
	_haz_mat_on = _mat(Color(1.0, 0.1, 0.05), 0.0, 0.3, 3.0)
	_haz_node = Node3D.new()
	_haz_node.position = cl_c + ydir * 0.036 + Vector3(hx, 0, 0)
	_haz_node.rotation = Vector3(tilt, 0, 0)
	car.add_child(_haz_node)
	var hz_sz := Vector3(0.05, 0.012, 0.036) if sport else Vector3(0.062, 0.014, 0.042)
	CarStyle.box(_haz_node, Vector3(hz_sz.x + 0.014, 0.008, hz_sz.z + 0.014), Vector3(0, -0.004, 0), dark)
	_haz_btn = CarStyle.box(_haz_node, hz_sz, Vector3(0, 0.006, 0), _haz_mat_off)
	# --- handbrake, one design per car type, mounted on the centre console behind the shifter
	var sy := 1.1 - float(car.sd) * 0.2 + 0.01
	_hb_style = "lever"
	if car.model in ["buggy", "gt3"]:
		_hb_style = "hydro"
	elif car.model in ["charger", "coupe", "m4", "hyper"]:
		_hb_style = "button"
	var boot := _mat(Color(0.015, 0.015, 0.02), 0.2, 0.9)
	var grip := _mat(Color(0.03, 0.03, 0.035), 0.1, 0.85)
	_hb_lever = Node3D.new()
	car.add_child(_hb_lever)
	_hb_tip = Node3D.new()
	_hb_lever.add_child(_hb_tip)
	match _hb_style:
		"lever":
			_hb_lever.position = Vector3(0.0, sy + 0.015, 0.66)
			CarStyle.box(car, Vector3(0.11, 0.035, 0.2), Vector3(0.0, sy + 0.012, 0.58), boot)        # gaiter / slot
			CarStyle.box(_hb_lever, Vector3(0.022, 0.022, 0.34), Vector3(0, 0, -0.17), chrome)
			CarStyle.box(_hb_lever, Vector3(0.05, 0.045, 0.11), Vector3(0, 0.004, -0.36), grip)
			CarStyle.box(_hb_lever, Vector3(0.012, 0.012, 0.05), Vector3(0, 0.03, -0.40), _mat(Color(0.8, 0.1, 0.08), 0.0, 0.5))   # ratchet button
			_hb_tip.position = Vector3(0, 0.0, -0.36)
			_hb_off = 0.02
			_hb_up = 0.52
		"hydro":
			_hb_lever.position = Vector3(0.0, sy + 0.02, 0.5)
			CarStyle.box(car, Vector3(0.09, 0.04, 0.13), Vector3(0.0, sy + 0.012, 0.5), boot)
			CarStyle.cyl(_hb_lever, 0.014, 0.30, Vector3(0, 0.15, 0), chrome)
			CarStyle.box(_hb_lever, Vector3(0.045, 0.1, 0.06), Vector3(0, 0.32, 0.0), grip)
			CarStyle.box(_hb_lever, Vector3(0.05, 0.012, 0.062), Vector3(0, 0.375, 0.0), _mat(Color(0.9, 0.5, 0.05), 0.0, 0.5, 0.4))
			_hb_tip.position = Vector3(0, 0.32, 0)
			_hb_off = -0.06
			_hb_up = 0.62
		_:
			# electric parking brake: round "P" button with a red ring on the console, right of the shifter
			_hb_lever.position = Vector3(0.085, sy + 0.004, 0.3)
			CarStyle.box(_hb_lever, Vector3(0.07, 0.008, 0.07), Vector3(0, -0.002, 0), boot)
			CarStyle.cyl(_hb_lever, 0.026, 0.014, Vector3(0, 0.006, 0), chrome)
			_hb_btn = CarStyle.cyl(_hb_lever, 0.017, 0.016, Vector3(0, 0.009, 0), _hb_led_off)
			_hb_tip.position = Vector3(0, 0.02, 0)
			_hb_off = 0.0
			_hb_up = 0.0
	_hb_ang = _hb_off
	_hb_lever.rotation.x = _hb_ang
	# --- high-beam flash lights (only lit while flashing)
	for x in [-0.6, 0.6]:
		var sp := SpotLight3D.new()
		sp.position = Vector3(x, 0.9, -2.0)
		sp.spot_range = 80.0
		sp.spot_angle = 26.0
		sp.light_energy = 9.0
		sp.light_color = Color(0.92, 0.95, 1.0)
		sp.visible = false
		car.add_child(sp)
		_flash_spots.append(sp)


func _set_win(v: float, emit := true) -> void:
	win_target = v
	Sfx.play3d("window", car, -8.0, 1.0 if v > 0.5 else 0.9)
	if emit:
		_emit("window", int(v))
	changed.emit()


func _set_dome(on: bool) -> void:
	dome_on = on
	if _dome_light != null:
		_dome_light.visible = on
	if _dome_mat != null:
		_dome_mat.emission_enabled = on
		_dome_mat.emission = Color(1.0, 0.93, 0.75)
		_dome_mat.emission_energy_multiplier = 3.0
	changed.emit()


func _set_fan(level: int) -> void:
	fan_level = level
	if _fan_snd != null:
		_fan_snd.volume_db = [-60.0, -30.0, -24.0, -18.0][clampi(level, 0, 3)]
	if _ac_node != null:
		(_ac_node.get_meta("mv") as Node3D).rotation.y = -float(level) * 0.8
	changed.emit()


func _set_hazard(on: bool) -> void:
	hazard = on
	_sig_t = 0.0
	_sig_on = on
	if on:
		_sig_sound(true)
	_sig_lights()
	if _haz_btn != null:
		_haz_btn.material_override = _haz_mat_on if on else _haz_mat_off
	changed.emit()


func _do_flash() -> void:
	_flash_t = 0.6
	Sfx.play3d("horn_short", car, 0.0, float(st["pitch"]))


func _set_hb(on: bool, emit := true) -> void:
	if _hb_btn != null:
		_hb_btn.material_override = _hb_led_on if on else _hb_led_off
	hb_on = on
	_hb_t = 0.0
	if not car.is_remote:
		car.set_handbrake(on)
	Sfx.play3d("hbrake", car, -2.0, 1.0 if on else 0.8)
	if emit:
		_emit("hbrake", 1 if on else 0)
	changed.emit()


func _tick_extras(delta: float) -> void:
	if car.has_meta("rain_mat"):
		_wet = move_toward(_wet, rain, delta * 0.08)
		(car.get_meta("rain_mat") as ShaderMaterial).set_shader_parameter("wet", _wet)
	if _panes.is_empty() and car.has_meta("panes"):
		_panes = car.get_meta("panes")
		_pane_v.resize(_panes.size())
		_pane_v.fill(0.0)
	# windows slide down into the doors (driver's first, the others a little slower)
	if not _panes.is_empty():
		var sum := 0.0
		for i in _panes.size():
			var spd := 0.9 if (float(_panes[i]["side"]) < 0.0 and int(_panes[i]["row"]) == 0) else 0.65
			_pane_v[i] = move_toward(float(_pane_v[i]), win_target, delta * spd)
			var n: Node3D = _panes[i]["node"]
			n.scale.y = maxf(1.0 - float(_pane_v[i]) * 0.97, 0.03)
			n.visible = n.scale.y > 0.05
			sum += float(_pane_v[i])
		win_avg = sum / float(_panes.size())
		if not car.is_remote and Radio != null:
			var b := 7.0 * win_avg
			if absf(b - Radio.window_boost) > 0.1:
				Radio.window_boost = b
				Radio._apply_volume()
	# high-beam flash: quick double blink
	if _flash_t > 0.0:
		_flash_t -= delta
		var on := _flash_t > 0.0 and fmod(_flash_t, 0.3) > 0.12
		for sp in _flash_spots:
			(sp as SpotLight3D).visible = on
	# handbrake: auto release after a moment, lever follows
	if hb_on:
		_hb_t += delta
		if _hb_t > 1.5:
			_set_hb(false)
	if _hb_lever != null and not (_busy and str(_a.get("name", "")) == "hbrake"):
		if _hb_style != "button":
			_hb_ang = lerpf(_hb_ang, _hb_up if hb_on else _hb_off, clampf(delta * 10.0, 0.0, 1.0))
			_hb_lever.rotation.x = _hb_ang


# ---- actions
func _window_act() -> Dictionary:
	var fire := func(): _set_win(0.0 if win_target > 0.5 else 1.0)
	if car.model in CRANK_CARS:
		var base := _win_node.position
		var mv: Node3D = _win_node.get_meta("mv")
		var tick := func(): Sfx.play3d("gear_tick", car, -6.0, 0.9)
		return {"side": "L", "dur": 1.7, "lean": 0.06,
			"events": [_ev(0.45, fire), _ev(0.7, tick), _ev(1.0, tick), _ev(1.3, tick)],
			"pose": func(t: float) -> Vector3:
				var f := smoothstep(0.2, 1.4, t)
				var a := f * TAU * 2.0 * (-1.0 if win_target > 0.5 else 1.0)
				mv.rotation.x = a
				return base + Vector3(0.05, cos(a) * 0.07, sin(a) * 0.07)}
	return _knob_action(_win_node, "switch", "L", fire, win_target > 0.5)


func _dome_act() -> Dictionary:
	var lamp := Vector3(-0.12, 1.95 - car.drop - 0.03, 0.02)
	var fire := func():
		_set_dome(not dome_on)
		Sfx.play3d("click", car, -2.0, 1.2)
		_emit("dome", 1 if dome_on else 0)
	return {"side": "R", "dur": 1.0, "lean": 0.05, "events": [_ev(0.45, fire)],
		"pose": func(t: float) -> Vector3:
			var rise := smoothstep(0.0, 0.4, t)
			var d := smoothstep(0.38, 0.46, t) * (1.0 - smoothstep(0.55, 0.65, t))
			return lamp + Vector3(0, -0.2 + 0.15 * rise + 0.03 * d, 0.03)}


func _ac_act() -> Dictionary:
	var a0 := -float(fan_level) * 0.8
	var nl := (fan_level + 1) % 4
	var a1 := -float(nl) * 0.8
	var fire := func():
		_set_fan(nl)
		Sfx.play3d("click", car, -3.0, 1.0)
		_emit("ac", nl)
	var mv: Node3D = _ac_node.get_meta("mv")
	var base := _ac_node.position + Vector3(0, 0.03, 0)
	return {"side": "R", "dur": 1.0, "lean": 0.3, "events": [_ev(0.5, fire)],
		"pose": func(t: float) -> Vector3:
			var f := smoothstep(0.25, 0.6, t)
			var ang := lerpf(a0, a1, f)
			mv.rotation.y = ang
			var down := smoothstep(0.1, 0.22, t) * (1.0 - smoothstep(0.7, 0.85, t))
			return base + Vector3(sin(-ang) * 0.025, 0.05 * (1.0 - down), cos(ang) * 0.025 - 0.02)}


func _hazard_act() -> Dictionary:
	var fire := func():
		_set_hazard(not hazard)
		Sfx.play3d("click", car, -2.0, 1.4)
		_emit("hazard", 1 if hazard else 0)
	var base := _haz_node.position
	return {"side": "R", "dur": 0.95, "lean": 0.25, "events": [_ev(0.5, fire)],
		"pose": func(t: float) -> Vector3:
			var d := smoothstep(0.3, 0.46, t) * (1.0 - smoothstep(0.55, 0.7, t))
			return base + Vector3(0, 0.07 - 0.06 * d, 0.0)}


func _flash_act() -> Dictionary:
	var sp := _sig_stalk
	var tip := _sig_tip
	var base := _pv.basis
	var fire := func():
		_do_flash()
		_emit("flash", 1)
	return {"side": "L", "dur": 0.9, "lean": 0.0, "events": [_ev(0.3, fire)],
		"pose": func(t: float) -> Vector3:
			var f := smoothstep(0.15, 0.3, t) * (1.0 - smoothstep(0.38, 0.46, t)) + smoothstep(0.5, 0.58, t) * (1.0 - smoothstep(0.7, 0.78, t))
			sp.transform = Transform3D(base * Basis(Vector3(0, 1, 0), 0.22 * f), sp.position)
			return car.to_local(tip.global_position)}


func _hbrake_act() -> Dictionary:
	var rel := hb_on
	var lev := _hb_lever
	var tip := _hb_tip
	var fire := func(): _set_hb(not rel)
	var btn := _hb_style == "button"
	var off := _hb_off
	var up := _hb_up
	return {"side": "R", "dur": 1.1, "lean": 0.08, "events": [_ev(0.5, fire)],
		"pose": func(t: float) -> Vector3:
			var f := smoothstep(0.3, 0.7, t)
			if btn:
				var d := smoothstep(0.35, 0.5, t) * (1.0 - smoothstep(0.55, 0.7, t))
				return car.to_local(tip.global_position) + Vector3(0, 0.075 - 0.05 * d, 0.0)
			var ang := lerpf(up, off, f) if rel else lerpf(off, up, f)
			_hb_ang = ang
			lev.rotation.x = ang
			return car.to_local(tip.global_position) + Vector3(0, 0.055, 0.0)}


func _greet_act() -> Dictionary:
	var sd: float = car.sd
	var open_it := func():
		_greet_opened = win_target < 0.5
		if _greet_opened:
			_set_win(1.0, false)
	var beep1 := func():
		Sfx.play3d("horn_short", car, -2.0, float(st["pitch"]))
		_emit("greet", 1)
	var beep2 := func(): Sfx.play3d("horn_short", car, -2.0, float(st["pitch"]) * 1.12)
	var close_it := func():
		if _greet_opened:
			_set_win(0.0, false)
			_greet_opened = false
	return {"side": "L", "dur": 3.1, "lean": 0.04,
		"events": [_ev(0.0, open_it), _ev(1.3, beep1), _ev(1.6, beep2), _ev(2.7, close_it)],
		"pose": func(t: float) -> Vector3:
			# up inside the cabin first (clear of the door card), then out over the door top through the open window, wave, and back the same way
			var up := smoothstep(0.1, 0.6, t) * (1.0 - smoothstep(2.6, 3.0, t))
			var out := smoothstep(0.7, 1.2, t) * (1.0 - smoothstep(2.2, 2.6, t))
			var wv := sin(t * 11.0) * 0.09 * smoothstep(1.2, 1.4, t) * (1.0 - smoothstep(2.0, 2.2, t))
			var rest := Vector3(-0.55, 1.15 - sd * 0.5, -0.25)
			var hi := Vector3(-0.66, 1.62, -0.12)
			var outer := Vector3(-1.2, 1.7, -0.12 + wv)
			return rest.lerp(hi, up).lerp(outer, out) + Vector3(0, absf(wv) * 0.25, 0)}
