extends Node
## Simulation-only business game systems. All currency amounts are fictional.

signal changed
signal event_posted(message: String)

const PRODUCTS = [
	{"id": "bread", "name": "خبز طازج", "cost": 6, "price": 11},
	{"id": "water", "name": "مياه معدنية", "cost": 8, "price": 14},
	{"id": "apples", "name": "تفاح", "cost": 12, "price": 21},
	{"id": "rice", "name": "أرز", "cost": 22, "price": 37},
	{"id": "milk", "name": "حليب", "cost": 15, "price": 27},
	{"id": "coffee", "name": "قهوة", "cost": 25, "price": 44},
	{"id": "phones", "name": "هواتف", "cost": 180, "price": 290},
	{"id": "shirts", "name": "ملابس", "cost": 45, "price": 79},
	{"id": "tools", "name": "أدوات منزلية", "cost": 32, "price": 55},
	{"id": "dates", "name": "تمور", "cost": 14, "price": 25},
	{"id": "juice", "name": "عصير", "cost": 10, "price": 18},
	{"id": "eggs", "name": "بيض", "cost": 17, "price": 29}
]
const SAVE_FILE = "user://merchant_save_v1.json"

var money: int = 70
var reputation: int = 1
var experience: int = 0
var day: int = 1
var stall_owned: bool = false
var shop_owned: bool = false
var worker_owned: bool = false
var sold_count: int = 0
var work_count: int = 0
var deliveries: int = 0
var store_name: String = "متجر الأمل"
var street_name: String = "شارع السوق"
var inventory: Dictionary = {}
var price_adjustments: Dictionary = {}
var market_shift: float = 1.0
var rival_price_factor: float = 1.0
var game_day_clock: float = 0.0
var work_cooldown: float = 0.0
var last_report: String = "ابحث عن التاجر للعمل واجمع رأس المال."

func _ready() -> void:
	for item in PRODUCTS:
		inventory[item["id"]] = 0
		price_adjustments[item["id"]] = 0
	load_game()

func _process(delta: float) -> void:
	work_cooldown = maxf(0.0, work_cooldown - delta)
	game_day_clock += delta
	if game_day_clock >= 90.0:
		game_day_clock = 0.0
		advance_day()

func product(index: int) -> Dictionary:
	return PRODUCTS[clampi(index, 0, PRODUCTS.size() - 1)]

func buy_cost(index: int) -> int:
	var item: Dictionary = product(index)
	return maxi(1, roundi(float(item["cost"]) * market_shift))

func competitor_price(index: int) -> int:
	var item: Dictionary = product(index)
	return maxi(2, roundi(float(item["price"]) * rival_price_factor))

func selling_price(index: int) -> int:
	var item: Dictionary = product(index)
	return maxi(1, roundi(float(item["price"]) + float(price_adjustments.get(item["id"], 0))))

func stock_for(index: int) -> int:
	return int(inventory.get(product(index)["id"], 0))

func work_shift() -> String:
	if work_cooldown > 0.0:
		return "استرح قليلاً قبل بدء العمل التالي."
	var wage: int = 38 + mini(work_count, 8) * 3
	money += wage
	experience += 10
	work_count += 1
	work_cooldown = 7.0
	changed.emit()
	return "أنهيت العمل! أجرك: %d عملة. يمكنك شراء بضاعة من المورد." % wage

func delivery_job() -> String:
	if work_cooldown > 0.0:
		return "لا تزال في فترة الراحة."
	if not stall_owned:
		return "افتح بسطة أولاً حتى تتمكن من توصيل منتجاتك."
	var pay: int = 55 + day * 2
	money += pay
	deliveries += 1
	experience += 6
	work_cooldown = 10.0
	changed.emit()
	return "تم توصيل الطلب بنجاح. ربحت %d عملة." % pay

func buy_stock(index: int, quantity: int = 3) -> String:
	if quantity < 1:
		return "الكمية غير صالحة."
	var total: int = buy_cost(index) * quantity
	if money < total:
		return "لا تملك المال الكافي! تحتاج إلى %d عملة." % total
	var item: Dictionary = product(index)
	money -= total
	inventory[item["id"]] = int(inventory[item["id"]]) + quantity
	experience += 2
	changed.emit()
	return "اشتريت %d من %s مقابل %d عملة." % [quantity, item["name"], total]

func sell_stock(index: int, quantity: int = 1) -> String:
	if not stall_owned:
		return "افتح بسطة أولاً حتى تتمكن من البيع."
	var item: Dictionary = product(index)
	if stock_for(index) < quantity:
		return "المخزون غير كافٍ. اذهب إلى المورد أولاً."
	var asking_price: int = selling_price(index)
	var rival_price: int = competitor_price(index)
	if asking_price > int(rival_price * 1.6):
		return "الزبائن يرفضون السعر المرتفع. خفّض السعر لتنافس!"
	var revenue: int = asking_price * quantity
	money += revenue
	inventory[item["id"]] = stock_for(index) - quantity
	sold_count += quantity
	reputation += 1
	experience += 4
	changed.emit()
	return "بعت %d من %s وحصلت على %d عملة." % [quantity, item["name"], revenue]

func change_price(index: int, direction: int) -> String:
	var item: Dictionary = product(index)
	var current: int = int(price_adjustments.get(item["id"], 0))
	price_adjustments[item["id"]] = clampi(current + direction, -int(item["price"]) + 1, int(item["price"]))
	changed.emit()
	return "سعر %s الآن %d (المنافس: %d)." % [item["name"], selling_price(index), competitor_price(index)]

func buy_stall() -> String:
	if stall_owned:
		return "أنت تملك بسطة بالفعل."
	if money < 250:
		return "البسطة تكلف 250 عملة. اعمل واجمع المال أولاً."
	money -= 250
	stall_owned = true
	reputation += 6
	experience += 40
	changed.emit()
	return "مبروك! اشتريت أول بسطة. الآن التجارة بدأت!"

func buy_shop() -> String:
	if not stall_owned:
		return "اشترِ بسطة أولاً."
	if shop_owned:
		return "أنت تملك محلاً بالفعل."
	if money < 1750:
		return "فتح المحل يكلف 1750 عملة."
	money -= 1750
	shop_owned = true
	reputation += 22
	experience += 100
	changed.emit()
	return "افتتحت محلك! يمكنك تغيير اسمه وتوظيف عامل."

func hire_worker() -> String:
	if not shop_owned:
		return "يجب أن تمتلك محلاً أولاً."
	if worker_owned:
		return "لديك عامل بالفعل."
	if money < 600:
		return "التوظيف يحتاج 600 عملة."
	money -= 600
	worker_owned = true
	changed.emit()
	return "تم توظيف عامل. سيدير مبيعات تلقائية من مخزونك كل يوم."

func set_sign(shop_title: String, road_title: String) -> String:
	var s: String = shop_title.strip_edges().substr(0, 32)
	var r: String = road_title.strip_edges().substr(0, 32)
	if s.is_empty():
		return "أدخل اسمًا للمحل."
	store_name = s
	if not r.is_empty():
		street_name = r
	changed.emit()
	return "تم تعديل لوحة المحل: " + store_name

func advance_day() -> void:
	day += 1
	market_shift = randf_range(0.85, 1.22)
	rival_price_factor = randf_range(0.82, 1.16)
	var report: String = "اليوم %d: تغيّرت أسعار السوق." % day
	if worker_owned:
		var automatic_profit: int = 0
		for i in range(PRODUCTS.size()):
			if stock_for(i) > 0:
				var item: Dictionary = product(i)
				inventory[item["id"]] = stock_for(i) - 1
				automatic_profit += selling_price(i)
		money += automatic_profit
		money = maxi(money - 18, 0)
		report += " العامل باع بضائع بقيمة %d ودُفع راتبه 18." % automatic_profit
	if shop_owned:
		money = maxi(money - 12, 0)
		report += " إيجار المحل: 12."
	last_report = report
	event_posted.emit(report)
	changed.emit()
	save_game()

func stage_name() -> String:
	if shop_owned:
		return "صاحب محل"
	if stall_owned:
		return "صاحب بسطة"
	return "عامل مبتدئ"

func objective() -> String:
	if not stall_owned:
		return "هدفك: اجمع 250 عملة واشترِ البسطة."
	if not shop_owned:
		return "هدفك: بِع المنتجات واجمع 1750 لفتح محل."
	if not worker_owned:
		return "هدفك: وظّف عاملاً بـ600 عملة."
	return "الهدف: طور تجارتك وتفوّق على أسعار المنافسين."

func save_game() -> bool:
	var file := FileAccess.open(SAVE_FILE, FileAccess.WRITE)
	if file == null:
		return false
	var payload: Dictionary = {
		"money": money, "reputation": reputation, "experience": experience,
		"day": day, "stall_owned": stall_owned, "shop_owned": shop_owned,
		"worker_owned": worker_owned, "sold_count": sold_count, "work_count": work_count,
		"deliveries": deliveries, "store_name": store_name, "street_name": street_name,
		"inventory": inventory, "price_adjustments": price_adjustments,
		"market_shift": market_shift, "rival_price_factor": rival_price_factor
	}
	file.store_string(JSON.stringify(payload))
	file.close()
	return true

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_FILE):
		return false
	var file := FileAccess.open(SAVE_FILE, FileAccess.READ)
	if file == null:
		return false
	var json := JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return false
	if not json.data is Dictionary:
		return false
	var d: Dictionary = json.data
	money = int(d.get("money", money))
	reputation = int(d.get("reputation", reputation))
	experience = int(d.get("experience", experience))
	day = int(d.get("day", day))
	stall_owned = bool(d.get("stall_owned", stall_owned))
	shop_owned = bool(d.get("shop_owned", shop_owned))
	worker_owned = bool(d.get("worker_owned", worker_owned))
	sold_count = int(d.get("sold_count", sold_count))
	work_count = int(d.get("work_count", work_count))
	deliveries = int(d.get("deliveries", deliveries))
	store_name = str(d.get("store_name", store_name))
	street_name = str(d.get("street_name", street_name))
	market_shift = float(d.get("market_shift", 1.0))
	rival_price_factor = float(d.get("rival_price_factor", 1.0))
	var stock: Dictionary = d.get("inventory", {})
	var adjustments: Dictionary = d.get("price_adjustments", {})
	for item in PRODUCTS:
		var key: String = item["id"]
		inventory[key] = maxi(0, int(stock.get(key, 0)))
		price_adjustments[key] = int(adjustments.get(key, 0))
	changed.emit()
	return true
