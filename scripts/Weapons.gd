## Таблица оружия: АК-47 (автомат), Desert Eagle (пистолет), снайперская винтовка.
class_name Weapons
extends RefCounted

const AK47 := {
	"id": "ak47",
	"name": "АК-47",
	"short_name": "АК",
	"auto": true,
	"damage": 27.0,
	"head_mult": 2.0,
	"rpm": 600.0,
	"mag": 30,
	"reserve": 210,
	"reserve_max": 300,
	"reload_time": 2.4,
	"spread": 1.2,
	"spread_move": 1.5,
	"recoil": 1.0,
	"kick": 0.022,
	"range": 220.0,
	"switch_time": 0.55,
	"zoom": false,
	"zoom_fov": 52.0,
	"zoom_sens": 0.75,
	"sound": "ak47",
	"tracer": Color(1.0, 0.82, 0.35),
	"hud_color": Color(0.95, 0.72, 0.30),
}

const DEAGLE := {
	"id": "deagle",
	"name": "Desert Eagle",
	"short_name": "DEAGLE",
	"auto": false,
	"damage": 55.0,
	"head_mult": 2.2,
	"rpm": 200.0,
	"mag": 7,
	"reserve": 56,
	"reserve_max": 84,
	"reload_time": 2.0,
	"spread": 0.75,
	"spread_move": 2.2,
	"recoil": 1.8,
	"kick": 0.045,
	"range": 160.0,
	"switch_time": 0.45,
	"zoom": false,
	"zoom_fov": 58.0,
	"zoom_sens": 0.8,
	"sound": "deagle",
	"tracer": Color(1.0, 0.72, 0.35),
	"hud_color": Color(0.95, 0.55, 0.25),
}

const SNIPER := {
	"id": "sniper",
	"name": "Снайперская винтовка",
	"short_name": "СНАЙПЕР",
	"auto": false,
	"damage": 115.0,
	"head_mult": 2.5,
	"rpm": 42.0,
	"mag": 5,
	"reserve": 30,
	"reserve_max": 45,
	"reload_time": 3.2,
	"spread": 0.07,
	"spread_move": 3.2,
	"recoil": 3.0,
	"kick": 0.075,
	"range": 400.0,
	"switch_time": 0.75,
	"zoom": true,
	"zoom_fov": 16.0,
	"zoom_sens": 0.32,
	"sound": "sniper",
	"tracer": Color(0.75, 0.92, 1.0),
	"hud_color": Color(0.60, 0.85, 1.0),
}


## Возвращает свежие копии описаний оружия для игрока.
static func create_loadout() -> Array[Dictionary]:
	var loadout: Array[Dictionary] = []
	for template in [AK47, DEAGLE, SNIPER]:
		var weapon: Dictionary = template.duplicate(true)
		weapon["ammo"] = weapon["mag"]
		weapon["reserve"] = weapon["reserve_max"]
		loadout.append(weapon)
	return loadout
