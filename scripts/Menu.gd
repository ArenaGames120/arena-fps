## Главное меню: ИГРАТЬ, НАСТРОЙКИ, ВЫХОД, выбор режима, карты и команды.
class_name Menu
extends CanvasLayer

signal play_requested(config: Dictionary)
signal quit_requested
signal settings_changed
signal closed

enum Screen { MAIN, MODES, MAPS, TEAM, SETTINGS }

var selected_mode := "tdm"
var selected_map := "dust2"

var _root: Control
var _screens := {}
var _screen_stack: Array[int] = []
var _from_pause := false
var _open := false

var _card_level: Label
var _card_bar: ProgressBar
var _card_xp: Label
var _card_stats: Label
var _team_sub: Label
var _modes_box: VBoxContainer
var _maps_box: VBoxContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 5
	_build()


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.visible = false
	add_child(_root)

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.03, 0.06, 0.62)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(dim)

	_build_main()
	_build_modes()
	_build_maps()
	_build_team()
	_build_settings()
	_show_screen(Screen.MAIN)
	refresh()


# --- Экраны -------------------------------------------------------------------

func _add_screen(name: int, width: float) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -width * 0.5
	panel.offset_right = width * 0.5
	panel.offset_top = -330
	panel.offset_bottom = 330
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.05, 0.09, 0.93)
	style.set_corner_radius_all(10)
	style.set_border_width_all(1)
	style.border_color = Color(0.35, 0.42, 0.55, 0.5)
	style.content_margin_left = 30
	style.content_margin_right = 30
	style.content_margin_top = 22
	style.content_margin_bottom = 22
	panel.add_theme_stylebox_override("panel", style)
	_root.add_child(panel)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 8)
	panel.add_child(column)
	_screens[name] = {"panel": panel, "box": column}
	return column


func _build_main() -> void:
	var box := _add_screen(Screen.MAIN, 720.0)
	box.add_child(_label("ARENA FPS", 54, Color(1, 0.95, 0.85), HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(_label("de_dust2 · de_mirage · три ствола · боты и режимы CS",
			19, Color(0.8, 0.86, 1.0, 0.85), HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(_spacer(14))

	_card_level = _label("", 26, Color(1.0, 0.9, 0.6), HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_card_level)
	_card_bar = ProgressBar.new()
	_card_bar.custom_minimum_size = Vector2(520, 16)
	_card_bar.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_card_bar.max_value = 1.0
	_card_bar.show_percentage = false
	_card_bar.add_theme_stylebox_override("background", _style(Color(0, 0, 0, 0.5)))
	_card_bar.add_theme_stylebox_override("fill", _style(Color(0.95, 0.78, 0.28)))
	box.add_child(_card_bar)
	_card_xp = _label("", 17, Color(1, 1, 1, 0.8), HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_card_xp)
	_card_stats = _label("", 17, Color(0.85, 0.9, 1.0, 0.8), HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_card_stats)
	box.add_child(_spacer(18))

	_button(box, "ИГРАТЬ", func() -> void: _open_modes(), 340)
	_button(box, "НАСТРОЙКИ", func() -> void: _open_screen(Screen.SETTINGS))
	_button(box, "ВЫХОД ИЗ ИГРЫ", func() -> void: quit_requested.emit())
	box.add_child(_spacer(12))
	box.add_child(_label("WASD — движение · SHIFT — бег · SPACE — прыжок · CTRL — присед",
			15, Color(0.8, 0.85, 0.95, 0.7), HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(_label("ЛКМ — огонь · ПКМ — прицел · 1/2/3 — оружие · R — перезарядка · TAB — табло · ESC — пауза",
			15, Color(0.8, 0.85, 0.95, 0.7), HORIZONTAL_ALIGNMENT_CENTER))


func _build_modes() -> void:
	var box := _add_screen(Screen.MODES, 720.0)
	box.add_child(_label("ВЫБОР РЕЖИМА", 38, Color(1, 0.95, 0.85), HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(_spacer(10))
	_modes_box = VBoxContainer.new()
	_modes_box.add_theme_constant_override("separation", 6)
	box.add_child(_modes_box)
	box.add_child(_spacer(14))
	_button(box, "НАЗАД", func() -> void: _show_screen(Screen.MAIN))


func _build_maps() -> void:
	var box := _add_screen(Screen.MAPS, 720.0)
	box.add_child(_label("ВЫБОР КАРТЫ", 38, Color(1, 0.95, 0.85), HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(_spacer(10))
	_maps_box = VBoxContainer.new()
	_maps_box.add_theme_constant_override("separation", 6)
	box.add_child(_maps_box)
	box.add_child(_spacer(14))
	_button(box, "НАЗАД", func() -> void: _open_modes())


func _build_team() -> void:
	var box := _add_screen(Screen.TEAM, 660.0)
	box.add_child(_label("ВАША КОМАНДА", 38, Color(1, 0.95, 0.85), HORIZONTAL_ALIGNMENT_CENTER))
	_team_sub = _label("", 19, Color(0.85, 0.9, 1.0, 0.85), HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_team_sub)
	box.add_child(_spacer(14))
	_button(box, "СПЕЦНАЗ (CT)", func() -> void: _start(0), 360)
	_button(box, "ТЕРРОРИСТЫ (T)", func() -> void: _start(1), 360)
	_button(box, "СЛУЧАЙНАЯ КОМАНДА", func() -> void: _start(randi() % 2), 360)
	box.add_child(_spacer(12))
	_button(box, "НАЗАД", func() -> void: _open_maps())


func _build_settings() -> void:
	var box := _add_screen(Screen.SETTINGS, 760.0)
	box.add_child(_label("НАСТРОЙКИ", 38, Color(1, 0.95, 0.85), HORIZONTAL_ALIGNMENT_CENTER))
	box.add_child(_spacer(8))

	var settings := Progression.instance()

	_add_slider(box, "Чувствительность мыши", 0.0006, 0.006, 0.0001, settings.sensitivity,
		func(v: float) -> String: return "%.4f" % v, _set_sensitivity)
	_add_slider(box, "Угол обзора (FOV)", 70.0, 115.0, 1.0, settings.fov,
		func(v: float) -> String: return "%d°" % int(v), _set_fov)
	_add_slider(box, "Громкость", 0.0, 1.0, 0.05, settings.volume,
		func(v: float) -> String: return "%d%%" % int(round(v * 100.0)), _set_volume)

	var difficulty := OptionButton.new()
	difficulty.add_item("Легко")
	difficulty.add_item("Обычно")
	difficulty.add_item("Сложно")
	difficulty.selected = clampi(settings.bot_skill, 0, 2)
	difficulty.item_selected.connect(_set_bot_skill)
	box.add_child(_row("Сложность ботов", difficulty))

	var invert := CheckButton.new()
	invert.button_pressed = settings.invert_y
	invert.toggled.connect(_set_invert)
	box.add_child(_row("Инверсия мыши", invert))

	var fullscreen := CheckButton.new()
	fullscreen.button_pressed = settings.fullscreen
	fullscreen.toggled.connect(_set_fullscreen)
	box.add_child(_row("Полный экран", fullscreen))

	box.add_child(_spacer(14))
	_button(box, "СБРОСИТЬ", _reset_settings)
	_button(box, "НАЗАД", func() -> void: _back())


func _rebuild_settings() -> void:
	var screen: Dictionary = _screens.get(Screen.SETTINGS, {})
	_screens.erase(Screen.SETTINGS)
	if screen.has("panel"):
		(screen["panel"] as Node).queue_free()
	_build_settings()
	_show_screen(Screen.SETTINGS)


func _set_sensitivity(value: float) -> void:
	Progression.instance().sensitivity = value
	_apply_settings()


func _set_fov(value: float) -> void:
	Progression.instance().fov = value
	_apply_settings()


func _set_volume(value: float) -> void:
	Progression.instance().volume = value
	_apply_settings()


func _set_bot_skill(index: int) -> void:
	Progression.instance().bot_skill = index
	_apply_settings()


func _set_invert(value: bool) -> void:
	Progression.instance().invert_y = value
	_apply_settings()


func _set_fullscreen(value: bool) -> void:
	Progression.instance().fullscreen = value
	_apply_settings()


func _reset_settings() -> void:
	var settings := Progression.instance()
	settings.sensitivity = 0.0022
	settings.fov = 78.0
	settings.volume = 0.8
	settings.invert_y = false
	settings.fullscreen = false
	settings.bot_skill = 1
	_apply_settings()
	_rebuild_settings()


# --- Виджеты ------------------------------------------------------------------

func _label(text: String, font_size: int, color: Color, align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = align
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _button(box: VBoxContainer, text: String, callback: Callable, width := 300) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(width, 46)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", 22)
	button.pressed.connect(callback)
	box.add_child(button)
	return button


func _spacer(height: int) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer


func _row(title: String, control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var label := _label(title, 19, Color(0.9, 0.93, 1.0, 0.9))
	label.custom_minimum_size = Vector2(320, 0)
	row.add_child(label)
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(control)
	return row


func _add_slider(box: VBoxContainer, title: String, min_value: float, max_value: float,
		step: float, value: float, formatter: Callable, on_change: Callable) -> void:
	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.value = value
	slider.custom_minimum_size = Vector2(340, 26)
	var value_label := _label(String(formatter.call(value)), 18, Color(1.0, 0.9, 0.6),
			HORIZONTAL_ALIGNMENT_RIGHT)
	value_label.custom_minimum_size = Vector2(90, 0)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var label := _label(title, 19, Color(0.9, 0.93, 1.0, 0.9))
	label.custom_minimum_size = Vector2(320, 0)
	row.add_child(label)
	row.add_child(slider)
	row.add_child(value_label)
	box.add_child(row)

	slider.value_changed.connect(func(v: float) -> void:
		value_label.text = String(formatter.call(v))
		on_change.call(v))


func _style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(3)
	return style


# --- Логика экранов -----------------------------------------------------------

func _show_screen(screen: int) -> void:
	for key in _screens.keys():
		(_screens[key]["panel"] as Control).visible = (int(key) == screen)


func _open_screen(screen: int) -> void:
	_screen_stack.append(screen)
	_show_screen(screen)


func _back() -> void:
	if _screen_stack.size() > 1:
		_screen_stack.pop_back()
		_show_screen(_screen_stack[_screen_stack.size() - 1])
	else:
		if _from_pause:
			close()
		else:
			_show_screen(Screen.MAIN)


func _open_modes() -> void:
	_screen_stack = [Screen.MODES]
	_refresh_modes()
	_show_screen(Screen.MODES)


func _open_maps() -> void:
	_screen_stack = [Screen.MAPS]
	_refresh_maps()
	_show_screen(Screen.MAPS)


func _refresh_modes() -> void:
	for child in _modes_box.get_children():
		child.queue_free()
	for data in Modes.all():
		var id := String(data["id"])
		var marker := "▶ " if id == selected_mode else "     "
		_button(_modes_box, marker + String(data["name"]), _mode_pressed.bind(id), 620)
		_modes_box.add_child(_label(String(data["desc"]), 16,
				Color(0.82, 0.87, 0.98, 0.75), HORIZONTAL_ALIGNMENT_CENTER))


func _mode_pressed(id: String) -> void:
	selected_mode = id
	_open_maps()


func _refresh_maps() -> void:
	for child in _maps_box.get_children():
		child.queue_free()
	for id in Levels.ORDER:
		var map_id := String(id)
		var info: Dictionary = Levels.MAPS[map_id]
		var marker := "▶ " if map_id == selected_map else "     "
		_button(_maps_box, marker + String(info["name"]), _map_pressed.bind(map_id), 620)
		_maps_box.add_child(_label(String(info["desc"]), 16,
				Color(0.82, 0.87, 0.98, 0.75), HORIZONTAL_ALIGNMENT_CENTER))


func _map_pressed(id: String) -> void:
	selected_map = id
	_open_team()


func _open_team() -> void:
	var mode := Modes.get_data(selected_mode)
	if not bool(mode["teams"]):
		_start(-1)
		return
	_team_sub.text = "%s · %s" % [String(mode["name"]), String(Levels.MAPS[selected_map]["name"])]
	_screen_stack = [Screen.TEAM]
	_show_screen(Screen.TEAM)


func _start(team: int) -> void:
	play_requested.emit({"mode": selected_mode, "map": selected_map, "team": team})


func _apply_settings() -> void:
	var settings := Progression.instance()
	settings.save()
	settings.apply_display()
	AudioServer.set_bus_volume_db(0, linear_to_db(clampf(settings.volume, 0.001, 1.0)))
	settings_changed.emit()


# --- Открытие и закрытие ------------------------------------------------------

func refresh() -> void:
	var settings := Progression.instance()
	_card_level.text = "УРОВЕНЬ %d · %s" % [settings.level, settings.rank_name()]
	_card_bar.value = settings.xp_ratio()
	_card_xp.text = "%d / %d опыта" % [settings.xp, settings.xp_to_next()]
	_card_stats.text = "Убийств: %d · В голову: %d (%s) · Матчей: %d · Побед: %d · K/D: %.2f" % [
		settings.kills, settings.headshots, settings.accuracy_text(),
		settings.matches, settings.wins, settings.kd_ratio()]


func open() -> void:
	_from_pause = false
	_screen_stack = [Screen.MAIN]
	_show_screen(Screen.MAIN)
	_root.visible = true
	_open = true
	refresh()


func open_settings(from_pause := true) -> void:
	_from_pause = from_pause
	_screen_stack = [Screen.SETTINGS]
	_show_screen(Screen.SETTINGS)
	_root.visible = true
	_open = true
	refresh()


func close() -> void:
	_root.visible = false
	_open = false
	closed.emit()


func is_open() -> bool:
	return _open


func _unhandled_input(event: InputEvent) -> void:
	if not _open:
		return
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_back()
