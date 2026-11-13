class_name SelfTest
extends Control
## TEMPORARY full check of the game, run on the player's own device: engine/device info, every catalog entry,
## all 3D cars, the rigged character, tracks, sounds, translations, input map, storage, livery, backend.
## Shows a pass / warning / fail list that can be copied or sent to the developer.
## It cannot catch runtime script errors of screens it does not open - those are listed under "not covered".

const SOUNDS := ["beep", "boom", "cheer", "clang", "click", "crash_hard", "ding", "fanfare", "fizz", "gear_clunk", "gear_tick", "go", "hbrake", "horn", "horn_short",
	"pop", "shutter", "sip", "stinger_crash", "stinger_win", "success", "thud", "warn", "whoosh", "window", "wiper"]

var _list: VBoxContainer
var _scroll: ScrollContainer
var _sum: Label
var _status: Label
var _lines: Array = []                  # [state, name, detail]
var _fail := 0
var _warn := 0
var _ok := 0
var _done := false


static func open(host: Node) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 95
	host.add_child(layer)
	var st := SelfTest.new()
	layer.add_child(st)
	st.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	st.tree_exited.connect(layer.queue_free)


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.035, 0.05, 0.98)
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 14
	v.offset_right = -14
	v.offset_top = 10
	v.offset_bottom = -10
	UI.lbl(v, UI.tx("FULL GAME CHECK (temporary)", "فحص شامل للعبة (مؤقت)"), 24, Color.WHITE, false)
	_sum = UI.lbl(v, "", 18, UI.TXT2, false)
	_status = UI.lbl(v, UI.tx("Running...", "جاري الفحص..."), 15, UI.ACCENT, false)
	_scroll = TScroll.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 2)
	_scroll.add_child(_list)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	UI.btn(row, UI.tx("Copy report", "نسخ التقرير"), UI.CARD2, func():
		DisplayServer.clipboard_set(_report())
		_status.text = UI.tx("Copied", "تم النسخ"), 18, Vector2(0, 48)).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI.btn(row, UI.tx("Send to developer", "إرسال للمطوّر"), Color(0.2, 0.4, 0.6), func():
		Backend.report("selftest", _report().left(3500))
		_status.text = UI.tx("Sent", "تم الإرسال"), 18, Vector2(0, 48)).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI.btn(row, UI.tx("Close", "إغلاق"), UI.ACCENT, func(): queue_free(), 18, Vector2(0, 48)).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_run.call_deferred()


func _add(state: String, nm: String, detail := "") -> void:
	_lines.append([state, nm, detail])
	match state:
		"ok":
			_ok += 1
		"warn":
			_warn += 1
		"fail":
			_fail += 1
	if state == "head":
		var h := UI.lbl(_list, nm, 17, UI.ACCENT, false)
		h.add_theme_constant_override("line_spacing", 6)
		return
	var col := UI.OK if state == "ok" else (Color(1.0, 0.8, 0.3) if state == "warn" else Color(1.0, 0.4, 0.35))
	var mark := "OK " if state == "ok" else ("!! " if state == "warn" else "XX ")
	var l := UI.lbl(_list, mark + nm + ((" - " + detail) if detail != "" else ""), 14, col, true)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sum.text = "OK %d   %s %d   %s %d" % [_ok, UI.tx("Warnings", "تحذيرات"), _warn, UI.tx("Failed", "فاشلة"), _fail]


func _check(cond: bool, nm: String, detail_fail := "", detail_ok := "") -> void:
	_add("ok" if cond else "fail", nm, detail_ok if cond else detail_fail)


func _head(t: String) -> void:
	_add("head", "== " + t + " ==")


func _report() -> String:
	var t := "HAIRPIN RUSH self-test  %s\n" % Time.get_datetime_string_from_system()
	for ln in _lines:
		if ln[0] == "head":
			t += "\n" + ln[1] + "\n"
		else:
			t += "[%s] %s%s\n" % [String(ln[0]).to_upper(), ln[1], (" - " + ln[2]) if ln[2] != "" else ""]
	t += "\nOK %d  WARN %d  FAIL %d" % [_ok, _warn, _fail]
	return t


func _run() -> void:
	await _sec_device()
	await _sec_catalog()
	await _sec_profile()
	await _sec_sounds()
	await _sec_i18n_input()
	await _sec_storage_livery()
	await _sec_tracks()
	await _sec_cars()
	await _sec_avatar()
	await _sec_backend()
	_head(UI.tx("Not covered by this check", "غير مشمول بهذا الفحص"))
	_add("warn", UI.tx("Real touch driving, multiplayer rooms, purchases, ads and gamepad need a person to test them.", "القيادة باللمس الفعلي، غرف اللعب الجماعي، الشراء، الإعلانات، ويد التحكم تحتاج شخصاً يجربها."))
	_done = true
	_status.text = UI.tx("Finished", "انتهى الفحص")
	if _fail == 0:
		_status.add_theme_color_override("font_color", UI.OK)


func _step(msg: String) -> void:
	_status.text = msg
	await get_tree().process_frame


# ---------------------------------------------------------------- sections
func _sec_device() -> void:
	_head(UI.tx("Device and engine", "الجهاز والمحرك"))
	await _step("device")
	_add("ok", "Godot", Engine.get_version_info().get("string", "?"))
	_add("ok", UI.tx("Game version", "نسخة اللعبة"), str(Backend.VERSION))
	_add("ok", UI.tx("System", "النظام"), "%s %s  %s" % [OS.get_name(), OS.get_version(), OS.get_model_name()])
	_add("ok", UI.tx("Renderer", "الرسوم"), "%s / %s" % [RenderingServer.get_video_adapter_name(), str(ProjectSettings.get_setting("rendering/renderer/rendering_method"))])
	_add("ok", UI.tx("Screen", "الشاشة"), "%s  scale %.2f  %s" % [str(DisplayServer.window_get_size()), DisplayServer.screen_get_scale(), OS.get_locale()])
	_add("ok", UI.tx("Quality preset", "جودة الرسوم"), str(Gfx.preset))
	var mem := OS.get_static_memory_usage() / 1048576.0
	_add("ok" if mem < 900.0 else "warn", UI.tx("Memory in use", "الذاكرة المستخدمة"), "%.0f MB" % mem)
	# frame rate over one second
	var t0 := Time.get_ticks_msec()
	var n := 0
	while Time.get_ticks_msec() - t0 < 1000:
		await get_tree().process_frame
		n += 1
	var fps := float(n)
	_add("ok" if fps >= 25.0 else "warn", "FPS (menu)", "%.0f" % fps)


func _sec_catalog() -> void:
	_head(UI.tx("Cars and items", "السيارات والعناصر"))
	await _step("catalog")
	var bad: Array = []
	for id in Catalog.CAR_ORDER:
		var m: Dictionary = Catalog.CARS.get(id, {})
		for k in ["power", "top", "grip", "armor", "price", "lvl", "r", "d"]:
			if not m.has(k):
				bad.append("%s.%s" % [id, k])
		if Catalog.nm(m) == "":
			bad.append(id + ".name")
	_check(bad.is_empty(), UI.tx("Cars (%d)", "السيارات (%d)") % Catalog.CAR_ORDER.size(), "missing: " + ", ".join(bad.slice(0, 8)))
	for slot in Catalog.CAR_SLOT_ORDER:
		var ids: Array = Catalog.CAR_SLOT_ORDER[slot]
		var miss: Array = []
		for id in ids:
			var e: Dictionary = Catalog.entry(slot, id)
			if e.is_empty() or Catalog.nm(e) == "" or not e.has("r"):
				miss.append(id)
		_check(miss.is_empty(), "%s (%d)" % [slot, ids.size()], "broken: " + ", ".join(miss.slice(0, 8)))
	for slot in Catalog.OUTFIT_ORDER:
		var ids2: Array = Catalog.OUTFIT_SLOTS[slot].keys()
		var miss2: Array = []
		for id in ids2:
			var e2: Dictionary = Catalog.entry(slot, id)
			if e2.is_empty() or Catalog.nm(e2) == "":
				miss2.append(id)
		_check(miss2.is_empty(), "outfit %s (%d)" % [slot, ids2.size()], "broken: " + ", ".join(miss2.slice(0, 8)))
	var pm: Array = []
	for pid in Catalog.PART_SLOTS:
		if not Catalog.PARTS.has(pid):
			pm.append(pid)
	_check(pm.is_empty(), "parts (%d)" % Catalog.PART_SLOTS.size(), "missing: " + ", ".join(pm))
	var wm: Array = []
	for cid in Catalog.CAR_ORDER:
		if Catalog.wheel_opts(cid).is_empty():
			wm.append(cid)
	_check(wm.is_empty(), UI.tx("Wheel options for every car", "العجلات لكل سيارة"), "none for: " + ", ".join(wm))
	var lv_bad: Array = []
	for slot2 in Catalog.CAR_SLOT_ORDER:
		for id3 in Catalog.CAR_SLOT_ORDER[slot2]:
			var e3: Dictionary = Catalog.entry(slot2, id3)
			if not e3.is_empty() and Catalog.item_lvl(e3) < 1:
				lv_bad.append("%s/%s" % [slot2, id3])
	_check(lv_bad.is_empty(), UI.tx("Level gates", "مستويات القفل"), "bad: " + ", ".join(lv_bad.slice(0, 6)))


func _sec_profile() -> void:
	_head(UI.tx("Player data", "بيانات اللاعب"))
	await _step("profile")
	_check(Catalog.CARS.has(Profile.car), UI.tx("Current car exists", "السيارة الحالية موجودة"), Profile.car)
	_check(Profile.cars.has(Profile.car), UI.tx("Current car is owned", "السيارة الحالية مملوكة"))
	_check(Profile.coins >= 0 and Profile.gems >= 0, UI.tx("Coins and gems not negative", "العملات والجواهر غير سالبة"), "%d / %d" % [Profile.coins, Profile.gems])
	_check(Profile.level >= 1, UI.tx("Level", "المستوى"), "bad", str(Profile.level))
	var cs: Dictionary = Profile.car_set()
	var bad: Array = []
	for slot in ["paint", "stripe", "rim", "glow", "decal", "flag", "spoiler", "front", "hood", "skirts", "wheel"]:
		var e: Dictionary = Catalog.entry(slot, str(cs.get(slot, "")))
		if e.is_empty():
			bad.append("%s=%s" % [slot, cs.get(slot, "")])
	_check(bad.is_empty(), UI.tx("Equipped items are valid", "العناصر المركّبة سليمة"), ", ".join(bad))
	var ob: Array = []
	for slot3 in Catalog.OUTFIT_ORDER:
		if Catalog.entry(slot3, str(Profile.outfit.get(slot3, ""))).is_empty():
			ob.append(slot3)
	_check(ob.is_empty(), UI.tx("Character outfit is valid", "ملابس الشخصية سليمة"), ", ".join(ob))
	_check(FileAccess.file_exists(Profile.SAVE), UI.tx("Save file exists", "ملف الحفظ موجود"))


func _sec_sounds() -> void:
	_head(UI.tx("Sounds", "الأصوات"))
	await _step("sounds")
	var miss: Array = []
	for s in SOUNDS:
		if Sfx.stream(s) == null:
			miss.append(s)
	_check(miss.is_empty(), "%d %s" % [SOUNDS.size(), UI.tx("sound effects", "مؤثر صوتي")], "missing: " + ", ".join(miss))
	_check(AudioServer.get_bus_count() > 0, UI.tx("Audio buses", "قنوات الصوت"))


func _sec_i18n_input() -> void:
	_head(UI.tx("Text and controls", "النصوص والتحكم"))
	await _step("i18n")
	var empty: Array = []
	for k in L.T:
		var pair: Array = L.T[k]
		if pair.size() < 2 or ((str(pair[0]) == "") != (str(pair[1]) == "")):
			empty.append(str(k))
	_check(empty.is_empty(), "%d %s" % [L.T.size(), UI.tx("translations (EN+AR)", "ترجمة (إنجليزي + عربي)")], "empty: " + ", ".join(empty.slice(0, 10)))
	var acts: Array = []
	var noev: Array = []
	for a in InputMap.get_actions():
		if str(a).begins_with("ui_"):
			continue
		acts.append(a)
		if InputMap.action_get_events(a).is_empty():
			noev.append(str(a))
	_check(noev.is_empty() and acts.size() > 0, "%d %s" % [acts.size(), UI.tx("input actions", "أوامر تحكم")], "no keys: " + ", ".join(noev))
	_add("ok", UI.tx("Touchscreen", "شاشة اللمس"), str(DisplayServer.is_touchscreen_available()))
	_add("ok", UI.tx("Gamepads connected", "أيادي متصلة"), str(Input.get_connected_joypads().size()))


func _sec_storage_livery() -> void:
	_head(UI.tx("Storage and spray studio", "التخزين واستوديو الرش"))
	await _step("storage")
	var p := "user://_selftest.txt"
	var f := FileAccess.open(p, FileAccess.WRITE)
	var wrote := false
	if f:
		f.store_string("ok")
		f.close()
		var g := FileAccess.open(p, FileAccess.READ)
		wrote = g != null and g.get_as_text() == "ok"
		DirAccess.remove_absolute(p)
	_check(wrote, UI.tx("Write and read a file on the device", "كتابة وقراءة ملف على الجهاز"), "cannot write user://")
	var im := Image.create(Livery.W, Livery.SIDE_H, false, Image.FORMAT_RGBA8)
	im.fill_rect(Rect2i(10, 10, 50, 50), Color(1, 0, 0, 1))
	Livery.save_img("_selftest", "side", im)
	var back := Livery.load_img("_selftest", "side")
	_check(back.get_pixel(20, 20).r > 0.9 and Livery.exists("_selftest"), UI.tx("Paint job save / load", "حفظ وتحميل الطلاء اليدوي"), "mismatch")
	Livery.clear("_selftest")
	var sh := Shader.new()
	sh.code = Livery.SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	_check(mat != null, UI.tx("Paint job shader", "شيدر الطلاء"))


func _sec_tracks() -> void:
	_head(UI.tx("Stages", "المراحل"))
	await _step("tracks")
	for sd in [1, 7, 23, 99, 4242]:
		var t0 := Time.get_ticks_msec()
		var st := Track.design_stage(sd)
		var tr := Track.from_stage(st)
		var ms := Time.get_ticks_msec() - t0
		_check(tr != null, UI.tx("Stage seed %d", "مرحلة رقم %d") % sd, "failed to build", "%d ms  %s" % [ms, str(st.get("theme", ""))])
		await get_tree().process_frame


func _sec_cars() -> void:
	_head(UI.tx("3D cars", "السيارات ثلاثية الأبعاد"))
	var vp := SubViewport.new()
	vp.size = Vector2i(160, 100)
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(vp)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 3, 9)
	vp.add_child(cam)
	cam.look_at(Vector3(0, 1, 0))
	for id in Catalog.CAR_ORDER:
		await _step("car " + id)
		var t0 := Time.get_ticks_msec()
		var car := Car.new()
		var lo := {"car": id, "paint": "red", "stripe": "none", "rim": "steel", "glow": "none", "decal": "none", "flag": "none", "spoiler": "none", "front": "none", "hood": "none", "skirts": "none", "wheel": "stock", "dp": CarStyle.DEFAULT_DP.duplicate(), "up": {}, "outfit": Profile.outfit}
		car.setup(0, Color(0.8, 0.1, 0.1), false, lo, true)
		vp.add_child(car)
		await get_tree().process_frame
		var meshes := car.find_children("*", "MeshInstance3D", true, false).size()
		var ms := Time.get_ticks_msec() - t0
		var good := car.body_mat != null and meshes > 20
		_check(good, id, "body=%s meshes=%d" % [str(car.body_mat != null), meshes], "%d parts, %d ms" % [meshes, ms])
		car.queue_free()
		await get_tree().process_frame
	# every paint, rim, wheel design and body kit on the first car
	var bad: Array = []
	for slot in ["paint", "stripe", "rim", "glow", "decal", "wheel", "spoiler", "front", "hood", "skirts"]:
		var ids: Array = Catalog.CAR_SLOT_ORDER[slot]
		if slot == "wheel":
			ids = Catalog.wheel_opts("hatch")
		elif Catalog.BODY_SLOTS.has(slot):
			ids = Catalog.body_opts("hatch", slot)
		for iid in ids:
			var car2 := Car.new()
			var lo2 := {"car": "hatch", "paint": "red", "stripe": "none", "rim": "steel", "glow": "none", "decal": "none", "flag": "none", "spoiler": "none", "front": "none", "hood": "none", "skirts": "none", "wheel": "stock", "dp": CarStyle.DEFAULT_DP.duplicate(), "up": {}, "outfit": Profile.outfit}
			lo2[slot] = iid
			car2.setup(0, Color(0.8, 0.1, 0.1), false, lo2, true)
			vp.add_child(car2)
			await get_tree().process_frame
			if car2.body_mat == null:
				bad.append("%s/%s" % [slot, iid])
			car2.queue_free()
		await _step("variants " + slot)
	_check(bad.is_empty(), UI.tx("Every paint / stripe / rim / kit / wheel builds", "كل طلاء / خط / جنط / طقم / عجلة يُبنى"), ", ".join(bad.slice(0, 8)))
	vp.queue_free()


func _sec_avatar() -> void:
	_head(UI.tx("Character", "الشخصية"))
	await _step("avatar")
	var vp := SubViewport.new()
	vp.size = Vector2i(120, 120)
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(vp)
	var av := Avatar.new()
	av.role = "preview"
	av.standing = true
	av.outfit = Profile.outfit
	vp.add_child(av)
	await get_tree().process_frame
	await get_tree().process_frame
	_check(RiggedActor.available(), UI.tx("Character model file", "ملف نموذج الشخصية"), "missing")
	if Gfx.human_chars:
		_check(av._rig_sk != null, UI.tx("Rigged body loads", "الجسم المتحرك يُحمَّل"), "skeleton missing", "%d bones" % (av._rig_sk.get_bone_count() if av._rig_sk else 0))
	else:
		_add("warn", UI.tx("Human characters are off in graphics settings", "الشخصيات البشرية مطفية في إعدادات الرسوم"), "box characters are used")
	vp.queue_free()


func _sec_backend() -> void:
	_head(UI.tx("Server", "الخادم"))
	await _step("backend")
	if Backend.url == "":
		_add("warn", UI.tx("Server address", "عنوان الخادم"), "offline mode")
		return
	var res := {"done": false, "code": -1, "ms": 0}
	var t0 := Time.get_ticks_msec()
	Backend.call_api(HTTPClient.METHOD_GET, "/api/config?game=" + Backend.GAME, null, func(code: int, d: Dictionary):
		res["done"] = true
		res["code"] = code
		res["ok"] = d.get("ok", false)
		res["ms"] = Time.get_ticks_msec() - t0)
	var w := 0.0
	while not res["done"] and w < 20.0:
		await get_tree().create_timer(0.25).timeout
		w += 0.25
	if not res["done"]:
		_add("fail", UI.tx("Server reply", "رد الخادم"), "no answer in 20 s")
	elif int(res["code"]) == 200 and res.get("ok", false):
		_add("ok" if int(res["ms"]) < 4000 else "warn", UI.tx("Server reply", "رد الخادم"), "%d ms" % int(res["ms"]))
	else:
		_add("fail", UI.tx("Server reply", "رد الخادم"), "HTTP %d" % int(res["code"]))
