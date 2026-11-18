extends Node3D
## TEST BENCH (not shipped): cornering: lateral g, sideslip, body roll at several speeds and steering amounts
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
var sc := 0
var SCEN := [[60.0,1.0],[100.0,1.0],[100.0,0.5],[160.0,0.5],[160.0,1.0],[120.0,-9.0],[160.0,-9.0]]
var lat_sum := 0.0
var n_s := 0
var max_slip := 0.0
var max_roll := 0.0
var lines := ""

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
	var target: float = SCEN[sc][0]
	var st: float = SCEN[sc][1]
	var thr := clampf((target - sp) * 0.08, 0.0, 1.0)
	var brk := clampf((sp - target) * 0.05, 0.0, 1.0)
	if t < 1.0:
		car.set_controls(0.0, 0.0, 0.0)
		return
	if sp < target - 3.0 and phase == 0:
		car.set_controls(0.0, 1.0, 0.0)
		return
	if phase == 0:
		phase = 1
		t = 0.0
		lat_sum = 0.0
		n_s = 0
		max_slip = 0.0
		max_roll = 0.0
	if st < -5.0:
		st = 1.0 if int(t / 1.2) % 2 == 0 else -1.0     # chicane: quick left-right changes
	if OS.get_environment("KICK") != "" and sc == 1 and t > 4.0 and t < 4.03:
		car.angular_velocity += -car.global_basis.z * float(OS.get_environment("KICK"))
	car.set_controls(st, thr, brk)
	var v := car.linear_velocity
	var ctr := car.global_transform.basis
	var vf := v - Vector3.UP * v.y
	var slip := 0.0
	if vf.length() > 3.0:
		slip = rad_to_deg(acos(clampf((-ctr.z).dot(vf.normalized()), -1.0, 1.0)))
	var roll := rad_to_deg(asin(clampf(ctr.x.y, -1.0, 1.0)))
	if st != 0.0 and SCEN[sc][1] < -5.0 and OS.get_environment("ROLLLOG") != "" and int(t * 20.0) != int((t - delta) * 20.0) and t > 3.0 and t < 7.0:
		print("  t=%.2f steer %+.0f roll %+.1f" % [t, st, roll])
	if sc == 0 and OS.get_environment("ROLLLOG") != "" and int(t * 4.0) != int((t - delta) * 4.0) and t > 3.0:
		print("  yaw %+.2f signed x.y %+.3f ay %+.2f" % [car.angular_velocity.y, ctr.x.y, car.angular_velocity.y * (-ctr.z).dot(v) / 9.81])
	if t > 3.0:
		lat_sum += absf(car.angular_velocity.y) * vf.length() / 9.81
		n_s += 1
		max_slip = maxf(max_slip, slip)
		max_roll = maxf(max_roll, absf(roll))
	if t > 8.0:
		lines += "   %3d km/h steer %.1f%s: %.2f g sustained | slip max %3.0f deg | roll max %4.1f deg | now %3.0f km/h\n" % [int(target), SCEN[sc][1], " (chicane)" if SCEN[sc][1] < -5.0 else "", lat_sum / maxf(n_s, 1), max_slip, max_roll, sp]
		sc += 1
		phase = 0
		t = 0.0
		if sc >= SCEN.size():
			print("%-8s (grip mu %.2f, downforce cla %.2f)\n%s" % [models[mi], float(car.spec["mu"]), float(car.spec["cla"]), lines])
			lines = ""
			sc = 0
			mi += 1
			if mi >= models.size():
				get_tree().quit()
				return
			_spawn()
