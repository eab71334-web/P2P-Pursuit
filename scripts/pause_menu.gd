class_name PauseMenu
extends Control
## In-race menu (like big games): tabs on the side - Controls, Graphics, Sound, Game - and a clear
## Continue / Leave pair at the bottom. Leaving always asks first. No transparency here (that lives in the button editor).

var hud_editor_cb := Callable()
var exit_cb := Callable()
var steer_cb := Callable()
var reset_cb := Callable()
var photo_cb := Callable()
var _confirm: Control
static var last_tab := "controls"
var _tab := last_tab
var _content: VBoxContainer
var _tabs := {}
var _dim: ColorRect
var _blur: ShaderMaterial
var _card: Control
var _closing := false
var _seg_n := 0
var _pop_seg := -1
var _pop_at := 0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 300
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 1)
	var bsh := Shader.new()
	bsh.code = BLUR_SHADER
	_blur = ShaderMaterial.new()
	_blur.shader = bsh
	_dim.material = _blur
	_dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)
	var vs := get_viewport_rect().size
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(cc)
	var card := UI.panel(cc, UI.PANEL, 18)
	var cw := minf(880.0, vs.x - 24.0)
	var ch := minf(520.0, vs.y - 20.0)
	card.custom_minimum_size = Vector2(cw, ch)
	var csb := UI.sb(Color(0, 0, 0, 0), 20, Color(1, 1, 1, 0.16), 2)
	csb.content_margin_left = 0
	csb.content_margin_right = 0
	csb.content_margin_top = 0
	csb.content_margin_bottom = 0
	card.add_theme_stylebox_override("panel", csb)
	_card = card
	var bg := ColorRect.new()
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = BG_SHADER
	var mat := ShaderMaterial.new()
	mat.shader = sh
	bg.material = mat
	bg.resized.connect(func(): mat.set_shader_parameter("rect_size", bg.size))
	card.add_child(bg)
	card.layout_direction = Control.LAYOUT_DIRECTION_LOCALE      # Arabic: tabs on the right, like the language reads
	var pad := MarginContainer.new()
	for mk in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + mk, 16)
	card.add_child(pad)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	pad.add_child(v)
	var t := UI.lbl(v, UI.tx("MENU", "القائمة"), 26, Color.WHITE, false)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var mid := HBoxContainer.new()
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 10)
	v.add_child(mid)
	# side tabs
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 6)
	side.custom_minimum_size = Vector2(150, 0)
	mid.add_child(side)
	for tb in [["controls", UI.tx("Controls", "التحكم"), "pad"], ["graphics", UI.tx("Graphics", "الرسوميات"), "screen"], ["sound", UI.tx("Sound", "الصوت"), "sound"], ["game", UI.tx("Game", "اللعبة"), "flag"]]:
		var key: String = tb[0]
		var b := UI.btn(side, tb[1], UI.CARD2, func():
			if _tab != key:
				_tab = key
				last_tab = key
				_fill(true), 19, Vector2(0, 52))
		var ic := HudEditor.Ico.new(str(tb[2]))
		ic.layout_direction = Control.LAYOUT_DIRECTION_LTR
		ic.anchor_top = 0.5
		ic.anchor_bottom = 0.5
		ic.offset_top = -11
		ic.offset_bottom = 11
		var rtl := TranslationServer.get_locale().begins_with("ar")
		ic.anchor_left = 1.0 if rtl else 0.0
		ic.anchor_right = ic.anchor_left
		ic.offset_left = -32 if rtl else 10
		ic.offset_right = -10 if rtl else 32
		b.add_child(ic)
		_tabs[key] = b
	var sc := TScroll.new()
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	mid.add_child(sc)
	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 8)
	sc.add_child(_content)
	# bottom: continue + leave
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	var go := UI.btn(row, UI.tx("Continue", "متابعة"), UI.ACCENT, func(): _close(), 22, Vector2(0, 54))
	go.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ex := UI.btn(row, UI.tx("Leave the race", "الخروج من اللعبة"), Color(0.62, 0.14, 0.14), _ask_exit, 22, Vector2(0, 54))
	ex.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_fill()
	_juice(self)
	_open_anim()


const BLUR_SHADER := """
shader_type canvas_item;
uniform sampler2D scr : hint_screen_texture, filter_linear_mipmap;
uniform float lod = 2.6;
uniform float dark = 0.5;
void fragment() {
	vec3 c = textureLod(scr, SCREEN_UV, lod).rgb;
	COLOR = vec4(c * (1.0 - dark), 1.0);
}
"""
const BG_SHADER := """
shader_type canvas_item;
uniform vec2 rect_size = vec2(800.0, 500.0);
uniform float radius = 20.0;
void fragment() {
	vec2 p = UV * rect_size - rect_size * 0.5;
	vec2 q = abs(p) - (rect_size * 0.5 - vec2(radius));
	float d = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - radius;
	float a = 1.0 - smoothstep(-1.0, 1.0, d);
	vec3 top = vec3(0.13, 0.15, 0.24);
	vec3 bot = vec3(0.05, 0.055, 0.085);
	vec3 col = mix(top, bot, smoothstep(0.0, 1.0, UV.y));
	float glow = smoothstep(0.7, 0.0, distance(UV, vec2(0.85, 0.0)));
	col += vec3(0.30, 0.17, 0.04) * glow * 0.45;
	COLOR = vec4(col, 0.985 * a);
}
"""


## opening: dim fades in, the card pops up a little
func _open_anim() -> void:
	_dim.modulate.a = 0.0
	_card.modulate.a = 0.0
	await get_tree().process_frame
	if not is_instance_valid(_card):
		return
	_card.pivot_offset = _card.size * 0.5
	_card.scale = Vector2(0.92, 0.92)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_dim, "modulate:a", 1.0, 0.2)
	tw.tween_property(_card, "modulate:a", 1.0, 0.18)
	tw.tween_property(_card, "scale", Vector2.ONE, 0.26).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## closing: the card shrinks and fades, then the menu is gone
func _close() -> void:
	if _closing:
		return
	_closing = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_dim, "modulate:a", 0.0, 0.15)
	tw.tween_property(_card, "modulate:a", 0.0, 0.13)
	tw.tween_property(_card, "scale", Vector2(0.94, 0.94), 0.15)
	tw.chain().tween_callback(queue_free)


## small bounce for a control (used when a choice lands)
func _pop(c: Control) -> void:
	c.resized.connect(func(): c.pivot_offset = c.size * 0.5)
	c.pivot_offset = c.size * 0.5
	c.scale = Vector2(0.86, 0.86)
	c.create_tween().tween_property(c, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## every button squeezes a little while pressed
func _juice(root: Node) -> void:
	for n in root.find_children("*", "Button", true, false):
		var b := n as Button
		if b.has_meta("juiced"):
			continue
		b.set_meta("juiced", true)
		b.resized.connect(func(): b.pivot_offset = b.size * 0.5)
		b.pivot_offset = b.size * 0.5
		b.button_down.connect(func():
			b.create_tween().tween_property(b, "scale", Vector2(0.95, 0.95), 0.06))
		b.button_up.connect(func():
			b.create_tween().tween_property(b, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))


func _fill(anim := false) -> void:
	for k in _tabs:
		var on: bool = k == _tab
		var b := _tabs[k] as Button
		for st in ["normal", "hover", "pressed", "focus"]:
			var tsb := UI.sb(UI.ACCENT if on else UI.CARD2, 12)
			if TranslationServer.get_locale().begins_with("ar"):
				tsb.content_margin_right = 40
			else:
				tsb.content_margin_left = 40
			b.add_theme_stylebox_override(st, tsb)
		b.add_theme_color_override("font_color", Color(0.08, 0.06, 0.04) if on else UI.TXT)
		b.add_theme_color_override("font_hover_color", Color(0.08, 0.06, 0.04) if on else UI.TXT)
	for c in _content.get_children():
		_content.remove_child(c)
		c.queue_free()
	_seg_n = 0
	match _tab:
		"controls": _tab_controls()
		"graphics": _tab_graphics()
		"sound": _tab_sound()
		_: _tab_game()
	if anim:                                        # tab switch: the rows slide in one after another
		var i := 0
		for c in _content.get_children():
			if c is Control:
				var cc := c as Control
				cc.modulate.a = 0.0
				var tw := cc.create_tween().set_parallel(true)
				tw.tween_property(cc, "modulate:a", 1.0, 0.18).set_delay(0.045 * i)
				i += 1
	_juice(_content)


func _seg(opts: Array, cur, cb: Callable) -> Control:
	var my_idx := _seg_n
	_seg_n += 1
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 4)
	for o in opts:
		var on: bool = (o[0] == cur) or (typeof(o[0]) == TYPE_FLOAT and typeof(cur) == TYPE_FLOAT and is_equal_approx(o[0], cur))
		var b := Button.new()
		b.text = str(o[1])
		b.custom_minimum_size = Vector2(0, 42)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 16)
		var col := UI.ACCENT if on else Color(1, 1, 1, 0.07)
		for st in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(st, UI.sb(col, 8))
		b.add_theme_color_override("font_color", Color(0.08, 0.06, 0.04) if on else UI.TXT2)
		b.add_theme_color_override("font_hover_color", Color(0.08, 0.06, 0.04) if on else UI.TXT)
		var val = o[0]
		if on and _pop_seg == my_idx and Time.get_ticks_msec() - _pop_at < 600:      # the value just picked pops into place
			_pop(b)
		b.pressed.connect(func():
			Sfx.play("click", -8.0)
			_pop_seg = my_idx
			_pop_at = Time.get_ticks_msec()
			cb.call(val)
			_fill())
		h.add_child(b)
	return h


func _row(title: String, ctl: Control, hint := "") -> void:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UI.sb(Color(1, 1, 1, 0.045), 14))
	var m := MarginContainer.new()
	for k in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + k, 10)
	pc.add_child(m)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	m.add_child(vb)
	UI.lbl(vb, title, 18, UI.TXT, false)
	if hint != "":
		UI.lbl(vb, hint, 13, UI.TXT2, true)
	vb.add_child(ctl)
	_content.add_child(pc)


func _big(text: String, col: Color, cb: Callable) -> void:
	var b := UI.btn(_content, text, col, cb, 20, Vector2(0, 56))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _near(v: float, opts: Array) -> float:
	var best: float = opts[0]
	for o in opts:
		if absf(float(o) - v) < absf(best - v):
			best = float(o)
	return best


func _onoff() -> Array:
	return [[true, UI.tx("On", "تشغيل")], [false, UI.tx("Off", "إيقاف")]]


func _tab_controls() -> void:
	if hud_editor_cb.is_valid():
		_big(UI.tx("Customise buttons", "تخصيص الأزرار"), Color(0.16, 0.34, 0.56), func():
			_close()
			hud_editor_cb.call())
	var sm := [["buttons", UI.tx("Buttons", "أزرار")], ["wheel", UI.tx("Wheel", "مقود")], ["wheel360", UI.tx("Wheel 360", "مقود 360")]]
	var cur: String = Profile.steer_mode if Profile.steer_mode != "" else "buttons"
	_row(UI.tx("Steering (touch)", "طريقة التوجيه (اللمس)"), _seg(sm, cur, func(x):
		Profile.steer_mode = x
		Profile.save()
		if steer_cb.is_valid():
			steer_cb.call()))
	_row(UI.tx("Gamepad (PS4 / PS5 / Xbox)", "يد التحكم (PS4 / PS5 / Xbox)"),
		_seg([["auto", UI.tx("Auto", "تلقائي")], ["show", UI.tx("Show", "إظهار")], ["hide", UI.tx("Hide", "إخفاء")]], Controls.touch_mode, func(x): Controls.set_touch_mode(x)),
		UI.tx("Touch buttons: Auto hides them while a gamepad is connected.", "أزرار اللمس: تلقائي يخفيها عند توصيل يد تحكم."))
	_big(UI.tx("Gamepad buttons", "أزرار اليد"), Color(0.3, 0.3, 0.45), func():
		get_tree().root.add_child(PadEditor.new()))


func _tab_graphics() -> void:
	var presets: Array = []
	for p in ["auto", "weak", "low", "medium", "high"]:
		presets.append([p, Gfx.preset_label(p)])
	_row(UI.tx("Graphics quality", "جودة الرسوميات"), _seg(presets, Gfx.preset, func(x): Gfx.set_preset(x)))
	var fo: Array = []
	for f in Gfx.FPS_OPTIONS:
		fo.append([f, "MAX" if f == 0 else str(f)])
	_row(UI.tx("Frame rate limit (FPS)", "حدّ الفريمات (FPS)"), _seg(fo, Gfx.fps, func(x): Gfx.set_value("fps", x)))
	_row(UI.tx("Resolution", "دقة الصورة"), _seg([[0.5, "50%"], [0.6, "60%"], [0.7, "70%"], [0.85, "85%"], [1.0, "100%"]], _near(Gfx.scale, [0.5, 0.6, 0.7, 0.85, 1.0]), func(x): Gfx.set_value("scale", x)))
	_row(UI.tx("View distance", "مدى الرؤية"), _seg([[0.35, UI.tx("Near", "قريب")], [0.55, UI.tx("Short", "قصير")], [0.8, UI.tx("Medium", "متوسط")], [1.0, UI.tx("Far", "بعيد")]], _near(Gfx.dist, [0.35, 0.55, 0.8, 1.0]), func(x): Gfx.set_value("dist", x)))
	_row(UI.tx("Effects", "المؤثرات"), _seg([[0.25, UI.tx("Min", "أدنى")], [0.5, UI.tx("Low", "قليل")], [0.8, UI.tx("Medium", "متوسط")], [1.0, UI.tx("Full", "كامل")]], _near(Gfx.fx, [0.25, 0.5, 0.8, 1.0]), func(x): Gfx.set_value("fx", x)))
	_row(UI.tx("Mirrors", "المرايا"), _seg([[0, UI.tx("Off", "إيقاف")], [1, UI.tx("Rear-view", "الأمامية")], [2, UI.tx("All", "الكل")]], Gfx.mirrors, func(x): Gfx.set_value("mirrors", x)))
	_row(UI.tx("Anti-aliasing", "تنعيم الحواف"), _seg([[0, UI.tx("Off", "إيقاف")], [2, "2x"], [4, "4x"]], Gfx.msaa, func(x): Gfx.set_value("msaa", x)))
	_row(UI.tx("Adaptive resolution", "دقة تلقائية"), _seg(_onoff(), Gfx.auto, func(x): Gfx.set_value("auto", x)))


func _tab_sound() -> void:
	var vo := [[0.0, UI.tx("Off", "إيقاف")], [0.4, "40%"], [0.7, "70%"], [1.0, "100%"]]
	_row(UI.tx("Master volume", "مستوى الصوت العام"), _seg(vo, _near(Gfx.vol_master, [0.0, 0.4, 0.7, 1.0]), func(x):
		Gfx.vol_master = x
		Gfx.apply()
		Gfx.save()))
	_row(UI.tx("Radio volume", "مستوى الراديو"), _seg(vo, _near(Gfx.vol_radio, [0.0, 0.4, 0.7, 1.0]), func(x):
		Gfx.vol_radio = x
		Gfx.apply()
		Gfx.save()))


func _tab_game() -> void:
	if reset_cb.is_valid():
		_big(UI.tx("Reset car to the road", "إعادة السيارة للطريق"), Color(0.16, 0.34, 0.56), func():
			_close()
			reset_cb.call())
	if photo_cb.is_valid():
		_big(UI.tx("Take a photo", "التقاط صورة"), Color(0.3, 0.3, 0.45), func():
			_close()
			photo_cb.call())
	_row(UI.tx("Show FPS counter", "عرض عدّاد الفريمات"), _seg(_onoff(), Gfx.show_fps, func(x):
		Gfx.show_fps = x
		Gfx.apply()
		Gfx.save()))
	_row(UI.tx("Vibration", "الاهتزاز"), _seg(_onoff(), Gfx.haptics, func(x):
		Gfx.haptics = x
		Gfx.save()))


func _ask_exit() -> void:
	if _confirm != null and is_instance_valid(_confirm):
		return
	_confirm = Control.new()
	_confirm.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confirm.z_index = 10
	add_child(_confirm)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confirm.add_child(dim)
	var cc := CenterContainer.new()
	cc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_confirm.add_child(cc)
	var card := UI.panel(cc, UI.PANEL, 18)
	card.custom_minimum_size = Vector2(520, 0)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	card.add_child(v)
	var h := UI.lbl(v, UI.tx("Leave the race?", "هل تريد الخروج من اللعبة؟"), 26, Color(1.0, 0.8, 0.3), false)
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var m := UI.lbl(v, UI.tx("Your progress in this race will be lost.", "ستخسر تقدّمك في هذا السباق."), 17, UI.TXT2, true)
	m.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	var no := UI.btn(row, UI.tx("Cancel", "إلغاء"), UI.CARD2, func(): _confirm.queue_free(), 22, Vector2(0, 56))
	no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var yes := UI.btn(row, UI.tx("Leave", "خروج"), Color(0.6, 0.15, 0.15), func():
		if exit_cb.is_valid():
			exit_cb.call(), 22, Vector2(0, 56))
	yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
