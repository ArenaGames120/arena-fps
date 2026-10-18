## Интерфейс боя: прицел, здоровье, патроны, счёт матча, табло, меню паузы и финал.
class_name HUD
extends CanvasLayer

signal resume_requested
signal restart_requested
signal menu_requested
signal settings_requested
signal quit_requested

enum UIState { PLAYING, PAUSED, DEAD, GAME_OVER }

const VIGNETTE_SHADER := """
shader_type canvas_item;
uniform vec4 tint : source_color = vec4(0.6, 0.0, 0.0, 1.0);
uniform float inner = 0.25;
uniform float outer = 0.75;
uniform float strength = 0.0;
uniform float aspect = 1.7777;
void fragment() {
	vec2 p = (UV - vec2(0.5)) * vec2(aspect, 1.0);
	float d = length(p);
	float edge = smoothstep(inner, outer, d);
	COLOR = vec4(tint.rgb, tint.a * edge * strength);
}
"""

const BOARD_MAX_ROWS := 12

var state: int = UIState.PLAYING
var kills := 0
var deaths := 0
var bots_alive := 0

var _player: Player = null
var _crosshair: Control
var _hitmarker_time := 0.0
var _hitmarker_head := false
var _spread_px := 6.0
var _scope_rect: ColorRect
var _scope_mat: ShaderMaterial
var _vignette: ColorRect
var _vignette_mat: ShaderMaterial
var _damage_flash := 0.0
var _hurt_strength := 0.0

var _health_bar: ProgressBar
var _health_label: Label
var _stamina_bar: ProgressBar
var _ammo_label: Label
var _weapon_label: Label
var _weapon_slots: Array[Label] = []
var _slots_box: HBoxContainer
var _status_label: Label
var _reload_bar: ProgressBar
var _center_hint: Label
var _feed: VBoxContainer
var _feed_items: Array = []

# Опыт и уровень
var _xp_label: Label
var _xp_bar: ProgressBar

# Объявления (раунд, победитель раунда)
var _announce_box: VBoxContainer
var _announce_title: Label
var _announce_sub: Label
var _announce_timer := 0.0

var _pause_screen: Control
var _death_screen: Control
var _death_label: Label
var _game_over_screen: Control
var _game_over_label: Label
var _game_over_sub: Label
var _xp_summary: Label
var _result_box: VBoxContainer
var _scope_visible := false
var _ui_visible := true

# Табло (TAB)
var _board: Control
var _board_title: Label
var _board_rows: Array = []
var _last_killer := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 1
	_build_crosshair()
	_build_scope()
	_build_vignette()
	_build_status()
	_build_health()
	_build_weapon_panel()
	_build_xp_panel()
	_build_feed()
	_build_announce()
	_build_scoreboard()
	_build_pause_screen()
	_build_death_screen()
	_build_game_over_screen()


func bind_player(player: Player) -> void:
	_player = player
	_player.hit_confirmed.connect(_on_hit_confirmed)
	_player.damaged.connect(_on_damaged)
	_player.health_changed.connect(_on_health_changed)
	_player.ammo_changed.connect(_on_ammo_changed)
	_player.weapon_changed.connect(_on_weapon_changed)
	_player.died.connect(_on_player_died)
	_player.respawned.connect(_on_player_respawned)
	_on_health_changed(_player.health, Player.MAX_HEALTH)
	_on_weapon_changed(_player.current_weapon(), _player.current_index)


# --- Построение интерфейса ---------------------------------------------------

func _build_crosshair() -> void:
	_crosshair = Control.new()
	_crosshair.set_anchors_preset(Control.PRESET_FULL_RECT)
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crosshair.draw.connect(_draw_crosshair)
	add_child(_crosshair)


func _build_scope() -> void:
	_scope_rect = ColorRect.new()
	_scope_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scope_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_scope_rect.visible = false
	var shader := Shader.new()
	shader.code = VIGNETTE_SHADER
	_scope_mat = ShaderMaterial.new()
	_scope_mat.shader = shader
	_scope_mat.set_shader_parameter("tint", Color(0.0, 0.0, 0.0, 1.0))
	_scope_mat.set_shader_parameter("inner", 0.79)
	_scope_mat.set_shader_parameter("outer", 0.84)
	_scope_mat.set_shader_parameter("strength", 1.0)
	_scope_rect.material = _scope_mat
	add_child(_scope_rect)


func _build_vignette() -> void:
	_vignette = ColorRect.new()
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := Shader.new()
	shader.code = VIGNETTE_SHADER
	_vignette_mat = ShaderMaterial.new()
	_vignette_mat.shader = shader
	_vignette_mat.set_shader_parameter("tint", Color(0.75, 0.05, 0.05, 1.0))
	_vignette_mat.set_shader_parameter("inner", 0.45)
	_vignette_mat.set_shader_parameter("outer", 1.25)
	_vignette_mat.set_shader_parameter("strength", 0.0)
	_vignette.material = _vignette_mat
	add_child(_vignette)


func _build_status() -> void:
	_status_label = _make_label("", 22, Color(1, 1, 1, 0.95), HORIZONTAL_ALIGNMENT_CENTER)
	_status_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_status_label.anchor_left = 0.0
	_status_label.anchor_right = 1.0
	_status_label.offset_top = 14
	_status_label.offset_bottom = 48
	add_child(_status_label)

	_center_hint = _make_label("", 18, Color(1, 0.9, 0.6, 0.9), HORIZONTAL_ALIGNMENT_CENTER)
	_center_hint.set_anchors_preset(Control.PRESET_CENTER)
	_center_hint.anchor_left = 0.0
	_center_hint.anchor_right = 1.0
	_center_hint.offset_top = 60
	_center_hint.offset_bottom = 92
	add_child(_center_hint)


func _build_health() -> void:
	_health_bar = ProgressBar.new()
	_health_bar.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_health_bar.offset_left = 26
	_health_bar.offset_top = -96
	_health_bar.offset_right = 286
	_health_bar.offset_bottom = -68
	_health_bar.max_value = 100.0
	_health_bar.value = 100.0
	_health_bar.show_percentage = false
	_health_bar.add_theme_stylebox_override("background", _style(Color(0, 0, 0, 0.45)))
	_health_bar.add_theme_stylebox_override("fill", _style(Color(0.85, 0.22, 0.22)))
	add_child(_health_bar)

	_health_label = _make_label("100", 20, Color(1, 1, 1, 0.95), HORIZONTAL_ALIGNMENT_LEFT)
	_health_label.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_health_label.offset_left = 28
	_health_label.offset_top = -128
	_health_label.offset_right = 288
	_health_label.offset_bottom = -100
	_health_label.text = "ЗДОРОВЬЕ · 100"
	add_child(_health_label)

	_stamina_bar = ProgressBar.new()
	_stamina_bar.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_stamina_bar.offset_left = 26
	_stamina_bar.offset_top = -58
	_stamina_bar.offset_right = 286
	_stamina_bar.offset_bottom = -46
	_stamina_bar.max_value = 100.0
	_stamina_bar.value = 100.0
	_stamina_bar.show_percentage = false
	_stamina_bar.add_theme_stylebox_override("background", _style(Color(0, 0, 0, 0.4)))
	_stamina_bar.add_theme_stylebox_override("fill", _style(Color(0.35, 0.75, 1.0, 0.9)))
	add_child(_stamina_bar)


func _build_weapon_panel() -> void:
	_weapon_label = _make_label("АК-47", 22, Color(1, 1, 1, 0.95), HORIZONTAL_ALIGNMENT_RIGHT)
	_weapon_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_weapon_label.offset_left = -420
	_weapon_label.offset_top = -140
	_weapon_label.offset_right = -26
	_weapon_label.offset_bottom = -110
	add_child(_weapon_label)

	_ammo_label = _make_label("30 / 210", 46, Color(1, 1, 1, 0.96), HORIZONTAL_ALIGNMENT_RIGHT)
	_ammo_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_ammo_label.offset_left = -420
	_ammo_label.offset_top = -108
	_ammo_label.offset_right = -26
	_ammo_label.offset_bottom = -44
	add_child(_ammo_label)

	var slots := HBoxContainer.new()
	_slots_box = slots
	slots.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	slots.offset_left = -300
	slots.offset_top = -40
	slots.offset_right = -26
	slots.offset_bottom = -12
	slots.alignment = BoxContainer.ALIGNMENT_END
	slots.add_theme_constant_override("separation", 16)
	add_child(slots)
	for i in 3:
		var label := _make_label("", 18, Color(1, 1, 1, 0.5), HORIZONTAL_ALIGNMENT_RIGHT)
		slots.add_child(label)
		_weapon_slots.append(label)

	_reload_bar = ProgressBar.new()
	_reload_bar.set_anchors_preset(Control.PRESET_CENTER)
	_reload_bar.anchor_left = 0.5
	_reload_bar.anchor_right = 0.5
	_reload_bar.offset_left = -90
	_reload_bar.offset_right = 90
	_reload_bar.offset_top = 44
	_reload_bar.offset_bottom = 58
	_reload_bar.max_value = 1.0
	_reload_bar.value = 0.0
	_reload_bar.show_percentage = false
	_reload_bar.visible = false
	_reload_bar.add_theme_stylebox_override("background", _style(Color(0, 0, 0, 0.5)))
	_reload_bar.add_theme_stylebox_override("fill", _style(Color(1.0, 0.8, 0.3)))
	add_child(_reload_bar)


## Уровень и полоса опыта — слева сверху, чтобы было видно прогресс в бою.
func _build_xp_panel() -> void:
	_xp_label = _make_label("", 16, Color(1.0, 0.92, 0.7, 0.9), HORIZONTAL_ALIGNMENT_LEFT)
	_xp_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_xp_label.offset_left = 26
	_xp_label.offset_top = 16
	_xp_label.offset_right = 386
	_xp_label.offset_bottom = 40
	add_child(_xp_label)

	_xp_bar = ProgressBar.new()
	_xp_bar.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_xp_bar.offset_left = 26
	_xp_bar.offset_top = 42
	_xp_bar.offset_right = 286
	_xp_bar.offset_bottom = 54
	_xp_bar.max_value = 1.0
	_xp_bar.value = 0.0
	_xp_bar.show_percentage = false
	_xp_bar.add_theme_stylebox_override("background", _style(Color(0, 0, 0, 0.45)))
	_xp_bar.add_theme_stylebox_override("fill", _style(Color(0.95, 0.78, 0.28, 0.95)))
	add_child(_xp_bar)


func _build_feed() -> void:
	_feed = VBoxContainer.new()
	_feed.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_feed.anchor_left = 1.0
	_feed.offset_left = -420
	_feed.offset_top = 60
	_feed.offset_right = -26
	_feed.offset_bottom = 260
	_feed.alignment = BoxContainer.ALIGNMENT_BEGIN
	_feed.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_feed)


## Большой текст по центру: «РАУНД 2», «РАУНД ВЫИГРАН» и т. п.
func _build_announce() -> void:
	_announce_box = VBoxContainer.new()
	_announce_box.set_anchors_preset(Control.PRESET_CENTER)
	_announce_box.anchor_left = 0.5
	_announce_box.anchor_right = 0.5
	_announce_box.anchor_top = 0.5
	_announce_box.anchor_bottom = 0.5
	_announce_box.offset_left = -420
	_announce_box.offset_right = 420
	_announce_box.offset_top = -160
	_announce_box.offset_bottom = -60
	_announce_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_announce_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_announce_box.visible = false
	add_child(_announce_box)

	_announce_title = _make_label("", 44, Color(1, 0.95, 0.8, 1.0), HORIZONTAL_ALIGNMENT_CENTER)
	_announce_box.add_child(_announce_title)
	_announce_sub = _make_label("", 22, Color(0.9, 0.95, 1.0, 0.9), HORIZONTAL_ALIGNMENT_CENTER)
	_announce_box.add_child(_announce_sub)


func _build_scoreboard() -> void:
	_board = Control.new()
	_board.set_anchors_preset(Control.PRESET_FULL_RECT)
	_board.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_board.visible = false
	add_child(_board)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.offset_left = -320
	panel.offset_right = 320
	panel.offset_top = 70
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := _style(Color(0.03, 0.04, 0.07, 0.85))
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	_board.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(column)

	_board_title = _make_label("ТАБЛО", 20, Color(1.0, 0.9, 0.6, 0.95), HORIZONTAL_ALIGNMENT_CENTER)
	column.add_child(_board_title)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(header)
	var header_color := Color(0.72, 0.78, 0.9, 0.8)
	header.add_child(_board_cell("БОЕЦ", header_color, 230, HORIZONTAL_ALIGNMENT_LEFT))
	header.add_child(_board_cell("ФРАГИ", header_color, 110, HORIZONTAL_ALIGNMENT_RIGHT))
	header.add_child(_board_cell("СМЕРТИ", header_color, 110, HORIZONTAL_ALIGNMENT_RIGHT))

	for i in BOARD_MAX_ROWS:
		var section := _make_label("", 19, Color(0.8, 0.86, 1.0, 0.9), HORIZONTAL_ALIGNMENT_LEFT)
		section.visible = false
		column.add_child(section)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 14)
		row.visible = false
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(row)
		var name_cell := _board_cell("", Color.WHITE, 230, HORIZONTAL_ALIGNMENT_LEFT)
		var frags_cell := _board_cell("", Color.WHITE, 110, HORIZONTAL_ALIGNMENT_RIGHT)
		var deaths_cell := _board_cell("", Color.WHITE, 110, HORIZONTAL_ALIGNMENT_RIGHT)
		row.add_child(name_cell)
		row.add_child(frags_cell)
		row.add_child(deaths_cell)
		_board_rows.append({
			"row": row, "name": name_cell, "frags": frags_cell,
			"deaths": deaths_cell, "section": section,
		})


func _board_cell(text: String, color: Color, width: int, align: int) -> Label:
	var label := _make_label(text, 20, color, align)
	label.custom_minimum_size = Vector2(width, 0)
	return label


func _build_pause_screen() -> void:
	_pause_screen = _build_overlay_panel("ПАУЗА", "", [], 460.0)
	_pause_screen.visible = false
	add_child(_pause_screen)
	_add_button_to(_pause_screen, "ПРОДОЛЖИТЬ", func() -> void: resume_requested.emit())
	_add_button_to(_pause_screen, "НАСТРОЙКИ", func() -> void: settings_requested.emit())
	_add_button_to(_pause_screen, "ГЛАВНОЕ МЕНЮ", func() -> void: menu_requested.emit())
	_add_button_to(_pause_screen, "ВЫХОД ИЗ ИГРЫ", func() -> void: quit_requested.emit())


func _build_death_screen() -> void:
	_death_screen = _build_overlay_panel("ВЫ ПОГИБЛИ", "", [], 420.0)
	_death_label = _death_screen.get_node("Box/Title") as Label
	var box := _death_screen.get_node("Box") as VBoxContainer
	var hint := _make_label("TAB — табло боя", 18, Color(0.85, 0.9, 1.0, 0.7), HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(hint)
	_death_screen.visible = false
	add_child(_death_screen)


func _build_game_over_screen() -> void:
	_game_over_screen = _build_overlay_panel("МАТЧ ОКОНЧЕН", "", [], 560.0)
	_game_over_label = _game_over_screen.get_node("Box/Title") as Label
	_game_over_sub = _game_over_screen.get_node("Box/Sub") as Label
	var box := _game_over_screen.get_node("Box") as VBoxContainer
	_result_box = VBoxContainer.new()
	_result_box.name = "Results"
	_result_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_result_box.add_theme_constant_override("separation", 4)
	_result_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_result_box)
	_xp_summary = _make_label("", 20, Color(0.95, 0.85, 0.5, 0.95), HORIZONTAL_ALIGNMENT_CENTER)
	box.add_child(_xp_summary)
	_game_over_screen.visible = false
	add_child(_game_over_screen)
	_add_button_to(_game_over_screen, "ИГРАТЬ СНОВА", func() -> void: restart_requested.emit())
	_add_button_to(_game_over_screen, "ГЛАВНОЕ МЕНЮ", func() -> void: menu_requested.emit())
	_add_button_to(_game_over_screen, "ВЫХОД ИЗ ИГРЫ", func() -> void: quit_requested.emit())


func _build_overlay_panel(title: String, subtitle: String, lines: Array, width: float) -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.02, 0.03, 0.05, 0.72)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)

	var box := VBoxContainer.new()
	box.name = "Box"
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.anchor_left = 0.5
	box.anchor_right = 0.5
	box.anchor_top = 0.5
	box.anchor_bottom = 0.5
	box.offset_left = -width * 0.5
	box.offset_right = width * 0.5
	box.offset_top = -300
	box.offset_bottom = 300
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(box)

	var title_label := _make_label(title, 46, Color(1, 1, 1, 0.98), HORIZONTAL_ALIGNMENT_CENTER)
	title_label.name = "Title"
	title_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(title_label)

	var sub := _make_label(subtitle, 22, Color(0.85, 0.9, 1.0, 0.8), HORIZONTAL_ALIGNMENT_CENTER)
	sub.name = "Sub"
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(sub)

	if not lines.is_empty():
		box.add_child(_make_spacer(12))
		for line in lines:
			var l := _make_label(line as String, 18, Color(0.9, 0.93, 1.0, 0.85), HORIZONTAL_ALIGNMENT_CENTER)
			l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			box.add_child(l)

	box.add_child(_make_spacer(18))
	return root


func _make_spacer(height: int) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return spacer


func _add_button_to(screen: Control, text: String, callback: Callable) -> void:
	var box := screen.get_node("Box") as VBoxContainer
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(300, 46)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	button.add_theme_font_size_override("font_size", 22)
	button.pressed.connect(callback)
	box.add_child(button)


func _make_label(text: String, font_size: int, color: Color, align: int) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = align
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("outline_size", 5)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(3)
	return style


# --- Реакция на события ------------------------------------------------------

func _on_hit_confirmed(is_head: bool, killed: bool) -> void:
	_hitmarker_time = 0.28 if not killed else 0.42
	_hitmarker_head = is_head


func _on_damaged(_amount: float, _from: Vector3) -> void:
	_damage_flash = minf(1.0, _damage_flash + 0.75)


func _on_health_changed(health: float, max_health: float) -> void:
	var ratio := health / maxf(max_health, 1.0)
	_health_bar.value = ratio * 100.0
	_health_label.text = "ЗДОРОВЬЕ · %d" % int(round(health))
	var fill := _health_bar.get_theme_stylebox("fill") as StyleBoxFlat
	fill.bg_color = Color(0.9 - 0.5 * ratio, 0.15 + 0.65 * ratio, 0.2, 1.0)


func _on_ammo_changed(weapon: Dictionary) -> void:
	_weapon_label.text = weapon["name"] as String
	_ammo_label.text = "%d / %d" % [int(weapon["ammo"]), int(weapon["reserve"])]
	_ammo_label.add_theme_color_override("font_color", weapon["hud_color"] as Color)
	_refresh_slots()


func _on_weapon_changed(weapon: Dictionary, index: int) -> void:
	_on_ammo_changed(weapon)
	for i in _weapon_slots.size():
		if i == index:
			_weapon_slots[i].add_theme_color_override("font_color", Color(1, 1, 1, 1))
		else:
			_weapon_slots[i].add_theme_color_override("font_color", Color(1, 1, 1, 0.45))


func _refresh_slots() -> void:
	if _player == null:
		return
	for i in _player.weapons.size():
		if i >= _weapon_slots.size():
			break
		var weapon := _player.weapons[i]
		_weapon_slots[i].text = "%d %s" % [i + 1, weapon["short_name"] as String]


func _on_player_died(_attacker: Node) -> void:
	state = UIState.DEAD
	_death_label.text = "ВЫ ПОГИБЛИ"
	_death_screen.visible = true


func _on_player_respawned() -> void:
	_death_screen.visible = false
	state = UIState.PLAYING
	_center_hint.text = ""


func add_kill_feed(text: String, color: Color) -> void:
	var label := _make_label(text, 18, color, HORIZONTAL_ALIGNMENT_RIGHT)
	_feed.add_child(label)
	_feed_items.append({"node": label, "time": 4.5})
	while _feed_items.size() > 5:
		var oldest: Dictionary = _feed_items.pop_front()
		(oldest["node"] as Label).queue_free()


func add_xp_popup(amount: int, is_headshot := false) -> void:
	if amount <= 0:
		return
	var color := Color(1.0, 0.88, 0.35) if not is_headshot else Color(1.0, 0.65, 0.9)
	_spawn_popup("+%d ОПЫТ" % amount, color)


## Баннер по центру: раунд, победитель раунда, смена сторон.
func announce(title: String, subtitle := "", duration := 2.2) -> void:
	_announce_title.text = title
	_announce_sub.text = subtitle
	_announce_box.visible = true
	_announce_box.modulate.a = 1.0
	_announce_timer = duration


func show_level_up(level: int, rank: String) -> void:
	announce("УРОВЕНЬ %d" % level, "Новое звание: %s" % rank, 3.0)


func _spawn_popup(text: String, color: Color) -> void:
	var label := _make_label(text, 24, color, HORIZONTAL_ALIGNMENT_CENTER)
	label.set_anchors_preset(Control.PRESET_CENTER)
	label.anchor_left = 0.5
	label.anchor_right = 0.5
	label.anchor_top = 0.5
	label.anchor_bottom = 0.5
	label.offset_left = -180
	label.offset_right = 180
	label.offset_top = 60
	label.offset_bottom = 96
	add_child(label)
	var tween := label.create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "offset_top", -20.0, 1.0)
	tween.tween_property(label, "offset_bottom", 16.0, 1.0)
	tween.chain().tween_callback(label.queue_free)


func show_center_hint(text: String) -> void:
	_center_hint.text = text


func set_scope_visible(value: bool) -> void:
	if _scope_visible == value:
		return
	_scope_visible = value
	_scope_rect.visible = value


## Строка состояния сверху: режим, карта, счёт и таймер.
func set_status(text: String) -> void:
	_status_label.text = text


## Панель опыта слева сверху.
func set_xp_info(level: int, rank: String, ratio: float, xp: int, needed: int) -> void:
	_xp_label.text = "УРОВЕНЬ %d · %s · %d/%d ОП" % [level, rank, xp, needed]
	_xp_bar.value = clampf(ratio, 0.0, 1.0)


## Показать/скрыть весь боевой интерфейс (в главном меню он не нужен).
func set_ui_visible(value: bool) -> void:
	_ui_visible = value
	for node in [_crosshair, _scope_rect, _health_bar, _health_label, _stamina_bar,
			_weapon_label, _ammo_label, _xp_label, _xp_bar, _status_label,
			_center_hint, _feed, _slots_box]:
		if node != null and is_instance_valid(node):
			(node as CanvasItem).visible = value
	if not value:
		_reload_bar.visible = false
		_announce_box.visible = false
		set_scoreboard_visible(false)


## Показать интерфейс боя (после старта матча).
func set_playing() -> void:
	state = UIState.PLAYING
	_pause_screen.visible = false
	_death_screen.visible = false
	_game_over_screen.visible = false
	_center_hint.text = ""
	_announce_box.visible = false


func show_pause(show_it: bool) -> void:
	_pause_screen.visible = show_it
	if show_it:
		state = UIState.PAUSED
	elif state == UIState.PAUSED:
		state = UIState.DEAD if (_player != null and not _player.alive) else UIState.PLAYING


func set_death_text(text: String) -> void:
	_death_label.text = text


func show_death(show_it: bool) -> void:
	_death_screen.visible = show_it


## Финал матча: заголовок, подпись, итоговая таблица и строка опыта.
func show_match_end(title: String, subtitle: String, rows: Array, xp_line := "") -> void:
	state = UIState.GAME_OVER
	_death_screen.visible = false
	_pause_screen.visible = false
	set_scoreboard_visible(false)
	_announce_box.visible = false
	_game_over_screen.visible = true
	_game_over_label.text = title
	if _game_over_sub != null:
		_game_over_sub.text = subtitle
	if _xp_summary != null:
		_xp_summary.text = xp_line
	if _result_box != null:
		for child in _result_box.get_children():
			child.queue_free()
		for i in mini(rows.size(), BOARD_MAX_ROWS + 4):
			var entry: Dictionary = rows[i]
			if entry.has("header"):
				_result_box.add_child(_make_label(String(entry["header"]), 19,
						Color(0.8, 0.86, 1.0, 0.85), HORIZONTAL_ALIGNMENT_CENTER))
				continue
			var color := entry["color"] as Color
			if bool(entry.get("is_player", false)):
				color = Color(0.65, 1.0, 0.7)
			var line := "%s — %d фрагов, %d смертей" % [
				String(entry["name"]), int(entry["frags"]), int(entry["deaths"])]
			_result_box.add_child(_make_label(line, 19, color, HORIZONTAL_ALIGNMENT_CENTER))


## Табло боя: строки уже отсортированы. Строка-раздел имеет ключ "header".
func update_scoreboard(rows: Array, title := "ТАБЛО") -> void:
	_board_title.text = title
	for i in _board_rows.size():
		var cells: Dictionary = _board_rows[i]
		var row := cells["row"] as HBoxContainer
		var section := cells["section"] as Label
		if i >= rows.size():
			row.visible = false
			section.visible = false
			continue
		var entry: Dictionary = rows[i]
		if entry.has("header"):
			row.visible = false
			section.visible = true
			section.text = String(entry["header"])
			section.add_theme_color_override("font_color", entry.get("color", Color(0.8, 0.86, 1.0, 0.9)))
			continue
		section.visible = false
		var color := entry["color"] as Color
		if bool(entry.get("is_player", false)):
			color = Color(0.65, 1.0, 0.7)
		row.visible = true
		var name_cell := cells["name"] as Label
		var frags_cell := cells["frags"] as Label
		var deaths_cell := cells["deaths"] as Label
		name_cell.text = "%d. %s" % [int(entry.get("place", i + 1)), String(entry["name"])]
		name_cell.add_theme_color_override("font_color", color)
		frags_cell.text = str(int(entry["frags"]))
		frags_cell.add_theme_color_override("font_color", color)
		deaths_cell.text = str(int(entry["deaths"]))
		deaths_cell.add_theme_color_override("font_color", Color(color.r, color.g, color.b, 0.7))


func set_scoreboard_visible(value: bool) -> void:
	if _board != null:
		_board.visible = value


func set_last_killer(killer: String) -> void:
	_last_killer = killer


func last_killer() -> String:
	return _last_killer


# --- Кадровые обновления -----------------------------------------------------

func _process(delta: float) -> void:
	var playing := (state == UIState.PLAYING or state == UIState.DEAD) and _ui_visible
	if _player != null and is_instance_valid(_player):
		_stamina_bar.value = _player.stamina_ratio() * 100.0
		var reload_ratio := _player.reload_ratio()
		_reload_bar.visible = reload_ratio >= 0.0 and _ui_visible
		if reload_ratio >= 0.0:
			_reload_bar.value = reload_ratio
		_spread_px = 5.0 + _player.spread_degrees() * 2.6
		set_scope_visible(_player.is_scoped())

	if _announce_timer > 0.0:
		_announce_timer -= delta
		if _announce_timer <= 0.8:
			_announce_box.modulate.a = clampf(_announce_timer / 0.8, 0.0, 1.0)
		if _announce_timer <= 0.0:
			_announce_box.visible = false

	_damage_flash = maxf(0.0, _damage_flash - delta * 1.9)
	var low_health := 0.0
	if _player != null and is_instance_valid(_player) and _player.alive:
		low_health = clampf(1.0 - _player.health / 45.0, 0.0, 1.0)
		var pulse := 0.75 + 0.25 * sin(Time.get_ticks_msec() * 0.004)
		low_health *= pulse
	_hurt_strength = maxf(_damage_flash * 0.85, low_health * 0.55)
	_vignette_mat.set_shader_parameter("strength", _hurt_strength)

	_hitmarker_time = maxf(0.0, _hitmarker_time - delta)
	_crosshair.visible = playing
	_crosshair.queue_redraw()

	var viewport_size := get_viewport().get_visible_rect().size
	var aspect := viewport_size.x / maxf(viewport_size.y, 1.0)
	_scope_mat.set_shader_parameter("aspect", aspect)
	_vignette_mat.set_shader_parameter("aspect", aspect)

	for i in range(_feed_items.size() - 1, -1, -1):
		var item: Dictionary = _feed_items[i]
		item["time"] = float(item["time"]) - delta
		var node := item["node"] as Label
		if not is_instance_valid(node):
			_feed_items.remove_at(i)
			continue
		if float(item["time"]) < 1.0:
			node.modulate.a = clampf(float(item["time"]), 0.0, 1.0)
		if float(item["time"]) <= 0.0:
			node.queue_free()
			_feed_items.remove_at(i)


func _draw_crosshair() -> void:
	var center := _crosshair.size * 0.5
	if _scope_visible:
		_draw_scope_reticle(center)
		_draw_hitmarker(center)
		return

	var color := Color(0.95, 1.0, 0.95, 0.9)
	var gap := _spread_px
	var length := 9.0
	var thickness := 1.6
	for i in 4:
		var direction := [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN][i] as Vector2
		_crosshair.draw_line(center + direction * gap, center + direction * (gap + length), color, thickness)
	_crosshair.draw_circle(center, 1.4, color)
	_draw_hitmarker(center)


## Сетка снайперского прицела: тонкий крест с делениями и центральной точкой.
func _draw_scope_reticle(center: Vector2) -> void:
	var ink := Color(0.02, 0.02, 0.02, 0.95)
	var reach := minf(center.x, center.y) * 0.98
	_crosshair.draw_line(center - Vector2(reach, 0), center + Vector2(reach, 0), ink, 1.0)
	_crosshair.draw_line(center - Vector2(0, reach), center + Vector2(0, reach), ink, 1.0)
	for i in range(1, 7):
		var step := float(i) * 42.0
		var tick := 9.0 if i % 2 == 0 else 5.0
		if step > reach - 10.0:
			break
		_crosshair.draw_line(center + Vector2(step, -tick), center + Vector2(step, tick), ink, 1.0)
		_crosshair.draw_line(center + Vector2(-step, -tick), center + Vector2(-step, tick), ink, 1.0)
		_crosshair.draw_line(center + Vector2(-tick, step), center + Vector2(tick, step), ink, 1.0)
		_crosshair.draw_line(center + Vector2(-tick, -step), center + Vector2(tick, -step), ink, 1.0)
	_crosshair.draw_circle(center, 1.6, ink)


func _draw_hitmarker(center: Vector2) -> void:
	if _hitmarker_time <= 0.0:
		return
	var alpha := clampf(_hitmarker_time / 0.28, 0.0, 1.0)
	var hit_color := Color(1.0, 0.35, 0.25, alpha) if not _hitmarker_head else Color(1.0, 0.85, 0.2, alpha)
	var offset := 6.0
	var reach := 13.0
	for corner in [Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]:
		var c := corner as Vector2
		_crosshair.draw_line(center + c * offset, center + c * reach, hit_color, 2.4)
