## Опыт, уровни и настройки игрока. Всё сохраняется в user://save.cfg
class_name Progression
extends RefCounted

const SAVE_PATH := "user://save.cfg"

const RANKS := [
	"Новичок", "Новичок", "Любитель", "Любитель", "Боец", "Боец", "Боец",
	"Ветеран", "Ветеран", "Ветеран", "Элита", "Элита", "Элита", "Элита",
	"Легенда", "Легенда", "Легенда", "Легенда", "Легенда", "Легенда",
]

# Прогресс
var level := 1
var xp := 0
var kills := 0
var headshots := 0
var deaths := 0
var matches := 0
var wins := 0
var rounds_won := 0
var best_streak := 0

# Настройки (применяются к игроку, звуку и картинке)
var sensitivity := 0.0022
var fov := 78.0
var volume := 0.8
var invert_y := false
var fullscreen := false
var bot_skill := 1          # 0 — легко, 1 — обычно, 2 — сложно
var show_fps := false
var crosshair_scale := 1.0

static var _instance: Progression = null


static func instance() -> Progression:
	if _instance == null:
		_instance = Progression.new()
		_instance.load()
	return _instance


## Сколько опыта нужно для перехода на следующий уровень.
func xp_to_next() -> int:
	return 150 + 100 * (level - 1)


func rank_name() -> String:
	return RANKS[clampi(level - 1, 0, RANKS.size() - 1)]


func xp_ratio() -> float:
	return clampf(float(xp) / float(maxi(xp_to_next(), 1)), 0.0, 1.0)


## Начисляет опыт, возвращает число полученных уровней (0, если не вырос).
func add_xp(amount: int) -> int:
	if amount <= 0:
		return 0
	xp += amount
	var gained := 0
	while xp >= xp_to_next():
		xp -= xp_to_next()
		level += 1
		gained += 1
	save()
	return gained


func register_kill(is_headshot: bool) -> void:
	kills += 1
	if is_headshot:
		headshots += 1
	save()


func register_death() -> void:
	deaths += 1
	save()


func register_match(won: bool) -> void:
	matches += 1
	if won:
		wins += 1
	save()


func register_round(won: bool) -> void:
	if won:
		rounds_won += 1
	save()


func kd_ratio() -> float:
	return float(kills) / float(maxi(deaths, 1))


func accuracy_text() -> String:
	return "%.0f%%" % (100.0 * float(headshots) / float(maxi(kills, 1)))


# --- Сохранение ---------------------------------------------------------------

func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "level", level)
	cfg.set_value("progress", "xp", xp)
	cfg.set_value("progress", "kills", kills)
	cfg.set_value("progress", "headshots", headshots)
	cfg.set_value("progress", "deaths", deaths)
	cfg.set_value("progress", "matches", matches)
	cfg.set_value("progress", "wins", wins)
	cfg.set_value("progress", "rounds_won", rounds_won)
	cfg.set_value("progress", "best_streak", best_streak)
	cfg.set_value("settings", "sensitivity", sensitivity)
	cfg.set_value("settings", "fov", fov)
	cfg.set_value("settings", "volume", volume)
	cfg.set_value("settings", "invert_y", invert_y)
	cfg.set_value("settings", "fullscreen", fullscreen)
	cfg.set_value("settings", "bot_skill", bot_skill)
	cfg.set_value("settings", "show_fps", show_fps)
	cfg.set_value("settings", "crosshair_scale", crosshair_scale)
	cfg.save(SAVE_PATH)


func load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return
	level = int(cfg.get_value("progress", "level", level))
	xp = int(cfg.get_value("progress", "xp", xp))
	kills = int(cfg.get_value("progress", "kills", kills))
	headshots = int(cfg.get_value("progress", "headshots", headshots))
	deaths = int(cfg.get_value("progress", "deaths", deaths))
	matches = int(cfg.get_value("progress", "matches", matches))
	wins = int(cfg.get_value("progress", "wins", wins))
	rounds_won = int(cfg.get_value("progress", "rounds_won", rounds_won))
	best_streak = int(cfg.get_value("progress", "best_streak", best_streak))
	sensitivity = float(cfg.get_value("settings", "sensitivity", sensitivity))
	fov = float(cfg.get_value("settings", "fov", fov))
	volume = float(cfg.get_value("settings", "volume", volume))
	invert_y = bool(cfg.get_value("settings", "invert_y", invert_y))
	fullscreen = bool(cfg.get_value("settings", "fullscreen", fullscreen))
	bot_skill = int(cfg.get_value("settings", "bot_skill", bot_skill))
	show_fps = bool(cfg.get_value("settings", "show_fps", show_fps))
	crosshair_scale = float(cfg.get_value("settings", "crosshair_scale", crosshair_scale))
	level = maxi(level, 1)


func apply_display() -> void:
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)


## Сложность ботов с учётом выбранного уровня в настройках.
func bot_skill_bonus() -> int:
	return bot_skill - 1
