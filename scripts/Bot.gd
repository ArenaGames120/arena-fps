## Бот-боец: команда, человекоподобная модель, зрение по линии видимости и стрельба.
## Умеет воевать и с игроком, и с другими ботами (в режиме «каждый сам за себя»).
class_name Bot
extends CharacterBody3D

signal died(bot: Node3D, attacker: Node)

const WORLD_MASK := 1
const PLAYER_MASK := 2
const BOT_MASK := 4
const HEAD_MASK := 8
const MOVE_MASK := WORLD_MASK | PLAYER_MASK | BOT_MASK
const AIM_MASK := WORLD_MASK | PLAYER_MASK | BOT_MASK | HEAD_MASK

const GRAVITY := 24.0
const BODY_HEIGHT := Human.BODY_HEIGHT
const BODY_RADIUS := Human.BODY_RADIUS
const HEAD_OFFSET := Human.HEAD_LOCAL.y
const HEAD_RADIUS := Human.HEAD_HITBOX_RADIUS
const EYE_OFFSET := Human.EYE_HEIGHT
const CHEST_OFFSET := 1.15
const VISION_INTERVAL := 0.12
const LAST_SEEN_MEMORY := 4.0
const HEADSHOT_MULTIPLIER := 1.6
# Игрок чуть приоритетнее равного по дистанции бота — бой не должен обходить его стороной.
const PLAYER_TARGET_BIAS := 0.85

const TEAM_CT := 0
const TEAM_T := 1
const CT_PRIMARY := Color(0.3, 0.37, 0.52)
const CT_GEAR := Color(0.15, 0.19, 0.27)
const CT_ACCENT := Color(0.45, 0.72, 1.0)
const T_PRIMARY := Color(0.6, 0.46, 0.26)
const T_GEAR := Color(0.28, 0.22, 0.15)
const T_ACCENT := Color(1.0, 0.62, 0.2)

enum State { HUNT, COMBAT }

var target: Node3D = null
var sfx: Sfx = null
var fx_root: Node3D = null

var bot_name := "Бот"
var bot_color := Color(0.72, 0.16, 0.14)
var slot_index := -1
var team := -1
var patrol_points: Array[Vector3] = []
var patrol_center := Vector3.ZERO
var patrol_radius := 28.0
## Куда бот «давит», когда никого не видит (сторона противника по оси Z).
var push_direction := 0.0

var max_health := 100.0
var health := 100.0
var alive := true
var frozen := false

# Боевые характеристики (усиливаются через set_difficulty()).
var damage := 7.0
var shot_interval := 0.28
var reaction_time := 0.45
var accuracy_deg := 4.6
var preferred_distance := 14.0
var move_speed := 5.6
var max_range := 55.0
var burst_size := 3

var _state: int = State.HUNT
var _lost_sight := 0.0
var _fire_timer := 0.0
var _burst_left := 0
var _reaction_left := 0.0
var _sees_target := false
var _retarget_timer := 0.0
var _vision_timer := 0.0
var _last_seen_timer := 0.0
var _last_seen_position := Vector3.ZERO
var _wander_point := Vector3.ZERO
var _strafe := 1.0
var _strafe_timer := 0.0
var _avoid_dir := Vector3.ZERO
var _avoid_timer := 0.0
var _stuck_check := 0.0
var _last_position := Vector3.ZERO
var _spawn_guard := 1.2
var _hurt_flash := 0.0
var _rng := RandomNumberGenerator.new()

var _visual: Node3D
var _human: Human
var _health_bar: Node3D
var _health_fill: MeshInstance3D
var _name_label: Label3D
var _muzzle: Node3D
var _head_rid := RID()


func _ready() -> void:
	_rng.randomize()
	collision_layer = BOT_MASK
	collision_mask = MOVE_MASK
	floor_max_angle = deg_to_rad(60.0)
	add_to_group("bot")
	_build_body()
	_last_position = global_position
	_wander_point = _random_patrol_point()


## Точки, по которым бот бродит, когда не видит врага.
func setup_combat(sfx_ref: Sfx, fx_ref: Node3D, points: Array, center := Vector3.ZERO,
		radius := 28.0) -> void:
	sfx = sfx_ref
	fx_root = fx_ref
	patrol_points.clear()
	for point in points:
		if point is Vector3:
			patrol_points.append(point as Vector3)
	patrol_center = center
	patrol_radius = radius
	_wander_point = _random_patrol_point()


## Имя, команда и цвет бойца для табло и килл-фида.
func assign_identity(display_name: String, team_id: int, color: Color, helmet: bool, slot := -1) -> void:
	bot_name = display_name
	team = team_id
	bot_color = color
	slot_index = slot
	if _human != null:
		_rebuild_look(color, helmet)
	if _name_label != null:
		_name_label.text = display_name
		_name_label.modulate = color.lightened(0.4)


func _rebuild_look(color: Color, helmet: bool) -> void:
	for child in _visual.get_children():
		child.queue_free()
	_human = Human.new()
	_visual.add_child(_human)
	var gear := CT_GEAR if team == TEAM_CT else T_GEAR
	if team < 0:
		gear = Color(0.18, 0.18, 0.2)
	_human.build(color, gear, color.lightened(0.35), helmet)
	_muzzle = _human.muzzle


## Уровень сложности: 0 — легко, 6+ — жёстко.
func set_difficulty(level: int) -> void:
	var l := clampi(level, 0, 6)
	damage = 7.0 + 1.0 * l
	shot_interval = maxf(0.14, 0.28 - 0.018 * l)
	reaction_time = maxf(0.18, 0.45 - 0.04 * l)
	accuracy_deg = maxf(1.2, 4.6 - 0.5 * l)
	move_speed = 5.6 + 0.35 * l


## Заморозка на время подготовки раунда: бот стоит и не стреляет.
func set_frozen(value: bool) -> void:
	frozen = value
	velocity = Vector3.ZERO
	target = null


## Подготовка к новому раунду: полное здоровье, новая позиция, боеготовность.
func reset_for_round(position: Vector3, yaw: float) -> void:
	global_position = position
	rotation.y = yaw
	velocity = Vector3.ZERO
	health = max_health
	alive = true
	frozen = true
	collision_layer = BOT_MASK
	collision_mask = MOVE_MASK
	set_physics_process(true)
	_state = State.HUNT
	target = null
	_sees_target = false
	_lost_sight = 0.0
	_last_seen_timer = 0.0
	_reaction_left = reaction_time
	_fire_timer = 0.4
	_spawn_guard = 1.0
	_avoid_timer = 0.0
	_stuck_check = 0.0
	_last_position = global_position
	_wander_point = _random_patrol_point()
	if _health_bar != null:
		_health_bar.visible = true
	if _name_label != null:
		_name_label.visible = true
	_restore_look()


func _restore_look() -> void:
	if _human == null:
		return
	for mat in _human.materials:
		mat.albedo_color.a = 1.0
	_visual.rotation_degrees = Vector3.ZERO
	_visual.position = Vector3.ZERO
	_hurt_flash = 0.0


func _build_body() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.height = BODY_HEIGHT
	capsule.radius = BODY_RADIUS
	shape.shape = capsule
	shape.position = Vector3(0, BODY_HEIGHT * 0.5, 0)
	add_child(shape)

	_visual = Node3D.new()
	add_child(_visual)

	_human = Human.new()
	_visual.add_child(_human)
	_human.build(bot_color, Color(0.18, 0.18, 0.2), bot_color.lightened(0.35), team != TEAM_T)
	_muzzle = _human.muzzle

	# Область головы — по ней считается хедшот.
	var head_area := Area3D.new()
	head_area.collision_layer = HEAD_MASK
	head_area.collision_mask = 0
	head_area.monitoring = false
	head_area.monitorable = true
	head_area.set_meta("head", true)
	var head_shape := CollisionShape3D.new()
	var head_sphere := SphereShape3D.new()
	head_sphere.radius = HEAD_RADIUS
	head_shape.shape = head_sphere
	head_area.add_child(head_shape)
	head_area.position = Vector3(0, HEAD_OFFSET, 0)
	add_child(head_area)
	_head_rid = head_area.get_rid()

	_build_health_bar()


func _build_health_bar() -> void:
	_health_bar = Node3D.new()
	_health_bar.position = Vector3(0, 2.16, 0)
	add_child(_health_bar)

	var bg := MeshInstance3D.new()
	var bg_mesh := QuadMesh.new()
	bg_mesh.size = Vector2(0.94, 0.13)
	bg.mesh = bg_mesh
	bg.material_override = Effects._make_material(Color(0.05, 0.05, 0.07), 0.0, 0.75)
	bg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_health_bar.add_child(bg)

	_health_fill = MeshInstance3D.new()
	var fill_mesh := QuadMesh.new()
	fill_mesh.size = Vector2(0.9, 0.09)
	_health_fill.mesh = fill_mesh
	_health_fill.material_override = Effects._make_material(Color(0.3, 0.9, 0.3), 0.6)
	_health_fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_health_fill.position = Vector3(0, 0, 0.01)
	_health_bar.add_child(_health_fill)

	_name_label = Label3D.new()
	_name_label.text = bot_name
	_name_label.font_size = 40
	_name_label.pixel_size = 0.006
	_name_label.outline_size = 10
	_name_label.modulate = bot_color.lightened(0.4)
	_name_label.outline_modulate = Color(0, 0, 0, 0.8)
	_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_name_label.no_depth_test = false
	_name_label.position = Vector3(0, 2.48, 0)
	add_child(_name_label)


# --- Урон ---------------------------------------------------------------------

func take_damage(amount: float, is_head: bool, hit_from := Vector3.ZERO, attacker: Node = null) -> bool:
	if not alive:
		return false
	health -= amount
	_hurt_flash = 0.14
	if health <= 0.0:
		_die(attacker)
		return true
	if _state == State.HUNT and attacker != null and is_instance_valid(attacker):
		# Получил урон — знает, кто стрелял.
		if attacker is Node3D:
			var attacker_3d := attacker as Node3D
			if _is_enemy(attacker_3d):
				target = attacker_3d
				_last_seen_position = attacker_3d.global_position
				_last_seen_timer = LAST_SEEN_MEMORY
		_state = State.COMBAT
		_reaction_left = 0.0
	if is_head and sfx:
		sfx.play_at(fx_root, global_position + Vector3.UP * HEAD_OFFSET, "headshot", -3.0, 40.0)
	return false


## Забыть текущую цель и заново её поискать (например, когда цель погибла).
func lose_target() -> void:
	target = null
	_sees_target = false
	_lost_sight = 0.0
	_last_seen_timer = 0.0
	_retarget_timer = 0.0
	_fire_timer = 0.6
	_reaction_left = reaction_time


## Куда идти, если врага давно не видно: зачистка карты в поисках выживших.
func hunt_to(point: Vector3) -> void:
	if target == null and not _sees_target:
		_wander_point = point
		_last_seen_timer = 0.0


## Полностью выключить бота (бой окончен): он просто стоит на месте.
func idle() -> void:
	target = null
	_state = State.HUNT
	_sees_target = false
	velocity = Vector3.ZERO
	set_physics_process(false)


func _die(attacker: Node) -> void:
	alive = false
	velocity = Vector3.ZERO
	collision_layer = 0
	collision_mask = WORLD_MASK
	set_physics_process(false)
	if sfx:
		sfx.play_at(fx_root, global_position, "die", -2.0, 70.0)
	if _name_label != null:
		_name_label.visible = false
	died.emit(self, attacker)
	_health_bar.visible = false

	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_visual, "rotation_degrees", Vector3(-88.0, 0.0, 0.0), 0.45)
	tween.tween_property(_visual, "position", Vector3(0, -0.35, 0), 0.45)
	var fade_tween := create_tween()
	fade_tween.tween_interval(1.4)
	if _human != null:
		for mat in _human.materials:
			fade_tween.tween_property(mat, "albedo_color:a", 0.0, 0.6)
	fade_tween.tween_callback(queue_free)


# --- Основной цикл ------------------------------------------------------------

func _physics_process(delta: float) -> void:
	_update_hurt_flash(delta)

	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = maxf(velocity.y, -1.0)
	_spawn_guard = maxf(0.0, _spawn_guard - delta)

	if frozen:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		_animate(delta, 0.0)
		_update_health_bar()
		return

	_update_targeting(delta)

	var to_target := Vector3.ZERO
	if target != null and is_instance_valid(target):
		to_target = target.global_position - global_position
		to_target.y = 0.0

	_update_state(delta, to_target.length())

	var desired := Vector3.ZERO
	if _state == State.COMBAT and _sees_target and to_target.length() > 0.01:
		var dist := to_target.length()
		var dir := to_target.normalized()
		if dist > preferred_distance + 2.0:
			desired = dir
		elif dist < preferred_distance - 3.0:
			desired = -dir
		_strafe_timer -= delta
		if _strafe_timer <= 0.0:
			_strafe_timer = _rng.randf_range(0.8, 1.8)
			_strafe = 1.0 if _rng.randf() < 0.5 else -1.0
		desired += dir.rotated(Vector3.UP, PI * 0.5 * _strafe) * 0.55
		if desired.length() > 0.01:
			desired = desired.normalized()
	else:
		desired = _hunt_direction(delta)

	if desired.length() > 0.001:
		desired = _avoid_obstacles(desired, delta)

	var speed := move_speed if _state == State.COMBAT else move_speed * 0.85
	var horizontal := Vector3(desired.x, 0.0, desired.z) * speed
	velocity.x = move_toward(velocity.x, horizontal.x, 40.0 * delta)
	velocity.z = move_toward(velocity.z, horizontal.z, 40.0 * delta)

	move_and_slide()
	_check_stuck(delta)
	_face_and_shoot(delta)
	_animate(delta, Vector2(velocity.x, velocity.z).length())
	_update_health_bar()


func _animate(delta: float, speed: float) -> void:
	if _human != null:
		_human.animate(delta, speed)


func _update_hurt_flash(delta: float) -> void:
	if _hurt_flash <= 0.0:
		return
	_hurt_flash -= delta
	if _human == null:
		return
	var power := 1.0 if _hurt_flash > 0.0 else 0.0
	for i in _human.materials.size():
		var mat := _human.materials[i]
		var base: Color = _human.base_colors[i] if i < _human.base_colors.size() else Color.WHITE
		mat.albedo_color = base.lerp(Color(1.0, 0.95, 0.9, base.a), power)


# --- Взаимодействие команд ----------------------------------------------------

func _team_of(node: Node) -> int:
	if node == null:
		return -1
	var value = node.get("team")
	if value == null:
		return -1
	return int(value)


## Враг ли этот узел. В режиме FFA (team < 0) враги — все, кроме себя.
func _is_enemy(node: Node) -> bool:
	if node == null or node == self:
		return false
	if not (node is Node3D):
		return false
	if not _is_alive(node):
		return false
	var other := _team_of(node)
	if team < 0 or other < 0:
		return true
	return other != team


## Направление движения, когда цели не видно: к последнему месту боя или патруль.
func _hunt_direction(delta: float) -> Vector3:
	var goal := _wander_point
	var use_memory := _last_seen_timer > 0.0
	if use_memory:
		goal = _last_seen_position
	var to_goal := goal - global_position
	to_goal.y = 0.0
	if to_goal.length() < 2.5:
		if use_memory:
			_last_seen_timer = 0.0
		else:
			_wander_point = _random_patrol_point()
		return Vector3.ZERO
	return to_goal.normalized()


## Случайная точка маршрута. В командных режимах боты идут в сторону врага.
func _random_patrol_point() -> Vector3:
	if patrol_points.is_empty():
		return patrol_center + Vector3(
			_rng.randf_range(-patrol_radius, patrol_radius), 0.0,
			_rng.randf_range(-patrol_radius, patrol_radius))
	if absf(push_direction) > 0.01:
		var forward_points: Array[Vector3] = []
		for point in patrol_points:
			if point.z * signf(push_direction) > 0.0:
				forward_points.append(point)
		if not forward_points.is_empty() and _rng.randf() < 0.9:
			return forward_points[_rng.randi_range(0, forward_points.size() - 1)]
	elif patrol_points.size() > 3 and _rng.randf() < 0.75:
		# Свободная схватка: тянемся к центру карты, где обычно кипит бой.
		var best := patrol_points[_rng.randi_range(0, patrol_points.size() - 1)]
		var best_distance := best.distance_to(patrol_center)
		for i in 4:
			var candidate: Vector3 = patrol_points[_rng.randi_range(0, patrol_points.size() - 1)]
			var distance := candidate.distance_to(patrol_center)
			if distance < best_distance:
				best_distance = distance
				best = candidate
		return best
	return patrol_points[_rng.randi_range(0, patrol_points.size() - 1)]


# --- Выбор цели ---------------------------------------------------------------

func _update_targeting(delta: float) -> void:
	_retarget_timer = maxf(0.0, _retarget_timer - delta)
	if target != null and not is_instance_valid(target):
		target = null
	if target != null and (not _is_alive(target) or not _is_enemy(target)):
		target = null
		_sees_target = false
		_last_seen_timer = 0.0

	_vision_timer -= delta
	if _vision_timer <= 0.0:
		_vision_timer = VISION_INTERVAL
		if target != null:
			_sees_target = _has_vision_to(target)
			if _sees_target:
				_last_seen_position = target.global_position
				_last_seen_timer = LAST_SEEN_MEMORY

	if target != null and not _sees_target:
		_last_seen_timer = maxf(0.0, _last_seen_timer - delta)
		if _last_seen_timer <= 0.0:
			target = null

	if target == null and _retarget_timer <= 0.0:
		_retarget_timer = _rng.randf_range(0.25, 0.55)
		_pick_target()


func _pick_target() -> void:
	var best: Node3D = null
	var best_score := INF
	for candidate in _combatants():
		if candidate == self or not _is_alive(candidate) or not _is_enemy(candidate):
			continue
		if not _has_vision_to(candidate):
			continue
		var distance := global_position.distance_to(candidate.global_position)
		if candidate.is_in_group("player"):
			distance *= PLAYER_TARGET_BIAS
		if distance < best_score:
			best_score = distance
			best = candidate
	if best != null:
		target = best
		_last_seen_position = best.global_position
		_last_seen_timer = LAST_SEEN_MEMORY


func _combatants() -> Array[Node3D]:
	var list: Array[Node3D] = []
	for node in get_tree().get_nodes_in_group("player"):
		if node is Node3D:
			list.append(node)
	for node in get_tree().get_nodes_in_group("bot"):
		if node is Node3D and node != self:
			list.append(node)
	return list


func _is_alive(node: Node) -> bool:
	var value = node.get("alive")
	return value == null or bool(value)


func _chest_point(node: Node3D) -> Vector3:
	return node.global_position + Vector3.UP * CHEST_OFFSET


func _has_vision_to(node: Node3D) -> bool:
	if node == null or not is_instance_valid(node) or not _is_alive(node):
		return false
	var eye := global_position + Vector3.UP * EYE_OFFSET
	var aim_point := _chest_point(node)
	var to_enemy := aim_point - eye
	if to_enemy.length() > max_range:
		return false
	var forward := -global_transform.basis.z
	if forward.dot(to_enemy.normalized()) < cos(deg_to_rad(95.0)):
		return false
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(eye, aim_point, WORLD_MASK | PLAYER_MASK | BOT_MASK)
	query.exclude = [get_rid(), _head_rid]
	var result := space.intersect_ray(query)
	if result.is_empty():
		return false
	return result["collider"] == node


func _update_state(delta: float, distance: float) -> void:
	if _state == State.HUNT:
		if _sees_target and distance < max_range:
			_state = State.COMBAT
			_reaction_left = reaction_time
			_burst_left = burst_size
		return
	if _sees_target and distance <= max_range * 1.35:
		_lost_sight = 0.0
		_reaction_left = maxf(0.0, _reaction_left - delta)
		return
	_lost_sight += delta
	if _lost_sight > 4.0:
		_lost_sight = 0.0
		_state = State.HUNT


func _avoid_obstacles(dir: Vector3, delta: float) -> Vector3:
	_avoid_timer -= delta
	if _avoid_timer > 0.0:
		return _avoid_dir
	var origin := global_position + Vector3.UP * 0.95
	if not _is_blocked(origin, dir):
		_avoid_dir = dir
		return dir
	var left := dir.rotated(Vector3.UP, deg_to_rad(58.0))
	var right := dir.rotated(Vector3.UP, deg_to_rad(-58.0))
	var left_free := not _is_blocked(origin, left)
	var right_free := not _is_blocked(origin, right)
	if left_free and right_free:
		_avoid_dir = left if _strafe > 0.0 else right
	elif left_free:
		_avoid_dir = left
	elif right_free:
		_avoid_dir = right
	else:
		_avoid_dir = -dir
		if is_on_floor():
			velocity.y = 6.5
	_avoid_timer = 0.5
	return _avoid_dir


func _is_blocked(origin: Vector3, dir: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * 2.0, WORLD_MASK)
	query.exclude = [get_rid()]
	var result := space.intersect_ray(query)
	if result.is_empty():
		return false
	# Низкий уступ (ящик) не считаем стеной — его можно перепрыгнуть.
	var point: Vector3 = result["position"]
	return (point.y - global_position.y) > 0.75


func _check_stuck(delta: float) -> void:
	_stuck_check += delta
	if _stuck_check < 0.6:
		return
	var moved := global_position.distance_to(_last_position)
	_stuck_check = 0.0
	_last_position = global_position
	if moved < 0.5 and is_on_floor():
		velocity.y = 7.0
		_avoid_timer = 0.0
		_strafe = -_strafe


func _face_and_shoot(delta: float) -> void:
	if target == null or not is_instance_valid(target):
		return
	var flat := target.global_position - global_position
	flat.y = 0.0
	if flat.length() > 0.05:
		var wanted_yaw := atan2(-flat.x, -flat.z)
		rotation.y = lerp_angle(rotation.y, wanted_yaw, 1.0 - exp(-6.0 * delta))

	_fire_timer = maxf(0.0, _fire_timer - delta)
	if _state != State.COMBAT or not _sees_target or _spawn_guard > 0.0:
		return
	if _reaction_left > 0.0 or _fire_timer > 0.0:
		return
	if _burst_left <= 0:
		_burst_left = burst_size
	_fire_timer = shot_interval if _burst_left > 1 else _rng.randf_range(0.55, 1.1)
	_burst_left -= 1
	_shoot()


func _shoot() -> void:
	if target == null or not is_instance_valid(target) or _muzzle == null:
		return
	var from := _muzzle.global_position
	var aim := _chest_point(target) + Vector3(0.0, _rng.randf_range(-0.25, 0.35), 0.0)
	var dir := (aim - from).normalized()
	var spread := deg_to_rad(accuracy_deg + clampf(_target_speed() * 0.22, 0.0, 2.5))
	dir = _spread_dir(dir, spread)

	var to := from + dir * max_range
	var space := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(from, to, AIM_MASK)
	query.exclude = [get_rid(), _head_rid]
	query.collide_with_areas = true
	var result := space.intersect_ray(query)
	var hit_point := to
	var hit_body := false
	if not result.is_empty():
		hit_point = result["position"]
		var collider: Object = result["collider"]
		var victim: Node = null
		var is_head := false
		if collider is Area3D and (collider as Area3D).has_meta("head"):
			is_head = true
			victim = (collider as Node).get_parent()
		elif collider is Node:
			victim = collider as Node
		# Своих не задеваем: дружественный огонь выключен.
		if victim != null and victim != self and _is_enemy(victim) and victim.has_method("take_damage"):
			hit_body = true
			victim.call("take_damage", damage * (HEADSHOT_MULTIPLIER if is_head else 1.0),
					is_head, hit_point, self)

	Effects.tracer(from, hit_point, Color(1.0, 0.55, 0.35), 0.07)
	if fx_root != null:
		Effects.muzzle_flash(_muzzle, Vector3(0, 0, -0.15), Color(1.0, 0.8, 0.4))
	if sfx:
		sfx.play_at(fx_root, from, "bot_shot", -6.0, 90.0)
	Effects.impact(hit_point, Vector3.UP, hit_body)


func _spread_dir(dir: Vector3, spread_rad: float) -> Vector3:
	var basis := Basis(Vector3.UP, _rng.randf_range(-spread_rad, spread_rad))
	var pitched := dir.rotated(Vector3.RIGHT, _rng.randf_range(-spread_rad, spread_rad))
	return (basis * pitched).normalized()


func _target_speed() -> float:
	if target is CharacterBody3D:
		return (target as CharacterBody3D).velocity.length()
	return 0.0


func _update_health_bar() -> void:
	if _health_bar == null:
		return
	var ratio := clampf(health / max_health, 0.0, 1.0)
	_health_fill.visible = ratio < 0.999
	_health_fill.scale.x = maxf(ratio, 0.001)
	_health_fill.position.x = -0.45 + 0.45 * ratio
	var mat := _health_fill.material_override as StandardMaterial3D
	if mat != null:
		mat.albedo_color = Color(1.0 - ratio, 0.9 * ratio, 0.15, 1.0)
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		var flat_cam := Vector3(cam.global_position.x, _health_bar.global_position.y, cam.global_position.z)
		if _health_bar.global_position.distance_to(flat_cam) > 0.2:
			_health_bar.look_at(flat_cam, Vector3.UP)
			_health_bar.rotate_object_local(Vector3.UP, PI)
