extends Node
## TEST HARNESS (not shipped): drives the game from env vars, takes screenshots.
## AUTO="solo" | "menu" ; SHOT_DIR ; AUTO_T = seconds list
var t := 0.0
var step := 0
var shots: Array = []
var mode := ""

func _ready() -> void:
	mode = OS.get_environment("AUTO")
	if mode == "":
		set_process(false)
		return
	L.tutorial_off = true
	if OS.get_environment("GFXP") != "":
		Gfx.set_preset(OS.get_environment("GFXP"))

func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(OS.get_environment("SHOT_DIR") + "/" + name + ".png")
	print("SHOT ", name)

func _process(d: float) -> void:
	t += d
	var sc := get_tree().current_scene
	match mode:
		"menu":
			if step == 0 and t > 3.0:
				step = 1; shot("menu0")
			elif step == 1 and t > 3.4:
				step = 2
				Profile.select_car("coupe") if Catalog.CARS.has("coupe") else null
			elif step == 2 and t > 4.2:
				step = 3; shot("menu1")
			elif step == 3 and t > 4.3:
				get_tree().quit()
		"garage":
			if step == 0 and t > 2.5:
				step = 1; Profile.level = 20; Profile.coins = 99999; Profile.cars["muscle"] = true; Profile.cars["gt3"] = true; Profile.car = "coupe"; Profile.cars["coupe"] = true
				sc.hub.select("garage")
			elif step == 1 and t > 4.5:
				step = 2; shot("garage0")
			elif step == 2 and t > 5.0:
				step = 3
				sc.hub.g_car = "hyper"
				sc.hub.select("garage")
			elif step == 3 and t > 7.0:
				step = 4; shot("garage1")
			elif step == 4 and t > 7.5:
				get_tree().quit()
		"modify":
			# SECS="paint,mods,wheels,engine" shots of each section of the modify page
			if step == 0 and t > 2.5:
				step = 1; Profile.level = 20; Profile.coins = 99999; Profile.car = "coupe"; Profile.cars["coupe"] = true
				Profile.buy_part("turbo", 2); Profile.buy_part("aero", 3)
				sc.hub.select("modify")
			elif step >= 1 and step <= 8 and t > 3.5 + step * 1.0:
				var secs: Array = ["paint", "mods", "wheels", "engine"]
				var sec: String = secs[(step - 1) % 4]
				if step <= 4:
					sc.hub.mod_section = sec
					sc.hub._mod_fill()
				else:
					sc.hub.mod_section = "paint"
					sc.hub.mod_sub["paint"] = "decal"
					Profile.owned["decal:rs"] = true
					Profile.equip_car_part("decal", "rs")
					sc.hub._mod_fill()
					sc.hub._rerender()
					if step > 5:
						get_tree().quit()
				step += 1
				await get_tree().create_timer(0.6).timeout
				shot("mod_%s" % (sec if step <= 5 else "decal"))
		"chests":
			if step == 0 and t > 2.5:
				step = 1; Profile.chests = {"bronze": 2, "silver": 2, "gold": 2}; sc.hub.select("chests")
			elif step == 1 and t > 3.8:
				step = 2; shot("chest0")
				sc.hub._open_chest("gold", null)
			elif step == 2 and t > 4.6:
				step = 3; shot("chest1")
			elif step == 3 and t > 5.6:
				step = 4; shot("chest2")
			elif step == 4 and t > 6.5:
				step = 5; shot("chest3")
			elif step == 5 and t > 6.6:
				get_tree().quit()
		"sqhost", "sqjoin":
			var who := OS.get_environment("WHO")
			if step == 0 and t > 2.0:
				step = 1
				Profile.pname = who
				if mode == "sqhost":
					print("HOST ", Net.host_game(who, 0, false, 4, 2))
					sc._show_lobby()
				else:
					print("JOIN ", Net.join_game("127.0.0.1", who))
			elif step == 1 and t > 6.0:
				step = 2
				print(who, " lobby players=", Net.players.size(), " squads=", Net.squads, " req=", Net.required_players)
				shot("lobby_" + who)
				Net.toggle_ready(true)
			elif step == 2 and t > 18.0:
				step = 3
				print(who, " in_game=", Net.in_game, " squads=", Net.squads, " ffa=", Net.ffa)
				shot("race_" + who)
			elif step == 3 and t > 40.0:
				step = 4
				shot("race2_" + who)
			elif step == 4 and t > 41.0:
				get_tree().quit()
		"settings":
			if step == 0 and t > 2.5:
				step = 1; sc.hub.select("settings")
			elif step == 1 and t > 3.5:
				step = 2; shot("settings0")
			elif step == 2 and t > 3.6:
				get_tree().quit()
		"cycle":
			if t > 2.5 + step * 0.25 and step < 14:
				var ids: Array = Catalog.CARS.keys()
				var id: String = ids[step % ids.size()]
				Profile.cars[id] = true
				Profile.select_car(id)
				if step % 2 == 1:
					shot("cyc%d" % step)
				step += 1
			elif step >= 14 and t > 8.0:
				get_tree().quit()
		"cars":
			# turntable shots of every car model: front 3/4, rear 3/4, side. CARS="hatch,coupe" to pick, PAINT=blue
			if step == 0 and t > 1.5:
				step = 1
				sc.visible = false
				_cars_setup()
			elif step >= 1 and step <= 100 and t > 2.0 + step * 0.45:
				_cars_step()
		"gear":
			# driver hand -> gear lever test. CARS="hatch,m4" picks cars; shots: wheel, mid-shift, new gear
			if step == 0 and t > 1.5:
				step = 1
				sc.visible = false
				_cars_setup()
			elif step >= 1 and t > 1.5 + step * 0.5:
				_gear_step()
		"pod4":
			if step == 0 and t > 2.0:
				step = 1
				var cc := Ceremony.new()
				var cols := [Color(0.82,0.1,0.1), Color(0.15,0.4,0.95), Color(0.15,0.7,0.3), Color(0.95,0.72,0.1), Color(0.65,0.25,0.85)]
				var cars := ["hatch","muscle","coupe","hyper","buggy"]
				var ents := []
				for i in 5:
					ents.append({"rank": i+1, "name": "Player %d" % (i+1), "plate": "Racer%d" % (i+1), "players": [{"name": "p", "outfit": {}, "role": "driver"}], "lo": {"car": cars[i], "paint": ["red","blue","green","yellow","purple"][i]}, "time": 80.0 + i * 7, "fin": i < 3, "dnf": false, "pct": 70 - i * 5, "color": cols[i], "place": L.t("place%d" % (i+1)), "mine": i == 1})
				cc.entries = ents
				cc.squad_rows = [{"name": "Team A", "pts": 30, "color": cols[0], "best": 0, "members": []}, {"name": "Team B", "pts": 22, "color": cols[1], "best": 1, "members": []}]
				cc.info_line = "+500 coins  +120 XP"
				cc.again_text = "Rematch"; cc.exit_text = "Back"
				cc.on_again = func(): pass
				cc.on_exit = func(): pass
				sc.visible = false
				cc.position = Vector3(0, 1800, 0)
				get_tree().root.add_child(cc)
				sc.get_node("Ceremony") if false else null
			elif step == 1 and t > 2.0 + float(OS.get_environment("SHOT_AT")):
				step = 2; shot("pod_%s" % OS.get_environment("SHOT_AT"))
				get_tree().quit()
		"podium":
			# fake a finished 4-car race and jump straight into the ceremony (visual test)
			if step == 0 and t > 2.0:
				step = 1
				sc._on_solo()
			elif step == 1 and t > 6.0:
				step = 2
				var w = get_tree().current_scene
				if w.has_method("_end_race"):
					w.results.append(0)
					w.teams[0].finished = true
					w.teams[0].finish_time = 88.0
					w._end_race()
			elif step == 2 and t > float(OS.get_environment("SHOT_AT")) :
				step = 3; shot("pod_%s" % OS.get_environment("SHOT_AT"))
				get_tree().quit()
		"solo":
			if step == 0 and t > 2.0:
				step = 1
				sc._on_solo()
			elif step == 1 and t > 3.0:
				step = 2
				pass
			elif step == 2 and t > 20.0:
				step = 3; shot("solo0")
			elif step == 3 and t > 24.0:
				Input.action_press("accel")
				step = 4
			elif step == 4 and t > 30.0:
				step = 5; shot("solo1")
				var w := get_tree().current_scene
				if w.has_method("_toggle_map"):
					w._toggle_map()
			elif step == 5 and t > 31.5:
				step = 6; shot("solo2")
			elif step == 6 and t > 33.0:
				get_tree().quit()


var _cs := {}
var _cs_list: Array = []
var _cs_car: Node3D
var _cs_cam: Camera3D


func _cars_setup() -> void:
	var root := get_tree().root
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.32, 0.34, 0.4)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.75, 0.78, 0.85)
	e.ambient_light_energy = 0.8
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, -30, 0)
	sun.light_energy = 1.1
	root.add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25, 150, 0)
	fill.light_energy = 0.5
	root.add_child(fill)
	var fl := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 60)
	fl.mesh = pm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.22, 0.23, 0.26)
	fl.material_override = m
	root.add_child(fl)
	_cs_cam = Camera3D.new()
	_cs_cam.fov = 38.0
	root.add_child(_cs_cam)
	var want := OS.get_environment("CARS")
	_cs_list = Catalog.CAR_ORDER.duplicate() if want == "" else Array(want.split(","))


func _cars_step() -> void:
	# each car uses 4 steps: build, shot front, shot rear, shot side
	var i := (step - 1) / 5
	var k := (step - 1) % 5
	if i >= _cs_list.size():
		get_tree().quit()
		return
	var id: String = _cs_list[i]
	if k == 0:
		if _cs_car:
			_cs_car.queue_free()
		var lo := {"car": id, "paint": OS.get_environment("PAINT") if OS.get_environment("PAINT") != "" else Catalog.CARS[id].get("paint", "red"),
			"stripe": OS.get_environment("STRIPE") if OS.get_environment("STRIPE") != "" else "none", "rim": "steel", "glow": "none"}
		var car := Car.new()
		car.setup(0, Color(0.2, 0.8, 0.3), false, lo, true)
		get_tree().root.add_child(car)
		car.set_plate_text("Racer")
		_cs_car = car
	else:
		var views := [Vector3(-5.2, 1.7, -6.2), Vector3(5.4, 2.0, 6.8), Vector3(8.2, 1.3, 0.0), Vector3(-0.45, 1.62, 0.25)]
		_cs_cam.position = views[k - 1]
		if k == 4:
			_cs_car.speed_kmh = _cs_car.top_speed * 0.55
			_cs_cam.fov = 70.0
			_cs_cam.look_at(Vector3(-0.45, 1.2, -0.93))
		else:
			_cs_cam.fov = 38.0
			_cs_cam.look_at(Vector3(0, 0.95, 0))
		_cs_cam.current = true
		shot("car_%s_%d" % [id, k])
	step += 1


var _gv_av: Avatar


func _gear_step() -> void:
	var i := (step - 1) / 6
	var k := (step - 1) % 6
	if i >= _cs_list.size():
		get_tree().quit()
		return
	var id: String = _cs_list[i]
	if k == 0:
		if _cs_car:
			_cs_car.queue_free()
		var lo := {"car": id, "paint": Catalog.CARS[id].get("paint", "red"), "stripe": "none", "rim": "steel", "glow": "none"}
		var car := Car.new()
		car.setup(0, Color(0.2, 0.8, 0.3), false, lo, true)
		get_tree().root.add_child(car)
		var av := Avatar.new()
		av.role = "driver"
		av.helmet_color = Color(0.2, 0.8, 0.3)
		av.shirt_color = Color(0.1, 0.5, 0.2)
		av.position = car.seat_origin("driver")
		car.add_child(av)
		car.driver_avatar = av
		_cs_car = car
		_gv_av = av
	else:
		var car: Car = _cs_car
		var a: String = "N"
		var b: String = "D"
		match car._gear_style:
			"h5", "h6": b = "1"
			"seq": b = "1"
			"buttons": b = "D"
		_cs_cam.fov = 75.0; _cs_cam.near = 0.05
		_cs_cam.position = car.to_global(Vector3(0.42, 1.5, 0.55))
		_cs_cam.look_at(car.to_global(Vector3(-0.2, 1.0, 0.0)))
		_cs_cam.current = true
		if k == 1:
			shot("gear_%s_0wheel" % id)
		elif k == 2:
			car._begin_shift(car.gear_sel, b)
			car.gear_sel = b
		elif k == 3:
			shot("gear_%s_1reach" % id)
		elif k == 5:
			shot("gear_%s_2done" % id)
	step += 1
