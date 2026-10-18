## Карты: de_dust2, de_mirage и тренировочная арена.
## Вся геометрия собирается кодом из примитивов; подписи — callout'ы как в CS.
class_name Levels
extends RefCounted

const WORLD_MASK := 1

const MAPS := {
	"dust2": {
		"name": "de_dust2",
		"desc": "Две точки, лонг, мид, кот и туннели.",
	},
	"mirage": {
		"name": "de_mirage",
		"desc": "Дворец, аппартаменты, окно в миде и коннектор.",
	},
	"arena": {
		"name": "Арена",
		"desc": "Небольшая тренировочная площадка с ящиками.",
	},
}

const ORDER := ["dust2", "mirage", "arena"]

const FLOOR_SAND := Color(0.62, 0.55, 0.42)
const WALL_SAND := Color(0.75, 0.68, 0.54)
const WALL_SAND2 := Color(0.68, 0.6, 0.47)
const TRIM := Color(0.5, 0.43, 0.32)
const CRATE := Color(0.48, 0.35, 0.2)
const CRATE2 := Color(0.38, 0.42, 0.28)
const STEEL := Color(0.46, 0.47, 0.5)
const CONCRETE := Color(0.58, 0.57, 0.55)
const ROOF := Color(0.42, 0.36, 0.3)
const LABEL_COLOR := Color(1.0, 0.92, 0.6)


## Собирает карту в root и возвращает данные: спавны команд, патрули, аптечки.
static func build(id: String, root: Node3D) -> Dictionary:
	var data := {
		"id": id,
		"half": 40.0,
		"team_spawns": {0: [], 1: []},
		"patrol": [],
		"health": [],
		"ammo": [],
	}
	match id:
		"mirage":
			data = _build_mirage(root)
		"arena":
			data = _build_arena(root)
		_:
			data = _build_dust2(root)
	_add_lighting(root, float(data["half"]))
	return data


# --- Общие помощники ----------------------------------------------------------

static func _box(root: Node3D, size: Vector3, pos: Vector3, color: Color,
		rot := Vector3.ZERO, node_name := "") -> StaticBody3D:
	var body := StaticBody3D.new()
	if node_name != "":
		body.name = node_name
	body.collision_layer = WORLD_MASK
	body.collision_mask = 0
	body.position = pos
	body.rotation_degrees = rot

	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.add_child(shape)

	var mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh.mesh = box_mesh
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.9
	mesh.material_override = material
	body.add_child(mesh)

	root.add_child(body)
	return body


## Стена между двумя точками в плоскости XZ.
static func _wall(root: Node3D, from: Vector2, to: Vector2, height: float,
		thickness: float, color: Color) -> StaticBody3D:
	var delta := to - from
	var length := delta.length()
	if length < 0.05:
		return null
	var mid := (from + to) * 0.5
	var angle := rad_to_deg(atan2(delta.y, delta.x))
	return _box(root, Vector3(length, height, thickness),
			Vector3(mid.x, height * 0.5, mid.y), color, Vector3(0.0, -angle, 0.0), "Стена")


## Каждый элемент списка: [x, z, высота, размер].
static func _crates(root: Node3D, list: Array, color: Color, node_name := "Укрытие") -> void:
	for item in list:
		var x := float(item[0])
		var z := float(item[1])
		var h := float(item[2])
		var s := float(item[3]) if item.size() > 3 else 2.0
		_box(root, Vector3(s, h, s), Vector3(x, h * 0.5, z), color, Vector3.ZERO, node_name)


## Подпись-ориентир (как callout'ы в CS).
static func _label(root: Node3D, text: String, pos: Vector3, color := LABEL_COLOR, size := 1.8) -> void:
	var label := Label3D.new()
	label.text = text
	label.font_size = 64
	label.pixel_size = 0.01 * size
	label.outline_size = 16
	label.modulate = color
	label.outline_modulate = Color(0.05, 0.04, 0.02, 0.9)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = false
	label.position = pos
	root.add_child(label)


static func _add_lighting(root: Node3D, half: float) -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, 38.0, 0.0)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = maxf(140.0, half * 3.0)
	root.add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-25.0, -140.0, 0.0)
	fill.light_energy = 0.3
	fill.shadow_enabled = false
	root.add_child(fill)


static func _spawn_row(x0: float, z0: float, dx: float, dz: float, count: int) -> Array[Vector3]:
	var list: Array[Vector3] = []
	for i in count:
		list.append(Vector3(x0 + dx * float(i), 0.3, z0 + dz * float(i)))
	return list


# --- de_dust2 -----------------------------------------------------------------

static func _build_dust2(root: Node3D) -> Dictionary:
	var half := 42.0
	_box(root, Vector3(half * 2.0, 1.0, half * 2.0), Vector3(0, -0.5, 0), FLOOR_SAND,
			Vector3.ZERO, "Пол")

	# Периметр карты.
	_wall(root, Vector2(-half, -half), Vector2(half, -half), 8.0, 1.0, WALL_SAND)
	_wall(root, Vector2(-half, half), Vector2(half, half), 8.0, 1.0, WALL_SAND)
	_wall(root, Vector2(-half, -half), Vector2(-half, half), 8.0, 1.0, WALL_SAND)
	_wall(root, Vector2(half, -half), Vector2(half, half), 8.0, 1.0, WALL_SAND)

	# --- Мид и разделители (z = -14 — линия между «нижней» и «верхней» частью)
	# Западная стена мида, с проходом из верхних туннелей (z 2..8).
	_wall(root, Vector2(-6, -14), Vector2(-6, 2), 6.0, 0.8, WALL_SAND2)
	_wall(root, Vector2(-6, 8), Vector2(-6, 23), 6.0, 0.8, WALL_SAND2)
	# Восточная стена мида, с выходом на кот (z -10..-4).
	_wall(root, Vector2(6, -14), Vector2(6, -10), 6.0, 0.8, WALL_SAND2)
	_wall(root, Vector2(6, -4), Vector2(6, 23), 6.0, 0.8, WALL_SAND2)
	# Туннели на западе: коридор x -42..-24 с выходом в мид (z 2..8).
	_wall(root, Vector2(-24, -14), Vector2(-24, 2), 6.0, 0.8, WALL_SAND2)
	_wall(root, Vector2(-24, 8), Vector2(-24, 20), 6.0, 0.8, WALL_SAND2)
	# Стена лонга с длинными дверями (z 12..16).
	_wall(root, Vector2(20, -14), Vector2(20, 12), 6.0, 0.8, WALL_SAND2)
	_wall(root, Vector2(20, 16), Vector2(20, 24), 6.0, 0.8, WALL_SAND2)
	_wall(root, Vector2(20, 24), Vector2(half, 24), 6.0, 0.8, WALL_SAND2)

	# Северный разделитель z = -14: проходы — туннели→B, мид→CT, шорт→A, лонг→A.
	_wall(root, Vector2(-half, -14), Vector2(-38, -14), 7.0, 0.8, WALL_SAND)
	_wall(root, Vector2(-24, -14), Vector2(-6, -14), 7.0, 0.8, WALL_SAND)
	_wall(root, Vector2(6, -14), Vector2(8, -14), 7.0, 0.8, WALL_SAND)
	_wall(root, Vector2(15, -14), Vector2(20, -14), 7.0, 0.8, WALL_SAND)
	_wall(root, Vector2(34, -14), Vector2(half, -14), 7.0, 0.8, WALL_SAND)

	# CT-спавн (x -10..10, z -42..-34).
	_wall(root, Vector2(-10, -34), Vector2(-3, -34), 6.0, 0.8, WALL_SAND2)
	_wall(root, Vector2(7, -34), Vector2(10, -34), 6.0, 0.8, WALL_SAND2)
	_wall(root, Vector2(-10, -42), Vector2(-10, -40), 6.0, 0.8, WALL_SAND2)
	_wall(root, Vector2(-10, -36), Vector2(-10, -34), 6.0, 0.8, WALL_SAND2)
	_wall(root, Vector2(10, -42), Vector2(10, -40), 6.0, 0.8, WALL_SAND2)
	_wall(root, Vector2(10, -36), Vector2(10, -34), 6.0, 0.8, WALL_SAND2)
	# CT-мид/рамп: запад — глухая стена к B, восток — проход в A (z -20..-16).
	_wall(root, Vector2(-10, -34), Vector2(-10, -14), 6.0, 0.8, WALL_SAND2)
	_wall(root, Vector2(10, -34), Vector2(10, -20), 6.0, 0.8, WALL_SAND2)
	_wall(root, Vector2(10, -16), Vector2(10, -14), 6.0, 0.8, WALL_SAND2)

	# Кот: невысокая площадка от мида к шорту (две ступени по 30 см).
	_box(root, Vector3(9.0, 0.6, 4.0), Vector3(10.5, 0.3, -7), STEEL, Vector3.ZERO, "Кот")
	_box(root, Vector3(2.0, 0.3, 4.0), Vector3(5.0, 0.15, -7), STEEL, Vector3.ZERO, "Ступень")
	_wall(root, Vector2(6, -9.3), Vector2(15, -9.3), 1.2, 0.5, STEEL)

	# --- Крыши над туннелями и проходами (для вида сверху)
	_box(root, Vector3(18.0, 0.4, 8.0), Vector3(-31, 5.6, -8), ROOF, Vector3.ZERO, "Крыша")
	_box(root, Vector3(8.0, 0.4, 10.0), Vector3(-15, 5.6, -8), ROOF, Vector3.ZERO, "Крыша")
	_box(root, Vector3(10.0, 0.4, 6.0), Vector3(26, 5.6, -20), ROOF, Vector3.ZERO, "Крыша")

	# --- Наполнение: ящики и укрытия
	_crates(root, [
		[0, -6, 1.4], [3, -2, 1.4, 1.6], [-3, 12, 1.4],
		[12, 4, 1.4, 2.2], [15, 8, 1.4],
	], CRATE)
	_crates(root, [
		[10, -8, 1.4, 2.0], [13, 2, 1.6, 2.4], [26, -4, 1.4], [30, 2, 1.4],
		[33, -8, 1.4, 2.2], [24, -30, 1.4, 2.4], [30, -32, 1.4, 2.0],
		[19, -22, 1.4], [36, -24, 1.4, 2.4], [22, -36, 1.4],
	], CRATE)
	_crates(root, [
		[-30, -24, 1.4, 2.4], [-24, -30, 1.4], [-34, -34, 1.4, 2.6],
		[-20, -20, 1.4], [-16, -28, 1.4, 2.2], [-30, -18, 1.4],
	], CRATE2)
	_crates(root, [
		[-34, 6, 1.4], [-30, 14, 1.6, 2.2], [-36, 16, 1.4],
		[-14, 6, 1.4], [-10, 14, 1.4, 2.2],
	], CRATE)
	# Платформа на B и возвышение на A.
	_box(root, Vector3(10.0, 0.8, 7.0), Vector3(-31, 0.4, -36), CONCRETE, Vector3.ZERO, "Плат")
	_box(root, Vector3(10.0, 0.4, 2.0), Vector3(-31, 0.2, -31.5), CONCRETE, Vector3.ZERO, "Ступень")
	_box(root, Vector3(9.0, 0.8, 8.0), Vector3(34, 0.4, -33), CONCRETE, Vector3.ZERO, "Плат")
	_box(root, Vector3(2.0, 0.4, 9.0), Vector3(28.5, 0.2, -33), CONCRETE, Vector3.ZERO, "Ступень")
	# «Длинный» забор вдоль лонга.
	_box(root, Vector3(1.0, 2.2, 26.0), Vector3(26.5, 1.1, 0), TRIM, Vector3.ZERO, "Забор")

	# --- Подписи-ориентиры
	_label(root, "T СПАВН", Vector3(0, 4.0, 33))
	_label(root, "CT СПАВН", Vector3(0, 4.0, -38))
	_label(root, "МИД", Vector3(0, 4.0, 10))
	_label(root, "ЛОНГ", Vector3(30, 4.0, 6))
	_label(root, "ТУННЕЛИ", Vector3(-31, 4.0, 10))
	_label(root, "КОТ", Vector3(11, 3.4, -7))
	_label(root, "A", Vector3(26, 5.0, -26), Color(1.0, 0.75, 0.4), 2.6)
	_label(root, "B", Vector3(-28, 5.0, -26), Color(0.7, 0.85, 1.0), 2.6)

	return {
		"id": "dust2",
		"name": "de_dust2",
		"half": half,
		"team_spawns": {
			0: _spawn_row(-6.0, -38.0, 3.0, 0.0, 5),
			1: _spawn_row(-6.0, 33.0, 3.0, 0.0, 5),
		},
		"patrol": [
			Vector3(0, 0.3, 8), Vector3(2, 0.3, -6), Vector3(0, 0.3, -24),
			Vector3(30, 0.3, 8), Vector3(30, 0.3, -8), Vector3(24, 0.3, -24),
			Vector3(34, 0.3, -32), Vector3(-30, 0.3, -24), Vector3(-34, 0.3, -34),
			Vector3(-31, 0.3, 8), Vector3(-14, 0.3, 12), Vector3(13, 0.3, -6),
		],
		"health": [Vector3(16, 0.4, -2), Vector3(-34, 0.4, -30), Vector3(2, 0.4, 20)],
		"ammo": [Vector3(-2, 0.4, -18), Vector3(32, 0.4, -26), Vector3(-30, 0.4, 4)],
	}


# --- de_mirage ----------------------------------------------------------------

static func _build_mirage(root: Node3D) -> Dictionary:
	var half := 40.0
	_box(root, Vector3(half * 2.0, 1.0, half * 2.0), Vector3(0, -0.5, 0), FLOOR_SAND,
			Vector3.ZERO, "Пол")

	_wall(root, Vector2(-half, -half), Vector2(half, -half), 8.0, 1.0, WALL_SAND)
	_wall(root, Vector2(-half, half), Vector2(half, half), 8.0, 1.0, WALL_SAND)
	_wall(root, Vector2(-half, -half), Vector2(-half, half), 8.0, 1.0, WALL_SAND)
	_wall(root, Vector2(half, -half), Vector2(half, half), 8.0, 1.0, WALL_SAND)

	# Мид: коридор x -6..6, с окном в CT-мид (z = -16).
	_wall(root, Vector2(-6, -16), Vector2(-6, 26), 6.0, 0.8, WALL_SAND2)
	_wall(root, Vector2(6, -8), Vector2(6, 26), 6.0, 0.8, WALL_SAND2)
	_wall(root, Vector2(-6, -16), Vector2(-2, -16), 6.0, 0.8, WALL_SAND2)
	_wall(root, Vector2(2, -16), Vector2(6, -16), 6.0, 0.8, WALL_SAND2)

	# CT-спавн (x -8..10, z -40..-16), глухая стена к B с дверью-кухней.
	_wall(root, Vector2(-8, -40), Vector2(-8, -37), 6.0, 0.8, WALL_SAND2)
	_wall(root, Vector2(-8, -31), Vector2(-8, -16), 6.0, 0.8, WALL_SAND2)
	_wall(root, Vector2(-8, -16), Vector2(-2, -16), 6.0, 0.8, WALL_SAND2)
	_wall(root, Vector2(2, -16), Vector2(10, -16), 6.0, 0.8, WALL_SAND2)

	# A: западная граница (x = 16) с проходами коннектора и CT-рампы.
	_wall(root, Vector2(16, -40), Vector2(16, -38), 6.0, 0.8, WALL_SAND)
	_wall(root, Vector2(16, -32), Vector2(16, -14), 6.0, 0.8, WALL_SAND)
	_wall(root, Vector2(16, -14), Vector2(16, -8), 6.0, 0.8, WALL_SAND)
	_wall(root, Vector2(10, -40), Vector2(16, -40), 6.0, 0.8, WALL_SAND)
	_wall(root, Vector2(10, -32), Vector2(16, -32), 6.0, 0.8, WALL_SAND)
	# Коннектор: коридор x 6..16, z -14..-8.
	_wall(root, Vector2(6, -8), Vector2(16, -8), 6.0, 0.8, WALL_SAND2)
	_wall(root, Vector2(6, -14), Vector2(16, -14), 6.0, 0.8, WALL_SAND2)

	# T-зона на востоке: x 16..28, z -16..26, открыта в T-спавн и в A.
	_wall(root, Vector2(28, -16), Vector2(28, 14), 6.0, 0.8, WALL_SAND2)
	_wall(root, Vector2(28, 20), Vector2(28, 26), 6.0, 0.8, WALL_SAND2)
	# Дворец: x 28..40, z -16..26, вход с юга.
	_wall(root, Vector2(28, 26), Vector2(half, 26), 6.0, 0.8, WALL_SAND2)

	# B: x -40..-8, z -40..-16; южная стена глухая, вход из аппартаментов.
	_wall(root, Vector2(-28, -16), Vector2(-8, -16), 6.0, 0.8, WALL_SAND2)
	# Аппартаменты: коридор x -40..-28, z -16..26, вход сверху открыт в B.
	_wall(root, Vector2(-28, -16), Vector2(-28, 18), 6.0, 0.8, WALL_SAND2)
	_wall(root, Vector2(-28, 24), Vector2(-28, 26), 6.0, 0.8, WALL_SAND2)

	# Наполнение: ящики на точках и в проходах.
	_crates(root, [
		[26, -22, 1.4, 2.2], [30, -26, 1.4], [24, -32, 1.4, 2.4], [34, -22, 1.4, 2.0],
		[20, -36, 1.4], [36, -34, 1.4, 2.2], [30, -36, 1.4], [22, -20, 1.4, 1.6],
	], CRATE)
	_crates(root, [
		[-18, -20, 1.4, 2.2], [-24, -24, 1.4], [-30, -22, 1.4, 2.4], [-34, -28, 1.4],
		[-16, -30, 1.4, 2.0], [-20, -34, 1.4], [-36, -34, 1.4, 2.2], [-28, -36, 1.4],
	], CRATE2)
	_crates(root, [
		[0, 2, 1.4, 1.8], [-2, 12, 1.4], [2, 18, 1.4, 1.6],
		[11, -11, 1.4, 1.6], [20, 4, 1.4], [26, -10, 1.4, 1.8],
		[-34, 4, 1.4], [-36, -6, 1.4, 2.0], [-30, 10, 1.4],
	], CRATE)
	# Возвышение в A (ящики «тетрис») и вагон на B.
	_box(root, Vector3(6.0, 0.8, 3.0), Vector3(30, 0.4, -30), CONCRETE, Vector3.ZERO, "Плат")
	_box(root, Vector3(3.0, 0.4, 3.0), Vector3(26, 0.2, -30), CONCRETE, Vector3.ZERO, "Ступень")
	_box(root, Vector3(2.4, 2.0, 5.0), Vector3(-24, 1.0, -22), STEEL, Vector3.ZERO, "Вагон")
	_box(root, Vector3(2.0, 1.0, 3.0), Vector3(-33, 0.5, -26), TRIM, Vector3.ZERO, "Лавочка")

	_label(root, "T СПАВН", Vector3(0, 4.0, 33))
	_label(root, "CT СПАВН", Vector3(0, 4.0, -37))
	_label(root, "МИД", Vector3(0, 4.0, 8))
	_label(root, "ОКНО", Vector3(0, 4.0, -16), Color(0.75, 0.9, 1.0), 1.6)
	_label(root, "КОННЕКТОР", Vector3(11, 3.6, -11), Color(1.0, 0.9, 0.7), 1.4)
	_label(root, "ДВОРЕЦ", Vector3(34, 4.0, 6), Color(1.0, 0.85, 0.6), 1.6)
	_label(root, "АППАРТАМЕНТЫ", Vector3(-34, 4.0, 6), Color(1.0, 0.85, 0.6), 1.4)
	_label(root, "КУХНЯ", Vector3(-13, 3.6, -35), Color(1.0, 0.9, 0.7), 1.4)
	_label(root, "A", Vector3(28, 5.0, -28), Color(1.0, 0.75, 0.4), 2.6)
	_label(root, "B", Vector3(-26, 5.0, -28), Color(0.7, 0.85, 1.0), 2.6)

	return {
		"id": "mirage",
		"name": "de_mirage",
		"half": half,
		"team_spawns": {
			0: _spawn_row(-6.0, -36.0, 3.0, 0.0, 5),
			1: _spawn_row(-6.0, 32.0, 3.0, 0.0, 5),
		},
		"patrol": [
			Vector3(0, 0.3, 6), Vector3(0, 0.3, -12), Vector3(11, 0.3, -11),
			Vector3(22, 0.3, -24), Vector3(32, 0.3, -30), Vector3(34, 0.3, 4),
			Vector3(22, 0.3, 10), Vector3(-26, 0.3, -24), Vector3(-33, 0.3, -32),
			Vector3(-34, 0.3, 6), Vector3(-16, 0.3, -34), Vector3(2, 0.3, 20),
		],
		"health": [Vector3(24, 0.4, -34), Vector3(-30, 0.4, -30), Vector3(0, 0.4, 16)],
		"ammo": [Vector3(11, 0.4, -11), Vector3(32, 0.4, -24), Vector3(-32, 0.4, 2)],
	}


# --- Тренировочная арена ------------------------------------------------------

static func _build_arena(root: Node3D) -> Dictionary:
	var half := 34.0
	_box(root, Vector3(half * 2.0, 1.0, half * 2.0), Vector3(0, -0.5, 0),
			Color(0.42, 0.42, 0.36), Vector3.ZERO, "Пол")
	_add_grid_lines(root, half)

	var wall_color := Color(0.55, 0.55, 0.58)
	_wall(root, Vector2(-half, -half), Vector2(half, -half), 5.0, 1.0, wall_color)
	_wall(root, Vector2(-half, half), Vector2(half, half), 5.0, 1.0, wall_color)
	_wall(root, Vector2(-half, -half), Vector2(-half, half), 5.0, 1.0, wall_color)
	_wall(root, Vector2(half, -half), Vector2(half, half), 5.0, 1.0, wall_color)

	var crate_color := Color(0.45, 0.34, 0.18)
	var crate_color2 := Color(0.35, 0.4, 0.26)
	var steel := Color(0.4, 0.42, 0.45)

	_crates(root, [
		[-8, -8, 1.4, 1.6], [-6.4, -9.6, 1.4, 1.6], [10, -12, 1.4, 1.6],
		[11.6, -13.2, 1.4, 1.6], [14, 6, 1.4, 1.6], [12.4, 7.4, 1.4, 1.6],
		[-14, 12, 1.4, 1.6], [-12.6, 13.4, 1.4, 1.6], [4, 18, 1.4, 1.6],
		[5.6, 19.4, 1.4, 1.6], [-20, -4, 1.4, 1.6], [-18.4, -5.4, 1.4, 1.6],
		[22, -22, 1.4, 1.6], [20.4, -20.4, 1.4, 1.6], [-4, 26, 1.4, 1.6],
		[0, 4, 1.4, 1.6], [2, 6, 1.4, 1.6],
	], crate_color)
	_crates(root, [
		[-2, -12, 1.4, 1.6], [-12, 2, 1.4, 1.6], [8, -2, 1.4, 1.6],
	], crate_color2)

	_box(root, Vector3(8.0, 1.3, 0.9), Vector3(0, 0.65, -18), steel, Vector3.ZERO, "Барьер")
	_box(root, Vector3(0.9, 1.3, 8.0), Vector3(18, 0.65, 0), steel, Vector3.ZERO, "Барьер")
	_box(root, Vector3(8.0, 1.3, 0.9), Vector3(-16, 0.65, 22), steel, Vector3.ZERO, "Барьер")
	for pillar in [Vector3(6, 0, -24), Vector3(-6, 0, 24), Vector3(24, 0, 12), Vector3(-24, 0, -12)]:
		_box(root, Vector3(2.2, 7.0, 2.2), pillar + Vector3(0, 3.5, 0), Color(0.48, 0.47, 0.44),
				Vector3.ZERO, "Колонна")
	_box(root, Vector3(3.0, 2.8, 6.0), Vector3(22, 1.4, 22), Color(0.24, 0.36, 0.38),
			Vector3.ZERO, "Контейнер")
	_box(root, Vector3(3.0, 2.8, 6.0), Vector3(-26, 1.4, 8), Color(0.34, 0.3, 0.22),
			Vector3.ZERO, "Контейнер")
	_box(root, Vector3(12.0, 0.6, 12.0), Vector3(-18, 3.0, -18), Color(0.36, 0.4, 0.46),
			Vector3.ZERO, "Возвышение")
	_box(root, Vector3(1.0, 0.6, 12.0), Vector3(-24.5, 3.0, -18), Color(0.5, 0.5, 0.52),
			Vector3.ZERO, "Перила")
	_box(root, Vector3(6.0, 0.5, 8.4), Vector3(-18, 1.55, -8.2), Color(0.5, 0.5, 0.52),
			Vector3(-22.0, 0.0, 0.0), "Пандус")
	_box(root, Vector3(1.2, 1.0, 12.0), Vector3(-18, 3.8, -24.4), Color(0.5, 0.5, 0.52),
			Vector3.ZERO, "Перила")

	_label(root, "АРЕНА", Vector3(0, 4.0, 0))

	return {
		"id": "arena",
		"name": "Арена",
		"half": half,
		"team_spawns": {
			0: _spawn_row(-6.0, -26.0, 3.0, 0.0, 5),
			1: _spawn_row(-6.0, 26.0, 3.0, 0.0, 5),
		},
		"patrol": [
			Vector3(0, 0.3, 12), Vector3(0, 0.3, -12), Vector3(16, 0.3, 0),
			Vector3(-16, 0.3, 0), Vector3(-18, 3.5, -18), Vector3(22, 0.3, -20),
			Vector3(-22, 0.3, 20), Vector3(8, 0.3, 22), Vector3(-8, 0.3, -22),
		],
		"health": [Vector3(-10, 0.4, 16), Vector3(16, 0.4, -16), Vector3(-18, 3.4, -14)],
		"ammo": [Vector3(10, 0.4, 12), Vector3(-20, 0.4, -20), Vector3(20, 0.4, 18)],
	}


static func _add_grid_lines(root: Node3D, half: float) -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.3, 0.27)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var step := 8.0
	var count := int(half * 2.0 / step)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(half * 2.0, 0.02, 0.12)
	var mesh_b := BoxMesh.new()
	mesh_b.size = Vector3(0.12, 0.02, half * 2.0)
	for i in count + 1:
		var offset := -half + float(i) * step
		var line_a := MeshInstance3D.new()
		line_a.mesh = mesh
		line_a.material_override = mat
		line_a.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		line_a.position = Vector3(0, 0.02, offset)
		root.add_child(line_a)

		var line_b := MeshInstance3D.new()
		line_b.mesh = mesh_b
		line_b.material_override = mat
		line_b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		line_b.position = Vector3(offset, 0.02, 0)
		root.add_child(line_b)
