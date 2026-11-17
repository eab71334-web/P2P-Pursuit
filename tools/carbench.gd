extends Node3D
## TEST BENCH (not shipped): measures 0-100 km/h, top speed, braking distance for every car in Realistic mode.
## run: tools/carbench.sh   env CAR=gt3 to test one car

var car: Car
var phase := 0
var t := 0.0
var log_t := 0.0
var res := {}
var models: Array = []
var mi := 0
var t100 := -1.0
var brake_start := Vector3.ZERO
var top_logged := false
var gear_log := ""

func _ready() -> void:
	Gfx.handling = "sim"
	var only := OS.get_environment("CAR")
	models = [only] if only != "" else Catalog.CAR_ORDER.duplicate()
	var g := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(60000, 2, 60000)
	cs.shape = bs
	g.add_child(cs)
	g.position = Vector3(0, -1.0, 0)
	add_child(g)
	_spawn()

func _spawn() -> void:
	if car != null:
		car.queue_free()
	car = Car.new()
	car.setup(0, Color.RED, false, {"car": models[mi]})
	car.position = Vector3(0, 0.8, 0)
	add_child(car)
	if OS.get_environment("MU") != "":
		for w in car.wheel_list:
			w.wheel_friction_slip = float(OS.get_environment("MU"))
	phase = 0
	t = 0.0
	t100 = -1.0
	top_logged = false
	gear_log = ""

func _physics_process(delta: float) -> void:
	if car == null or not is_instance_valid(car) or not car.is_inside_tree():
		return
	t += delta
	var sp := car.speed_kmh
	match phase:
		0:
			if t < 1.0:
				car.set_controls(0.0, 0.0, 0.0)
				return
			car.set_controls(0.0, 1.0, 0.0)
			if OS.get_environment("DBG") != "" and t < 20.0 and int(t) != int(t - delta) and t > 3.0:
				var sk := ""
				for w in car.wheel_list:
					sk += " %.2f/%.0f" % [w.get_skidinfo(), w.wheel_friction_slip]
				print("t=%.1f v=%.1f km/h gear %d rpm %d ef=%.0f skid%s" % [t - 1.0, sp, car.gear, int(car.eng_rpm), car.engine_force, sk])
			if t100 < 0.0 and sp >= 100.0:
				t100 = t - 1.0
			if int(t * 2.0) != int((t - delta) * 2.0) and int(t) % 4 == 0 and t < 30.0:
				gear_log += "  t=%.0f %d km/h g%d %d rpm\n" % [t, int(sp), car.gear, int(car.eng_rpm)]
			var top := float(car.spec["top"])
			if t > 70.0 or (t > 20.0 and sp > top * 0.995):
				res[models[mi]] = {"t100": t100, "top": sp, "t_end": t}
				phase = 1
				t = 0.0
		1:
			# braking from 100 km/h: coast up to speed first
			if sp > 100.0:
				car.set_controls(0.0, 0.0, 0.0)
			else:
				if brake_start == Vector3.ZERO:
					brake_start = car.global_position
				car.set_controls(0.0, 0.0, 1.0)
		2:
			pass
	if phase == 1 and brake_start != Vector3.ZERO and sp < 1.0:
		var dist := brake_start.distance_to(car.global_position)
		res[models[mi]]["brake100"] = dist
		print("%-8s 0-100: %5.2fs (real %.1f) | top %5.1f km/h (real %.0f) | 100-0: %5.1f m (real-ish %.0f) | mass %d\n%s" % [models[mi], t100, float(car.spec["zero100"]), res[models[mi]]["top"], float(car.spec["top"]), dist, 100.0 / 3.6 * 100.0 / 3.6 / (2.0 * 9.81 * float(car.spec["brake"])), int(car.mass), gear_log])
		brake_start = Vector3.ZERO
		mi += 1
		if mi >= models.size():
			get_tree().quit()
			return
		_spawn()
	elif phase == 1 and t > 90.0:
		print(models[mi], " brake test timeout, speed ", sp)
		mi += 1
		if mi >= models.size():
			get_tree().quit()
			return
		_spawn()
