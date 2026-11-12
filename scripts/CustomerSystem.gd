extends Node3D
## Customers actually enter the player's stall/shop, choose goods,
## walk to the register, queue and leave after checkout.
## A small capped queue prevents heavy simulation costs on mobile.

signal customer_news(message: String)
signal queue_changed()

const MAX_CUSTOMERS: int = 4
const ARRIVAL_SECONDS: float = 10.0
const ACTOR_SPEED: float = 2.35
const CHARACTERS = [
	"character-female-a", "character-male-c", "character-male-e",
	"character-female-b", "character-female-c", "character-male-d"
]

var economy: Node
var city: Node3D
var customers: Array[Dictionary] = []
var spawn_clock: float = 6.0
var serial: int = 0

func configure(economy_node: Node, city_node: Node3D) -> void:
	economy = economy_node
	city = city_node

func _ready() -> void:
	name = "CustomerSystem"

func _process(delta: float) -> void:
	if economy == null or not economy.stall_owned:
		return
	spawn_clock += delta
	if spawn_clock >= ARRIVAL_SECONDS:
		spawn_clock = 0.0
		if customers.size() < MAX_CUSTOMERS:
			_spawn()
	for customer in customers.duplicate():
		var actor: Node3D = customer["actor"]
		var route: Array = customer["route"]
		var segment: int = int(customer["segment"])
		if segment >= route.size():
			continue
		var target: Vector3 = route[segment]
		var delta_pos: Vector3 = target - actor.position
		delta_pos.y = 0.0
		if delta_pos.length() < 0.12:
			customer["segment"] = segment + 1
			if segment == 1 and economy.shop_owned and not customer["leaving"]:
				_carry_product(customer)
			if int(customer["segment"]) >= route.size():
				if customer["leaving"]:
					customers.erase(customer)
					actor.queue_free()
					queue_changed.emit()
				else:
					customer["ready"] = true
					queue_changed.emit()
			continue
		actor.position = actor.position.move_toward(Vector3(target.x, actor.position.y, target.z), ACTOR_SPEED * delta)
		actor.rotation.y = lerp_angle(actor.rotation.y, atan2(-delta_pos.x, -delta_pos.z), minf(1.0, delta * 8.0))
		var model: Node3D = customer.get("model", null)
		if model != null:
			model.position.y = 0.025 * absf(sin(Time.get_ticks_msec() * 0.012 + float(customer["id"])))

func _spawn() -> void:
	if economy == null or not economy.stall_owned:
		return
	var at_shop: bool = economy.shop_owned
	var store_center: Vector3 = city.LOCATIONS["shop"] if at_shop else city.LOCATIONS["stall"]
	var actor := Node3D.new()
	actor.name = "Customer_%03d" % serial
	actor.position = store_center + Vector3(6.5 + float(serial % 3), 0, 8.0)
	add_child(actor)
	var id_name: String = CHARACTERS[serial % CHARACTERS.size()]
	serial += 1
	var model: Node3D = null
	var path: String = "res://assets/models/mini-characters/" + id_name + ".glb"
	if ResourceLoader.exists(path):
		var scene: Resource = load(path)
		if scene is PackedScene:
			model = (scene as PackedScene).instantiate()
			actor.add_child(model)
			preload("res://scripts/ModelFit.gd").person(model, 1.7)
	if model == null:
		var mesh := MeshInstance3D.new()
		var shape := CapsuleMesh.new()
		shape.radius = 0.3
		shape.height = 1.7
		mesh.mesh = shape
		mesh.position.y = 0.85
		actor.add_child(mesh)

	var item_index: int = serial % economy.PRODUCTS.size()
	var candidates: Array[int] = []
	for i in range(economy.PRODUCTS.size()):
		if economy.stock_for(i) > 0:
			candidates.append(i)
	if not candidates.is_empty():
		item_index = candidates[serial % candidates.size()]
	var route: Array[Vector3] = []
	if at_shop:
		route = [
			store_center + Vector3(0, 0, 7.5), # enter through front door
			store_center + Vector3(1.2, 0, -2.1), # choose product at a shelf
			store_center + Vector3(-3.0, 0, 3.0 + float(customers.size() % 3) * 0.72) # cashier queue
		]
	else:
		route = [store_center + Vector3(0, 0, 2.3)]
	customers.append({
		"actor": actor, "model": model, "route": route,
		"segment": 0, "ready": false, "leaving": false,
		"id": serial, "product_index": item_index, "quantity": 1
	})
	customer_news.emit("زبون جديد يقترب من %s، توجه إلى المحاسبة." % ("محلك" if at_shop else "بسطتك"))
	queue_changed.emit()

func _carry_product(customer: Dictionary) -> void:
	# Once a shopper reaches the shelf, attach a visible grocery item in their hand.
	var index: int = int(customer["product_index"])
	var item_id: String = str(economy.product(index)["id"])
	var shapes := {
		"bread": "bread", "water": "bottle-oil", "apples": "apple",
		"rice": "bread", "milk": "bottle-oil", "coffee": "bottle-oil",
		"phones": "bottle-oil", "shirts": "bag", "tools": "bottle-oil",
		"dates": "apple", "juice": "bottle-oil", "eggs": "egg"
	}
	var model_id: String = shapes.get(item_id, "apple")
	var path: String = "res://assets/models/food-kit/" + model_id + ".glb"
	if not ResourceLoader.exists(path):
		return
	var model: Resource = load(path)
	if not model is PackedScene:
		return
	var actor: Node3D = customer["actor"]
	var prop: Node3D = (model as PackedScene).instantiate()
	prop.name = "SelectedProduct"
	actor.add_child(prop)
	prop.position = Vector3(0.38, 1.10, -0.27)
	preload("res://scripts/ModelFit.gd").product(prop, 0.30)
	customer["held_product"] = prop

func waiting_count() -> int:
	var count: int = 0
	for customer in customers:
		if bool(customer["ready"]) and not bool(customer["leaving"]):
			count += 1
	return count

func next_item_name() -> String:
	for customer in customers:
		if customer["ready"] and not customer["leaving"]:
			return str(economy.product(int(customer["product_index"]))["name"])
	return "لا يوجد زبون عند المحاسبة"

func checkout() -> String:
	if economy == null or not economy.stall_owned:
		return "اشترِ بسطة ووفّر منتجات أولاً."
	for customer in customers:
		if not customer["ready"] or customer["leaving"]:
			continue
		var idx: int = int(customer["product_index"])
		var before: int = economy.sold_count
		var result: String = economy.sell_stock(idx, int(customer["quantity"]))
		if economy.sold_count == before:
			return result
		customer["ready"] = false
		customer["leaving"] = true
		if customer.has("held_product") and is_instance_valid(customer["held_product"]):
			(customer["held_product"] as Node).queue_free()
		var entrance: Vector3 = city.LOCATIONS["shop"] if economy.shop_owned else city.LOCATIONS["stall"]
		customer["route"] = [entrance + Vector3(1, 0, 7.5), entrance + Vector3(9, 0, 10)]
		customer["segment"] = 0
		queue_changed.emit()
		return "المحاسبة تمت! الزبون استلم %s. %s" % [economy.product(idx)["name"], result]
	return "لا يوجد زبون جاهز الآن. الزبائن يدخلون ويتسوقون ثم يتوجهون للمحاسبة."

func debug_spawn_customer() -> void:
	_spawn()

func debug_mark_arrived() -> void:
	for customer in customers:
		customer["segment"] = customer["route"].size()
		customer["ready"] = true
