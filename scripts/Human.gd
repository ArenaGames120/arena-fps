## Человекоподобная модель бойца: голова, торс, руки, ноги, бронежилет и оружие.
## Собирается из примитивов, умеет ходить (машет конечностями) и падать при смерти.
class_name Human
extends Node3D

## Центр головы в локальных координатах модели — по нему ставится хитбокс хедшота.
const HEAD_LOCAL := Vector3(0.0, 1.62, 0.0)
const HEAD_HITBOX_RADIUS := 0.15
const EYE_HEIGHT := 1.62
const BODY_HEIGHT := 1.8
const BODY_RADIUS := 0.36

var muzzle: Node3D = null
var head_node: Node3D = null
## Все материалы модели — нужны для вспышки урона и растворения трупа.
var materials: Array[StandardMaterial3D] = []
## Исходные цвета материалов (для вспышки урона).
var base_colors: Array[Color] = []
var body_material: StandardMaterial3D = null

var _leg_l: Node3D
var _leg_r: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _root_bob: Node3D
var _time := 0.0
var _rng := RandomNumberGenerator.new()


func _init() -> void:
	_rng.randomize()


## primary — цвет формы команды, gear — снаряжение, accent — светящиеся детали.
func build(primary: Color, gear: Color, accent: Color, helmet := true) -> void:
	_root_bob = Node3D.new()
	add_child(_root_bob)

	var suit := _material(primary, 0.85)
	var dark := _material(gear, 0.8)
	var skin := _material(Color(0.62, 0.47, 0.36), 0.75)
	var glow := _material(accent.darkened(0.25), 0.5)
	glow.emission_enabled = true
	glow.emission = accent
	glow.emission_energy_multiplier = 1.7
	body_material = suit

	# Ноги: пивот в бедре, сама нога висит вниз — так удобно качать ходьбу.
	_leg_l = _limb(_root_bob, Vector3(-0.11, 0.86, 0.0))
	_box(_leg_l, Vector3(0.17, 0.8, 0.19), Vector3(0.0, -0.4, 0.0), dark)
	_box(_leg_l, Vector3(0.19, 0.12, 0.28), Vector3(0.0, -0.79, -0.04), dark)
	_leg_r = _limb(_root_bob, Vector3(0.11, 0.86, 0.0))
	_box(_leg_r, Vector3(0.17, 0.8, 0.19), Vector3(0.0, -0.4, 0.0), dark)
	_box(_leg_r, Vector3(0.19, 0.12, 0.28), Vector3(0.0, -0.79, -0.04), dark)

	# Таз и торс.
	_box(_root_bob, Vector3(0.4, 0.2, 0.26), Vector3(0.0, 0.86, 0.0), dark)
	_box(_root_bob, Vector3(0.46, 0.55, 0.28), Vector3(0.0, 1.2, 0.0), suit)
	_box(_root_bob, Vector3(0.42, 0.34, 0.33), Vector3(0.0, 1.22, 0.0), dark)
	_box(_root_bob, Vector3(0.2, 0.12, 0.06), Vector3(-0.11, 1.26, -0.17), dark)
	_box(_root_bob, Vector3(0.56, 0.13, 0.29), Vector3(0.0, 1.43, 0.0), suit)

	# Руки.
	_arm_l = _limb(_root_bob, Vector3(-0.3, 1.4, 0.0))
	_box(_arm_l, Vector3(0.14, 0.58, 0.16), Vector3(0.0, -0.31, 0.0), suit)
	_box(_arm_l, Vector3(0.14, 0.13, 0.16), Vector3(0.0, -0.65, 0.0), dark)
	_arm_r = _limb(_root_bob, Vector3(0.3, 1.4, 0.0))
	_box(_arm_r, Vector3(0.14, 0.58, 0.16), Vector3(0.0, -0.31, 0.0), suit)
	_box(_arm_r, Vector3(0.14, 0.13, 0.16), Vector3(0.0, -0.65, 0.0), dark)

	# Шея и голова.
	_box(_root_bob, Vector3(0.14, 0.1, 0.14), Vector3(0.0, 1.5, 0.0), skin)
	head_node = Node3D.new()
	head_node.position = HEAD_LOCAL
	_root_bob.add_child(head_node)
	_box(head_node, Vector3(0.22, 0.26, 0.24), Vector3.ZERO, skin)
	_box(head_node, Vector3(0.16, 0.06, 0.03), Vector3(0.0, 0.02, -0.12), glow)
	if helmet:
		# Шлем спецназа.
		_box(head_node, Vector3(0.25, 0.13, 0.27), Vector3(0.0, 0.1, 0.0), dark)
		_box(head_node, Vector3(0.26, 0.05, 0.06), Vector3(0.0, 0.02, -0.12), dark)
	else:
		# Кепка и маска террориста.
		_box(head_node, Vector3(0.24, 0.07, 0.27), Vector3(0.0, 0.11, -0.01), glow)
		_box(head_node, Vector3(0.21, 0.11, 0.03), Vector3(0.0, -0.04, -0.12), dark)

	# Оружие в руках: ствол смотрит вперёд (−Z).
	var gun := Node3D.new()
	gun.position = Vector3(0.17, 1.2, -0.24)
	_root_bob.add_child(gun)
	_box(gun, Vector3(0.07, 0.11, 0.62), Vector3(0.0, 0.0, -0.2), dark)
	_box(gun, Vector3(0.05, 0.16, 0.09), Vector3(0.0, -0.12, -0.06), dark)
	_box(gun, Vector3(0.04, 0.05, 0.24), Vector3(0.0, 0.02, -0.55), dark)
	muzzle = Node3D.new()
	muzzle.name = "Muzzle"
	muzzle.position = Vector3(0.0, 0.03, -0.72)
	gun.add_child(muzzle)


func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	materials.append(mat)
	base_colors.append(color)
	return mat


func _limb(parent: Node3D, at: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = at
	parent.add_child(pivot)
	return pivot


func _box(parent: Node3D, size: Vector3, at: Vector3, mat: Material) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = mat
	mesh.position = at
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	parent.add_child(mesh)
	return mesh


## Покачивание конечностями при ходьбе. speed — горизонтальная скорость бойца.
func animate(delta: float, speed: float) -> void:
	var moving := clampf(speed / 5.5, 0.0, 1.3)
	_time += delta * (3.0 + speed * 1.6)
	var amp := moving * 0.5
	if _leg_l != null:
		_leg_l.rotation.x = sin(_time) * amp
		_leg_r.rotation.x = -sin(_time) * amp
	if _arm_l != null:
		_arm_l.rotation.x = -sin(_time) * amp * 0.65 - 0.25
		_arm_r.rotation.x = sin(_time) * amp * 0.65 - 0.25
	if _root_bob != null:
		_root_bob.position.y = absf(sin(_time)) * 0.03 * moving
