# Copyright (c) 2026 KRG Studios. All rights reserved. See LICENSE.
class_name CarSpecs
extends RefCounted
## Real-world data for every car (public figures of the real cars each model is styled after).
## mass kg | hp | tq = peak torque Nm | tq_lo/tq_hi = rpm band of the torque plateau | red = redline rpm | idle rpm
## g = gear ratios | fd = final drive | r = tyre rolling radius m | cd = drag coefficient | a = frontal area m2
## cla = downforce coefficient x area (m2) | drive = RWD / FWD / AWD | wf = front weight share | top = top speed km/h
## brake = best braking deceleration in g | mu = tyre grip (street 1.0, sport 1.1, slick 1.3) | zero100 = real 0-100 km/h time (s) for the self-test
const SPECS := {
	"hatch": {"mass": 1380.0, "hp": 296.0, "tq": 400.0, "tq_lo": 2000.0, "tq_hi": 5200.0, "red": 6700.0, "idle": 900.0,
		"g": [3.62, 2.19, 1.52, 1.17, 0.93, 0.76], "fd": 3.9, "r": 0.33, "cd": 0.33, "a": 2.2, "cla": 0.1, "drive": "AWD", "wf": 0.60,
		"top": 250.0, "brake": 1.0, "mu": 1.05, "zero100": 5.6, "acc": 0.55},
	"buggy": {"mass": 900.0, "hp": 220.0, "tq": 280.0, "tq_lo": 3000.0, "tq_hi": 6000.0, "red": 7200.0, "idle": 1000.0,
		"g": [3.4, 2.1, 1.45, 1.1, 0.88], "fd": 3.5, "r": 0.37, "cd": 0.55, "a": 2.0, "cla": 0.0, "drive": "RWD", "wf": 0.44,
		"top": 170.0, "brake": 0.85, "mu": 1.1, "zero100": 4.8, "acc": 0.7},
	"muscle": {"mass": 1750.0, "hp": 480.0, "tq": 570.0, "tq_lo": 3500.0, "tq_hi": 5500.0, "red": 7200.0, "idle": 800.0,
		"g": [3.66, 2.43, 1.69, 1.32, 1.0, 0.65], "fd": 3.55, "r": 0.345, "cd": 0.37, "a": 2.3, "cla": 0.15, "drive": "RWD", "wf": 0.53,
		"top": 250.0, "brake": 1.0, "mu": 1.0, "zero100": 4.3, "acc": 0.85},
	"sierra": {"mass": 1200.0, "hp": 224.0, "tq": 290.0, "tq_lo": 3000.0, "tq_hi": 5500.0, "red": 7000.0, "idle": 900.0,
		"g": [3.36, 1.81, 1.26, 1.0, 0.83], "fd": 3.62, "r": 0.31, "cd": 0.34, "a": 2.0, "cla": 0.25, "drive": "RWD", "wf": 0.52,
		"top": 240.0, "brake": 0.95, "mu": 1.0, "zero100": 6.2, "acc": 0.62},
	"pickup": {"mass": 2300.0, "hp": 392.0, "tq": 583.0, "tq_lo": 2300.0, "tq_hi": 4500.0, "red": 6200.0, "idle": 750.0,
		"g": [4.7, 3.14, 2.1, 1.67, 1.29, 1.0, 0.84, 0.67], "fd": 3.7, "r": 0.4, "cd": 0.45, "a": 3.0, "cla": 0.0, "drive": "AWD", "wf": 0.56,
		"top": 180.0, "brake": 0.85, "mu": 1.0, "zero100": 6.0, "acc": 0.65},
	"charger": {"mass": 1860.0, "hp": 485.0, "tq": 644.0, "tq_lo": 3600.0, "tq_hi": 5200.0, "red": 6200.0, "idle": 750.0,
		"g": [4.71, 3.14, 2.1, 1.67, 1.29, 1.0, 0.84, 0.67], "fd": 3.09, "r": 0.35, "cd": 0.36, "a": 2.4, "cla": 0.2, "drive": "RWD", "wf": 0.54,
		"top": 270.0, "brake": 1.0, "mu": 1.05, "zero100": 4.4, "acc": 0.9},
	"coupe": {"mass": 1550.0, "hp": 382.0, "tq": 500.0, "tq_lo": 1800.0, "tq_hi": 5000.0, "red": 6800.0, "idle": 800.0,
		"g": [5.25, 3.36, 2.17, 1.72, 1.32, 1.0, 0.82, 0.64], "fd": 3.15, "r": 0.335, "cd": 0.31, "a": 2.1, "cla": 0.45, "drive": "RWD", "wf": 0.50,
		"top": 250.0, "brake": 1.1, "mu": 1.15, "zero100": 4.1, "acc": 0.75},
	"m4": {"mass": 1725.0, "hp": 503.0, "tq": 650.0, "tq_lo": 2650.0, "tq_hi": 5500.0, "red": 7200.0, "idle": 800.0,
		"g": [4.71, 3.14, 2.1, 1.67, 1.29, 1.0, 0.84, 0.67], "fd": 3.15, "r": 0.335, "cd": 0.35, "a": 2.3, "cla": 0.45, "drive": "RWD", "wf": 0.51,
		"top": 290.0, "brake": 1.1, "mu": 1.15, "zero100": 3.8, "acc": 0.7},
	"gt3": {"mass": 1450.0, "hp": 518.0, "tq": 465.0, "tq_lo": 6300.0, "tq_hi": 8300.0, "red": 9000.0, "idle": 1000.0,
		"g": [3.75, 2.38, 1.72, 1.34, 1.08, 0.89, 0.74], "fd": 3.97, "r": 0.34, "cd": 0.34, "a": 2.1, "cla": 1.3, "drive": "RWD", "wf": 0.39,
		"top": 296.0, "brake": 1.45, "mu": 1.35, "zero100": 3.2, "acc": 0.68},
	"hyper": {"mass": 1995.0, "hp": 1500.0, "tq": 1600.0, "tq_lo": 2000.0, "tq_hi": 6000.0, "red": 7100.0, "idle": 900.0,
		"g": [3.8, 2.8, 2.1, 1.65, 1.3, 1.05, 0.85, 0.7], "fd": 3.4, "r": 0.36, "cd": 0.36, "a": 2.1, "cla": 1.1, "drive": "AWD", "wf": 0.43,
		"top": 380.0, "brake": 1.35, "mu": 1.25, "zero100": 2.5, "acc": 0.8},
}


static func get_spec(model: String) -> Dictionary:
	return SPECS.get(model, SPECS["hatch"])


## engine torque (Nm) at a given rpm: gentle rise to the plateau, flat, then a fall towards the redline
static func torque_at(sp: Dictionary, rpm: float) -> float:
	var lo := float(sp["tq_lo"])
	var hi := float(sp["tq_hi"])
	var red := float(sp["red"])
	var idle := float(sp["idle"])
	var t: float
	if rpm < lo:
		t = lerpf(0.5, 1.0, smoothstep(idle * 0.8, lo, rpm))
	elif rpm <= hi:
		t = 1.0
	else:
		t = lerpf(1.0, 0.78, clampf((rpm - hi) / maxf(red - hi, 1.0), 0.0, 1.0))
	return float(sp["tq"]) * t


## gear (1-based) and engine rpm for a road speed
static func rpm_for(sp: Dictionary, gear: int, speed_ms: float) -> float:
	var g: Array = sp["g"]
	var ratio := float(g[clampi(gear - 1, 0, g.size() - 1)]) * float(sp["fd"])
	return speed_ms / float(sp["r"]) * ratio * 60.0 / TAU
