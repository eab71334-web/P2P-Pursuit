class_name TScroll
extends ScrollContainer
## ScrollContainer that scrolls by dragging a finger anywhere (also over buttons), with inertia and no
## visible scrollbars. A drag never "presses" the button it started on; a short tap still does.

const DEADZONE := 14.0

var _down := false
var _drag := false
var _start := Vector2.ZERO
var _vel := Vector2.ZERO
var _last_t := 0.0


func _ready() -> void:
	get_v_scroll_bar().modulate.a = 0.0
	get_h_scroll_bar().modulate.a = 0.0
	get_v_scroll_bar().mouse_filter = Control.MOUSE_FILTER_IGNORE
	get_h_scroll_bar().mouse_filter = Control.MOUSE_FILTER_IGNORE
	if vertical_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO:
		vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	if horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_AUTO:
		horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER


func _inside(p: Vector2) -> bool:
	return is_visible_in_tree() and get_global_rect().has_point(p)


func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if _inside(event.global_position):
				_down = true
				_drag = false
				_start = event.global_position
				_vel = Vector2.ZERO
		elif _down:
			_down = false
			if _drag:
				get_viewport().set_input_as_handled()
			_drag = false
	elif event is InputEventMouseMotion and _down:
		var p: Vector2 = event.global_position
		if not _drag:
			if p.distance_to(_start) < DEADZONE:
				return
			_drag = true
			propagate_notification(NOTIFICATION_SCROLL_BEGIN)   # buttons under the finger drop their press
		var rel: Vector2 = event.relative
		_scroll_by(-rel)
		_vel = _vel.lerp(-rel / maxf(get_process_delta_time(), 0.001), 0.35)
		get_viewport().set_input_as_handled()


func _scroll_by(d: Vector2) -> void:
	if vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
		scroll_vertical = int(scroll_vertical + d.y)
	if horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
		scroll_horizontal = int(scroll_horizontal + d.x)


func _process(delta: float) -> void:
	if _down or _vel.length() < 8.0:
		return
	_scroll_by(_vel * delta)
	_vel *= pow(0.04, delta)
