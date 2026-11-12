extends Node3D
## Hand-built procedural city: roads, shops, housing, vehicles, NPCs and signboards.
## No copyrighted model or third-party texture is embedded.

const BLOCK_SIZE: float = 24.0
const MAP_RADIUS: int = 4
const LOCATIONS = {
	"employer": Vector3(8, 0, 8),
	"supplier": Vector3(-9, 0, 8),
	"stall": Vector3(9, 0, -10),
	"shop": Vector3(-9, 0, -10),
	"rival": Vector3(17, 0, 8),
	"delivery": Vector3(-19, 0, -8)
}
const LOCATION_LABELS = {
	"employer": "صاحب العمل",
	"supplier": "المورد",
	"stall": "مكان البسطة",
	"shop": "محلك",
	"rival": "تاجر منافس",
	"delivery": "نقطة التوصيل"
}
const PALETTE = [
	Color(0.78, 0.71, 0.60), Color(0.85, 0.76, 0.62),
	Color(0.67, 0.77, 0.80), Color(0.87, 0.82, 0.72),
	Color(0.74, 0.65, 0.58), Color(0.77, 0.73, 0.76)
]

var sun: DirectionalLight3D
var business_sign: Label3D
var street_sign: Label3D
var stall_canvas: Node3D
var shop_front: Node3D
var shop_roof: MeshInstance3D
var wandering_people: Array[Dictionary] = []
var time: float = 0.0
var building_count: int = 0

func _ready() -> void:
	name = "ProceduralCity"
	_create_environment()
	_create_streets()
	_create_blocks()
	_create_market()
	_create_cars_and_people()
	_create_street_lamps()

func _material(color: Color, rough: float = 0.88) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = rough
	return material

func _box(label: String, at: Vector3, size: Vector3, color: Color, solid: bool = false, parent: Node3D = null) -> MeshInstance3D:
	var body := MeshInstance3D.new()
	body.name = label
	var shape := BoxMesh.new()
	shape.size = size
	body.mesh = shape
	body.material_override = _material(color)
	body.position = at
	if parent == null:
		add_child(body)
	else:
		parent.add_child(body)
	if solid:
		var static_body := StaticBody3D.new()
		var collision := CollisionShape3D.new()
		var collision_box := BoxShape3D.new()
		collision_box.size = size
		collision.shape = collision_box
		static_body.add_child(collision)
		body.add_child(static_body)
	return body

func _cylinder(label: String, at: Vector3, radius: float, tall: float, color: Color, parent: Node3D = null) -> MeshInstance3D:
	var body := MeshInstance3D.new()
	body.name = label
	var shape := CylinderMesh.new()
	shape.top_radius = radius
	shape.bottom_radius = radius
	shape.height = tall
	body.mesh = shape
	body.position = at
	body.material_override = _material(color)
	if parent == null:
		add_child(body)
	else:
		parent.add_child(body)
	return body

func _sphere(label: String, at: Vector3, radius: float, color: Color, parent: Node3D = null) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.name = label
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	node.mesh = mesh
	node.position = at
	node.material_override = _material(color)
	if parent == null:
		add_child(node)
	else:
		parent.add_child(node)
	return node

func _sign(text_value: String, at: Vector3, parent: Node3D = null, scale_value: float = 0.01) -> Label3D:
	var label := Label3D.new()
	label.name = "ArabicSign"
	label.text = text_value
	label.font_size = 46
	label.pixel_size = scale_value
	label.text_direction = TextServer.DIRECTION_RTL
	var cairo_path: String = "res://assets/fonts/Cairo.ttf"
	if ResourceLoader.exists(cairo_path):
		label.font = load(cairo_path)
	elif ResourceLoader.exists("res://assets/fonts/NotoNaskhArabic.ttf"):
		label.font = load("res://assets/fonts/NotoNaskhArabic.ttf")
	label.modulate = Color(1.0, 0.96, 0.76)
	label.outline_size = 5
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = at
	if parent == null:
		add_child(label)
	else:
		parent.add_child(label)
	return label

func _create_environment() -> void:
	var world := WorldEnvironment.new()
	world.name = "SunlitSky"
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.61, 0.78, 0.94)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.78, 0.81, 0.85)
	environment.ambient_light_energy = 0.65
	world.environment = environment
	add_child(world)
	sun = DirectionalLight3D.new()
	sun.name = "DayNightSun"
	sun.rotation_degrees = Vector3(-49, 32, 0)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	add_child(sun)
	_box("Earth and collision ground", Vector3(0, -0.6, 0), Vector3(236, 1.2, 236), Color(0.70, 0.67, 0.58), true)

func _create_streets() -> void:
	for i in range(-MAP_RADIUS, MAP_RADIUS + 1):
		var at: float = float(i) * BLOCK_SIZE
		_box("Road north/south", Vector3(at, 0.035, 0), Vector3(8.0, 0.08, 222.0), Color(0.22, 0.25, 0.29))
		_box("Road east/west", Vector3(0, 0.04, at), Vector3(222.0, 0.08, 8.0), Color(0.22, 0.25, 0.29))
		for j in range(-MAP_RADIUS, MAP_RADIUS + 1):
			var other: float = float(j) * BLOCK_SIZE
			if j != 0:
				_box("Lane divider", Vector3(at, 0.085, other + 8), Vector3(0.14, 0.012, 3.0), Color(0.94, 0.89, 0.62))
				_box("Lane divider", Vector3(other + 8, 0.09, at), Vector3(3.0, 0.012, 0.14), Color(0.94, 0.89, 0.62))

func _licensed_model(relative_path: String, at: Vector3, requested_size: Vector3, parent: Node3D = null) -> Node3D:
	var path: String = "res://assets/models/" + relative_path + ".glb"
	if not ResourceLoader.exists(path):
		return null
	var scene: Resource = load(path)
	if not scene is PackedScene:
		return null
	var instance: Node3D = (scene as PackedScene).instantiate()
	instance.name = "CC0_" + relative_path.get_file()
	if parent == null:
		add_child(instance)
	else:
		parent.add_child(instance)
	instance.position = at
	var fitter = preload("res://scripts/ModelFit.gd")
	if relative_path.begins_with("mini-characters"):
		fitter.person(instance, 1.72)
	elif relative_path.begins_with("car-kit"):
		fitter.vehicle(instance, 4.15)
	elif relative_path.begins_with("city-kit"):
		fitter.building(instance, minf(requested_size.x, requested_size.z), requested_size.y)
	else:
		fitter.product(instance, maxf(maxf(requested_size.x, requested_size.y), requested_size.z))
	return instance

func _create_blocks() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 642311
	for ix in range(-MAP_RADIUS, MAP_RADIUS):
		for iz in range(-MAP_RADIUS, MAP_RADIUS):
			var x: float = (float(ix) + 0.5) * BLOCK_SIZE
			var z: float = (float(iz) + 0.5) * BLOCK_SIZE
			if ix >= -1 and ix <= 0 and iz >= -1 and iz <= 0:
				_box("Central Market Plaza", Vector3(x, 0.07, z), Vector3(14, 0.12, 14), Color(0.67, 0.65, 0.59))
				continue
			if (abs(ix) + abs(iz)) % 9 == 0:
				_park(Vector3(x, 0, z))
				continue
			var floors: int = rng.randi_range(2, 6)
			var tall: float = float(floors) * 2.75
			var building_color: Color = PALETTE[rng.randi_range(0, PALETTE.size() - 1)]
			var body_size := Vector3(13.5, tall, 13.5)
			var is_commercial: bool = abs(ix) + abs(iz) <= 4
			var folder: String = "city-kit-commercial" if is_commercial else "city-kit-suburban"
			var variant: String = ("building-" + char(97 + building_count % 14)) if is_commercial else ("building-type-" + char(97 + building_count % 18))
			var model: Node3D = _licensed_model(folder + "/" + variant, Vector3(x, 0, z), body_size)
			var shell := _box("Building collision %d" % building_count, Vector3(x, tall / 2, z), body_size, building_color, true)
			if model != null:
				shell.visible = false
				building_count += 1
				continue
			_box("Roof parapet", Vector3(x, tall + 0.35, z), Vector3(14, 0.7, 14), Color(0.54, 0.49, 0.46))
			_box("Entry door", Vector3(x, 1.25, z - 6.85), Vector3(2.2, 2.5, 0.14), Color(0.27, 0.23, 0.19))
			for floor_index in range(1, floors + 1):
				for column in [-1, 0, 1]:
					var window_color := Color(0.13, 0.27, 0.35) if rng.randf() > 0.27 else Color(0.66, 0.53, 0.30)
					_box("Window", Vector3(x + column * 3.5, floor_index * 2.7 - 0.85, z - 6.81), Vector3(1.3, 1.5, 0.12), window_color)
			building_count += 1

func _park(at: Vector3) -> void:
	_box("Pocket park", at + Vector3(0, 0.12, 0), Vector3(14, 0.23, 14), Color(0.31, 0.49, 0.27))
	for i in range(3):
		var x: float = float(i - 1) * 4.0
		_cylinder("Palm trunk", at + Vector3(x, 2.3, 0), 0.26, 4.4, Color(0.39, 0.29, 0.18))
		_sphere("Palm canopy", at + Vector3(x, 4.9, 0), 2.0, Color(0.12, 0.40, 0.20))

func _create_market() -> void:
	_build_vendor(LOCATIONS["employer"], "وظائف - اعمل هنا", Color(0.15, 0.45, 0.65))
	_build_vendor(LOCATIONS["supplier"], "المورد - بضائع بالجملة", Color(0.23, 0.48, 0.31))
	stall_canvas = Node3D.new()
	stall_canvas.name = "PlayerStall"
	stall_canvas.position = LOCATIONS["stall"]
	add_child(stall_canvas)
	_box("Counter", Vector3(0, 0.85, 0), Vector3(4.4, 1.7, 1.9), Color(0.62, 0.36, 0.17), false, stall_canvas)
	_box("Stall awning", Vector3(0, 2.95, 0), Vector3(5.5, 0.25, 2.7), Color(0.77, 0.22, 0.17), false, stall_canvas)
	for i in range(5):
		_sphere("Fruit display", Vector3(-1.65 + i * 0.8, 1.84, -0.15), 0.28, Color(0.86, 0.37 + i * 0.08, 0.08), stall_canvas)
	_sign("بسطة تجارية", Vector3(0, 3.1, 0), stall_canvas, 0.005)
	shop_front = Node3D.new()
	shop_front.name = "PlayerShop"
	shop_front.position = LOCATIONS["shop"]
	add_child(shop_front)
	# The shop is an enterable interior, not a solid cube.
	_box("Store tiled floor", Vector3(0, 0.14, 0), Vector3(11.6, 0.2, 11.1), Color(0.78, 0.75, 0.66), false, shop_front)
	_box("Rear wall", Vector3(0, 2.8, -5.5), Vector3(11.6, 5.6, 0.36), Color(0.81, 0.79, 0.72), true, shop_front)
	_box("Left side wall", Vector3(-5.75, 2.8, 0), Vector3(0.36, 5.6, 11.1), Color(0.81, 0.79, 0.72), true, shop_front)
	_box("Right side wall", Vector3(5.75, 2.8, 0), Vector3(0.36, 5.6, 11.1), Color(0.81, 0.79, 0.72), true, shop_front)
	shop_roof = _box("Roof", Vector3(0, 5.65, 0), Vector3(11.9, 0.36, 11.4), Color(0.60, 0.57, 0.50), true, shop_front)
	_box("Front left", Vector3(-4.1, 2.8, 5.5), Vector3(3.0, 5.6, 0.34), Color(0.81, 0.79, 0.72), true, shop_front)
	_box("Front right", Vector3(4.1, 2.8, 5.5), Vector3(3.0, 5.6, 0.34), Color(0.81, 0.79, 0.72), true, shop_front)
	_box("Door lintel", Vector3(0, 4.9, 5.5), Vector3(5.4, 1.4, 0.34), Color(0.81, 0.79, 0.72), true, shop_front)
	_box("Shop board", Vector3(0, 5.17, 5.75), Vector3(11.1, 1.0, 0.2), Color(0.08, 0.33, 0.29), false, shop_front)
	business_sign = _sign("محل للإيجار", Vector3(0, 5.2, 5.93), shop_front, 0.008)
	street_sign = _sign("شارع السوق", Vector3(0, 4.32, 5.93), shop_front, 0.004)
	# A register with a clear customer-facing checkout lane.
	_box("Checkout register", Vector3(-3.55, 0.80, 3.0), Vector3(1.25, 1.6, 2.3), Color(0.37, 0.27, 0.20), false, shop_front)
	_box("Cash register", Vector3(-3.55, 1.68, 2.5), Vector3(0.70, 0.26, 0.55), Color(0.12, 0.16, 0.21), false, shop_front)
	_box("Register screen", Vector3(-3.55, 1.97, 2.32), Vector3(0.50, 0.47, 0.08), Color(0.17, 0.42, 0.42), false, shop_front)
	for shelf_index in range(6):
		var shelf_x: float = -3.2 + float(shelf_index % 3) * 3.2
		var shelf_z: float = -3.4 + float(floori(shelf_index / 3.0)) * 2.5
		_box("Grocery shelf backing", Vector3(shelf_x, 1.32, shelf_z), Vector3(1.65, 2.65, 0.58), Color(0.57, 0.50, 0.42), false, shop_front)
		for row_index in range(3):
			_box("Shelf tier", Vector3(shelf_x, 0.45 + float(row_index) * 0.80, shelf_z + 0.34), Vector3(1.72, 0.09, 0.76), Color(0.67, 0.58, 0.47), false, shop_front)
			for column_index in range(4):
				var item_pos: Vector3 = Vector3(shelf_x - 0.60 + float(column_index) * 0.40, 0.51 + float(row_index) * 0.80, shelf_z + 0.24)
				var food_ids := ["apple", "bread", "banana", "orange", "lemon", "egg", "carrot", "pizza", "donut", "bottle-oil"]
				var food_id: String = food_ids[(shelf_index * 5 + row_index * 4 + column_index) % food_ids.size()]
				if _licensed_model("food-kit/" + food_id, item_pos, Vector3(0.28, 0.27, 0.28), shop_front) == null:
					_box("Grocery package", item_pos, Vector3(0.25, 0.29, 0.26), PALETTE[(shelf_index + row_index + column_index) % PALETTE.size()], false, shop_front)
	# Soft overhead lights help the shop interior feel like a real place.
	for light_i in [-1, 1]:
		var lamp := OmniLight3D.new()
		lamp.name = "InteriorLight"
		lamp.position = Vector3(float(light_i) * 2.5, 4.7, -0.7)
		lamp.light_color = Color(1.0, 0.93, 0.81)
		lamp.light_energy = 0.72
		lamp.omni_range = 9.0
		lamp.shadow_enabled = false
		shop_front.add_child(lamp)
	_build_vendor(LOCATIONS["rival"], "المنافس - راقب الأسعار", Color(0.62, 0.26, 0.27))
	_build_vendor(LOCATIONS["delivery"], "التوصيل - مهمات", Color(0.45, 0.32, 0.66))
	_sign("سوق المدينة", Vector3(0, 2.8, 0), null, 0.004)

func _build_vendor(at: Vector3, title: String, awning: Color) -> void:
	var vendor := Node3D.new()
	vendor.position = at
	add_child(vendor)
	_box("Counter", Vector3(0, 0.7, 0), Vector3(3.6, 1.4, 1.65), Color(0.53, 0.33, 0.16), false, vendor)
	_box("Awning", Vector3(0, 2.85, 0), Vector3(4.4, 0.23, 2.8), awning, false, vendor)
	_cylinder("Post left", Vector3(-1.75, 1.4, -0.95), 0.09, 2.8, Color(0.30, 0.25, 0.20), vendor)
	_cylinder("Post right", Vector3(1.75, 1.4, -0.95), 0.09, 2.8, Color(0.30, 0.25, 0.20), vendor)
	_sign(title, Vector3(0, 3.05, 0), vendor, 0.005)
	_person(at + Vector3(0.4, 0, -2.1), Color(0.35, 0.33, 0.51), false)

func _person(at: Vector3, shirt: Color, wander: bool) -> void:
	var actor := Node3D.new()
	actor.position = at
	add_child(actor)
	var character_ids := ["character-male-a", "character-male-b", "character-male-c", "character-female-a", "character-female-b", "character-male-d"]
	var chosen: String = character_ids[randi() % character_ids.size()]
	var imported: Node3D = _licensed_model("mini-characters/" + chosen, Vector3.ZERO, Vector3(0.7, 1.8, 0.7), actor)
	if imported == null:
		_box("NPC clothing", Vector3(0, 1.15, 0), Vector3(0.57, 0.78, 0.35), shirt, false, actor)
	if imported == null:
		_sphere("NPC head", Vector3(0, 1.77, 0), 0.24, Color(0.66, 0.43, 0.28), actor)
	if imported == null:
		_box("NPC legs", Vector3(0, 0.43, 0), Vector3(0.46, 0.8, 0.29), Color(0.22, 0.23, 0.25), false, actor)
	if wander:
		wandering_people.append({"node": actor, "base": at, "phase": randf_range(0, TAU)})

func _create_cars_and_people() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3812
	for i in range(34):
		var x: float = float(rng.randi_range(-3, 3)) * 24.0 + 9.0
		var z: float = float(rng.randi_range(-3, 3)) * 24.0 + 6.0
		_person(Vector3(x, 0, z), PALETTE[i % PALETTE.size()], true)
	# Parking bays: use real three-dimensional car models, not rectangular placeholder cars.
	var parked_types := ["sedan", "sedan-sports", "taxi", "delivery", "hatchback-sports"]
	for i in range(9):
		if i == 4 or i == 5:
			continue # Clear the spawn and the market pedestrian crossing.
		var lane: float = float(i - 4) * 22.0
		var parked_car := Node3D.new()
		parked_car.name = "ParkedVehicle"
		parked_car.position = Vector3(lane, 0.0, 3.2)
		parked_car.rotation.y = PI / 2.0
		add_child(parked_car)
		var model: Node3D = _licensed_model("car-kit/" + parked_types[i % parked_types.size()], Vector3.ZERO, Vector3(2.0, 1.65, 4.2), parked_car)
		if model == null:
			_box("Car fallback body", Vector3(0, 0.72, 0), Vector3(1.95, 0.95, 4.1), PALETTE[i % PALETTE.size()], false, parked_car)

func _create_street_lamps() -> void:
	for x in range(-3, 4, 2):
		for z in range(-3, 4, 2):
			var at := Vector3(float(x) * 24.0 + 5, 0, float(z) * 24.0 + 5)
			_cylinder("Lamp pole", at + Vector3(0, 3.1, 0), 0.13, 6.2, Color(0.31, 0.34, 0.35))
			_sphere("Lamp light", at + Vector3(0, 6.2, 0), 0.3, Color(1.0, 0.86, 0.54))

func update_shop_roof(player_position: Vector3) -> void:
	if shop_roof == null:
		return
	var delta_pos: Vector3 = player_position - LOCATIONS["shop"]
	shop_roof.visible = not (absf(delta_pos.x) < 5.6 and absf(delta_pos.z) < 5.4)

func set_ownership(has_stall: bool, has_shop: bool, shop_name: String, road_name: String) -> void:
	if business_sign != null:
		business_sign.text = shop_name if has_shop else "محل للإيجار - 1750"
	if street_sign != null:
		street_sign.text = road_name
	if stall_canvas != null:
		stall_canvas.visible = true

func nearest_location(from_position: Vector3, max_distance: float = 7.5) -> String:
	var nearest: String = ""
	var best_distance: float = max_distance
	for location_key in LOCATIONS:
		var dist: float = from_position.distance_to(LOCATIONS[location_key])
		if dist < best_distance:
			best_distance = dist
			nearest = location_key
	return nearest

func _process(delta: float) -> void:
	time += delta
	for entry in wandering_people:
		var node: Node3D = entry["node"]
		var base: Vector3 = entry["base"]
		var phase: float = entry["phase"]
		var angle: float = time * 0.38 + phase
		node.position = base + Vector3(sin(angle) * 1.7, 0, cos(angle) * 1.5)
		node.rotation.y = angle
	if sun != null:
		sun.rotation_degrees.x = -50.0 + 17.0 * sin(time / 48.0)
		sun.light_energy = 0.65 + 0.55 * sin(time / 58.0) * sin(time / 58.0)
