class_name PaintStudio
extends Control
## Spray studio: an empty screen with the car; pick one of the colours you own and spray with your finger.
## Tools: airbrush, fine nozzle, wide fan, splatter, straight line, eraser, fill. Undo/redo, drips, mirror, templates, random spray.
## The paint is saved as a livery (see Livery) and projected onto the real 3D car.

signal closed(changed: bool)

const MAXUNDO := 12
const TOOLS := [
	["air", "رش ناعم", "Airbrush"], ["fine", "فوهة دقيقة", "Fine"], ["fan", "مروحة", "Fan"], ["splat", "رشق", "Splatter"],
	["line", "خط مستقيم", "Line"], ["erase", "ممحاة", "Eraser"], ["fill", "تعبئة", "Fill"]]

var car_id := "hatch"
var lo := {}
var view := "side"                      # side | top
var layers := {}                        # view -> Image (the paint)
var masks := {}                         # view -> Image (silhouette of the car)
var shots := {}                         # view -> ImageTexture (the car without paint)
var tool := "air"
var colour := Color(0.9, 0.1, 0.12)
var rand_colour := false
var size_f := 0.35
var flow_f := 0.7
var drips_on := true
var mirror_on := false
var changed := false

var _undo: Array = []
var _redo: Array = []
var _stage: Control
var _paint_tr: TextureRect
var _car_tr: TextureRect
var _tex := {}                          # view -> ImageTexture (paint layer)
var _area: Control
var _down := false
var _last := Vector2.ZERO
var _line_a := Vector2.ZERO
var _line_b := Vector2.ZERO
var _cursor := Vector2(-100, -100)
var _dwell := 0.0
var _drips: Array = []
var _brush_cache := {}
var _brush_key := ""
var _tool_btns := {}
var _view_btns := {}
var _pal: GridContainer
var _ready_ok := false
var _view3d: Control
var _owned: Array = []
var _hint: Label
var _undo_b: Button
var _redo_b: Button
var _mirror_b: Button
var _drip_b: Button
var _rand_b: Button
var _size_s: HSlider
var _flow_s: HSlider
var _sw: ColorRect


static func open(host: Node, p_car: String, p_lo: Dictionary, on_close: Callable) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 80
	host.add_child(layer)
	var st := PaintStudio.new()
	st.car_id = p_car
	st.lo = p_lo.duplicate()
	st.lo["lv"] = false
	layer.add_child(st)
	st.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	st.closed.connect(func(ch: bool):
		layer.queue_free()
		on_close.call(ch))


func _ready() -> void:
	for id in Catalog.PAINT_ORDER:
		if Profile.owns("paint", id):
			_owned.append(id)
	if _owned.is_empty():
		_owned = ["red"]
	colour = Catalog.PAINTS[_owned[0]]["c"]
	layers["side"] = Livery.load_img(car_id, "side")
	layers["top"] = Livery.load_img(car_id, "top")
	_build_ui()
	_render_cars()


# ---------------------------------------------------------------- UI
func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.045, 0.06)
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# top bar
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	add_child(top)
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 12
	top.offset_right = -12
	top.offset_top = 8
	top.offset_bottom = 58
	UI.btn(top, UI.tx("< Back", "< رجوع"), UI.CARD2, func(): _close(), 20, Vector2(110, 48))
	var title := UI.lbl(top, UI.tx("SPRAY STUDIO", "استوديو الرش"), 24, Color.WHITE, false)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for v in [["side", "جانب", "Side"], ["top", "سقف", "Top"], ["3d", "ثلاثي الأبعاد", "3D"]]:
		var b := UI.btn(top, UI.tx(v[2], v[1]), UI.CARD2, func(): _set_view(v[0]), 18, Vector2(96, 48))
		_view_btns[v[0]] = b
	_undo_b = UI.btn(top, UI.tx("Undo", "تراجع"), UI.CARD2, func(): _do_undo(), 18, Vector2(86, 48))
	_redo_b = UI.btn(top, UI.tx("Redo", "إعادة"), UI.CARD2, func(): _do_redo(), 18, Vector2(86, 48))
	UI.btn(top, UI.tx("Clear", "مسح الكل"), Color(0.45, 0.18, 0.18), func(): _clear_view(), 18, Vector2(100, 48))
	UI.btn(top, UI.tx("Save", "حفظ"), UI.OK.darkened(0.25), func(): _save(), 22, Vector2(110, 48))
	# canvas area
	_area = Control.new()
	_area.clip_contents = true
	_area.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_area)
	_area.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_area.offset_left = 132
	_area.offset_right = -138
	_area.offset_top = 66
	_area.offset_bottom = -92
	_area.gui_input.connect(_on_input)
	_area.resized.connect(_layout)
	_stage = StageCtl.new()
	(_stage as StageCtl).st = self
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_area.add_child(_stage)
	_car_tr = TextureRect.new()
	_car_tr.stretch_mode = TextureRect.STRETCH_SCALE
	_car_tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_car_tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_car_tr)
	_car_tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_paint_tr = TextureRect.new()
	_paint_tr.stretch_mode = TextureRect.STRETCH_SCALE
	_paint_tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_paint_tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage.add_child(_paint_tr)
	_paint_tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nuniform sampler2D mask;\nvoid fragment(){ vec4 c = texture(TEXTURE, UV); c.a *= step(0.5, texture(mask, UV).a); COLOR = c; }"
	var mat := ShaderMaterial.new()
	mat.shader = sh
	_paint_tr.material = mat
	_hint = UI.lbl(_area, UI.tx("Getting the car ready...", "جاري تجهيز السيارة..."), 22, UI.TXT2, false)
	_hint.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	# tools (left)
	var tools := VBoxContainer.new()
	tools.add_theme_constant_override("separation", 5)
	add_child(tools)
	tools.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	tools.offset_left = 8
	tools.offset_right = 126
	tools.offset_top = 68
	tools.offset_bottom = -94
	for t in TOOLS:
		var b := UI.btn(tools, UI.tx(t[2], t[1]), UI.CARD2, func(): _set_tool(t[0]), 17, Vector2(0, 52))
		b.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_tool_btns[t[0]] = b
	# palette (right)
	var pp := VBoxContainer.new()
	pp.add_theme_constant_override("separation", 6)
	add_child(pp)
	pp.set_anchors_and_offsets_preset(Control.PRESET_RIGHT_WIDE)
	pp.offset_left = -130
	pp.offset_right = -8
	pp.offset_top = 68
	pp.offset_bottom = -94
	UI.lbl(pp, UI.tx("Your colours", "ألوانك"), 15, UI.TXT2, false)
	var sc := TScroll.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pp.add_child(sc)
	_pal = GridContainer.new()
	_pal.columns = 3
	_pal.add_theme_constant_override("h_separation", 6)
	_pal.add_theme_constant_override("v_separation", 6)
	sc.add_child(_pal)
	var cols: Array = [Color.WHITE, Color(0.05, 0.05, 0.06)]
	for id in _owned:
		cols.append(Catalog.PAINTS[id]["c"])
	for c in cols:
		_pal.add_child(_swatch(c))
	_rand_b = UI.btn(pp, UI.tx("Random colour", "لون عشوائي"), UI.CARD2, func():
		rand_colour = not rand_colour
		_refresh(), 16, Vector2(0, 46))
	# bottom bar
	var bot := HBoxContainer.new()
	bot.add_theme_constant_override("separation", 8)
	add_child(bot)
	bot.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	bot.offset_left = 8
	bot.offset_right = -8
	bot.offset_top = -86
	bot.offset_bottom = -6
	_sw = ColorRect.new()
	_sw.custom_minimum_size = Vector2(46, 46)
	_sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bot.add_child(_sw)
	var sbx := VBoxContainer.new()
	sbx.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bot.add_child(sbx)
	var r1 := HBoxContainer.new()
	sbx.add_child(r1)
	UI.lbl(r1, UI.tx("Size", "الحجم"), 15, UI.TXT2, false).custom_minimum_size = Vector2(60, 0)
	_size_s = _slider(r1, size_f, func(v: float): size_f = v)
	var r2 := HBoxContainer.new()
	sbx.add_child(r2)
	UI.lbl(r2, UI.tx("Flow", "الكثافة"), 15, UI.TXT2, false).custom_minimum_size = Vector2(60, 0)
	_flow_s = _slider(r2, flow_f, func(v: float): flow_f = v)
	_drip_b = UI.btn(bot, UI.tx("Drips", "سيلان"), UI.CARD2, func():
		drips_on = not drips_on
		_refresh(), 16, Vector2(80, 60))
	_mirror_b = UI.btn(bot, UI.tx("Mirror", "مرآة"), UI.CARD2, func():
		mirror_on = not mirror_on
		_refresh(), 16, Vector2(80, 60))
	UI.btn(bot, UI.tx("Race stripes", "خطوط سباق"), Color(0.2, 0.3, 0.5), func(): _tpl_stripes(), 15, Vector2(96, 60))
	UI.btn(bot, UI.tx("Fade", "تدرج"), Color(0.2, 0.3, 0.5), func(): _tpl_fade(), 15, Vector2(70, 60))
	UI.btn(bot, UI.tx("Camo", "تمويه"), Color(0.2, 0.3, 0.5), func(): _tpl_camo(), 15, Vector2(70, 60))
	UI.btn(bot, UI.tx("Random spray", "رش عشوائي"), Color(0.45, 0.22, 0.65), func(): _tpl_random(), 16, Vector2(100, 60))
	_refresh()


func _slider(parent: Node, v: float, cb: Callable) -> HSlider:
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.01
	s.value = v
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.custom_minimum_size = Vector2(120, 26)
	parent.add_child(s)
	s.value_changed.connect(func(x: float):
		cb.call(x)
		_brush_cache.clear())
	return s


func _swatch(c: Color) -> Control:
	var b := Button.new()
	b.custom_minimum_size = Vector2(36, 36)
	var n := UI.sb(c, 18, Color(1, 1, 1, 0.25), 2)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", UI.sb(c, 18, Color.WHITE, 3))
	b.add_theme_stylebox_override("pressed", UI.sb(c, 18, Color.WHITE, 3))
	b.add_theme_stylebox_override("focus", n)
	b.pressed.connect(func():
		colour = c
		rand_colour = false
		Sfx.play("click", -10.0)
		_brush_cache.clear()
		_refresh())
	return b


func _refresh() -> void:
	for k in _tool_btns:
		var on: bool = k == tool
		var b: Button = _tool_btns[k]
		for st in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(st, UI.sb(UI.ACCENT if on else UI.CARD2, 8))
	for k in _view_btns:
		var on2: bool = k == view or (k == "3d" and _view3d != null)
		var b2: Button = _view_btns[k]
		for st in ["normal", "hover", "pressed", "focus"]:
			b2.add_theme_stylebox_override(st, UI.sb(UI.ACCENT if on2 else UI.CARD2, 8))
	for pair in [[_drip_b, drips_on and view == "side"], [_mirror_b, mirror_on], [_rand_b, rand_colour]]:
		var bb: Button = pair[0]
		for st in ["normal", "hover", "pressed", "focus"]:
			bb.add_theme_stylebox_override(st, UI.sb(Color(0.2, 0.5, 0.35) if pair[1] else UI.CARD2, 8))
	_undo_b.disabled = _undo.is_empty()
	_redo_b.disabled = _redo.is_empty()
	_sw.color = colour
	_stage.queue_redraw()


func _set_tool(t: String) -> void:
	tool = t
	Sfx.play("click", -10.0)
	_refresh()


func _set_view(v: String) -> void:
	if v == "3d":
		_show_3d()
		return
	if _view3d:
		_view3d.queue_free()
		_view3d = null
		_area.get_child(0).visible = true
	view = v
	_drips.clear()
	_apply_textures()
	_layout()
	_refresh()


# ---------------------------------------------------------------- car renders (background + silhouette)
func _render_cars() -> void:
	for v in ["side", "top"]:
		var w := Livery.W
		var h := Livery.SIDE_H if v == "side" else Livery.TOP_H
		var vp := SubViewport.new()
		vp.size = Vector2i(w, h)
		vp.transparent_bg = true
		vp.own_world_3d = true
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(vp)
		var env := WorldEnvironment.new()
		var e := Environment.new()
		e.background_mode = Environment.BG_CLEAR_COLOR
		e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		e.ambient_light_color = Color(0.75, 0.78, 0.85)
		e.ambient_light_energy = 0.7
		env.environment = e
		vp.add_child(env)
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-55, -25, 0)
		sun.light_energy = 0.8
		vp.add_child(sun)
		var cam := Camera3D.new()
		cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		cam.keep_aspect = Camera3D.KEEP_HEIGHT
		vp.add_child(cam)
		if v == "side":
			cam.size = Livery.HEI
			cam.position = Vector3(10, Livery.Y0 + Livery.HEI * 0.5, 0)
			cam.look_at(Vector3(0, Livery.Y0 + Livery.HEI * 0.5, 0), Vector3.UP)
		else:
			cam.size = Livery.WID
			cam.position = Vector3(0, 10, 0)
			cam.look_at(Vector3.ZERO, Vector3(-1, 0, 0))
		var car := Car.new()
		car.setup(0, Catalog.PAINTS[lo.get("paint", "red")]["c"], false, lo, true)
		vp.add_child(car)
		for i in 4:
			await get_tree().process_frame
		var im := vp.get_texture().get_image()
		vp.queue_free()
		im.convert(Image.FORMAT_RGBA8)
		masks[v] = im
		shots[v] = ImageTexture.create_from_image(im)
	_ready_ok = true
	_hint.visible = false
	_apply_textures()
	_layout()
	_refresh()


func _apply_textures() -> void:
	if not _ready_ok:
		return
	_car_tr.texture = shots[view]
	if not _tex.has(view):
		_tex[view] = ImageTexture.create_from_image(layers[view])
	_paint_tr.texture = _tex[view]
	(_paint_tr.material as ShaderMaterial).set_shader_parameter("mask", shots[view])


func _upload() -> void:
	(_tex[view] as ImageTexture).update(layers[view])


func _layout() -> void:
	if _stage == null or _area == null:
		return
	var im: Image = layers[view]
	var sc := minf(_area.size.x / float(im.get_width()), _area.size.y / float(im.get_height()))
	_stage.size = Vector2(im.get_width(), im.get_height()) * sc
	_stage.position = (_area.size - _stage.size) * 0.5
	_stage.queue_redraw()


func _to_img(p: Vector2) -> Vector2:
	var im: Image = layers[view]
	return (p - _stage.position) / _stage.size * Vector2(im.get_width(), im.get_height())


func _scale() -> float:
	var im: Image = layers[view]
	return _stage.size.x / float(im.get_width())


# ---------------------------------------------------------------- input
func _on_input(ev: InputEvent) -> void:
	if not _ready_ok or _view3d:
		return
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		if ev.pressed:
			_begin(_to_img(ev.position))
		else:
			_end()
	elif ev is InputEventMouseMotion:
		_cursor = ev.position
		if _down:
			_move(_to_img(ev.position))
		_stage.queue_redraw()


func _begin(p: Vector2) -> void:
	if tool == "fill":
		_push_undo()
		_fill(_pick())
		_commit()
		return
	_push_undo()
	_down = true
	_last = p
	_line_a = p
	_line_b = p
	_dwell = 0.0
	if rand_colour:
		colour = Catalog.PAINTS[_owned[randi() % _owned.size()]]["c"]
		_brush_cache.clear()
		_refresh()
	if tool != "line":
		_dab(p)
		_upload()


func _move(p: Vector2) -> void:
	if tool == "line":
		_line_b = p
		_stage.queue_redraw()
		return
	var d := p.distance_to(_last)
	if d < 1.0:
		return
	var r := _radius()
	var step := maxf(1.0, r * (0.22 if tool == "air" else 0.3))
	var n := int(d / step)
	for i in range(1, n + 1):
		_dab(_last.lerp(p, float(i) / float(n)))
	_last = _last.lerp(p, float(n) / float(maxf(n, 1))) if n > 0 else _last
	_dwell = 0.0 if d > 3.0 else _dwell
	_upload()


func _end() -> void:
	if not _down:
		return
	_down = false
	if tool == "line":
		var d := _line_a.distance_to(_line_b)
		var step := maxf(1.0, _radius() * 0.2)
		var n := maxi(1, int(d / step))
		for i in range(n + 1):
			_dab(_line_a.lerp(_line_b, float(i) / float(n)))
		_upload()
	_commit()


func _process(d: float) -> void:
	if not _ready_ok or _view3d:
		return
	var dirty := false
	# paint dripping when the nozzle stays in one place (side view)
	if _down and tool in ["air", "fan"] and drips_on and view == "side":
		_dwell += d
		if _dwell > 0.55:
			_dwell = 0.0
			_drips.append({"p": _last, "len": 0.0, "max": randf_range(30.0, 90.0), "w": randf_range(1.6, 3.2), "c": colour})
	var alive: Array = []
	for dr in _drips:
		var step := 55.0 * d
		var n := maxi(1, int(step / 1.5))
		for i in n:
			dr["len"] += step / n
			var pt: Vector2 = dr["p"] + Vector2(randf_range(-0.4, 0.4), dr["len"])
			_blob(pt, dr["w"], dr["c"], 0.85)
		dirty = true
		if dr["len"] < dr["max"]:
			alive.append(dr)
	_drips = alive
	if dirty:
		_upload()


# ---------------------------------------------------------------- brushes
func _radius() -> float:
	var base := lerpf(4.0, 60.0, size_f)
	match tool:
		"fine":
			return maxf(2.0, base * 0.4)
		"fan":
			return base * 1.7
		"erase":
			return base * 0.9
	return base


func _brush(r: float, hard: float, alpha: float, c: Color) -> Image:
	var ri := maxi(1, int(round(r / 2.0)) * 2)
	var key := "%d_%.1f_%.2f_%s" % [ri, hard, alpha, c.to_html()]
	if _brush_cache.has(key):
		return _brush_cache[key]
	if _brush_cache.size() > 24:
		_brush_cache.clear()
	var s := ri * 2 + 1
	var im := Image.create(s, s, false, Image.FORMAT_RGBA8)
	for y in s:
		for x in s:
			var d := Vector2(x - ri, y - ri).length() / float(ri)
			if d <= 1.0:
				var a := pow(1.0 - d, hard) * alpha
				im.set_pixel(x, y, Color(c.r, c.g, c.b, a))
	_brush_cache[key] = im
	return im


func _stamp(p: Vector2, r: float, hard: float, alpha: float, c: Color) -> void:
	var im: Image = layers[view]
	var b := _brush(r, hard, alpha, c)
	var ri := int(b.get_width() / 2)
	im.blend_rect(b, Rect2i(0, 0, b.get_width(), b.get_height()), Vector2i(int(p.x) - ri, int(p.y) - ri))


func _blob(p: Vector2, r: float, c: Color, a: float) -> void:
	_stamp(p, r, 0.35, a, c)


func _dab(p: Vector2) -> void:
	var pts: Array = [p]
	if mirror_on and view == "top":
		var im: Image = layers[view]
		pts.append(Vector2(p.x, im.get_height() - p.y))
	for q in pts:
		_dab_one(q)


func _dab_one(p: Vector2) -> void:
	var r := _radius()
	match tool:
		"air":
			_stamp(p, r, 1.6, 0.10 + flow_f * 0.2, colour)
			_speckle(p, r * 1.25, 4, colour, flow_f)
		"fine":
			_stamp(p, r, 0.5, 0.35 + flow_f * 0.5, colour)
		"fan":
			_stamp(p, r, 2.2, 0.04 + flow_f * 0.1, colour)
			_speckle(p, r * 1.1, 8, colour, flow_f)
		"splat":
			if p.distance_to(_last) >= r * 0.9 or _last == p:
				for i in 14:
					var o := Vector2.from_angle(randf() * TAU) * r * 1.8 * sqrt(randf())
					_stamp(p + o, randf_range(1.5, maxf(3.0, r * 0.28)), 0.3, 0.9, colour)
		"erase":
			var im: Image = layers[view]
			var ri := maxi(2, int(r))
			var key := "e%d" % ri
			if not _brush_cache.has(key):
				var mk := Image.create(ri * 2 + 1, ri * 2 + 1, false, Image.FORMAT_RGBA8)
				for y in mk.get_height():
					for x in mk.get_width():
						if Vector2(x - ri, y - ri).length() <= ri:
							mk.set_pixel(x, y, Color.WHITE)
				_brush_cache[key] = mk
			var m: Image = _brush_cache[key]
			var blank := Image.create(m.get_width(), m.get_height(), false, Image.FORMAT_RGBA8)
			im.blit_rect_mask(blank, m, Rect2i(0, 0, m.get_width(), m.get_height()), Vector2i(int(p.x) - ri, int(p.y) - ri))
		"line":
			_stamp(p, r, 0.9, 0.5 + flow_f * 0.5, colour)


func _speckle(p: Vector2, r: float, n: int, c: Color, f: float) -> void:
	for i in n:
		var o := Vector2.from_angle(randf() * TAU) * r * sqrt(randf())
		_stamp(p + o, randf_range(1.0, 2.2), 0.2, 0.5 + f * 0.4, c)


# ---------------------------------------------------------------- fill and templates
func _pick() -> Color:
	if rand_colour:
		return Catalog.PAINTS[_owned[randi() % _owned.size()]]["c"]
	return colour


func _masked(img: Image) -> Image:
	var out := Image.create(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
	var m: Image = masks[view]
	out.blit_rect_mask(img, m, Rect2i(0, 0, img.get_width(), img.get_height()), Vector2i.ZERO)
	return out


func _blend_full(img: Image) -> void:
	var im: Image = layers[view]
	im.blend_rect(img, Rect2i(0, 0, img.get_width(), img.get_height()), Vector2i.ZERO)


func _fill(c: Color) -> void:
	var im: Image = layers[view]
	var t := Image.create(im.get_width(), im.get_height(), false, Image.FORMAT_RGBA8)
	t.fill(Color(c.r, c.g, c.b, 0.35 + flow_f * 0.65))
	_blend_full(_masked(t))


func _tpl_stripes() -> void:
	if not _ready_ok:
		return
	_push_undo()
	var im: Image = layers[view]
	var w := im.get_width()
	var h := im.get_height()
	var t := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var c := _pick()
	var c2 := Color.WHITE if c.get_luminance() < 0.6 else Color(0.05, 0.05, 0.06)
	if view == "top":
		var mid := h / 2
		t.fill_rect(Rect2i(0, mid - 70, w, 56), c)
		t.fill_rect(Rect2i(0, mid + 14, w, 56), c)
		t.fill_rect(Rect2i(0, mid - 8, w, 16), c2)
	else:
		t.fill_rect(Rect2i(0, 170, w, 46), c)
		t.fill_rect(Rect2i(0, 222, w, 12), c2)
	_blend_full(_masked(t))
	_commit()


func _tpl_fade() -> void:
	if not _ready_ok:
		return
	_push_undo()
	var im: Image = layers[view]
	var w := im.get_width()
	var h := im.get_height()
	var t := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var c := _pick()
	if view == "side":
		for y in h:
			t.fill_rect(Rect2i(0, y, w, 1), Color(c.r, c.g, c.b, clampf(float(y) / float(h) * 1.4 - 0.2, 0.0, 0.95)))
	else:
		for x in w:
			t.fill_rect(Rect2i(x, 0, 1, h), Color(c.r, c.g, c.b, clampf(1.0 - float(x) / float(w) * 1.3, 0.0, 0.95)))
	_blend_full(_masked(t))
	_commit()


func _tpl_camo() -> void:
	if not _ready_ok:
		return
	_push_undo()
	var im: Image = layers[view]
	var cols: Array = []
	for i in 4:
		cols.append(_pick() if i == 0 else Catalog.PAINTS[_owned[randi() % _owned.size()]]["c"])
	for i in 70:
		var p := Vector2(randf() * im.get_width(), randf() * im.get_height())
		_stamp(p, randf_range(14.0, 44.0), 0.25, 0.95, cols[randi() % cols.size()])
	_commit()


func _tpl_random() -> void:
	if not _ready_ok:
		return
	_push_undo()
	var im: Image = layers[view]
	var w := float(im.get_width())
	var h := float(im.get_height())
	for k in 9:
		var c: Color = Catalog.PAINTS[_owned[randi() % _owned.size()]]["c"]
		var a := Vector2(randf() * w, randf() * h)
		var b := Vector2(randf() * w, randf() * h)
		var ctrl := Vector2(randf() * w, randf() * h)
		var r := randf_range(10.0, 46.0)
		for i in 40:
			var t := float(i) / 39.0
			var q := a.lerp(ctrl, t).lerp(ctrl.lerp(b, t), t)
			_stamp(q, r, 1.4, 0.35, c)
			_speckle(q, r * 1.3, 3, c, 0.8)
	Sfx.play("whoosh", -8.0)
	_commit()


# ---------------------------------------------------------------- history
func _push_undo() -> void:
	_undo.append({"v": view, "i": (layers[view] as Image).duplicate()})
	if _undo.size() > MAXUNDO:
		_undo.pop_front()
	_redo.clear()


func _commit() -> void:
	changed = true
	_upload()
	_refresh()


func _do_undo() -> void:
	if _undo.is_empty():
		return
	var s: Dictionary = _undo.pop_back()
	_redo.append({"v": s["v"], "i": (layers[s["v"]] as Image).duplicate()})
	layers[s["v"]] = s["i"]
	_tex[s["v"]] = ImageTexture.create_from_image(s["i"])
	changed = true
	_apply_textures()
	_refresh()


func _do_redo() -> void:
	if _redo.is_empty():
		return
	var s: Dictionary = _redo.pop_back()
	_undo.append({"v": s["v"], "i": (layers[s["v"]] as Image).duplicate()})
	layers[s["v"]] = s["i"]
	_tex[s["v"]] = ImageTexture.create_from_image(s["i"])
	changed = true
	_apply_textures()
	_refresh()


func _clear_view() -> void:
	_push_undo()
	(layers[view] as Image).fill(Color(0, 0, 0, 0))
	_commit()


# ---------------------------------------------------------------- save / 3D
func _save() -> void:
	_write()
	Sfx.play("success", -2.0)
	_close()


func _write() -> void:
	for v in ["side", "top"]:
		var im: Image = layers[v]
		if im.is_invisible():
			if FileAccess.file_exists(Livery.path(car_id, v)):
				DirAccess.remove_absolute(Livery.path(car_id, v))
		else:
			Livery.save_img(car_id, v, im)


func _show_3d() -> void:
	if _view3d:
		return
	_write()
	changed = true
	_area.get_child(0).visible = false
	var p3 := Preview3D.new()
	p3.zoom = 0.9
	var l3 := lo.duplicate()
	l3["lv"] = Livery.exists(car_id)
	p3.ready.connect(func(): p3.show_car(l3))
	_area.add_child(p3)
	p3.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_view3d = p3
	_refresh()


func _close() -> void:
	closed.emit(changed)


class StageCtl extends Control:
	var st: PaintStudio

	func _draw() -> void:
		if st == null:
			return
		draw_rect(Rect2(Vector2.ZERO, size), Color(0.09, 0.1, 0.13))
		var step := 40.0
		var x := 0.0
		while x < size.x:
			draw_line(Vector2(x, 0), Vector2(x, size.y), Color(1, 1, 1, 0.035))
			x += step
		var y := 0.0
		while y < size.y:
			draw_line(Vector2(0, y), Vector2(size.x, y), Color(1, 1, 1, 0.035))
			y += step
		if st._ready_ok and not st._view3d:
			var sc := st._scale()
			var cur := st._cursor - position
			if st.tool == "line" and st._down:
				var a := st._line_a * sc
				var b := st._line_b * sc
				draw_line(a, b, Color(st.colour.r, st.colour.g, st.colour.b, 0.7), maxf(2.0, st._radius() * 2.0 * sc))
			if cur.x > 0 and cur.y > 0 and cur.x < size.x and cur.y < size.y:
				draw_arc(cur, maxf(3.0, st._radius() * sc), 0.0, TAU, 40, Color(1, 1, 1, 0.8), 1.5)
