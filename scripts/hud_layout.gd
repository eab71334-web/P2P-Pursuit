# Copyright (c) 2026 KRG Studios. All rights reserved. See LICENSE.
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
	"c_more": {"fx": 0.238, "fy": 0.669, "w": 110.0, "h": 68.0},
	"left": {"fx": 0.07, "fy": 0.854, "w": 140.0, "h": 130.0},
	"right": {"fx": 0.195, "fy": 0.854, "w": 140.0, "h": 130.0},
	"c_drink": {"fx": 0.238, "fy": 0.564, "w": 110.0, "h": 68.0},
	"c_mirl": {"fx": 0.054, "fy": 0.669, "w": 110.0, "h": 68.0},
	"c_mirr": {"fx": 0.146, "fy": 0.669, "w": 110.0, "h": 68.0},
	# the rest of the race screen (centres / sizes as the game lays them out at 1280x720)
	"reset": {"fx": 0.936, "fy": 0.051, "w": 136.0, "h": 46.0},
	"emote": {"fx": 0.936, "fy": 0.129, "w": 136.0, "h": 46.0},
	"punch": {"fx": 0.936, "fy": 0.207, "w": 136.0, "h": 46.0},
	"stickers": {"fx": 0.936, "fy": 0.285, "w": 136.0, "h": 46.0},
	"photo": {"fx": 0.936, "fy": 0.440, "w": 136.0, "h": 46.0},
	"hudcfg": {"fx": 0.064, "fy": 0.160, "w": 136.0, "h": 42.0},
	"menu": {"fx": 0.064, "fy": 0.229, "w": 136.0, "h": 42.0},
	"radio_prev": {"fx": 0.409, "fy": 0.949, "w": 50.0, "h": 46.0},
	"radio_name": {"fx": 0.5, "fy": 0.949, "w": 172.0, "h": 46.0},
	"radio_next": {"fx": 0.591, "fy": 0.949, "w": 50.0, "h": 46.0},
	"msize": {"fx": 0.752, "fy": 0.724, "w": 80.0, "h": 46.0},
	"mnear": {"fx": 0.819, "fy": 0.724, "w": 80.0, "h": 46.0},
	"map": {"fx": 0.886, "fy": 0.724, "w": 80.0, "h": 46.0},
	"beacon": {"fx": 0.953, "fy": 0.724, "w": 80.0, "h": 46.0},
	"g_left": {"fx": 0.052, "fy": 0.91, "w": 92.0, "h": 70.0},
	"g_fwd": {"fx": 0.13, "fy": 0.91, "w": 92.0, "h": 70.0},
	"g_right": {"fx": 0.208, "fy": 0.91, "w": 92.0, "h": 70.0},
	"g_stop": {"fx": 0.286, "fy": 0.91, "w": 92.0, "h": 70.0},
}
## other buttons of the race screen that the player may switch off (they keep their own place; no moving)
const HIDEABLE := ["reset", "emote", "punch", "stickers", "photo", "menu", "hudcfg", "radio_prev", "radio_name", "radio_next", "msize", "mnear", "map", "beacon", "g_left", "g_fwd", "g_right", "g_stop"]
## the six-plus extras live in the "More" page by default; the player can ADD them to the screen as free buttons
## (default spot below, then he drags them wherever he wants).
## gas and brake cannot be removed (touch driving needs them)
const LOCKED := ["gas", "brake", "left", "right", "reset", "emote", "stickers", "menu"]
const EXTRA := ["p2_haz", "p2_flash", "p2_hb", "p2_win", "p2_ac", "p2_dome", "p2_greet", "c_kind"]
const ESSENTIAL := ["gas", "brake", "left", "right", "c_horn", "c_sigl", "c_sigr", "c_lights", "c_wipers", "c_more", "c_drink", "c_mirl", "c_mirr"]
const ORDER := ["gas", "brake", "left", "right", "c_horn", "c_sigl", "c_sigr", "c_lights", "c_wipers", "c_more",
	"reset", "emote", "punch", "stickers", "photo", "menu", "hudcfg", "radio_prev", "radio_name", "radio_next", "msize", "mnear", "map", "beacon", "g_left", "g_fwd", "g_right", "g_stop",
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
		"c_lights": UI.tx("LIGHTS", "إضاءة"), "c_wipers": UI.tx("WIPER", "مساحات"), "c_more": UI.tx("MORE >>", "المزيد >>"),
		"reset": UI.tx("Reset car", "إعادة السيارة"), "emote": UI.tx("Emote", "حركة"), "punch": UI.tx("Punch", "لكمة"),
		"left": UI.tx("Steer <", "توجيه <"), "right": UI.tx("Steer >", "توجيه >"), "stickers": UI.tx("Stickers", "ملصقات"), "photo": UI.tx("Photo", "صورة"), "menu": UI.tx("Menu", "القائمة"), "hudcfg": UI.tx("Buttons", "الأزرار"), "radio_prev": UI.tx("Radio <", "راديو <"), "radio_name": UI.tx("Radio", "راديو"), "radio_next": UI.tx("Radio >", "راديو >"),
		"msize": UI.tx("SIZE", "الحجم"), "mnear": UI.tx("NEAR", "قرّب"), "map": UI.tx("MAP", "الخريطة"), "beacon": UI.tx("Signal", "إشارة"),
		"g_left": UI.tx("Say: left", "قل: يسار"), "g_fwd": UI.tx("Say: forward", "قل: قدام"), "g_right": UI.tx("Say: right", "قل: يمين"), "g_stop": UI.tx("Say: stop", "قل: قف"),
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
				"sc": float(cf.get_value(id, "sc", 1.0)), "rot": float(cf.get_value(id, "rot", 0.0)), "al": float(cf.get_value(id, "al", 1.0))}


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


## transparency of ONE button (the editor sets it on the selected buttons)
static func get_alpha(id: String) -> float:
	_load()
	return clampf(float((_data[id] as Dictionary).get("al", 1.0)), 0.15, 1.0) if _data.has(id) else 1.0


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
	return {"fx": d["fx"], "fy": d["fy"], "sc": 1.0, "rot": 0.0, "al": 1.0}


static var _real := {}                 # where the game really put each button on THIS screen (centre fractions + size)


## does this button exist in the race the player is in (solo has no punch, drivers no gesture row ...)
static func exists(id: String) -> bool:
	return _real.is_empty() or _real.has(id) or EXTRA.has(id)


static func _def(id: String) -> Dictionary:
	if _real.has(id) and not EXTRA.has(id):
		return _real[id]
	if DEFAULTS.has(id):
		return DEFAULTS[id]
	var i := EXTRA.find(id)
	if i < 0:
		i = 0
	return {"fx": 0.31 + 0.1 * float(i % 5), "fy": 0.33 + 0.105 * float(i / 5), "w": 110.0, "h": 68.0}


static func set_entry(id: String, e: Dictionary) -> void:
	_load()
	e["fx"] = clampf(float(e["fx"]), 0.03, 0.97)
	e["fy"] = clampf(float(e["fy"]), 0.04, 0.96)
	e["sc"] = clampf(float(e["sc"]), SC_MIN, SC_MAX)
	e["rot"] = wrapf(float(e["rot"]), -180.0, 180.0)
	e["al"] = clampf(float(e.get("al", 1.0)), 0.15, 1.0)
	_data[id] = e
	save()


static func reset(id := "") -> void:
	_load()
	if id == "":
		_data.clear()
		_hidden.clear()
	elif EXTRA.has(id) and _data.has(id):
		_data[id] = {"fx": _def(id)["fx"], "fy": _def(id)["fy"], "sc": 1.0, "rot": 0.0, "al": 1.0}      # stays on screen, back to its default spot
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
			var P := z.get_viewport_rect().size
			if P.x > 10.0 and P.y > 10.0:
				_real[id] = {"fx": z.anchor_left + (z.offset_left + z.offset_right) * 0.5 / P.x, "fy": z.anchor_top + (z.offset_top + z.offset_bottom) * 0.5 / P.y,
					"w": z.offset_right - z.offset_left, "h": z.offset_bottom - z.offset_top}
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
	if not exists(id):
		return false
	if ESSENTIAL.has(id) or HIDEABLE.has(id):
		return not _hidden.has(id)
	return _data.has(id)


static func add_button(id: String) -> void:
	_load()
	if ESSENTIAL.has(id) or HIDEABLE.has(id):
		_hidden.erase(id)
		save()
	elif not _data.has(id):
		var e := entry(id)
		set_entry(id, e)


static func remove_button(id: String) -> void:
	_load()
	if LOCKED.has(id):
		return
	if ESSENTIAL.has(id) or HIDEABLE.has(id):
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
