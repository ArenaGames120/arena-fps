## Аптечка или ящик с патронами. Возрождается через некоторое время.
class_name Pickup
extends Area3D

enum Kind { HEALTH, AMMO }

var kind := Kind.HEALTH
var respawn_time := 22.0
var amount := 40.0
var _visual: Node3D
var _cooldown := 0.0
var _spin := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2  # только игрок
	monitoring = true
	var sphere := SphereShape3D.new()
	sphere.radius = 1.5
	var shape := CollisionShape3D.new()
	shape.shape = sphere
	shape.position = Vector3(0, 0.8, 0)
	add_child(shape)
	_build_visual()
	body_entered.connect(_on_body_entered)


func _build_visual() -> void:
	_visual = Node3D.new()
	_visual.position = Vector3(0, 0.8, 0)
	add_child(_visual)

	var color := Color(0.25, 0.9, 0.35) if kind == Kind.HEALTH else Color(1.0, 0.8, 0.2)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.4
	mat.roughness = 0.3

	var box := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(0.55, 0.55, 0.55)
	box.mesh = box_mesh
	box.material_override = mat
	_visual.add_child(box)

	var ring := MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.5
	ring_mesh.outer_radius = 0.58
	ring_mesh.rings = 12
	ring_mesh.ring_segments = 8
	ring.mesh = ring_mesh
	ring.material_override = mat
	ring.position = Vector3(0, -0.55, 0)
	_visual.add_child(ring)

	if kind == Kind.HEALTH:
		_add_cross(Vector3(0.34, 0.05, 0.05), mat)
		_add_cross(Vector3(0.05, 0.34, 0.05), mat)
	else:
		for i in 3:
			_add_bar(-0.16 + i * 0.16, mat)


func _add_cross(size: Vector3, mat: Material) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = mat
	mesh.position = Vector3(0, 0, 0.3)
	_visual.add_child(mesh)


func _add_bar(offset: float, mat: Material) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.09, 0.34, 0.09)
	mesh.mesh = box
	mesh.material_override = mat
	mesh.position = Vector3(offset, 0, 0.3)
	_visual.add_child(mesh)


func _process(delta: float) -> void:
	if _cooldown > 0.0:
		_cooldown -= delta
		if _cooldown <= 0.0:
			_visual.visible = true
	elif _visual.visible:
		_spin += delta * 1.6
		_visual.rotation.y = _spin


func _on_body_entered(body: Node3D) -> void:
	if _cooldown > 0.0 or not _visual.visible:
		return
	if not body.is_in_group("player"):
		return
	var used := false
	if kind == Kind.HEALTH and body.has_method("heal"):
		used = bool(body.call("heal", amount))
	elif kind == Kind.AMMO and body.has_method("give_ammo"):
		used = bool(body.call("give_ammo"))
	if not used:
		return
	_visual.visible = false
	_cooldown = respawn_time
	Effects.impact(global_position + Vector3(0, 0.8, 0), Vector3.UP,
			kind == Kind.HEALTH)
