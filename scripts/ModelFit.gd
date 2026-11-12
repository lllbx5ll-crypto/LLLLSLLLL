extends RefCounted
## Imports licensed glTF assets at a consistent metre scale.
## Imported scene meshes may contain parent transforms; measuring each mesh AABB
## without those transforms was the cause of oversized human models.

static func bounds(root: Node3D) -> AABB:
	var corners: Array[Vector3] = []
	_collect(root, root, corners)
	if corners.is_empty():
		return AABB(Vector3(-0.5, 0.0, -0.5), Vector3.ONE)
	var result := AABB(corners[0], Vector3.ZERO)
	for point in corners:
		result = result.expand(point)
	return result

static func _collect(root: Node3D, node: Node, out_points: Array[Vector3]) -> void:
	if node is MeshInstance3D:
		var part := node as MeshInstance3D
		if part.mesh != null:
			var local_transform: Transform3D = root.global_transform.affine_inverse() * part.global_transform
			var bbox: AABB = part.mesh.get_aabb()
			for i in range(8):
				out_points.append(local_transform * bbox.get_endpoint(i))
	for child in node.get_children():
		_collect(root, child, out_points)

static func person(model: Node3D, height_metres: float = 1.74) -> void:
	var bbox := bounds(model)
	var scale_factor: float = height_metres / maxf(bbox.size.y, 0.05)
	scale_factor = clampf(scale_factor, 0.001, 40.0)
	_place_on_ground(model, bbox, scale_factor, false)

static func vehicle(model: Node3D, length_metres: float = 4.15) -> void:
	var bbox := bounds(model)
	var horizontally_long_x: bool = bbox.size.x > bbox.size.z
	var longer: float = maxf(bbox.size.x, bbox.size.z)
	var shorter: float = minf(bbox.size.x, bbox.size.z)
	var scale_factor: float = minf(length_metres / maxf(longer, 0.05), 2.05 / maxf(shorter, 0.05))
	scale_factor = minf(scale_factor, 1.85 / maxf(bbox.size.y, 0.05))
	scale_factor = clampf(scale_factor, 0.001, 50.0)
	_place_on_ground(model, bbox, scale_factor, horizontally_long_x)

static func building(model: Node3D, footprint: float = 13.5, max_height: float = 20.0) -> void:
	var bbox := bounds(model)
	var factor: float = minf(footprint / maxf(bbox.size.x, 0.05), footprint / maxf(bbox.size.z, 0.05))
	factor = minf(factor, max_height / maxf(bbox.size.y, 0.05))
	_place_on_ground(model, bbox, clampf(factor, 0.001, 40.0), false)

static func product(model: Node3D, max_metres: float = 0.4) -> void:
	var bbox := bounds(model)
	var factor: float = max_metres / maxf(maxf(bbox.size.x, bbox.size.y), maxf(bbox.size.z, 0.05))
	_place_on_ground(model, bbox, clampf(factor, 0.001, 40.0), false)

static func _place_on_ground(model: Node3D, bbox: AABB, scale_factor: float, rotate_for_forward: bool) -> void:
	model.scale = Vector3.ONE * scale_factor
	if rotate_for_forward:
		model.rotation.y += PI / 2.0
	var center: Vector3 = bbox.get_center()
	var offset := Vector3(-center.x, -bbox.position.y, -center.z) * scale_factor
	model.position += Basis(Vector3.UP, model.rotation.y) * offset
