## Визуальные эффекты: трассеры, искры от попаданий, вспышки выстрела, кровь.
class_name Effects
extends RefCounted

## Корневой узел арены, куда складываются эффекты. Ставится из Main.gd.
static var root: Node3D = null

static var _tracer_mesh: BoxMesh = null
static var _spark_mesh: SphereMesh = null


static func _ensure_meshes() -> void:
	if _tracer_mesh == null:
		_tracer_mesh = BoxMesh.new()
		_tracer_mesh.size = Vector3(0.035, 0.035, 1.0)
	if _spark_mesh == null:
		_spark_mesh = SphereMesh.new()
		_spark_mesh.radius = 0.06
		_spark_mesh.height = 0.12
		_spark_mesh.radial_segments = 8
		_spark_mesh.rings = 4


static func _make_material(color: Color, emission: float, alpha := 1.0, unshaded := true) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(color.r, color.g, color.b, alpha)
	if unshaded:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if emission > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emission
	if alpha < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat


## Светящаяся линия выстрела, быстро исчезает.
static func tracer(from: Vector3, to: Vector3, color: Color, lifetime := 0.09) -> void:
	if root == null:
		return
	var distance := from.distance_to(to)
	if distance < 0.15:
		return
	_ensure_meshes()
	var line := MeshInstance3D.new()
	line.mesh = _tracer_mesh
	line.material_override = _make_material(color, 6.0, 0.85)
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(line)
	line.global_position = (from + to) * 0.5
	if not _safe_look_at(line, to):
		line.queue_free()
		return
	line.scale = Vector3(1.0, 1.0, distance)
	_fade_out(line, lifetime)


## Вспышка и искры в точке попадания. blood = попадание по боту.
static func impact(point: Vector3, normal: Vector3, blood := false) -> void:
	if root == null:
		return
	_ensure_meshes()
	var color := Color(0.9, 0.15, 0.12) if blood else Color(1.0, 0.75, 0.3)
	var spark := MeshInstance3D.new()
	spark.mesh = _spark_mesh
	spark.material_override = _make_material(color, 5.0)
	spark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(spark)
	var scale_base := 1.6 if blood else 1.0
	spark.global_position = point + normal * 0.05
	spark.scale = Vector3.ONE * scale_base
	_fade_out(spark, 0.18, Vector3.ONE * scale_base * 0.4)

	if blood:
		for i in 5:
			var drop := MeshInstance3D.new()
			drop.mesh = _spark_mesh
			drop.material_override = _make_material(Color(0.55, 0.02, 0.02), 1.5)
			drop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			root.add_child(drop)
			drop.global_position = point + normal * 0.05
			drop.scale = Vector3.ONE * 0.8
			var drift := Vector3(randf_range(-0.32, 0.32), randf_range(0.1, 0.5), randf_range(-0.32, 0.32))
			var tween := drop.create_tween()
			tween.set_parallel(true)
			tween.tween_property(drop, "global_position", drop.global_position + normal * 0.5 + drift, 0.35)
			tween.tween_property(drop, "scale", Vector3.ONE * 0.15, 0.35)
			tween.chain().tween_callback(drop.queue_free)


## Дульная вспышка у ствола.
static func muzzle_flash(parent: Node3D, offset: Vector3, color := Color(1.0, 0.85, 0.45)) -> void:
	if parent == null or not parent.is_inside_tree():
		return
	_ensure_meshes()
	var flash := MeshInstance3D.new()
	flash.mesh = _spark_mesh
	flash.material_override = _make_material(color, 9.0)
	flash.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(flash)
	flash.position = offset
	flash.scale = Vector3.ONE * 2.4

	var light := OmniLight3D.new()
	light.light_color = color
	light.light_energy = 4.0
	light.omni_range = 9.0
	parent.add_child(light)
	light.position = offset

	_fade_out(flash, 0.06)
	var ltween := light.create_tween()
	ltween.tween_property(light, "light_energy", 0.0, 0.07)
	ltween.tween_callback(light.queue_free)


static func _fade_out(node: Node3D, lifetime: float, target_scale := Vector3.ZERO) -> void:
	var tween := node.create_tween()
	tween.set_parallel(true)
	if target_scale != Vector3.ZERO:
		tween.tween_property(node, "scale", target_scale, lifetime)
	tween.chain().tween_callback(node.queue_free)
	var mat: Material = node.material_override
	if mat is StandardMaterial3D:
		var m: StandardMaterial3D = mat
		var t := node.create_tween()
		t.tween_property(m, "albedo_color:a", 0.0, lifetime)
		t.tween_callback(func() -> void: m.emission_energy_multiplier = 0.0)


static func _safe_look_at(node: Node3D, to: Vector3) -> bool:
	if node.global_position.distance_to(to) < 0.05:
		return false
	node.look_at(to, Vector3.UP)
	return true
