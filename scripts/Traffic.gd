extends Node3D
## Moving non-colliding procedural traffic to make the city feel occupied.
## Cars are original meshes. Player can explore roads freely.

const PAINTS = [
	Color(0.78, 0.20, 0.14), Color(0.18, 0.35, 0.63),
	Color(0.84, 0.80, 0.74), Color(0.24, 0.31, 0.34),
	Color(0.65, 0.67, 0.59), Color(0.80, 0.60, 0.20)
]
var vehicles: Array[Dictionary] = []
var running_time: float = 0.0

func _ready() -> void:
	name = "Traffic"
	for i in range(12):
		var car := Node3D.new()
		car.name = "MovingCar_%02d" % i
		add_child(car)
		var car_models := ["sedan", "taxi", "delivery", "hatchback-sports", "sedan-sports"]
		var model_path: String = "res://assets/models/car-kit/" + car_models[i % car_models.size()] + ".glb"
		var has_car_model: bool = ResourceLoader.exists(model_path)
		if has_car_model:
			var model = load(model_path)
			if model is PackedScene:
				var art: Node3D = (model as PackedScene).instantiate()
				car.add_child(art)
				preload("res://scripts/ModelFit.gd").vehicle(art, 4.2)
			else:
				has_car_model = false
		if not has_car_model:
			_mesh_box(car, "Chassis", Vector3(0, 0.72, 0), Vector3(1.75, 0.66, 3.55), PAINTS[i % PAINTS.size()])
		if not has_car_model:
			_mesh_box(car, "Cabin", Vector3(0, 1.18, 0.0), Vector3(1.4, 0.58, 1.8), Color(0.16, 0.27, 0.33))
		if not has_car_model:
			_mesh_box(car, "Front lamps", Vector3(0, 0.71, -1.83), Vector3(1.23, 0.17, 0.07), Color(1, 0.90, 0.55))
		if not has_car_model:
			_mesh_box(car, "Tail lamps", Vector3(0, 0.70, 1.81), Vector3(1.23, 0.17, 0.07), Color(0.82, 0.10, 0.12))
		if not has_car_model:
			for side in [-1, 1]:
				for axle in [-1, 1]:
					var wheel := MeshInstance3D.new()
					var shape := CylinderMesh.new()
					shape.height = 0.2
					shape.top_radius = 0.31
					shape.bottom_radius = 0.31
					wheel.mesh = shape
					wheel.position = Vector3(side * 0.88, 0.40, axle * 1.06)
					wheel.rotation_degrees.z = 90.0
					var rubber := StandardMaterial3D.new()
					rubber.albedo_color = Color(0.10, 0.10, 0.11)
					wheel.material_override = rubber
					car.add_child(wheel)
		vehicles.append({
			"node": car, "axis": i % 2, "route": (i % 7 - 3) * 24.0,
			"offset": 2.0 if i % 3 == 0 else -2.0,
			"speed": 4.0 + float(i % 4) * 0.65,
			"phase": float(i) * 17.6
		})

func _mesh_box(parent: Node3D, title: String, at: Vector3, size: Vector3, color: Color) -> void:
	var node := MeshInstance3D.new()
	node.name = title
	var shape := BoxMesh.new()
	shape.size = size
	node.mesh = shape
	node.position = at
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	node.material_override = material
	parent.add_child(node)

func _process(delta: float) -> void:
	running_time += delta
	for entry in vehicles:
		var vehicle: Node3D = entry["node"]
		var offset: float = entry["offset"]
		var progress: float = fposmod(running_time * entry["speed"] + entry["phase"] + 104.0, 208.0) - 104.0
		var route: float = entry["route"]
		if int(entry["axis"]) == 0:
			vehicle.position = Vector3(route + offset, 0, progress)
			vehicle.rotation.y = 0.0
		else:
			vehicle.position = Vector3(progress, 0, route + offset)
			vehicle.rotation.y = PI / 2.0
