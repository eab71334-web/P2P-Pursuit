# Copyright (c) 2026 KRG Studios. All rights reserved. See LICENSE.
extends Node
## Autoload "Controls": gamepad support (PS4 / PS5 / Xbox / any pad Godot recognises, also over Bluetooth) with buttons the player can
## re-map in Settings, and the touch-controls policy: with a pad connected the on-screen buttons are hidden ("auto").
## Driving axes (steer / gas / brake) are InputMap actions; the cabin buttons are looked up through `cabin_for(event)`.

signal changed

const SAVE := "user://controls.cfg"

## labels use PlayStation names; Godot's JOY_BUTTON_A = Cross, B = Circle, X = Square, Y = Triangle
const BUTTON_NAMES := {
	JOY_BUTTON_A: "Cross ✕", JOY_BUTTON_B: "Circle ○", JOY_BUTTON_X: "Square □", JOY_BUTTON_Y: "Triangle △",
	JOY_BUTTON_LEFT_SHOULDER: "L1", JOY_BUTTON_RIGHT_SHOULDER: "R1", JOY_BUTTON_LEFT_STICK: "L3", JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_DPAD_UP: "D-Pad ↑", JOY_BUTTON_DPAD_DOWN: "D-Pad ↓", JOY_BUTTON_DPAD_LEFT: "D-Pad ←", JOY_BUTTON_DPAD_RIGHT: "D-Pad →",
	JOY_BUTTON_BACK: "Share / Select", JOY_BUTTON_START: "Options / Start", JOY_BUTTON_GUIDE: "PS / Guide", JOY_BUTTON_TOUCHPAD: "Touchpad",
}

## every cabin / game action a pad button can trigger: id -> [English, Arabic]
const ACTIONS := {
	"horn": ["Horn", "بوق"], "flash": ["High beam flash", "ضوء بعيد"], "hbrake": ["Handbrake", "فرامل اليد"], "reset": ["Reset car", "إعادة السيارة"],
	"signal_left": ["Signal left", "إشارة يسار"], "signal_right": ["Signal right", "إشارة يمين"], "lights": ["Lights", "إضاءة"],
	"wipers": ["Wipers", "مساحات"], "mirror_left": ["Mirror left", "مرآة يسار"], "mirror_right": ["Mirror right", "مرآة يمين"],
	"window": ["Windows", "نوافذ"], "hazard": ["Hazard", "طوارئ"], "ac": ["A/C fan", "مروحة"], "dome": ["Cabin light", "إضاءة داخلية"],
	"greet": ["Greet", "تحية"], "drink": ["Drink", "اشرب"], "map_toggle": ["Map", "الخريطة"], "radio_next": ["Radio next", "الراديو التالي"],
	"radio_prev": ["Radio previous", "الراديو السابق"], "emote": ["Emote", "إيماءة"], "look_mate": ["Look at teammate", "التفات للزميل"],
}
## defaults (button -> action). The axes: left stick = steer, R2 = gas, L2 = brake (fixed, they are analogue).
const DEFAULTS := {
	"hbrake": JOY_BUTTON_A, "horn": JOY_BUTTON_X, "flash": JOY_BUTTON_B, "reset": JOY_BUTTON_Y,
	"signal_left": JOY_BUTTON_LEFT_SHOULDER, "signal_right": JOY_BUTTON_RIGHT_SHOULDER,
	"lights": JOY_BUTTON_DPAD_UP, "wipers": JOY_BUTTON_DPAD_DOWN, "mirror_left": JOY_BUTTON_DPAD_LEFT, "mirror_right": JOY_BUTTON_DPAD_RIGHT,
	"window": JOY_BUTTON_LEFT_STICK, "look_mate": JOY_BUTTON_RIGHT_STICK, "map_toggle": JOY_BUTTON_BACK, "radio_next": JOY_BUTTON_TOUCHPAD,
}

var map := {}                  # action id -> pad button (-1 = none)
var touch_mode := "auto"       # auto (hidden while a pad is connected) | show | hide
var _listening := ""           # action being re-mapped (the next pad button press binds it)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load()
	Input.joy_connection_changed.connect(func(_d, _c): changed.emit())


func pad_connected() -> bool:
	return not Input.get_connected_joypads().is_empty()


## true = draw the on-screen driving buttons
func touch_wanted() -> bool:
	match touch_mode:
		"show":
			return true
		"hide":
			return false
	return not pad_connected()


func button_name(b: int) -> String:
	if b < 0:
		return "—"
	return str(BUTTON_NAMES.get(b, "Button %d" % b))


## the action a pad button press stands for ("" = none)
func cabin_for(event: InputEvent) -> String:
	if not (event is InputEventJoypadButton) or not event.pressed:
		return ""
	for a in map:
		if int(map[a]) == event.button_index:
			return a
	return ""


func start_listen(action: String) -> void:
	_listening = action


func listening() -> String:
	return _listening


func _input(event: InputEvent) -> void:
	if _listening != "" and event is InputEventJoypadButton and event.pressed:
		for a in map:                                   # a button belongs to one action only
			if int(map[a]) == event.button_index:
				map[a] = -1
		map[_listening] = event.button_index
		_listening = ""
		_save()
		changed.emit()
		get_viewport().set_input_as_handled()


func reset_defaults() -> void:
	map = DEFAULTS.duplicate()
	for a in ACTIONS:
		if not map.has(a):
			map[a] = -1
	_save()
	changed.emit()


func set_touch_mode(m: String) -> void:
	touch_mode = m
	_save()
	changed.emit()


## analogue driving: called once at start-up from Net._setup_inputs (InputMap actions steer/accel/brake get pad events too)
func add_pad_events() -> void:
	var add := func(action: String, ev: InputEvent):
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_add_event(action, ev)
	for sgn in [-1.0, 1.0]:
		var a := InputEventJoypadMotion.new()
		a.axis = JOY_AXIS_LEFT_X
		a.axis_value = sgn
		add.call("steer_left" if sgn < 0 else "steer_right", a)
	var gas := InputEventJoypadMotion.new()
	gas.axis = JOY_AXIS_TRIGGER_RIGHT
	gas.axis_value = 1.0
	add.call("accel", gas)
	var brk := InputEventJoypadMotion.new()
	brk.axis = JOY_AXIS_TRIGGER_LEFT
	brk.axis_value = 1.0
	add.call("brake", brk)
	InputMap.action_set_deadzone("steer_left", 0.15)
	InputMap.action_set_deadzone("steer_right", 0.15)


func _save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("pad", "map", map)
	cf.set_value("pad", "touch_mode", touch_mode)
	cf.save(SAVE)


func _load() -> void:
	map = DEFAULTS.duplicate()
	for a in ACTIONS:
		if not map.has(a):
			map[a] = -1
	var cf := ConfigFile.new()
	if cf.load(SAVE) == OK:
		var m: Dictionary = cf.get_value("pad", "map", {})
		for a in m:
			if ACTIONS.has(a):
				map[a] = int(m[a])
		touch_mode = str(cf.get_value("pad", "touch_mode", "auto"))
