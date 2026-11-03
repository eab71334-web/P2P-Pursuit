# Copyright (c) 2026 Sabak Studios. All rights reserved. See LICENSE.
class_name HudLayout
extends RefCounted
## Player-made layout of the essential driving buttons (gas, brake, horn, signals, lights, wipers):
## position (fraction of the screen), size and rotation, saved on the device. The editor (HudEditor) writes it,
## the race HUD (world.gd) reads it. Buttons with no saved entry stay exactly where the game puts them.

const SAVE := "user://hud_layout.cfg"
## id -> default centre (fraction of the screen) and size in px, matching the race HUD
const DEFAULTS := {
	"gas": {"fx": 0.926, "fy": 0.854, "w": 150.0, "h": 130.0},
	"brake": {"fx": 0.793, "fy": 0.854, "w": 150.0, "h": 130.0},
	"c_sigl": {"fx": 0.054, "fy": 0.458, "w": 110.0, "h": 68.0},
	"c_horn": {"fx": 0.146, "fy": 0.458, "w": 110.0, "h": 68.0},
	"c_sigr": {"fx": 0.238, "fy": 0.458, "w": 110.0, "h": 68.0},
	"c_lights": {"fx": 0.054, "fy": 0.564, "w": 110.0, "h": 68.0},
	"c_wipers": {"fx": 0.146, "fy": 0.564, "w": 110.0, "h": 68.0},
}
## the six-plus extras live in the "More" page by default; the player can ADD them to the screen as free buttons
## (default spot below, then he drags them wherever he wants).
## gas and brake cannot be removed (touch driving needs them)
const LOCKED := ["gas", "brake"]
const EXTRA := ["c_drink", "c_mirl", "c_mirr", "p2_haz", "p2_flash", "p2_hb", "p2_win", "p2_ac", "p2_dome", "p2_greet", "c_kind"]
const ESSENTIAL := ["gas", "brake", "c_horn", "c_sigl", "c_sigr", "c_lights", "c_wipers"]
const ORDER := ["gas", "brake", "c_horn", "c_sigl", "c_sigr", "c_lights", "c_wipers",
	"c_drink", "c_mirl", "c_mirr", "p2_haz", "p2_flash", "p2_hb", "p2_win", "p2_ac", "p2_dome", "p2_greet", "c_kind"]
const SC_MIN := 0.6
const SC_MAX := 1.8

static var _data := {}                 # the layout in use (what the race shows)
static var _hidden := {}               # essential buttons the player removed from the screen
static var _slots: Array = []         # saved presets: [{filled: bool, data: Dictionary}]; 3 to start, the player can add more
static var active := 0
const MIN_SLOTS := 3
static var _loaded := false
static var intro_seen := false


static func names() -> Dictionary:
	return {"gas": UI.tx("GAS", "بنزين"), "brake": UI.tx("BRAKE", "فرامل"), "c_horn": UI.tx("HORN", "بوق"),
		"c_sigl": UI.tx("< SIGNAL", "< إشارة"), "c_sigr": UI.tx("SIGNAL >", "إشارة >"),
		"c_lights": UI.tx("LIGHTS", "إضاءة"), "c_wipers": UI.tx("WIPER", "مساحات"),
		"c_drink": UI.tx("DRINK", "اشرب"), "c_mirl": UI.tx("MIRROR L", "مرآة يسار"), "c_mirr": UI.tx("MIRROR R", "مرآة يمين"),
		"p2_haz": UI.tx("HAZARD", "طوارئ"), "p2_flash": UI.tx("HIGH BEAM", "ضوء بعيد"), "p2_hb": UI.tx("HANDBRAKE", "فرامل يد"),
		"p2_win": UI.tx("WINDOWS", "نوافذ"), "p2_ac": UI.tx("A/C FAN", "مروحة"), "p2_dome": UI.tx("CABIN LIGHT", "إضاءة داخلية"),
		"p2_greet": UI.tx("GREET", "تحية"), "c_kind": UI.tx("JUICE / ENERGY", "عصير / طاقة")}


static func _load() -> void:
	if _loaded:
		return
	_loaded = true
	for i in MIN_SLOTS:
		_slots.append({"filled": false, "data": {}})
	var cf := ConfigFile.new()
	if cf.load(SAVE) != OK:
		return
	var n := int(cf.get_value("slots", "n", MIN_SLOTS))
	active = int(cf.get_value("slots", "active", 0))
	while _slots.size() < n:
		_slots.append({"filled": false, "data": {}})
	for i in n:
		var sec := "slot_%d" % i
		if cf.has_section(sec):
			_slots[i] = {"filled": bool(cf.get_value(sec, "filled", false)), "data": cf.get_value(sec, "data", {}), "hidden": cf.get_value(sec, "hidden", {})}
	active = clampi(active, 0, _slots.size() - 1)
	intro_seen = bool(cf.get_value("meta", "intro_seen", false))
	_hidden = cf.get_value("working", "hidden", {})
	for id in ORDER:
		if cf.has_section(id):
			_data[id] = {"fx": float(cf.get_value(id, "fx", 0.5)), "fy": float(cf.get_value(id, "fy", 0.5)),
				"sc": float(cf.get_value(id, "sc", 1.0)), "rot": float(cf.get_value(id, "rot", 0.0))}


static func save() -> void:
	var cf := ConfigFile.new()
	cf.set_value("meta", "intro_seen", intro_seen)
	cf.set_value("slots", "n", _slots.size())
	cf.set_value("slots", "active", active)
	for i in _slots.size():
		cf.set_value("slot_%d" % i, "filled", _slots[i]["filled"])
		cf.set_value("slot_%d" % i, "data", _slots[i]["data"])
		cf.set_value("slot_%d" % i, "hidden", _slots[i].get("hidden", {}))
	cf.set_value("working", "hidden", _hidden)
	for id in _data:
		var e: Dictionary = _data[id]
		for k in e:
			cf.set_value(id, k, e[k])
	cf.save(SAVE)


static func mark_intro() -> void:
	_load()
	intro_seen = true
	save()


static func is_intro_seen() -> bool:
	_load()
	return intro_seen


static func has_saved(id: String) -> bool:
	_load()
	return _data.has(id)


static func entry(id: String) -> Dictionary:
	_load()
	if _data.has(id):
		return (_data[id] as Dictionary).duplicate()
	var d := _def(id)
	return {"fx": d["fx"], "fy": d["fy"], "sc": 1.0, "rot": 0.0}


static func _def(id: String) -> Dictionary:
	if DEFAULTS.has(id):
		return DEFAULTS[id]
	var i := EXTRA.find(id)
	if i < 0:
		i = 0
	return {"fx": 0.31 + 0.1 * float(i % 5), "fy": 0.33 + 0.105 * float(i / 5), "w": 110.0, "h": 68.0}


static func set_entry(id: String, e: Dictionary) -> void:
	_load()
	e["fx"] = clampf(float(e["fx"]), 0.03, 0.97)
	e["fy"] = clampf(float(e["fy"]), 0.2, 0.86)
	e["sc"] = clampf(float(e["sc"]), SC_MIN, SC_MAX)
	e["rot"] = wrapf(float(e["rot"]), -180.0, 180.0)
	_data[id] = e
	save()


static func reset(id := "") -> void:
	_load()
	if id == "":
		_data.clear()
		_hidden.clear()
	elif EXTRA.has(id) and _data.has(id):
		_data[id] = {"fx": _def(id)["fx"], "fy": _def(id)["fy"], "sc": 1.0, "rot": 0.0}      # stays on screen, back to its default spot
	else:
		_data.erase(id)
	save()


## put a Control where the layout says (anchored at the saved screen fraction, scaled and rotated around its centre)
static func place(c: Control, id: String) -> void:
	var e := entry(id)
	var d := _def(id)
	var w: float = d["w"]
	var h: float = d["h"]
	c.anchor_left = e["fx"]
	c.anchor_right = e["fx"]
	c.anchor_top = e["fy"]
	c.anchor_bottom = e["fy"]
	c.offset_left = -w * 0.5
	c.offset_right = w * 0.5
	c.offset_top = -h * 0.5
	c.offset_bottom = h * 0.5
	c.pivot_offset = Vector2(w * 0.5, h * 0.5)
	c.scale = Vector2(e["sc"], e["sc"])
	c.rotation = deg_to_rad(float(e["rot"]))


## race HUD: the player's changes only (buttons he never touched stay exactly where the game puts them)
static var _orig := {}
static var _hid := {}


static func apply_world(zones: Dictionary) -> void:
	_load()
	for id in ORDER:
		if not zones.has(id):
			continue
		var z := zones[id] as Control
		var key := z.get_instance_id()
		if not _orig.has(key):                    # remember where the game put it
			_orig[key] = {"al": z.anchor_left, "ar": z.anchor_right, "at": z.anchor_top, "ab": z.anchor_bottom,
				"ol": z.offset_left, "or": z.offset_right, "ot": z.offset_top, "ob": z.offset_bottom,
				"pv": z.pivot_offset, "sc": z.scale, "rot": z.rotation}
		if is_removed(id):
			z.visible = false
			_hid[key] = true
		elif _data.has(id):
			place(z, id)
			if EXTRA.has(id):
				z.visible = true
		else:                                      # untouched (or reset / removed again): back to the game's own spot
			var o: Dictionary = _orig[key]
			z.anchor_left = o["al"]
			z.anchor_right = o["ar"]
			z.anchor_top = o["at"]
			z.anchor_bottom = o["ab"]
			z.offset_left = o["ol"]
			z.offset_right = o["or"]
			z.offset_top = o["ot"]
			z.offset_bottom = o["ob"]
			z.pivot_offset = o["pv"]
			z.scale = o["sc"]
			z.rotation = o["rot"]
		if _hid.has(key) and not is_removed(id):      # put back on the screen after being removed
			_hid.erase(key)
			z.visible = true


## essential button taken off the screen
static func is_removed(id: String) -> bool:
	_load()
	return _hidden.has(id)


## extra button the player put on the screen (free, always visible - no longer in the More page)
static func is_added(id: String) -> bool:
	_load()
	return EXTRA.has(id) and _data.has(id)


## is the button part of the player's screen right now (what the editor shows)
static func is_on_screen(id: String) -> bool:
	_load()
	if ESSENTIAL.has(id):
		return not _hidden.has(id)
	return _data.has(id)


static func add_button(id: String) -> void:
	_load()
	if ESSENTIAL.has(id):
		_hidden.erase(id)
		save()
	elif not _data.has(id):
		var e := entry(id)
		set_entry(id, e)


static func remove_button(id: String) -> void:
	_load()
	if ESSENTIAL.has(id):
		_hidden[id] = true
	else:
		_data.erase(id)
	save()


# ---- saved presets ("slots"): save the current layout, load, delete, add as many as you like
static func slot_count() -> int:
	_load()
	return _slots.size()


static func slot_filled(i: int) -> bool:
	_load()
	return i >= 0 and i < _slots.size() and bool(_slots[i]["filled"])


static func all_filled() -> bool:
	_load()
	for sl in _slots:
		if not bool(sl["filled"]):
			return false
	return true


static func select_slot(i: int) -> void:
	_load()
	if i < 0 or i >= _slots.size():
		return
	active = i
	_data = (_slots[i]["data"] as Dictionary).duplicate(true) if bool(_slots[i]["filled"]) else {}
	_hidden = (_slots[i].get("hidden", {}) as Dictionary).duplicate(true) if bool(_slots[i]["filled"]) else {}
	save()


static func save_slot() -> void:
	_load()
	_slots[active] = {"filled": true, "data": _data.duplicate(true), "hidden": _hidden.duplicate(true)}
	save()


## empties a slot; extra slots (4th and up) disappear completely
static func delete_slot(i: int) -> void:
	_load()
	if i < 0 or i >= _slots.size():
		return
	if i >= MIN_SLOTS:
		_slots.remove_at(i)
	else:
		_slots[i] = {"filled": false, "data": {}, "hidden": {}}
	active = clampi(i if i < _slots.size() else _slots.size() - 1, 0, _slots.size() - 1)
	_data.clear()
	_hidden.clear()
	save()


static func add_slot() -> void:
	_load()
	_slots.append({"filled": false, "data": {}})
	select_slot(_slots.size() - 1)


## editor "Exit" throws the unsaved changes away: remember what was in use when it opened
static func snapshot() -> Dictionary:
	_load()
	return {"data": _data.duplicate(true), "active": active, "hidden": _hidden.duplicate(true)}


static func restore(snap: Dictionary) -> void:
	_load()
	_data = (snap["data"] as Dictionary).duplicate(true)
	_hidden = (snap["hidden"] as Dictionary).duplicate(true)
	active = clampi(int(snap["active"]), 0, _slots.size() - 1)
	save()
