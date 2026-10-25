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
				step = 4
				sc._show_lan(true)
			elif step == 4 and t > 5.2:
				step = 5; shot("menu_lan")
			elif step == 5 and t > 5.4:
				step = 6
				sc._show_lan(false)
				sc._show_online(true)
			elif step == 6 and t > 6.3:
				step = 7; shot("menu_online")
			elif step == 7 and t > 6.5:
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
		"steer":
			# FORCE_TOUCH=1 : picker -> pick wheel360 -> drive view with the wheel turned
			if step == 0 and t > 2.0:
				step = 1; Profile.steer_mode = ""; sc._on_solo()
			elif step == 1 and t > 6.0:
				step = 2; shot("steer_picker")
			elif step == 2 and t > 6.5:
				step = 3
				var w := get_tree().current_scene
				(w._picker as SteerUI.Picker).picked.emit(OS.get_environment("MODE") if OS.get_environment("MODE") != "" else "wheel360")
			elif step == 3 and t > 9.0:
				step = 4
				Input.action_press("accel")
			elif step == 4 and t > 14.0:
				step = 5
				get_tree().current_scene.wheel_touch = 99; get_tree().current_scene.wheel_angle = 3.6
			elif step == 5 and t > 24.0:
				step = 6; shot("steer_a")
			elif step == 6 and t > 24.3:
				step = 7
				get_tree().current_scene.wheel_angle = -1.4
			elif step == 7 and t > 26.0:
				step = 8; shot("steer_b")
			elif step == 8 and t > 26.5:
				get_tree().quit()
		"body":
			# BODY="gt3" CAR kit shots: stock + each body option on the 3D car, plus the Modify body section
			if step == 0 and t > 2.5:
				step = 1; Profile.level = 20; Profile.coins = 99999
				var cid: String = OS.get_environment("CAR") if OS.get_environment("CAR") != "" else "coupe"
				Profile.car = cid; Profile.cars[cid] = true
				for sl in Catalog.BODY_SLOTS:
					for bid in Catalog.body_opts(cid, sl):
						Profile.owned[sl + ":" + bid] = true
				sc.hub.select("modify"); sc.hub.mod_section = "body"; sc.hub._mod_fill()
			elif step == 1 and t > 4.5:
				step = 2; shot("body_ui")
			elif step == 2 and t > 5.0:
				step = 3
				var cid2: String = Profile.car
				var set := {"spoiler": "gt", "front": "canards", "hood": "vents", "skirts": "wide"}
				for k2 in set:
					if Catalog.body_opts(cid2, k2).has(set[k2]):
						Profile.equip_car_part(k2, set[k2])
					else:
						Profile.equip_car_part(k2, Catalog.body_opts(cid2, k2)[-1])
				Profile.owned["stripe:white"] = true; Profile.equip_car_part("stripe", "white")
				var wo: Array = Catalog.wheel_opts(cid2)
				Profile.owned["wheel:" + str(wo[-1])] = true; Profile.equip_car_part("wheel", str(wo[-1]))
				sc.hub._rerender()
			elif step == 3 and t > 7.5:
				step = 4; shot("body_full")
			elif step == 4 and t > 8.0:
				get_tree().quit()
		"modify":
			# SECS="paint,mods,wheels,engine" shots of each section of the modify page
			if step == 0 and t > 2.5:
				step = 1; Profile.level = 20; Profile.coins = 99999; Profile.car = (OS.get_environment("CAR") if OS.get_environment("CAR") != "" else "coupe"); Profile.cars[Profile.car] = true
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
					sc.hub.mod_sub["paint"] = OS.get_environment("SUB") if OS.get_environment("SUB") != "" else "decal"
					Profile.owned["decal:rs"] = true
					Profile.equip_car_part("decal", "rs")
					sc.hub._mod_fill()
					sc.hub._rerender()
					if step > 5:
						get_tree().quit()
				step += 1
				await get_tree().create_timer(0.6).timeout
				shot("mod_%s" % (sec if step <= 5 else "decal"))
		"promo":
			_promo(sc)
		"film":
			_film(sc)
		"film2":
			_film2(sc)
		"icon":
			_icon(sc)
		"result":
			if step == 0 and t > 2.0:
				step = 1; sc._on_solo()
			elif step == 1:
				var w2 := get_tree().current_scene
				if w2 != null and w2.get("state") != null and int(w2.get("state")) == 2:
					step = 2; _rt = t
			elif step == 2 and t > _rt + 1.5:
				step = 3
				get_tree().current_scene._show_result(1, 108.4)
			elif step == 3 and t > _rt + 3.5:
				step = 4; shot("result"); get_tree().quit()
		"shop":
			if step == 0 and t > 2.5:
				step = 1; sc.hub.select("shop")
			elif step == 1 and t > 3.5:
				step = 2; shot("shop")
				Checkout.open(sc.hub, Billing.pack("c3500"))
			elif step == 2 and t > 4.3:
				step = 3; shot("checkout"); get_tree().quit()
		"about":
			if step == 0 and t > 2.5:
				step = 1; sc.hub.select("settings")
			elif step == 1 and t > 3.5:
				step = 2
				for n in sc.hub.find_children("*", "ScrollContainer", true, false):
					(n as ScrollContainer).scroll_vertical = 99999
			elif step == 2 and t > 4.2:
				step = 3; shot("about"); get_tree().quit()
		"intro":
			var ts_: Array = [0.9, 2.0, 2.7, 3.5, 4.6, 5.8, 7.0]
			if step < ts_.size() and t > ts_[step]:
				shot("intro%d" % step)
				step += 1
			elif step >= ts_.size() and t > 9.2:
				print("INTRO scene now: ", get_tree().current_scene.name)
				get_tree().quit()
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
		"stk":
			# every sticker above a car (stk_<n>.png) + the picker window in a solo race
			if step == 0 and t > 1.5:
				step = 1
				sc.visible = false
				_cars_setup()
			elif step >= 1 and step <= 13 and t > 2.0 + step * 0.8:
				if step == 1:
					var lo := {"car": "hatch", "paint": "red", "stripe": "none", "rim": "steel", "glow": "none", "wheel": "stock"}
					var car := Car.new()
					car.setup(0, Color(0.2, 0.8, 0.3), false, lo, true)
					get_tree().root.add_child(car)
					_cs_car = car
				else:
					_cs_cam.position = Vector3(5.5, 3.4, 7.5)
					_cs_cam.look_at(Vector3(0, 2.7, 0))
					_cs_cam.fov = 42.0
					_cs_cam.current = true
				var cur := step
				step += 1
				if cur >= 2:
					await shot("stk_%02d" % (cur - 2))
				if cur <= 12:
					Stickers.show_on(_cs_car, cur - 1, false)
			elif step == 14 and t > 16.0:
				step = 16
				_cs_car.queue_free()
				_cs_cam.current = false
				sc.visible = true
				L.tutorial_off = true
				sc._on_solo()
			elif step == 16 and t > 32.0:
				step = 17
				get_tree().current_scene._toggle_stickers()
				var pk = get_tree().current_scene.sticker_picker
				print("PICKER ", pk, " ", pk.position if pk else "-", " ", pk.size if pk else "-", " vis=", pk.is_visible_in_tree() if pk else "-")
			elif step == 17 and t > 33.5:
				step = 18
				await shot("stk_picker")
				get_tree().current_scene._send_sticker(6)
			elif step == 18 and t > 34.5:
				get_tree().quit()
		"replay":
			# solo race, drive a bit, blow the car up, then play the replay and take shots of it
			if step == 0 and t > 2.0:
				step = 1
				L.tutorial_off = true
				sc._on_solo()
				Input.action_press("accel")
			elif step == 1 and t > 17.0:
				step = 2
				var w = get_tree().current_scene
				w._explode(w.teams[0])
			elif step == 2 and t > 19.0:
				step = 3
				var w2 = get_tree().current_scene
				print("REPLAY avail=", w2.director.available(), " frames=", w2.director.frames.size())
				w2._play_replay()
			elif step >= 3 and step <= 8 and t > 19.5 + (step - 3) * 1.1:
				var cur2 := step
				step += 1
				await shot("replay_%d" % (cur2 - 3))
			elif step == 9:
				Input.action_release("accel")
				get_tree().quit()
		"photo":
			# solo race, take a HUD photo card, then check the saved PNG
			if step == 0 and t > 2.0:
				step = 1
				L.tutorial_off = true
				sc._on_solo()
				Input.action_press("accel")
			elif step == 1 and t > 10.0:
				step = 2
				get_tree().current_scene._take_photo()
			elif step == 2 and t > 13.0:
				var sd := DirAccess.open("user://share")
				print("PHOTOS ", sd.get_files() if sd else "none")
				Input.action_release("accel")
				get_tree().quit()
		"repair":
			# driver outside the car holding the extinguisher: right hand = body, left hand = nozzle (then covering the engine)
			if step == 0 and t > 2.0:
				step = 1
				L.tutorial_off = true
				sc._on_solo()
			elif step == 1 and t > 14.0:
				step = 2
				var w = get_tree().current_scene
				w.local_avatar.go_outside(Vector3(0.9, -0.2, -3.2))
				w.local_avatar.work = 2
			elif step == 2 and t > 16.0:
				step = 3; shot("repair0")
				get_tree().current_scene.look_pitch = -0.28
				get_tree().current_scene.local_avatar.cover_hand = true
			elif step == 3 and t > 17.5:
				step = 4; shot("repair1")
				var av2 = get_tree().current_scene.local_avatar
				av2.cover_hand = false
			elif step == 4 and t > 19.0:
				step = 5; shot("repair2")
				get_tree().quit()
		"online":
			# joins a headless server on 127.0.0.1 (see tools/online_test.sh), readies up, drives, takes shots
			if step == 0 and t > 2.0:
				step = 1
				L.tutorial_off = true
				Profile.steer_mode = "buttons"
				Net.joined.connect(func(): print("JOINED"))
				Net.join_failed.connect(func(): print("JOIN_FAILED"))
				Net.lobby_closed.connect(func(r): print("CLOSED ", r))
				var e := Net.join_game(OS.get_environment("SRV") if OS.get_environment("SRV") != "" else "127.0.0.1", OS.get_environment("NAME"))
				print("JOIN err=", e)
			elif step == 1 and t > 22.0:
				step = 2; shot("online_" + OS.get_environment("NAME") + "0")
				if OS.get_environment("NAME") == "A":
					get_tree().current_scene._send_sticker(6)
				print("INGAME ", Net.in_game, " players=", Net.players)
				Input.action_press("accel")
			elif step == 2 and t > 23.5 and not _stk_seen:
				_stk_seen = true
				var ww := get_tree().current_scene
				var seen := []
				for tt in ww.teams:
					seen.append(tt.car.get_node_or_null("Sticker") != null)
				print("STICKERS_SEEN ", seen)
			elif step == 2 and t > 30.0:
				step = 3; shot("online_" + OS.get_environment("NAME") + "1")
				var w := get_tree().current_scene
				print("SCENE ", w.name, " speed=", w.teams[w.my_team].speed if "teams" in w else -1)
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
var _stk_seen := false
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
	var i := (step - 1) / 6
	var k := (step - 1) % 6
	if i >= _cs_list.size():
		get_tree().quit()
		return
	var id: String = _cs_list[i]
	if k == 0:
		if _cs_car:
			_cs_car.queue_free()
		var lo := {"car": id, "paint": OS.get_environment("PAINT") if OS.get_environment("PAINT") != "" else Catalog.CARS[id].get("paint", "red"),
			"stripe": OS.get_environment("STRIPE") if OS.get_environment("STRIPE") != "" else "none", "rim": "steel", "glow": "none", "wheel": OS.get_environment("WHEEL") if OS.get_environment("WHEEL") != "" else "stock"}
		var car := Car.new()
		car.setup(0, Color(0.2, 0.8, 0.3), false, lo, true)
		get_tree().root.add_child(car)
		car.set_plate_text("Racer")
		_cs_car = car
	else:
		var views := [Vector3(-5.2, 1.7, -6.2), Vector3(5.4, 2.0, 6.8), Vector3(8.2, 1.3, 0.0), Vector3(-0.45, 1.62, 0.25), Vector3(-2.3, 1.7, 0.6)]
		_cs_cam.position = views[k - 1]
		if k == 4:
			_cs_car.speed_kmh = _cs_car.top_speed * 0.55
			_cs_cam.fov = 70.0
			_cs_cam.look_at(Vector3(-0.45, 1.2, -0.93))
		elif k == 5:
			_cs_cam.fov = 30.0
			_cs_cam.look_at(Vector3(-1.1, 1.35, -0.8))
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
		var lo := {"car": id, "paint": Catalog.CARS[id].get("paint", "red"), "stripe": "none", "rim": "steel", "glow": "none", "wheel": OS.get_environment("WHEEL") if OS.get_environment("WHEEL") != "" else "stock"}
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


# ---------------------------------------------------------------- promo video timeline (recorded with tools/rec.sh)
var _pc: CanvasLayer
var _cap_lbl: Label
var _rt := -1.0
var _pflags := {}

func _cap(text: String, col := Color(1, 1, 1), size := 70) -> void:
	if _pc == null:
		_pc = CanvasLayer.new()
		_pc.layer = 100
		get_tree().root.add_child(_pc)
	if _cap_lbl:
		_cap_lbl.queue_free()
	_cap_lbl = null
	if text == "":
		return
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	l.add_theme_constant_override("outline_size", 16)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	l.anchor_left = 0.0
	l.anchor_right = 1.0
	l.offset_left = 0
	l.offset_right = 0
	l.offset_top = -190
	l.offset_bottom = -70
	_pc.add_child(l)
	_cap_lbl = l

func _once(key: String, cond: bool) -> bool:
	if cond and not _pflags.has(key):
		_pflags[key] = true
		return true
	return false

func _own_equip(slot: String, id: String) -> void:
	Profile.owned[slot + ":" + id] = true
	Profile.equip_car_part(slot, id)

func _promo(sc: Node) -> void:
	# ---- garage part (menu scene) t 0..14
	if _once("g0", t > 1.5):
		Profile.level = 20; Profile.coins = 99999
		Profile.car = "m4"; Profile.cars["m4"] = true
		sc.hub.select("modify")
		sc.hub.mod_section = "paint"; sc.hub.mod_sub["paint"] = "paint"; sc.hub._mod_fill()
		_cap("عدّل سيارتك بالكامل", Color(1, 0.62, 0.2))
	var paints: Array = Catalog.PAINT_ORDER
	for k in 4:
		if _once("p%d" % k, t > 2.0 + k * 0.7):
			_own_equip("paint", paints[(k * 3 + 2) % paints.size()])
			sc.hub._rerender()
	if _once("st", t > 5.0):
		sc.hub.mod_sub["paint"] = "stripe"; sc.hub._mod_fill()
		_own_equip("stripe", "white"); sc.hub._rerender()
	if _once("wh", t > 6.4):
		sc.hub.mod_section = "wheels"; sc.hub._mod_fill()
		_cap("جنوط حقيقية لكل سيارة", Color(1, 0.62, 0.2))
	var wo: Array = Catalog.wheel_opts("m4")
	for k in wo.size():
		if _once("w%d" % k, t > 6.8 + k * 0.8):
			_own_equip("wheel", wo[k]); sc.hub._rerender()
	if _once("en", t > 9.6):
		sc.hub.mod_section = "engine"; sc.hub._mod_fill()
		_cap("محرك حقيقي بخمس مراحل", Color(1, 0.62, 0.2))
	if _once("bd", t > 11.6):
		sc.hub.mod_section = "body"; sc.hub._mod_fill()
		_cap("")
		for sl in ["spoiler", "front", "hood", "skirts"]:
			var op: Array = Catalog.body_opts("m4", sl)
			_own_equip(sl, op[-1])
		sc.hub._rerender()
	if _once("solo", t > 13.8):
		_cap("")
		sc._on_solo()
	# ---- race part: anchor on RUNNING
	var w := get_tree().current_scene
	if _rt < 0.0 and w.get("state") != null and int(w.get("state")) == 2:
		_rt = 0.0
		print("PROMO race start at t=", t)
	if _rt < 0.0:
		return
	_rt += get_process_delta_time()
	if _rt > 0.2:
		Input.action_press("accel", 1.0)
	var ts = w.teams[w.my_team]
	if _once("c1", _rt > 0.5):
		_cap("سواق شبه أعمى...", Color(1, 1, 1))
	if _once("c2", _rt > 3.5):
		_cap("وصاحبك هو عيونك!", Color(0.5, 0.9, 1.0))
		if w.has_method("_toggle_map"):
			w._toggle_map()
	if _once("c3", _rt > 7.0):
		_cap("")
		if w.has_method("_toggle_map"):
			w._toggle_map()
	if _once("fire", _rt > 8.0):
		ts.damage = 95.0
		_cap("غلطة وحدة...", Color(1, 0.6, 0.15))
	if _once("boom", _rt > 12.5):
		w._explode(ts)
		_cap("انفجار!", Color(1, 0.25, 0.15), 96)
	if _once("end", _rt > 18.0):
		_cap("")
		var bg := ColorRect.new()
		bg.color = Color(0.04, 0.05, 0.07)
		bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		_pc.add_child(bg)
		var vb := VBoxContainer.new()
		vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		vb.alignment = BoxContainer.ALIGNMENT_CENTER
		bg.add_child(vb)
		for e in [["هيربن راش", 92, Color(1, 0.55, 0.12)], ["العب مع صاحبك على نفس الواي فاي", 48, Color(1, 1, 1)], ["iPhone + Android", 38, Color(0.6, 0.65, 0.72)]]:
			var l := Label.new()
			l.text = e[0]
			l.add_theme_font_size_override("font_size", e[1])
			l.add_theme_color_override("font_color", e[2])
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			vb.add_child(l)
	if _rt > 22.0:
		get_tree().quit()


# ---------------------------------------------------------------- cinematic: 6-player race, aerial -> low -> chase -> driver cam
var _fcam: Camera3D
var _ft := -1.0
var _fwait := 0.0
var _stuck := {}
var _hazards := {}
var _f2_pos := Vector3.ZERO
var _f2_a0 := 0.0

func _film_start() -> void:
	Profile.level = 20; Profile.coins = 99999
	Profile.car = "m4"; Profile.cars["m4"] = true
	Net.host_game("Player", 0, false, 6)
	var cars := ["muscle", "gt3", "hyper", "charger", "buggy"]
	var paints := ["yellow", "white", "orange", "blue", "green"]
	var names := ["أحمد", "سالم", "ليلى", "خالد", "مراد"]
	for k in 5:
		var id := 100 + k
		Net.players[id] = names[k]
		var lo: Dictionary = Profile.loadout()
		lo["car"] = cars[k]
		lo["paint"] = paints[k]
		lo["stripe"] = "white" if k % 2 == 0 else "none"
		lo["wheel"] = "stock"
		lo["decal"] = "none"; lo["spoiler"] = "none"; lo["front"] = "none"; lo["hood"] = "none"; lo["skirts"] = "none"
		lo["up"] = {}
		Net.loadouts[id] = lo
		Net.rdy[id] = true
		Net.present[id] = true
	Net.start_now()

func _bot_drive(w: Node, ts, k: int) -> void:
	var pts: PackedVector3Array = w.track.points
	var sp: float = ts.car.speed_kmh
	var idx := mini(ts.prog + (4 if sp < 50.0 else 7), pts.size() - 1)
	var loc: Vector3 = ts.car.global_transform.affine_inverse() * pts[idx]
	if k == 0:       # steer around any burning wreck on the road
		for o in w.teams:
			if o != ts and (o.phase >= 1 or _hazards.has(o.idx)):
				var rel: Vector3 = ts.car.global_transform.affine_inverse() * o.car.global_position
				if rel.z < 4.0 and rel.z > -40.0 and absf(rel.x) < 5.0:
					loc.x += (5.5 if rel.x < 0.0 else -5.5)
	var ang := atan2(loc.x, -loc.z)
	var steer := clampf(ang * 1.8, -1.0, 1.0)
	if sp < 3.0 and ts.phase == 0:
		_stuck[k] = float(_stuck.get(k, 0.0)) + get_process_delta_time()
		if float(_stuck[k]) > 0.9:
			_stuck[k] = 0.0
			w._reset_team(ts)
			return
	else:
		_stuck[k] = 0.0
	var tgt := ((96.0 if k == 0 else 84.0 - 3.0 * k)) if absf(ang) < 0.25 else (58.0 if absf(ang) < 0.5 else 38.0)
	var thr := clampf((tgt - sp) / 10.0, 0.0, 1.0)
	var brk := clampf((sp - tgt) / 15.0, 0.0, 1.0)
	if k == 0:
		Input.action_release("steer_left"); Input.action_release("steer_right")
		if steer < 0.0:
			Input.action_press("steer_left", -steer)
		else:
			Input.action_press("steer_right", steer)
		if thr > 0.02:
			Input.action_press("accel", thr)
		else:
			Input.action_release("accel")
		if brk > 0.05:
			Input.action_press("brake", brk)
		else:
			Input.action_release("brake")
		if int(Engine.get_process_frames()) % 48 == 0:
			print("ME sp=", snappedf(sp, 0.1), " ang=", snappedf(ang, 0.01), " thr=", snappedf(thr, 0.01), " prog=", ts.prog, " phase=", ts.phase, " hold=", ts.car.hold)
	else:
		ts.input = Vector3(steer, thr, brk)

func _film(sc: Node) -> void:
	if _once("start", t > 1.5):
		_film_start()
	var w := get_tree().current_scene
	if w == null or w.get("teams") == null or w.get("state") == null:
		return
	if _once("ready", true):
		for id in Net.players:
			w.ready_peers[id] = true
		w.call_deferred("_check_all_ready")
	if _fcam == null:
		_fcam = Camera3D.new()
		_fcam.fov = 60.0
		get_tree().root.add_child(_fcam)
	if _ft < 0.0:
		if int(w.state) >= 1:
			_ft = 0.0
			print("FILM countdown at t=", t)
		else:
			return
	_ft += get_process_delta_time()
	var d := get_process_delta_time()
	var teams: Array = w.teams
	if int(w.state) == 2:
		for k in teams.size():
			_bot_drive(w, teams[k], k)
	var lead = teams[0]
	for ts in teams:
		if ts.prog > lead.prog:
			lead = ts
	var gp: Vector3 = teams[0].car.global_position
	var centre := Vector3.ZERO
	for ts in teams:
		centre += ts.car.global_position
	centre /= float(teams.size())
	# --- shot 1: aerial crane over the grid (0 - 6 s)
	if _ft < 4.8:
		w.hud.visible = false
		var a := -0.9 + _ft * 0.2
		var hgt := lerpf(30.0, 12.0, clampf(_ft / 4.8, 0.0, 1.0))
		var rad := lerpf(22.0, 15.0, clampf(_ft / 4.8, 0.0, 1.0))
		var fw: Vector3 = Track.forward(w.track.headings[3])
		var tgt := centre + fw * clampf(_ft - 3.5, 0.0, 9.0) * 4.0
		_fcam.global_position = tgt + Vector3(sin(a) * rad, hgt, cos(a) * rad)
		_fcam.look_at(tgt, Vector3.UP)
		_fcam.current = true
		if _once("f1", true):
			_cap("6 لاعبين... سباق واحد", Color(1, 0.62, 0.2), 78)
	# --- shot 2: low trackside camera (6 - 10.5 s)
	elif _ft < 9.5:
		if _once("f2", true):
			_cap("انطلاق!", Color(1, 1, 1), 96)
			var i := 9
			var left: Vector3 = Track.left_of(w.track.headings[i])
			_fcam.global_position = w.track.points[i] + left * 6.0 + Vector3(0, 0.5, 0)
			_fcam.fov = 55.0
		_fcam.look_at(lead.car.global_position + Vector3(0, 0.6, 0), Vector3.UP)
		_fcam.current = true
	# --- shot 3: chase helicopter on the pack (10.5 - 16 s)
	elif _ft < 15.0:
		if _once("f3", true):
			_cap("سباق حقيقي مع أصحابك", Color(0.5, 0.9, 1.0), 78)
			_fcam.fov = 62.0
		var b: Basis = lead.car.global_basis
		var want: Vector3 = lead.car.global_position + b * Vector3(5.0, 7.0, 15.0)
		_fcam.global_position = _fcam.global_position.lerp(want, clampf(d * 3.0, 0.0, 1.0))
		_fcam.look_at(lead.car.global_position + Vector3(0, 0.8, -6.0), Vector3.UP)
		_fcam.current = true
		if _once("boom", _ft > 12.0):
			var bt = teams[4]
			bt.damage = 95.0
			w._explode(bt)
			_cap("وحدة تنفجر!", Color(1, 0.3, 0.15), 90)
	# --- shot 4: the driver's own camera (16 - 24 s)
	elif _ft < 25.0:
		if _once("f4", true):
			w.hud.visible = true
			if w.local_avatar and w.local_avatar.cam:
				w.local_avatar.cam.current = true
			_cap("وإنت السواق", Color(1, 1, 1), 84)
	elif _ft < 29.0:
		if _once("end", true):
			_cap("")
			var bg := ColorRect.new()
			bg.color = Color(0.04, 0.05, 0.07)
			bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			_pc.add_child(bg)
			var vb := VBoxContainer.new()
			vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			vb.alignment = BoxContainer.ALIGNMENT_CENTER
			bg.add_child(vb)
			for e in [["هيربن راش", 92, Color(1, 0.55, 0.12)], ["العب مع صاحبك على نفس الواي فاي", 48, Color(1, 1, 1)], ["iPhone + Android", 38, Color(0.6, 0.65, 0.72)]]:
				var l := Label.new()
				l.text = e[0]
				l.add_theme_font_size_override("font_size", e[1])
				l.add_theme_color_override("font_color", e[2])
				l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				vb.add_child(l)
	else:
		get_tree().quit()


# ================================================================ film2: professional action cut
class SpeedLines extends Control:
	var a := 0.0
	func _process(_d: float) -> void:
		queue_redraw()
	func _draw() -> void:
		if a <= 0.01:
			return
		var rng := RandomNumberGenerator.new()
		rng.seed = Engine.get_process_frames() * 7919
		var c := size * 0.5
		var rmax := c.length()
		for i in 46:
			var ang := rng.randf() * TAU
			var r0 := rmax * rng.randf_range(0.42, 0.7)
			var r1 := r0 + rmax * rng.randf_range(0.12, 0.35)
			var d := Vector2(cos(ang), sin(ang))
			draw_line(c + d * r0, c + d * r1, Color(1, 1, 1, a * rng.randf_range(0.25, 0.7)), rng.randf_range(1.5, 3.5))

var _f2 := {}
var _bars: Array = []
var _num: Label
var _flash: ColorRect
var _lines: SpeedLines
var _shake := 0.0
var _last_n := -1
var _n_t0 := 0.0
var _crash_ft := -1.0
var _cam_basis_off := Vector3.ZERO

func _f2_overlay() -> void:
	if _pc == null:
		_pc = CanvasLayer.new()
		_pc.layer = 100
		get_tree().root.add_child(_pc)
	_lines = SpeedLines.new()
	_lines.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_lines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pc.add_child(_lines)
	for k in 2:
		var b := ColorRect.new()
		b.color = Color(0, 0, 0)
		b.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE if k == 0 else Control.PRESET_BOTTOM_WIDE)
		b.custom_minimum_size = Vector2(0, 0)
		b.size = Vector2(1280, 0)
		_pc.add_child(b)
		_bars.append(b)
	_flash = ColorRect.new()
	_flash.color = Color(1, 1, 1, 0)
	_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pc.add_child(_flash)
	_num = Label.new()
	_num.add_theme_font_size_override("font_size", 280)
	_num.add_theme_color_override("font_color", Color(1, 1, 1))
	_num.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_num.add_theme_constant_override("outline_size", 28)
	_num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_num.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_num.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_num.pivot_offset = Vector2(640, 360)
	_pc.add_child(_num)

func _set_bars(h: float) -> void:
	_bars[0].offset_top = 0; _bars[0].offset_bottom = h
	_bars[1].offset_top = -h; _bars[1].offset_bottom = 0

func _f2_cam(pos: Vector3, look: Vector3, fov: float) -> void:
	var sh := Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * _shake * 0.35
	_fcam.global_position = pos + sh
	_fcam.look_at(look + sh * 0.5, Vector3.UP)
	_fcam.fov = fov
	_fcam.current = true

func _stage_pileup(w: Node, me, A, B) -> void:
	var i0: int = me.prog + 12
	var h: float = w.track.headings[i0]
	var fwd: Vector3 = Track.forward(h)
	var left: Vector3 = Track.left_of(h)
	var base: Vector3 = w.track.points[i0] + Vector3(0, 0.8, 0)
	A.car.teleport(Transform3D(Basis(Vector3.UP, h), base + left * 2.2))
	B.car.teleport(Transform3D(Basis(Vector3.UP, h), base - fwd * 26.0 - left * 0.4))
	PhysicsServer3D.body_set_state(A.car.get_rid(), PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, fwd * 22.0)
	PhysicsServer3D.body_set_state(B.car.get_rid(), PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, fwd * 30.0)
	_hazards[1] = true
	_hazards[2] = true
	_f2["stage_ft"] = _ft


func _film2(sc: Node) -> void:
	if _once("start", t > 1.5):
		seed(11)
		_film_start()
	var w := get_tree().current_scene
	if w.get("teams") == null or w.get("state") == null:
		return
	if _once("ready", true):
		for id in Net.players:
			w.ready_peers[id] = true
		w.call_deferred("_check_all_ready")
	if _fcam == null:
		_fcam = Camera3D.new()
		get_tree().root.add_child(_fcam)
		_f2_overlay()
	if _ft < 0.0:
		if int(w.state) >= 1:
			_ft = 0.0
			print("FILM2 countdown at t=", t)
		else:
			return
	_ft += 1.0 / 24.0
	var teams: Array = w.teams
	var me = teams[0]
	var A = teams[1]
	var B = teams[2]
	if int(w.state) == 2:
		for k in teams.size():
			if _hazards.has(k) and (k == 1 or k == 2):
				continue
			_bot_drive(w, teams[k], k)
	var lead = teams[0]
	for ts in teams:
		if ts.prog > lead.prog:
			lead = ts
	var centre := Vector3.ZERO
	for ts in teams:
		centre += ts.car.global_position
	centre /= float(teams.size())
	_shake = maxf(0.0, _shake - 1.0 / 24.0 * 1.6)
	_flash.color.a = maxf(0.0, _flash.color.a - 1.0 / 24.0 * 2.5)
	_lines.a = 0.0
	# ---- countdown numerals (synced with the game's own beeps)
	var n := -1
	if int(w.state) == 1:
		n = ceili(w.countdown_left)
	elif int(w.state) == 2 and _ft < 5.0:
		n = 0
	if n != _last_n:
		_last_n = n
		_n_t0 = _ft
	if n >= 1 and n <= 3:
		_num.text = str(n)
		_num.modulate = Color(1, 1, 1, 1)
	elif n == 0:
		_num.text = "انطلق!"
		_num.modulate = Color(1, 0.6, 0.15, clampf(1.0 - (_ft - _n_t0 - 0.6) * 2.5, 0.0, 1.0))
	else:
		_num.text = ""
	var pop := clampf((_ft - _n_t0) * 7.0, 0.0, 1.0)
	_num.scale = Vector2.ONE * lerpf(1.8, 1.0, pop)
	# ---- shot 1: aerial crane on the grid (0 - 3.6)
	if _ft < 3.6:
		w.hud.visible = false
		_set_bars(70)
		var u := _ft / 3.6
		var a := -0.9 + _ft * 0.25
		var hgt := lerpf(28.0, 9.0, u)
		var rad := lerpf(22.0, 12.0, u)
		_f2_cam(centre + Vector3(sin(a) * rad, hgt, cos(a) * rad), centre, lerpf(55.0, 42.0, u))
	# ---- shot 2: low trackside, slow-mo launch (3.6 - 7.0)
	elif _ft < 7.0:
		w.hud.visible = false
		_set_bars(70)
		if _once("f2", true):
			var i := 9
			var left: Vector3 = Track.left_of(w.track.headings[i])
			_f2_pos = w.track.points[i] + left * 5.5 + Vector3(0, 0.45, 0)
			_shake = 0.6
			_cap("", Color.WHITE)
		Engine.time_scale = 0.5 if _ft < 5.6 else lerpf(0.5, 1.0, clampf((_ft - 5.6) / 1.2, 0.0, 1.0))
		if _once("stage", _ft > 6.0):
			_stage_pileup(w, me, A, B)
		_f2_cam(_f2_pos, lead.car.global_position + Vector3(0, 0.6, 0), 48.0)
		_lines.a = 0.5
	# ---- shot 3: driver POV, a car ahead blocks the road (7.0 - 10.2)
	elif _ft < 8.9:
		Engine.time_scale = 1.0
		_set_bars(0)
		w.hud.visible = true
		if _once("f3", true):
			if w.local_avatar and w.local_avatar.cam:
				w.local_avatar.cam.current = true
			_cap("غلطة وحدة تكفي...", Color(1, 0.62, 0.2), 80)
	# ---- shot 4: slow-motion orbit around the pile-up (10.2 - 16.0)
	elif _ft < 14.7:
		_set_bars(70)
		w.hud.visible = false
		if _once("f4", true):
			_cap("")
			_f2_a0 = 2.2
		var u4 := _ft - 8.9
		Engine.time_scale = 0.28 if u4 < 3.6 else lerpf(0.28, 1.0, clampf((u4 - 3.6) / 1.4, 0.0, 1.0))
		_f2_a0 += 1.0 / 24.0 * 0.55
		var tgt: Vector3 = (A.car.global_position + B.car.global_position) * 0.5 + Vector3(0, 0.8, 0)
		var rad4 := lerpf(11.0, 7.0, clampf(u4 / 4.0, 0.0, 1.0))
		_f2_cam(tgt + Vector3(sin(_f2_a0) * rad4, lerpf(1.2, 3.4, clampf(u4 / 4.0, 0.0, 1.0)), cos(_f2_a0) * rad4), tgt, 52.0)
		_lines.a = 0.0
		if _once("cap4", u4 > 1.2):
			_cap("وإللي وراه ما قدر يوقف!", Color(1, 0.3, 0.15), 82)
	# ---- shot 5: chase on the survivors, speed lines (16.0 - 21.0)
	elif _ft < 19.7:
		Engine.time_scale = 1.0
		_set_bars(70)
		if _once("f5", true):
			_cap("وإنت... تقدر تتفاداه؟", Color(1, 1, 1), 84)
			_fcam.global_position = me.car.global_position + me.car.global_basis * Vector3(4.0, 3.0, 11.0)
		var want: Vector3 = me.car.global_position + me.car.global_basis * Vector3(3.5, 2.6, 9.0)
		_f2_cam(_fcam.global_position.lerp(want, 0.18), me.car.global_position + Vector3(0, 0.9, -5.0), 62.0)
		_lines.a = clampf(me.car.speed_kmh / 110.0, 0.0, 1.0) * 0.6
	elif _ft < 24.7:
		Engine.time_scale = 1.0
		_set_bars(0)
		if _once("end", true):
			_cap("")
			var bg := ColorRect.new()
			bg.color = Color(0.04, 0.05, 0.07)
			bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			_pc.add_child(bg)
			var vb := VBoxContainer.new()
			vb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			vb.alignment = BoxContainer.ALIGNMENT_CENTER
			bg.add_child(vb)
			for e in [["هيربن راش", 96, Color(1, 0.55, 0.12)], ["سباق 6 لاعبين على نفس الواي فاي", 50, Color(1, 1, 1)], ["iPhone + Android", 38, Color(0.6, 0.65, 0.72)]]:
				var l := Label.new()
				l.text = e[0]
				l.add_theme_font_size_override("font_size", e[1])
				l.add_theme_color_override("font_color", e[2])
				l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				vb.add_child(l)
	else:
		get_tree().quit()
	# ---- the scripted pile-up: A swerves across the road, B cannot stop and rolls over him
	if _f2.has("stage_ft"):
		var st: float = _ft - float(_f2["stage_ft"])
		if st > 0.0 and st < 3.0 and _crash_ft < 0.0:
			if st > 1.6:
				A.input = Vector3(1.0, 0.0, 0.6)       # hard right + brake: broadside on the road
			else:
				A.input = Vector3(0.0, 0.8, 0.0)
			var rel: Vector3 = B.car.global_transform.affine_inverse() * A.car.global_position
			B.input = Vector3(clampf(atan2(rel.x, -rel.z) * 1.2, -1.0, 1.0), 1.0, 0.0)
			var dist: float = A.car.global_position.distance_to(B.car.global_position)
			if (dist < 4.6 and st > 0.4) or st > 3.4:
				_crash_ft = _ft
				print("CRASH at ft=", _ft)
				var fw: Vector3 = -B.car.global_basis.z
				B.car.apply_central_impulse(Vector3(0, B.car.mass * 6.0, 0) + fw * B.car.mass * 1.0)
				B.car.apply_torque_impulse(-fw * B.car.mass * 5.0)
				A.car.apply_torque_impulse(Vector3(0, A.car.mass * 2.5, 0))
				_shake = 1.0
				_flash.color.a = 0.8
		elif _crash_ft > 0.0 and _ft - _crash_ft < 3.0:
			A.input = Vector3(0, 0, 1.0)
			B.input = Vector3(0, 0, 0.5)
		elif _crash_ft > 0.0:
			_hazards[1] = true


# ---------------------------------------------------------------- store icon / cover art (ICON_MODE=square|cover)
func _icon(sc: Node) -> void:
	var cover := OS.get_environment("ICON_MODE") == "cover"
	if step == 0 and t > 1.5:
		step = 1
		sc.visible = false
		var root := get_tree().root
		var env := WorldEnvironment.new()
		var e := Environment.new()
		e.background_mode = Environment.BG_COLOR
		e.background_color = Color(0.035, 0.04, 0.055)
		e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		e.ambient_light_color = Color(0.5, 0.55, 0.7)
		e.ambient_light_energy = 0.55
		e.glow_enabled = true
		e.glow_intensity = 0.9
		e.glow_bloom = 0.15
		env.environment = e
		root.add_child(env)
		var key := DirectionalLight3D.new()
		key.rotation_degrees = Vector3(-30, -50, 0)
		key.light_energy = 1.25
		root.add_child(key)
		var rim := DirectionalLight3D.new()
		rim.rotation_degrees = Vector3(-15, 140, 0)
		rim.light_color = Color(1.0, 0.55, 0.2)
		rim.light_energy = 1.6
		root.add_child(rim)
		var fl := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(80, 80)
		fl.mesh = pm
		var fm := StandardMaterial3D.new()
		fm.albedo_color = Color(0.09, 0.1, 0.13)
		fm.metallic = 0.1
		fm.roughness = 0.6
		fl.material_override = fm
		root.add_child(fl)
		# speed streaks behind the car
		for i in 26:
			var b := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.05 + randf() * 0.05, 0.05, 6.0 + randf() * 16.0)
			b.mesh = bm
			var mm := StandardMaterial3D.new()
			mm.albedo_color = Color(1, 0.5, 0.12)
			mm.emission_enabled = true
			mm.emission = Color(1, 0.5, 0.12)
			mm.emission_energy_multiplier = 3.0
			b.material_override = mm
			b.position = Vector3(randf_range(-9, 9), randf_range(0.2, 4.0), randf_range(6, 30))
			if absf(b.position.x) < 2.2:
				b.position.x += signf(b.position.x + 0.01) * 3.0
			root.add_child(b)
		var lo := {"car": "gt3", "paint": "orange", "stripe": "white", "rim": "black", "glow": "none", "decal": "none", "spoiler": "gt", "front": "splitter", "hood": "none", "skirts": "none", "wheel": "centre"}
		var car := Car.new()
		car.setup(0, Color(1, 0.55, 0.12), false, lo, true)
		car.rotation_degrees.y = 18.0
		root.add_child(car)
		car.set_plate_text("")
		_cs_car = car
		_cs_cam = Camera3D.new()
		_cs_cam.fov = 34.0 if not cover else 30.0
		_cs_cam.position = Vector3(-5.9, 1.35, -8.0) if not cover else Vector3(-5.8, 1.15, -7.4)
		root.add_child(_cs_cam)
		_cs_cam.look_at(Vector3(0.25 if not cover else -1.4, 0.95 if not cover else 0.9, 0.0), Vector3.UP)
		_cs_cam.current = true
		if cover:
			var cl := CanvasLayer.new()
			cl.layer = 50
			root.add_child(cl)
			var yy := 240.0
			for e2 in [["هيربن راش", 58, Color(1, 0.58, 0.14)], ["HAIRPIN RUSH", 32, Color(0.9, 0.92, 0.97)], ["سباق تعاوني على الواي فاي", 24, Color(0.62, 0.67, 0.75)]]:
				var l := Label.new()
				l.text = e2[0]
				l.add_theme_font_size_override("font_size", e2[1])
				l.add_theme_color_override("font_color", e2[2])
				l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
				l.add_theme_constant_override("outline_size", 10)
				l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				l.position = Vector2(700, yy)
				l.size = Vector2(560, e2[1] * 1.5)
				cl.add_child(l)
				yy += e2[1] * 1.5 + 6.0
	elif step == 1 and t > 4.0:
		step = 2
		shot("icon_" + ("cover" if cover else "square"))
	elif step == 2 and t > 4.6:
		get_tree().quit()
