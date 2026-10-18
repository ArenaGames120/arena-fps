## Игрок от первого лица: бег, прыжки, присед, три ствола и стрельба.
class_name Player
extends CharacterBody3D

signal hit_confirmed(is_head: bool, killed: bool)
signal damaged(amount: float, from_position: Vector3)
signal health_changed(health: float, max_health: float)
signal weapon_changed(weapon: Dictionary, index: int)
signal ammo_changed(weapon: Dictionary)
signal died(attacker: Node)
signal respawned

const WORLD_MASK := 1
const PLAYER_MASK := 2
const BOT_MASK := 4
const HEAD_MASK := 8
const BULLET_MASK := WORLD_MASK | BOT_MASK | HEAD_MASK

const GRAVITY := 24.0
const WALK_SPEED := 6.2
const SPRINT_SPEED := 9.6
const CROUCH_SPEED := 3.2
const GROUND_ACCEL := 55.0
const AIR_ACCEL := 15.0
const JUMP_VELOCITY := 7.6
const MAX_HEALTH := 100.0
const EYE_HEIGHT := 1.62
const CROUCH_EYE_HEIGHT := 1.05
const SPRINT_FOV_BONUS := 7.0

var sfx: Sfx = null
var weapons: Array[Dictionary] = []
var current_index := 0
var health := MAX_HEALTH
var alive := true
var input_enabled := false
var mouse_sensitivity := 0.0022
var base_fov := 78.0
var invert_y := false
## Команда игрока: 0 — спецназ, 1 — террористы, -1 — каждый сам за себя.
var team := -1
## Дружественный огонь (в свободной схватке он не важен).
var friendly_fire := false
## Был ли последний выстрел игрока в голову (используется для опыта за фраг).
var last_hit_head := false

var kills := 0
var deaths := 0

var _yaw := 0.0
var _pitch := 0.0
var _recoil_pitch := 0.0
var _recoil_yaw := 0.0
var _fire_timer := 0.0
var _reload_timer := 0.0
var _reload_total := 0.0
var _switch_timer := 0.0
var _trigger_down := false
var _aiming := false
var _crouched := false
var _sprinting := false
var _trigger_reset := 0.0
var _bob_time := 0.0
var _bob_offset := 0.0
var _step_distance := 0.0
var _recoil_accum := 0.0
var _last_land_velocity := 0.0
var _rng := RandomNumberGenerator.new()
var _voice: AudioStreamPlayer
var _camera: Camera3D
var _neck: Node3D
var _collision: CollisionShape3D
var _capsule: CapsuleShape3D
var _viewmodel_root: Node3D
var _viewmodel_tilt: Node3D
var _viewmodels := {}
var _muzzle: Node3D = null
var _view_kick := 0.0
var _stamina := 100.0
var _stamina_delay := 0.0
var _neck_height := EYE_HEIGHT


func _ready() -> void:
	_rng.randomize()
	add_to_group("player")
	collision_layer = PLAYER_MASK
	collision_mask = WORLD_MASK | BOT_MASK | PLAYER_MASK
	floor_max_angle = deg_to_rad(55.0)

	_capsule = CapsuleShape3D.new()
	_capsule.height = 1.8
	_capsule.radius = 0.35
	_collision = CollisionShape3D.new()
	_collision.shape = _capsule
	_collision.position = Vector3(0, 0.9, 0)
	add_child(_collision)

	_neck = Node3D.new()
	_neck.position = Vector3(0, EYE_HEIGHT, 0)
	add_child(_neck)

	var settings := Progression.instance()
	mouse_sensitivity = settings.sensitivity
	base_fov = settings.fov
	invert_y = settings.invert_y

	_camera = Camera3D.new()
	_camera.near = 0.05
	_camera.far = 600.0
	_camera.fov = base_fov
	_neck.add_child(_camera)

	_viewmodel_root = Node3D.new()
	_viewmodel_root.position = Vector3(0.16, -0.16, -0.30)
	_camera.add_child(_viewmodel_root)

	# Узел наклона: в прицеливании ствол выравнивается по центру экрана.
	_viewmodel_tilt = Node3D.new()
	_viewmodel_root.add_child(_viewmodel_tilt)

	_voice = AudioStreamPlayer.new()
	_voice.volume_db = -4.0
	add_child(_voice)

	weapons = Weapons.create_loadout()
	_build_viewmodels()
	_select_weapon(0, true)


func setup(sfx_ref: Sfx) -> void:
	sfx = sfx_ref


## Перечитать настройки (чувствительность, FOV, инверсия мыши) из профиля.
func apply_settings() -> void:
	var settings := Progression.instance()
	mouse_sensitivity = settings.sensitivity
	invert_y = settings.invert_y
	base_fov = settings.fov


# --- Оружие и модель в руках -------------------------------------------------

func _build_viewmodels() -> void:
	for weapon in weapons:
		var model := _build_viewmodel(weapon["id"] as String)
		model.visible = false
		_viewmodel_tilt.add_child(model)
		_viewmodels[weapon["id"]] = model


func _build_viewmodel(id: String) -> Node3D:
	var root := Node3D.new()
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.17, 0.17, 0.19)
	metal.roughness = 0.45
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.32, 0.19, 0.09)
	wood.roughness = 0.75
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.09, 0.09, 0.1)
	dark.roughness = 0.6

	var muzzle_offset := Vector3(0, 0.03, -0.95)
	match id:
		"ak47":
			_add_box(root, Vector3(0.07, 0.09, 0.46), Vector3(0, 0, -0.24), wood)
			_add_box(root, Vector3(0.05, 0.05, 0.26), Vector3(0, 0.015, -0.56), metal)
			_add_cylinder(root, 0.017, 0.26, Vector3(0, 0.03, -0.78), metal)
			_add_box(root, Vector3(0.05, 0.18, 0.09), Vector3(0, -0.12, -0.18), dark)
			_add_box(root, Vector3(0.05, 0.10, 0.14), Vector3(0, -0.04, -0.04), wood)
			_add_box(root, Vector3(0.035, 0.045, 0.10), Vector3(0, 0.065, -0.44), dark)
			muzzle_offset = Vector3(0, 0.03, -0.95)
		"deagle":
			_add_box(root, Vector3(0.055, 0.085, 0.26), Vector3(0, 0.005, -0.16), metal)
			_add_cylinder(root, 0.015, 0.18, Vector3(0, 0.015, -0.34), metal)
			_add_box(root, Vector3(0.05, 0.17, 0.10), Vector3(0, -0.12, -0.02), dark)
			_add_box(root, Vector3(0.03, 0.04, 0.08), Vector3(0, 0.05, -0.22), dark)
			muzzle_offset = Vector3(0, 0.015, -0.45)
		"sniper":
			_add_box(root, Vector3(0.055, 0.085, 0.55), Vector3(0, 0, -0.42), metal)
			_add_cylinder(root, 0.019, 0.50, Vector3(0, 0.02, -0.98), metal)
			_add_cylinder(root, 0.032, 0.28, Vector3(0, 0.095, -0.42), dark)
			_add_box(root, Vector3(0.05, 0.17, 0.09), Vector3(0, -0.11, -0.22), dark)
			_add_box(root, Vector3(0.05, 0.11, 0.22), Vector3(0, -0.05, -0.16), dark)
			_add_cylinder(root, 0.011, 0.22, Vector3(0, -0.10, -0.72), metal)
			muzzle_offset = Vector3(0, 0.02, -1.25)

	_muzzle = Node3D.new()
	_muzzle.name = "Muzzle"
	_muzzle.position = muzzle_offset
	root.add_child(_muzzle)
	return root


func _add_box(parent: Node3D, size: Vector3, position: Vector3, mat: Material) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = mat
	mesh.position = position
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)


func _add_cylinder(parent: Node3D, radius: float, height: float, position: Vector3, mat: Material) -> void:
	var mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = height
	cyl.radial_segments = 10
	cyl.rings = 0
	mesh.mesh = cyl
	mesh.material_override = mat
	mesh.position = position
	mesh.rotation_degrees = Vector3(90, 0, 0)
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)


func current_weapon() -> Dictionary:
	return weapons[current_index]


func _select_weapon(index: int, instant := false) -> void:
	if index < 0 or index >= weapons.size():
		return
	if index == current_index and not instant:
		return
	current_index = index
	var weapon := current_weapon()
	for id in _viewmodels.keys():
		(_viewmodels[id] as Node3D).visible = (id == weapon["id"])
	var active_model := _viewmodels.get(weapon["id"]) as Node3D
	if active_model != null:
		_muzzle = active_model.get_node_or_null("Muzzle") as Node3D
	else:
		_muzzle = null
	_reload_timer = 0.0
	_switch_timer = 0.0 if instant else float(weapon["switch_time"])
	_aiming = false
	_recoil_accum = 0.0
	if sfx != null and not instant:
		sfx.play(_voice, "switch", -8.0)
	weapon_changed.emit(weapon, current_index)
	ammo_changed.emit(weapon)


func next_weapon() -> void:
	if not alive:
		return
	_select_weapon((current_index + 1) % weapons.size())


func is_scoped() -> bool:
	return _aiming and bool(current_weapon()["zoom"]) and _switch_timer <= 0.0


func spread_degrees() -> float:
	var weapon := current_weapon()
	var speed := Vector2(velocity.x, velocity.z).length()
	var move_penalty := clampf(speed / SPRINT_SPEED, 0.0, 1.0) * float(weapon["spread_move"])
	var base := float(weapon["spread"]) + move_penalty + _recoil_accum * 0.55
	if not is_on_floor():
		base += 2.5
	if _aiming:
		base *= 0.45
	if _crouched:
		base *= 0.7
	return maxf(base, 0.05)


# --- Ввод --------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if not input_enabled:
		return
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		var motion := event as InputEventMouseMotion
		var sens := mouse_sensitivity
		var weapon := current_weapon()
		if _aiming:
			sens *= float(weapon["zoom_sens"])
		_yaw -= motion.relative.x * sens
		var pitch_delta := -motion.relative.y * sens
		if invert_y:
			pitch_delta = -pitch_delta
		_pitch = clampf(_pitch + pitch_delta, -1.5, 1.45)
	elif event is InputEventMouseButton and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		var button := event as InputEventMouseButton
		if button.pressed:
			if button.button_index == MOUSE_BUTTON_WHEEL_UP:
				next_weapon()
			elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				_select_weapon((current_index - 1 + weapons.size()) % weapons.size())
	elif event.is_action_pressed("weapon_1"):
		_select_weapon(0)
	elif event.is_action_pressed("weapon_2"):
		_select_weapon(1)
	elif event.is_action_pressed("weapon_3"):
		_select_weapon(2)
	elif event.is_action_pressed("weapon_next"):
		next_weapon()
	elif event.is_action_pressed("reload"):
		start_reload()


# --- Физика и движение -------------------------------------------------------

func _physics_process(delta: float) -> void:
	_tick_timers(delta)
	if not alive:
		_update_camera(delta)
		return

	_handle_movement(delta)
	if input_enabled:
		_handle_actions(delta)
	_update_camera(delta)


func _tick_timers(delta: float) -> void:
	_fire_timer = maxf(0.0, _fire_timer - delta)
	_trigger_reset = maxf(0.0, _trigger_reset - delta)
	if _switch_timer > 0.0:
		_switch_timer = maxf(0.0, _switch_timer - delta)
		if _switch_timer == 0.0:
			_trigger_reset = 0.05
	if _reload_timer > 0.0:
		_reload_timer -= delta
		if _reload_timer <= 0.0:
			_finish_reload()
	_recoil_pitch = lerpf(_recoil_pitch, 0.0, 1.0 - exp(-9.0 * delta))
	_recoil_yaw = lerpf(_recoil_yaw, 0.0, 1.0 - exp(-9.0 * delta))
	_recoil_accum = maxf(0.0, _recoil_accum - delta * 2.4)
	_view_kick = lerpf(_view_kick, 0.0, 1.0 - exp(-12.0 * delta))


func _handle_movement(delta: float) -> void:
	var wish := Vector2.ZERO
	if input_enabled:
		wish = Vector2(
			Input.get_axis("move_left", "move_right"),
			Input.get_axis("move_forward", "move_back")
		)
		wish = wish.limit_length(1.0)

	var want_crouch := input_enabled and Input.is_action_pressed("crouch")
	var want_sprint := input_enabled and Input.is_action_pressed("sprint") and wish.y < -0.2 and not want_crouch

	if want_sprint and _stamina <= 0.5:
		want_sprint = false
	_sprinting = want_sprint and _stamina > 0.5
	if _sprinting:
		_stamina = maxf(0.0, _stamina - 17.0 * delta)
		_stamina_delay = 1.1
	else:
		_stamina_delay = maxf(0.0, _stamina_delay - delta)
		if _stamina_delay <= 0.0:
			_stamina = minf(100.0, _stamina + 13.0 * delta)
	_apply_crouch(want_crouch, delta)

	var speed := WALK_SPEED
	if _crouched:
		speed = CROUCH_SPEED
	elif _sprinting:
		speed = SPRINT_SPEED
	if _aiming:
		speed *= 0.55

	var yaw_basis := Basis(Vector3.UP, _yaw)
	var direction := yaw_basis * Vector3(wish.x, 0.0, wish.y)
	if direction.length() > 1.0:
		direction = direction.normalized()

	var accel := GROUND_ACCEL if is_on_floor() else AIR_ACCEL
	var target := direction * speed
	velocity.x = move_toward(velocity.x, target.x, accel * delta)
	velocity.z = move_toward(velocity.z, target.z, accel * delta)

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		if velocity.y < 0.0:
			_last_land_velocity = -velocity.y
		velocity.y = -0.5
		if input_enabled and Input.is_action_just_pressed("jump"):
			_apply_crouch(false, delta)
			velocity.y = JUMP_VELOCITY

	velocity.y = maxf(velocity.y, -70.0)
	move_and_slide()
	_update_footsteps(delta)


func _apply_crouch(want_crouch: bool, delta: float) -> void:
	if _crouched and not want_crouch and _ceiling_blocked():
		want_crouch = true
	_crouched = want_crouch
	var target_height := 1.15 if _crouched else 1.8
	var target_radius := 0.4 if _crouched else 0.35
	_capsule.height = lerpf(_capsule.height, target_height, 1.0 - exp(-14.0 * delta))
	_capsule.radius = lerpf(_capsule.radius, target_radius, 1.0 - exp(-14.0 * delta))
	_collision.position.y = _capsule.height * 0.5


func _ceiling_blocked() -> bool:
	var space := get_world_3d().direct_space_state
	var from := global_position + Vector3.UP * 1.15
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.UP * 0.75, WORLD_MASK)
	query.exclude = [get_rid()]
	return not space.intersect_ray(query).is_empty()


func _update_footsteps(delta: float) -> void:
	if not is_on_floor():
		return
	var speed := Vector2(velocity.x, velocity.z).length()
	if speed < 0.8:
		return
	_step_distance += speed * delta
	if _step_distance < 2.1:
		return
	_step_distance = 0.0
	if sfx != null:
		sfx.play(_voice, "footstep", -16.0 if not _sprinting else -10.0, 0.12)


func _handle_actions(delta: float) -> void:
	_aiming = Input.is_action_pressed("aim") and alive and _reload_timer <= 0.0

	# Перезарядка вручную или автоматически при пустом магазине.
	if Input.is_action_just_pressed("reload"):
		start_reload()

	var weapon := current_weapon()
	var auto := bool(weapon["auto"])
	var pressed := Input.is_action_pressed("fire")
	var wants_fire := false
	if auto:
		wants_fire = pressed
	else:
		wants_fire = pressed and not _trigger_down
	_trigger_down = pressed

	if not wants_fire:
		return
	if _switch_timer > 0.0 or _reload_timer > 0.0 or _fire_timer > 0.0:
		return
	if int(weapon["ammo"]) <= 0:
		if _fire_timer <= 0.0:
			_fire_timer = 0.35
			if sfx != null:
				sfx.play(_voice, "empty", -8.0)
			start_reload()
		return
	_fire()


func start_reload() -> void:
	if not alive:
		return
	var weapon := current_weapon()
	if _reload_timer > 0.0 or _switch_timer > 0.0:
		return
	if int(weapon["ammo"]) >= int(weapon["mag"]):
		return
	if int(weapon["reserve"]) <= 0:
		return
	_reload_timer = float(weapon["reload_time"])
	_reload_total = _reload_timer
	if sfx != null:
		sfx.play(_voice, "reload", -6.0)


func _finish_reload() -> void:
	var weapon := current_weapon()
	var mag := int(weapon["mag"])
	var ammo := int(weapon["ammo"])
	var reserve := int(weapon["reserve"])
	var need := mag - ammo
	var take := mini(need, reserve)
	weapons[current_index]["ammo"] = ammo + take
	weapons[current_index]["reserve"] = reserve - take
	if sfx != null:
		sfx.play(_voice, "reload_done", -8.0)
	ammo_changed.emit(current_weapon())


func _fire() -> void:
	var weapon := current_weapon()
	_fire_timer = 60.0 / float(weapon["rpm"])
	weapons[current_index]["ammo"] = int(weapon["ammo"]) - 1
	weapon = current_weapon()
	ammo_changed.emit(weapon)

	var kick := float(weapon["kick"])
	_recoil_pitch += kick
	_recoil_yaw += _rng.randf_range(-kick, kick) * 0.7
	_recoil_accum = minf(_recoil_accum + float(weapon["recoil"]) * 0.18, 6.0)
	_view_kick = minf(_view_kick + kick * 1.6, 0.09)

	if sfx != null:
		sfx.play(_voice, weapon["sound"] as String, -2.0)
	if _muzzle != null:
		Effects.muzzle_flash(_muzzle, Vector3(0, 0, -0.12), weapon["tracer"] as Color)

	var dir := -_camera.global_transform.basis.z
	var spread := deg_to_rad(spread_degrees())
	dir = dir.rotated(_camera.global_transform.basis.x, _rng.randf_range(-spread, spread))
	dir = dir.rotated(_camera.global_transform.basis.y, _rng.randf_range(-spread, spread))
	dir = dir.normalized()

	var from := _camera.global_position
	var to := from + dir * float(weapon["range"])
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to, BULLET_MASK)
	query.exclude = [get_rid()]
	query.collide_with_areas = true
	var result := space.intersect_ray(query)

	var tracer_from := from
	if _muzzle != null:
		tracer_from = _muzzle.global_position
	var hit_point := to
	if result.is_empty():
		Effects.tracer(tracer_from, hit_point, weapon["tracer"] as Color)
		return
	hit_point = result["position"]
	Effects.tracer(tracer_from, hit_point, weapon["tracer"] as Color)
	_resolve_hit(result["collider"] as Object, result["position"] as Vector3, result["normal"] as Vector3, weapon)


func _resolve_hit(collider: Object, point: Vector3, normal: Vector3, weapon: Dictionary) -> void:
	var is_head := false
	var victim := collider
	if collider is Area3D and (collider as Area3D).has_meta("head"):
		is_head = true
		victim = (collider as Node).get_parent()
	if victim == null or not victim.has_method("take_damage"):
		Effects.impact(point, normal, false)
		return
	if not _is_enemy(victim):
		Effects.impact(point, normal, true)
		return
	var damage := float(weapon["damage"]) * (float(weapon["head_mult"]) if is_head else 1.0)
	last_hit_head = is_head
	var killed: bool = bool(victim.call("take_damage", damage, is_head, point, self))
	Effects.impact(point, normal, true)
	if sfx != null:
		sfx.play(_voice, "headshot" if is_head else "hit", -6.0)
	hit_confirmed.emit(is_head, killed)
	if killed and sfx != null:
		sfx.play(_voice, "kill", -4.0)


# --- Состояние игрока --------------------------------------------------------

## Враг ли это (своих в командных режимах не задеваем).
func _is_enemy(node: Node) -> bool:
	if node == null or not (node is Node3D):
		return false
	if friendly_fire:
		return true
	var other = node.get("team")
	if other == null:
		return true
	if team < 0 or int(other) < 0:
		return true
	return int(other) != team


func take_damage(amount: float, is_head: bool, from_position: Vector3, attacker: Node = null) -> bool:
	if not alive:
		return false
	health = maxf(0.0, health - amount)
	damaged.emit(amount, from_position)
	health_changed.emit(health, MAX_HEALTH)
	if sfx != null:
		sfx.play(_voice, "hurt", -7.0)
	if health <= 0.0:
		_die(attacker)
		return true
	return false


func _die(attacker: Node = null) -> void:
	if not alive:
		return
	alive = false
	input_enabled = false
	_aiming = false
	velocity = Vector3.ZERO
	_reset_combat_state()
	died.emit(attacker)


func _reset_combat_state() -> void:
	_trigger_down = false
	_reload_timer = 0.0
	_switch_timer = 0.0
	_fire_timer = 0.0


func respawn_position(position: Vector3, yaw := 0.0) -> void:
	global_position = position
	velocity = Vector3.ZERO
	health = MAX_HEALTH
	alive = true
	_yaw = yaw
	_pitch = 0.0
	_recoil_pitch = 0.0
	_recoil_yaw = 0.0
	_recoil_accum = 0.0
	_stamina = 100.0
	_reset_combat_state()
	_crouched = false
	_apply_crouch(false, 1.0)
	_neck_height = EYE_HEIGHT
	_select_weapon(current_index, true)
	health_changed.emit(health, MAX_HEALTH)
	respawned.emit()


func heal(amount: float) -> bool:
	if not alive or health >= MAX_HEALTH:
		return false
	health = minf(MAX_HEALTH, health + amount)
	health_changed.emit(health, MAX_HEALTH)
	return true


func give_ammo() -> bool:
	var changed := false
	for i in weapons.size():
		var weapon := weapons[i]
		if int(weapon["reserve"]) < int(weapon["reserve_max"]):
			weapons[i]["reserve"] = int(weapon["reserve_max"])
			changed = true
	if changed:
		ammo_changed.emit(current_weapon())
	return changed


func stamina_ratio() -> float:
	return _stamina / 100.0


## Включить/выключить камеру игрока (используется меню и паузой).
func set_camera_current(value: bool) -> void:
	_camera.current = value


func reload_ratio() -> float:
	if _reload_timer <= 0.0 or _reload_total <= 0.0:
		return -1.0
	return 1.0 - _reload_timer / _reload_total


# --- Камера -----------------------------------------------------------------

func _update_camera(delta: float) -> void:
	rotation.y = _yaw
	var target_neck_y := CROUCH_EYE_HEIGHT if _crouched else EYE_HEIGHT
	_neck_height = lerpf(_neck_height, target_neck_y, 1.0 - exp(-12.0 * delta))
	_neck.rotation.x = _pitch + _recoil_pitch
	_neck.rotation.y = _recoil_yaw

	var speed := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and speed > 0.5:
		_bob_time += delta * (6.0 + speed * 1.35)
		var amp := clampf(speed / SPRINT_SPEED, 0.0, 1.0) * 0.032
		_bob_offset = sin(_bob_time * 2.0) * amp
	else:
		_bob_offset = lerpf(_bob_offset, 0.0, 1.0 - exp(-8.0 * delta))
	_neck.position.y = _neck_height + _bob_offset

	var strafe := Input.get_axis("move_left", "move_right") if input_enabled else 0.0
	_neck.rotation.z = lerpf(_neck.rotation.z, -strafe * 0.014, 1.0 - exp(-8.0 * delta))

	var weapon := current_weapon()
	var target_fov := base_fov
	if _aiming and _switch_timer <= 0.0:
		target_fov = float(weapon["zoom_fov"])
	elif _sprinting:
		target_fov = base_fov + SPRINT_FOV_BONUS
	_camera.fov = lerpf(_camera.fov, target_fov, 1.0 - exp(-9.0 * delta))

	# Положение модели оружия: бег, прицеливание, отдача перезарядки.
	var aiming_now := _aiming and _switch_timer <= 0.0
	var base_pos := Vector3(0.16, -0.16, -0.30)
	var aim_pos := Vector3(0.0, -0.075, -0.20)
	var target_pos := aim_pos if aiming_now else base_pos
	if _sprinting and not _aiming:
		target_pos += Vector3(0.0, -0.03, 0.03)
	if _reload_timer > 0.0:
		var progress := 1.0 - _reload_timer / maxf(_reload_total, 0.01)
		var dip := sin(progress * PI)
		target_pos += Vector3(0.02, -0.17, 0.05) * dip
	var sway := clampf(speed / SPRINT_SPEED, 0.0, 1.0)
	target_pos.y += sin(_bob_time * 2.0) * 0.012 * sway
	_viewmodel_root.position = _viewmodel_root.position.lerp(target_pos, 1.0 - exp(-11.0 * delta))

	var tilt := 0.0 if aiming_now else 1.0
	var tilt_k := 1.0 - exp(-10.0 * delta)
	_viewmodel_tilt.rotation.x = lerpf(_viewmodel_tilt.rotation.x, deg_to_rad(1.5 * tilt), tilt_k)
	_viewmodel_tilt.rotation.y = lerpf(_viewmodel_tilt.rotation.y, deg_to_rad(-3.0 * tilt), tilt_k)

	var kick_target := Vector3(_recoil_pitch * -1.4, 0.0, _view_kick * 2.0)
	_viewmodel_root.rotation.x = lerpf(_viewmodel_root.rotation.x, kick_target.x, 1.0 - exp(-16.0 * delta))
	_viewmodel_root.rotation.z = lerpf(_viewmodel_root.rotation.z, kick_target.z, 1.0 - exp(-16.0 * delta))

	var hide := is_scoped()
	_viewmodel_root.visible = not hide and alive
