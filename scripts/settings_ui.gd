# Copyright (c) 2026 AVF. All rights reserved. See LICENSE.
class_name SettingsUI
extends Control
## Settings tab: performance presets (incl. weak-device mode), frame-rate cap, advanced graphics, audio.

var _box: VBoxContainer


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()


func _rebuild() -> void:
	_build.call_deferred()


func _build() -> void:
	for c in get_children():
		c.free()
	var sc := TScroll.new()
	sc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(sc)
	_box = VBoxContainer.new()
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_box.add_theme_constant_override("separation", 10)
	sc.add_child(_box)
	# ---- controls
	_head(UI.tx("CONTROLS", "التحكم"))
	var sm: Array = []
	for m in SteerUI.MODES:
		sm.append([m, SteerUI.mode_name(m)])
	_row(UI.tx("Steering (touch)", "طريقة التوجيه (اللمس)"), SteerUI.mode_desc(Profile.steer_mode if Profile.steer_mode != "" else "buttons"),
		_seg(sm, Profile.steer_mode if Profile.steer_mode != "" else "buttons", func(v): Profile.steer_mode = v; Profile.save(); _rebuild()))
	# ---- performance
	_head(UI.tx("PERFORMANCE", "الأداء"))
	var weak := Gfx.preset == "weak"
	var note := UI.tx("Weak device mode lowers resolution, view distance, effects and mirrors so the game runs smoothly on old phones.",
		"وضع الجهاز الضعيف يخفّض الدقة ومدى الرؤية والمؤثرات والمرايات ليشتغل اللعب بسلاسة على الأجهزة القديمة.")
	var presets: Array = []
	for p in ["auto", "weak", "low", "medium", "high"]:
		presets.append([p, Gfx.preset_label(p)])
	_row(UI.tx("Graphics quality", "جودة الرسوميات"), note, _seg(presets, Gfx.preset, func(v): Gfx.set_preset(v); _rebuild()))
	var fo: Array = []
	for f in Gfx.FPS_OPTIONS:
		fo.append([f, "MAX" if f == 0 else str(f)])
	_row(UI.tx("Frame rate limit (FPS)", "حدّ الفريمات (FPS)"),
		UI.tx("Lower = cooler phone and longer battery. 60 is smooth, 90/120 need a strong device.", "أقل = جهاز أبرد وبطارية أطول. 60 سلس، و90/120 تحتاج جهاز قوي."),
		_seg(fo, Gfx.fps, func(v): Gfx.set_value("fps", v); _rebuild()))
	_row(UI.tx("Adaptive resolution", "دقة تلقائية"),
		UI.tx("Lowers the resolution automatically when the FPS drops during a race.", "تخفّض الدقة تلقائياً لما تنزل الفريمات أثناء السباق."),
		_seg([[true, UI.tx("On", "تشغيل")], [false, UI.tx("Off", "إيقاف")]], Gfx.auto, func(v): Gfx.set_value("auto", v); _rebuild()))
	_row(UI.tx("Show FPS counter", "عرض عدّاد الفريمات"), "",
		_seg([[true, UI.tx("On", "تشغيل")], [false, UI.tx("Off", "إيقاف")]], Gfx.show_fps, func(v): Gfx.show_fps = v; Gfx.apply(); Gfx.save(); _rebuild()))
	# ---- advanced
	_head(UI.tx("ADVANCED GRAPHICS", "رسوميات متقدمة"))
	var sc_opts: Array = []
	for v in [0.5, 0.6, 0.7, 0.85, 1.0]:
		sc_opts.append([v, "%d%%" % int(v * 100)])
	_row(UI.tx("Resolution", "دقة الصورة"), "", _seg(sc_opts, _near(Gfx.scale, [0.5, 0.6, 0.7, 0.85, 1.0]), func(v): Gfx.set_value("scale", v); _rebuild()))
	_row(UI.tx("View distance", "مدى الرؤية"), "",
		_seg([[0.35, UI.tx("Near", "قريب")], [0.55, UI.tx("Short", "قصير")], [0.8, UI.tx("Medium", "متوسط")], [1.0, UI.tx("Far", "بعيد")]], _near(Gfx.dist, [0.35, 0.55, 0.8, 1.0]), func(v): Gfx.set_value("dist", v); _rebuild()))
	_row(UI.tx("Effects (smoke, fire, sparks)", "المؤثرات (دخان، نار، شرار)"), "",
		_seg([[0.25, UI.tx("Min", "أدنى")], [0.5, UI.tx("Low", "قليل")], [0.8, UI.tx("Medium", "متوسط")], [1.0, UI.tx("Full", "كامل")]], _near(Gfx.fx, [0.25, 0.5, 0.8, 1.0]), func(v): Gfx.set_value("fx", v); _rebuild()))
	_row(UI.tx("Scenery (trees)", "المناظر (الأشجار)"), "",
		_seg([[0.3, UI.tx("Few", "قليل")], [0.55, UI.tx("Some", "عادي")], [0.85, UI.tx("Many", "كثير")], [1.0, UI.tx("Full", "كامل")]], _near(Gfx.trees, [0.3, 0.55, 0.85, 1.0]), func(v): Gfx.set_value("trees", v); _rebuild()))
	_row(UI.tx("Mirrors", "المرايات"), UI.tx("Working side and rear-view mirrors cost performance.", "المرايات الحقيقية (الجانبية والأمامية) تستهلك أداء."),
		_seg([[0, UI.tx("Off", "إيقاف")], [1, UI.tx("Rear-view", "الأمامية")], [2, UI.tx("All", "الكل")]], Gfx.mirrors, func(v): Gfx.set_value("mirrors", v); _rebuild()))
	_row(UI.tx("Map screen refresh", "تحديث شاشة الخريطة"), "",
		_seg([[8, "8"], [15, "15"], [30, "30"], [60, "60"]], _near(float(Gfx.map_fps), [8.0, 15.0, 30.0, 60.0]), func(v): Gfx.set_value("map_fps", int(v)); _rebuild()))
	_row(UI.tx("Anti-aliasing", "تنعيم الحواف"), "",
		_seg([[0, UI.tx("Off", "إيقاف")], [2, "2x"], [4, "4x"]], Gfx.msaa, func(v): Gfx.set_value("msaa", v); _rebuild()))
	_row(UI.tx("Animated 3D showroom", "المعرض ثلاثي الأبعاد المتحرك"), UI.tx("Off = static picture in menus (saves battery).", "إيقاف = صورة ثابتة في القوائم (توفر البطارية)."),
		_seg([[true, UI.tx("On", "تشغيل")], [false, UI.tx("Off", "إيقاف")]], Gfx.hero, func(v): Gfx.set_value("hero", v); _rebuild()))
	_row(UI.tx("V-Sync", "مزامنة الشاشة"), "",
		_seg([[true, UI.tx("On", "تشغيل")], [false, UI.tx("Off", "إيقاف")]], Gfx.vsync, func(v): Gfx.vsync = v; Gfx.apply(); Gfx.save(); _rebuild()))
	# ---- sound / feel
	_head(UI.tx("SOUND & FEEL", "الصوت والإحساس"))
	var vo := [[0.0, UI.tx("Mute", "صامت")], [0.4, "40%"], [0.7, "70%"], [1.0, "100%"]]
	_row(UI.tx("Master volume", "مستوى الصوت العام"), "", _seg(vo, _near(Gfx.vol_master, [0.0, 0.4, 0.7, 1.0]), func(v): Gfx.vol_master = v; Gfx.apply(); Gfx.save(); _rebuild()))
	_row(UI.tx("Radio volume", "مستوى الراديو"), "", _seg(vo, _near(Gfx.vol_radio, [0.0, 0.4, 0.7, 1.0]), func(v): Gfx.vol_radio = v; Gfx.apply(); Gfx.save(); _rebuild()))
	_row(UI.tx("Vibration", "الاهتزاز"), "",
		_seg([[true, UI.tx("On", "تشغيل")], [false, UI.tx("Off", "إيقاف")]], Gfx.haptics, func(v): Gfx.haptics = v; Gfx.save(); _rebuild()))
	if weak:
		var tip := UI.lbl(_box, UI.tx("Tip: close other apps, and set the phone to battery-saver off for steady FPS.", "نصيحة: سكّر التطبيقات الثانية وأوقف وضع توفير الطاقة عشان تثبت الفريمات."), 15, UI.TXT2)
		tip.custom_minimum_size = Vector2(300, 0)
	_head(UI.tx("ABOUT & LICENSE", "حول اللعبة والرخصة"))
	var lic := UI.lbl(_box, UI.tx("Co-Driver Rally  (c) 2026 AVF. All rights reserved.\nThis game, its code, art, sounds and all files are the exclusive property of AVF. Copying, modifying, redistributing, re-publishing, selling, extracting assets or removing this notice is prohibited without written permission.", "رالي السائق المساعد  (c) 2026 AVF. جميع الحقوق محفوظة.\nهذه اللعبة وكودها وصورها وأصواتها وكل ملفاتها ملكٌ حصريٌّ لـ AVF. يُمنع النسخ أو التعديل أو إعادة التوزيع أو النشر أو البيع أو استخراج الملفات أو إزالة هذا الإشعار دون إذن كتابي."), 14, UI.TXT2)
	lic.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lic.custom_minimum_size = Vector2(300, 0)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 20)
	_box.add_child(sp)


func _near(v: float, opts: Array) -> float:
	var best: float = opts[0]
	for o in opts:
		if absf(float(o) - v) < absf(best - v):
			best = o
	return best


func _head(text: String) -> void:
	var l := UI.lbl(_box, text, 15, UI.ACCENT, false)
	l.add_theme_constant_override("outline_size", 0)


func _row(title: String, desc: String, ctrl: Control) -> void:
	var p := UI.panel(_box, UI.CARD, 10)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	p.add_child(h)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.custom_minimum_size = Vector2(260, 0)
	h.add_child(v)
	UI.lbl(v, title, 19, UI.TXT)
	if desc != "":
		UI.lbl(v, desc, 13, UI.TXT2)
	ctrl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ctrl)


## segmented control: options = [[value, label], ...]
func _seg(opts: Array, cur, cb: Callable) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	for o in opts:
		var on: bool = (o[0] == cur) or (typeof(o[0]) == TYPE_FLOAT and typeof(cur) == TYPE_FLOAT and is_equal_approx(o[0], cur))
		var b := Button.new()
		b.text = str(o[1])
		b.custom_minimum_size = Vector2(66, 42)
		b.add_theme_font_size_override("font_size", 16)
		var col := UI.ACCENT if on else Color(1, 1, 1, 0.06)
		b.add_theme_stylebox_override("normal", UI.sb(col, 8))
		b.add_theme_stylebox_override("hover", UI.sb(col.lightened(0.15), 8))
		b.add_theme_stylebox_override("pressed", UI.sb(col.darkened(0.1), 8))
		b.add_theme_stylebox_override("focus", UI.sb(col, 8))
		b.add_theme_color_override("font_color", Color(0.08, 0.06, 0.04) if on else UI.TXT2)
		b.add_theme_color_override("font_hover_color", Color(0.08, 0.06, 0.04) if on else UI.TXT)
		var val = o[0]
		b.pressed.connect(func():
			Sfx.play("click", -8.0)
			cb.call(val))
		h.add_child(b)
	return h
