## Ядро игры: меню, карты, режимы (FFA, командный бой, соревновательный, напарники),
## боты с командами, счёт матча, раунды и начисление опыта.
extends Node3D

const WORLD_MASK := 1
const RESPAWN_DELAY := 3.6
const BOT_RESPAWN_MIN := 2.5
const BOT_RESPAWN_MAX := 4.5
const FREEZE_TIME := 3.0
const ROUND_BREAK := 4.0
const CT_COLOR := Color(0.45, 0.7, 1.0)
const T_COLOR := Color(1.0, 0.72, 0.34)
const BOT_COLORS := [
	Color(0.74, 0.18, 0.15), Color(0.86, 0.45, 0.1), Color(0.62, 0.2, 0.52),
	Color(0.35, 0.55, 0.85), Color(0.8, 0.72, 0.16), Color(0.24, 0.66, 0.5),
	Color(0.55, 0.35, 0.8), Color(0.85, 0.3, 0.35), Color(0.45, 0.6, 0.25),
]

enum GameState { MENU, PLAYING, PAUSED, MATCH_OVER }

var sfx: Sfx
var hud: HUD
var menu: Menu
var player: Player
var map_root: Node3D
var bots: Array[Bot] = []
## Ростер: имя, команда, цвет и счёт бойца. Сохраняется между смертями и раундами.
var slots: Array[Dictionary] = []

var mode_id := "tdm"
var mode: Dictionary = {}
var map_id := "dust2"
var map_data: Dictionary = {}
var map_name := "de_dust2"
var team := 0
var state: int = GameState.MENU

var kills := 0
var deaths := 0
var headshots := 0
var match_time := 0.0
var match_xp := 0
var team_frags := {0: 0, 1: 0}
var team_rounds := {0: 0, 1: 0}
var round_number := 0
var round_time_left := 0.0
var round_over := false
var round_end_timer := 0.0
var freeze_timer := 0.0
var player_dead := false
var player_respawn_timer := 0.0

var _menu_camera: Camera3D
var _menu_angle := 0.0
var _hud_timer := 0.0
var _hunt_timer := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rng.randomize()
	GameInput.ensure_actions()

	var settings := Progression.instance()
	settings.apply_display()
	AudioServer.set_bus_volume_db(0, linear_to_db(clampf(settings.volume, 0.001, 1.0)))

	map_root = Node3D.new()
	map_root.name = "Map"
	map_root.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(map_root)
	Effects.root = map_root

	sfx = Sfx.new()
	_build_environment()

	player = Player.new()
	player.name = "Player"
	player.process_mode = Node.PROCESS_MODE_PAUSABLE
	player.input_enabled = false
	player.set_physics_process(false)
	add_child(player)
	player.setup(sfx)
	player.died.connect(_on_player_died)

	_menu_camera = Camera3D.new()
	_menu_camera.near = 0.1
	_menu_camera.far = 700.0
	_menu_camera.fov = 72.0
	add_child(_menu_camera)

	hud = HUD.new()
	hud.name = "HUD"
	add_child(hud)
	hud.bind_player(player)
	hud.resume_requested.connect(_resume_game)
	hud.restart_requested.connect(_restart_match)
	hud.menu_requested.connect(_to_main_menu)
	hud.settings_requested.connect(_open_settings_from_pause)
	hud.quit_requested.connect(_quit_game)

	menu = Menu.new()
	menu.name = "Menu"
	add_child(menu)
	menu.play_requested.connect(start_match)
	menu.quit_requested.connect(_quit_game)
	menu.settings_changed.connect(_on_settings_changed)
	menu.closed.connect(_on_menu_closed)

	_to_main_menu()


# --- Мир ----------------------------------------------------------------------

func _build_environment() -> void:
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color(0.26, 0.44, 0.78)
	sky_material.sky_horizon_color = Color(0.74, 0.79, 0.86)
	sky_material.ground_bottom_color = Color(0.36, 0.34, 0.31)
	sky_material.ground_horizon_color = Color(0.64, 0.63, 0.6)
	sky.sky_material = sky_material
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0
	env.glow_enabled = true
	world_env.environment = env
	add_child(world_env)


# --- Меню ---------------------------------------------------------------------

func _to_main_menu() -> void:
	state = GameState.MENU
	get_tree().paused = false
	_clear_match()
	player.input_enabled = false
	player.set_physics_process(false)
	player.alive = true
	player.health = Player.MAX_HEALTH
	player.global_position = Vector3(0, -40, 0)
	hud.set_ui_visible(false)
	hud.show_pause(false)
	hud.show_death(false)
	# Показываем выбранную карту на фоне меню.
	var showcase := menu.selected_map if menu != null else "dust2"
	map_data = Levels.build(showcase, map_root)
	map_name = String(map_data["name"])
	menu.open()
	_menu_camera.current = true
	player.set_camera_current(false)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _open_settings_from_pause() -> void:
	if state != GameState.PAUSED:
		return
	hud.show_pause(false)
	menu.open_settings(true)


func _on_menu_closed() -> void:
	if state == GameState.PAUSED:
		hud.show_pause(true)


func _on_settings_changed() -> void:
	player.apply_settings()


func _quit_game() -> void:
	get_tree().quit()


# --- Матч ---------------------------------------------------------------------

func _clear_match() -> void:
	for bot in bots:
		if is_instance_valid(bot):
			bot.queue_free()
	bots.clear()
	slots.clear()
	for child in map_root.get_children():
		child.queue_free()
	team_frags = {0: 0, 1: 0}
	team_rounds = {0: 0, 1: 0}


func start_match(config: Dictionary) -> void:
	mode_id = String(config.get("mode", "tdm"))
	team = int(config.get("team", 0))
	mode = Modes.get_data(mode_id)
	if not bool(mode["teams"]):
		team = -1
	map_id = String(config.get("map", "dust2"))

	menu.close()
	_clear_match()
	map_data = Levels.build(map_id, map_root)
	map_name = String(map_data["name"])
	_spawn_pickups()
	_setup_roster()

	kills = 0
	headshots = 0
	deaths = 0
	match_time = 0.0
	match_xp = 0
	round_number = 0
	round_over = false
	player_dead = false
	player.team = team
	player.friendly_fire = not bool(mode["teams"])
	player.kills = 0
	player.deaths = 0
	player.set_physics_process(true)
	player.global_position = _spawn_point_for(team, 0)
	player.respawn_position(_spawn_point_for(team, 0), _team_yaw(team))

	state = GameState.PLAYING
	get_tree().paused = false
	_menu_camera.current = false
	player.set_camera_current(true)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	hud.set_ui_visible(true)
	hud.set_playing()
	hud.set_last_killer("")
	_update_hud_xp()
	hud.update_scoreboard(_scoreboard_rows(), _board_title())
	hud.set_status(_status_text())

	if bool(mode["rounds"]):
		_start_round()
	else:
		for i in slots.size():
			var slot: Dictionary = slots[i]
			var t := int(slot["team"])
			var bot := _spawn_slot(i, _spawn_point_for(t, int(slot["spawn"])))
			bot.rotation.y = _team_yaw(t)
		player.input_enabled = true
		hud.announce(String(mode["name"]).to_upper(), "%s · %s" % [map_name, _goal_text()], 2.6)


func _restart_match() -> void:
	if mode.is_empty():
		return
	start_match({"mode": mode_id, "map": map_id, "team": team})


func _setup_roster() -> void:
	slots.clear()
	if not bool(mode["teams"]):
		var count := int(mode["enemies"])
		for i in count:
			slots.append({
				"name": "Бот-%d" % (i + 1), "team": -1,
				"color": BOT_COLORS[i % BOT_COLORS.size()],
				"frags": 0, "deaths": 0, "bot": null, "respawn": 0.0, "spawn": i,
			})
		return
	var size := int(mode["team_size"])
	for t in 2:
		var count := (size - 1) if t == team else size
		var base := "Спецназ" if t == 0 else "Террорист"
		var color := CT_COLOR if t == 0 else T_COLOR
		for i in count:
			var tint := color.lerp(Color.WHITE, 0.1 * float(i % 3))
			slots.append({
				"name": "%s-%d" % [base, i + 1], "team": t, "color": tint,
				"frags": 0, "deaths": 0, "bot": null, "respawn": 0.0, "spawn": i,
			})


func _spawn_pickups() -> void:
	for spot in map_data.get("health", []):
		var pickup := Pickup.new()
		pickup.kind = Pickup.Kind.HEALTH
		pickup.position = spot
		map_root.add_child(pickup)
	for spot in map_data.get("ammo", []):
		var pickup := Pickup.new()
		pickup.kind = Pickup.Kind.AMMO
		pickup.position = spot
		map_root.add_child(pickup)


func _spawn_slot(index: int, position: Vector3) -> Bot:
	var slot: Dictionary = slots[index]
	var bot := Bot.new()
	bot.bot_name = String(slot["name"])
	bot.position = position
	map_root.add_child(bot)
	bot.assign_identity(String(slot["name"]), int(slot["team"]), slot["color"], int(slot["team"]) == 0, index)
	bot.set_difficulty(_bot_level())
	bot.push_direction = _push_for_team(int(slot["team"]))
	bot.setup_combat(sfx, map_root, map_data.get("patrol", []), Vector3.ZERO, 30.0)
	bot.died.connect(_on_bot_died)
	slot["bot"] = bot
	slot["respawn"] = _rng.randf_range(BOT_RESPAWN_MIN, BOT_RESPAWN_MAX)
	bots.append(bot)
	return bot


func _bot_level() -> int:
	var base := 2
	match mode_id:
		"ffa":
			base = mini(6, kills / 5)
		"tdm":
			base = 3
		_:
			base = 4
	return clampi(base + Progression.instance().bot_skill_bonus(), 0, 6)


func _spawn_point_for(team_id: int, index: int) -> Vector3:
	var spawns: Array = []
	if team_id >= 0 and map_data["team_spawns"].has(team_id):
		spawns = (map_data["team_spawns"][team_id] as Array).duplicate()
	else:
		for t in [0, 1]:
			spawns.append_array(map_data["team_spawns"][t] as Array)
		for point in map_data.get("patrol", []):
			spawns.append(point as Vector3)
	if spawns.is_empty():
		return Vector3(0, 0.3, 0)
	var point: Vector3 = spawns[posmod(index, spawns.size())]
	return point + Vector3(_rng.randf_range(-1.0, 1.0), 0.3, _rng.randf_range(-1.0, 1.0))


func _pick_safe_spawn(team_id: int) -> Vector3:
	var candidates: Array[Vector3] = []
	if team_id >= 0:
		for point in map_data["team_spawns"][team_id]:
			candidates.append(point as Vector3)
	else:
		for t in [0, 1]:
			for point in map_data["team_spawns"][t]:
				candidates.append(point as Vector3)
		for point in map_data.get("patrol", []):
			candidates.append(point as Vector3)
	if candidates.is_empty():
		return Vector3(0, 0.3, 0)
	var best := candidates[0]
	var best_distance := -1.0
	for candidate in candidates:
		var nearest := 999.0
		for bot in bots:
			if is_instance_valid(bot) and bot.alive:
				nearest = minf(nearest, candidate.distance_to(bot.global_position))
		if nearest > best_distance:
			best_distance = nearest
			best = candidate
	return best + Vector3(_rng.randf_range(-1.0, 1.0), 0.3, _rng.randf_range(-1.0, 1.0))


# --- Раунды -------------------------------------------------------------------

func _start_round() -> void:
	round_number += 1
	round_over = false
	round_time_left = float(mode["round_time"])
	for bot in bots:
		if is_instance_valid(bot):
			bot.queue_free()
	bots.clear()
	for i in slots.size():
		slots[i]["bot"] = null
	for i in slots.size():
		var slot: Dictionary = slots[i]
		var t := int(slot["team"])
		var bot := _spawn_slot(i, _spawn_point_for(t, int(slot["spawn"])))
		bot.rotation.y = _team_yaw(t)
		bot.set_frozen(true)
	player.respawn_position(_spawn_point_for(team, 0), _team_yaw(team))
	player.input_enabled = false
	player_dead = false
	hud.show_death(false)
	freeze_timer = FREEZE_TIME
	hud.announce("РАУНД %d" % round_number, "%s · %s" % [_score_line(), _team_name(team)], 2.4)
	hud.set_status(_status_text())


func _unfreeze() -> void:
	for bot in bots:
		if is_instance_valid(bot):
			bot.set_frozen(false)
	if not player_dead:
		player.input_enabled = true
	hud.announce("В БОЙ!", "", 1.2)


func _alive_count() -> Array[int]:
	var counts: Array[int] = [0, 0]
	if player.alive and team >= 0:
		counts[team] += 1
	for bot in bots:
		if is_instance_valid(bot) and bot.alive and bot.team >= 0:
			counts[bot.team] += 1
	return counts


func _check_round_end() -> void:
	if round_over or freeze_timer > 0.0:
		return
	var alive := _alive_count()
	var winner := -2
	if alive[0] <= 0 and alive[1] <= 0:
		winner = -1
	elif alive[0] <= 0:
		winner = 1
	elif alive[1] <= 0:
		winner = 0
	elif round_time_left <= 0.0:
		winner = 0
	else:
		return
	_end_round(winner)


func _end_round(winner: int) -> void:
	round_over = true
	round_end_timer = ROUND_BREAK
	var player_won := winner == team
	if winner >= 0:
		team_rounds[winner] = int(team_rounds[winner]) + 1
	var title := "НИЧЬЯ В РАУНДЕ"
	if winner >= 0:
		title = "РАУНД ВЫИГРАН" if player_won else "РАУНД ПРОИГРАН"
	hud.announce(title, _score_line(), 3.0)
	if winner >= 0:
		var xp := int(mode["xp_round_win"]) if player_won else int(mode["xp_round_loss"])
		_award_xp(xp, "за раунд")
		Progression.instance().register_round(player_won)
	for bot in bots:
		if is_instance_valid(bot) and bot.alive:
			bot.set_frozen(true)
	player.input_enabled = false
	hud.set_scoreboard_visible(false)
	hud.update_scoreboard(_scoreboard_rows(), _board_title())

	var to_win := int(mode["rounds_to_win"])
	if int(team_rounds[team]) >= to_win:
		_end_match(true, "%s взяли %d раунда" % [_team_name(team), to_win])
	elif int(team_rounds[1 - team]) >= to_win:
		_end_match(false, "%s взяли %d раунда" % [_team_name(1 - team), to_win])


# --- Боты и фраги -------------------------------------------------------------

func _slot_of(node: Node) -> int:
	if node == null:
		return -1
	for i in slots.size():
		if slots[i]["bot"] == node:
			return i
	return -1


func _team_of(node: Node) -> int:
	if node == null:
		return -1
	if node == player:
		return team
	var value = node.get("team")
	if value == null:
		return -1
	return int(value)


func _on_bot_died(bot: Node3D, attacker: Node) -> void:
	bots.erase(bot)
	var index := _slot_of(bot)
	if index < 0:
		return
	var slot: Dictionary = slots[index]
	slot["bot"] = null
	slot["deaths"] = int(slot["deaths"]) + 1
	var victim_name := String(slot["name"])
	var victim_color := slot["color"] as Color
	var victim_team := int(slot["team"])

	var killer_name := ""
	var killer_team := -1
	if attacker == player:
		var headshot := player.last_hit_head
		kills += 1
		if headshot:
			headshots += 1
		player.kills = kills
		Progression.instance().register_kill(headshot)
		_award_xp(int(mode["xp_headshot"]) if headshot else int(mode["xp_kill"]), "за фраг")
		hud.add_kill_feed("Вы устранили %s%s" % [victim_name, " (в голову)" if headshot else ""],
				Color(0.62, 1.0, 0.62))
	elif attacker is Bot:
		var killer_index := _slot_of(attacker)
		if killer_index >= 0:
			var killer_slot: Dictionary = slots[killer_index]
			killer_slot["frags"] = int(killer_slot["frags"]) + 1
			killer_name = String(killer_slot["name"])
			killer_team = int(killer_slot["team"])
			var feed_color := (killer_slot["color"] as Color).lerp(victim_color, 0.4).lightened(0.35)
			hud.add_kill_feed("%s устранил %s" % [killer_name, victim_name], feed_color)
	else:
		hud.add_kill_feed("%s погиб" % victim_name, victim_color.lightened(0.25))

	if killer_team >= 0 and victim_team >= 0 and killer_team != victim_team:
		team_frags[killer_team] = int(team_frags[killer_team]) + 1

	# Бойцы слышат перестрелку и подтягиваются к месту схватки.
	if attacker != null:
		_alert_bots_to(bot.global_position)

	if bool(mode["respawn"]):
		slot["respawn"] = _rng.randf_range(BOT_RESPAWN_MIN, BOT_RESPAWN_MAX)
	_check_frag_end()


## После гибели бойца часть его товарищей/врагов бежит к месту боя.
func _alert_bots_to(point: Vector3) -> void:
	for bot in bots:
		if is_instance_valid(bot) and bot.alive and _rng.randf() < 0.6:
			bot.hunt_to(point)


func _on_player_died(attacker: Node) -> void:
	if state != GameState.PLAYING and state != GameState.MATCH_OVER:
		return
	deaths += 1
	player.deaths = deaths
	player_dead = true
	Progression.instance().register_death()
	hud.set_scoreboard_visible(false)
	_lose_all_targets()

	var killer_name := ""
	if attacker is Bot:
		var index := _slot_of(attacker)
		if index >= 0:
			var slot: Dictionary = slots[index]
			slot["frags"] = int(slot["frags"]) + 1
			killer_name = String(slot["name"])
			var killer_team := int(slot["team"])
			if killer_team >= 0 and team >= 0 and killer_team != team:
				team_frags[killer_team] = int(team_frags[killer_team]) + 1
			hud.add_kill_feed("%s устранил вас" % killer_name, (slot["color"] as Color).lightened(0.3))
	else:
		hud.add_kill_feed("Вас устранили", Color(1.0, 0.45, 0.45))
	hud.set_last_killer(killer_name)
	_alert_bots_to(player.global_position)

	if bool(mode["rounds"]):
		hud.set_death_text("ВЫ ПОГИБЛИ\nЖдём конца раунда\nФрагов: %d%s" % [kills, _killer_line()])
		hud.show_death(true)
		_check_round_end()
	elif bool(mode["respawn"]):
		player_respawn_timer = RESPAWN_DELAY
		hud.set_death_text(_death_countdown_text())
		hud.show_death(true)
		_check_frag_end()


func _killer_line() -> String:
	var killer := hud.last_killer()
	return "\nВас устранил: %s" % killer if killer != "" else ""


func _death_countdown_text() -> String:
	return "ВЫ ПОГИБЛИ\nВозрождение через %.1f с\nФрагов: %d · В голову: %d%s" % [
		maxf(player_respawn_timer, 0.0), kills, headshots, _killer_line()]


func _respawn_player() -> void:
	player_dead = false
	player.respawn_position(_pick_safe_spawn(team), _team_yaw(team))
	player.input_enabled = true
	hud.set_last_killer("")
	_lose_all_targets()


func _lose_all_targets() -> void:
	for bot in bots:
		if is_instance_valid(bot):
			bot.lose_target()


func _maintain_bots(delta: float) -> void:
	for i in slots.size():
		var slot: Dictionary = slots[i]
		var bot := slot["bot"] as Bot
		if bot != null and not is_instance_valid(bot):
			slot["bot"] = null
			bot = null
		if bot != null:
			continue
		slot["respawn"] = float(slot["respawn"]) - delta
		if float(slot["respawn"]) > 0.0:
			continue
		var t := int(slot["team"])
		var point := _spawn_point_for(t, int(slot["spawn"]) + _rng.randi_range(0, 4))
		var new_bot := _spawn_slot(i, point)
		new_bot.rotation.y = _team_yaw(t)


## В раундовых режимах подталкиваем ботов к вражескому респауну, чтобы
## последние выжившие не отсиживались до конца времени раунда.
func _push_bots_to_enemy() -> void:
	for bot in bots:
		if not is_instance_valid(bot) or not bot.alive or bot.team < 0:
			continue
		var spawns: Array = map_data["team_spawns"][1 - bot.team]
		if spawns.is_empty():
			continue
		bot.hunt_to(spawns[_rng.randi_range(0, spawns.size() - 1)])


func _check_frag_end() -> void:
	if state != GameState.PLAYING or bool(mode["rounds"]) or mode.is_empty():
		return
	var limit := int(mode["frag_limit"])
	if not bool(mode["teams"]):
		if kills >= limit:
			_end_match(true, "Вы первым набрали %d фрагов" % limit)
			return
		var leader := -1
		var leader_frags := 0
		for i in slots.size():
			var frags := int(slots[i]["frags"])
			if frags > leader_frags:
				leader_frags = frags
				leader = i
		if leader >= 0 and leader_frags >= limit:
			_end_match(false, "%s первым набрал %d фрагов" % [slots[leader]["name"], limit])
		return
	if int(team_frags[team]) >= limit:
		_end_match(true, "%s набрали %d фрагов" % [_team_name(team), limit])
	elif int(team_frags[1 - team]) >= limit:
		_end_match(false, "%s набрали %d фрагов" % [_team_name(1 - team), limit])


func _end_match(player_won: bool, subtitle: String) -> void:
	if state == GameState.MATCH_OVER:
		return
	state = GameState.MATCH_OVER
	player.input_enabled = false
	freeze_timer = 0.0
	_lose_all_targets()
	for bot in bots:
		if is_instance_valid(bot):
			bot.idle()
	_award_xp(int(mode["xp_win"]) if player_won else int(mode["xp_loss"]), "за матч")
	Progression.instance().register_match(player_won)
	hud.set_scoreboard_visible(false)
	hud.show_match_end("ПОБЕДА" if player_won else "ПОРАЖЕНИЕ", subtitle,
			_scoreboard_rows(), "Опыт за матч: +%d · Убийств: %d (в голову: %d) · Смертей: %d" % [
				match_xp, kills, headshots, deaths])
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _award_xp(amount: int, _reason: String) -> void:
	if amount <= 0:
		return
	match_xp += amount
	var settings := Progression.instance()
	var levels := settings.add_xp(amount)
	hud.add_xp_popup(amount)
	_update_hud_xp()
	if levels > 0:
		hud.show_level_up(settings.level, settings.rank_name())


func _update_hud_xp() -> void:
	var settings := Progression.instance()
	hud.set_xp_info(settings.level, settings.rank_name(), settings.xp_ratio(),
			settings.xp, settings.xp_to_next())


# --- Вспомогательные данные ---------------------------------------------------

func _team_name(team_id: int) -> String:
	if team_id == 0:
		return "СПЕЦНАЗ"
	if team_id == 1:
		return "ТЕРРОРИСТЫ"
	return "БОЙЦЫ"


func _team_color(team_id: int) -> Color:
	return CT_COLOR if team_id == 0 else T_COLOR


func _team_yaw(team_id: int) -> float:
	return PI if team_id == 0 else 0.0


func _push_for_team(team_id: int) -> float:
	if team_id == 0:
		return 1.0
	if team_id == 1:
		return -1.0
	return 0.0


func _goal_text() -> String:
	if bool(mode["rounds"]):
		return "до %d раундов" % int(mode["rounds_to_win"])
	if bool(mode["teams"]):
		return "до %d фрагов команды" % int(mode["frag_limit"])
	return "до %d фрагов" % int(mode["frag_limit"])


func _score_line() -> String:
	if bool(mode["teams"]):
		return "%s %d : %d %s" % [_team_name(0), int(team_rounds[0]), int(team_rounds[1]), _team_name(1)]
	return "Фраги: %d · Смертей: %d" % [kills, deaths]


func _board_title() -> String:
	return "%s · %s" % [String(mode.get("name", "Бой")).to_upper(), map_name]


func _status_text() -> String:
	var minutes := int(match_time) / 60
	var seconds := int(match_time) % 60
	if bool(mode["rounds"]):
		var left := int(ceilf(maxf(round_time_left, 0.0)))
		if freeze_timer > 0.0:
			return "%s · РАУНД %d · ПОДГОТОВКА %d с" % [_score_line(), round_number, int(ceilf(freeze_timer))]
		return "%s · РАУНД %d · %02d:%02d · %s" % [_score_line(), round_number, left / 60, left % 60, map_name]
	if bool(mode["teams"]):
		var to_win := maxi(0, int(mode["frag_limit"]) - int(team_frags[team]))
		return "%s %d : %d %s · До победы: %d · %02d:%02d" % [
			_team_name(0), int(team_frags[0]), int(team_frags[1]), _team_name(1),
			to_win, minutes, seconds]
	return "СВОБОДНАЯ СХВАТКА · Фраги: %d/%d · Смертей: %d · Ботов: %d · %02d:%02d" % [
		kills, int(mode["frag_limit"]), deaths, bots.size(), minutes, seconds]


## Строки табло: в командных режимах с разделами по командам, в FFA — общий список.
func _scoreboard_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	if not bool(mode["teams"]):
		var ffa: Array[Dictionary] = [{
			"name": "ВЫ", "frags": kills, "deaths": deaths,
			"is_player": true, "color": Color(0.65, 1.0, 0.7),
		}]
		for i in slots.size():
			var slot: Dictionary = slots[i]
			ffa.append({
				"name": String(slot["name"]), "frags": int(slot["frags"]),
				"deaths": int(slot["deaths"]), "is_player": false,
				"color": slot["color"] as Color,
			})
		ffa.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a["frags"]) > int(b["frags"]))
		for i in ffa.size():
			var entry := ffa[i]
			entry["place"] = i + 1
			rows.append(entry)
		return rows

	for t in 2:
		var header := "%s — %d фрагов" % [_team_name(t), int(team_frags[t])]
		if bool(mode["rounds"]):
			header = "%s — %d раундов" % [_team_name(t), int(team_rounds[t])]
		rows.append({"header": header, "color": _team_color(t)})
		var team_rows: Array[Dictionary] = []
		for i in slots.size():
			var slot: Dictionary = slots[i]
			if int(slot["team"]) != t:
				continue
			team_rows.append({
				"name": String(slot["name"]), "frags": int(slot["frags"]),
				"deaths": int(slot["deaths"]), "is_player": false,
				"color": slot["color"] as Color,
			})
		if team == t:
			team_rows.append({
				"name": "ВЫ", "frags": kills, "deaths": deaths,
				"is_player": true, "color": Color(0.65, 1.0, 0.7),
			})
		team_rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			return int(a["frags"]) > int(b["frags"]))
		for i in team_rows.size():
			var entry := team_rows[i]
			entry["place"] = i + 1
			rows.append(entry)
	return rows


# --- Пауза и ввод -------------------------------------------------------------

func _toggle_pause() -> void:
	if state != GameState.PLAYING:
		return
	state = GameState.PAUSED
	player.input_enabled = false
	get_tree().paused = true
	hud.show_pause(true)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _resume_game() -> void:
	if state != GameState.PAUSED:
		return
	state = GameState.PLAYING
	get_tree().paused = false
	hud.show_pause(false)
	if not player_dead:
		player.input_enabled = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("scoreboard") or event.is_action_released("scoreboard"):
		if state == GameState.PLAYING:
			get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause"):
		_toggle_pause()
		return
	if state == GameState.PLAYING and not player_dead and not menu.is_open():
		if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
			if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


# --- Кадр ---------------------------------------------------------------------

func _process(delta: float) -> void:
	if state == GameState.MENU:
		_menu_angle += delta * 0.09
		var radius := maxf(46.0, float(map_data.get("half", 40.0)) * 1.2)
		_menu_camera.position = Vector3(cos(_menu_angle) * radius, radius * 0.6, sin(_menu_angle) * radius)
		_menu_camera.look_at(Vector3(0, 1.5, 0), Vector3.UP)
		return
	if state != GameState.PLAYING:
		return

	match_time += delta

	if freeze_timer > 0.0:
		freeze_timer -= delta
		if freeze_timer <= 0.0:
			_unfreeze()

	if round_over:
		round_end_timer -= delta
		if round_end_timer <= 0.0:
			_start_round()
	elif bool(mode["rounds"]) and freeze_timer <= 0.0:
		round_time_left = maxf(0.0, round_time_left - delta)
		_check_round_end()
		_hunt_timer -= delta
		if _hunt_timer <= 0.0:
			_hunt_timer = 6.0
			_push_bots_to_enemy()

	if bool(mode["respawn"]):
		_maintain_bots(delta)
		if player_dead:
			player_respawn_timer -= delta
			hud.set_death_text(_death_countdown_text())
			if player_respawn_timer <= 0.0:
				_respawn_player()

	if freeze_timer > 0.0 or round_over:
		hud.set_status(_status_text())
		return

	hud.set_scoreboard_visible(Input.is_action_pressed("scoreboard"))
	_hud_timer -= delta
	if _hud_timer <= 0.0:
		_hud_timer = 0.25
		hud.update_scoreboard(_scoreboard_rows(), _board_title())
		hud.set_status(_status_text())
