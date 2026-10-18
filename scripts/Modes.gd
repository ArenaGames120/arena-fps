## Описание игровых режимов: командный бой, соревновательный, напарники и FFA.
class_name Modes
extends RefCounted

const DATA := {
	"ffa": {
		"name": "Каждый сам за себя",
		"short": "FFA",
		"desc": "Все против всех: боты воюют и между собой. Победа — 15 фрагов.",
		"teams": false,
		"team_size": 0,
		"enemies": 8,
		"respawn": true,
		"respawn_delay": 3.0,
		"rounds": false,
		"frag_limit": 15,
		"friendly_fire": true,
		"xp_kill": 10,
		"xp_headshot": 15,
		"xp_win": 120,
		"xp_loss": 50,
	},
	"tdm": {
		"name": "Командный бой",
		"short": "TDM",
		"desc": "Спецназ против террористов, возрождение после смерти. Победа — 50 фрагов команды.",
		"teams": true,
		"team_size": 4,
		"respawn": true,
		"respawn_delay": 3.0,
		"rounds": false,
		"frag_limit": 50,
		"friendly_fire": false,
		"xp_kill": 10,
		"xp_headshot": 15,
		"xp_win": 150,
		"xp_loss": 60,
	},
	"comp": {
		"name": "Соревновательный",
		"short": "COMP",
		"desc": "Раунды 4×4 без возрождения: побеждает команда, первой взявшая 4 раунда.",
		"teams": true,
		"team_size": 4,
		"respawn": false,
		"rounds": true,
		"rounds_to_win": 4,
		"round_time": 120.0,
		"friendly_fire": false,
		"xp_kill": 12,
		"xp_headshot": 18,
		"xp_round_win": 40,
		"xp_round_loss": 15,
		"xp_win": 200,
		"xp_loss": 80,
	},
	"wingman": {
		"name": "Напарники",
		"short": "WINGMAN",
		"desc": "Бой 2×2 без возрождения: побеждает пара, первой взявшая 4 раунда.",
		"teams": true,
		"team_size": 2,
		"respawn": false,
		"rounds": true,
		"rounds_to_win": 4,
		"round_time": 100.0,
		"friendly_fire": false,
		"xp_kill": 15,
		"xp_headshot": 20,
		"xp_round_win": 50,
		"xp_round_loss": 20,
		"xp_win": 220,
		"xp_loss": 90,
	},
}

const ORDER := ["tdm", "comp", "wingman", "ffa"]


static func get_data(id: String) -> Dictionary:
	var data: Dictionary = DATA.get(id, DATA["ffa"])
	return data.duplicate(true)


static func mode_name(id: String) -> String:
	return String(get_data(id)["name"])


static func mode_short(id: String) -> String:
	return String(get_data(id)["short"])


static func all() -> Array[Dictionary]:
	var list: Array[Dictionary] = []
	for id in ORDER:
		var data := get_data(id)
		data["id"] = id
		list.append(data)
	return list
