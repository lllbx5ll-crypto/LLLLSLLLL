extends Node3D
## Merchants City 3D - Al-Qmishi
## Arabic-first playable trading foundation and Android-friendly touch UI.

var economy: Node
var city: Node3D
var avatar: CharacterBody3D
var camera: Camera3D
var sound: Node
var ui_root: Control
var hud: Label
var product_info: Label
var location_info: Label
var notice_label: Label
var pop_overlay: ColorRect
var store_edit: LineEdit
var road_edit: LineEdit
var help_overlay: ColorRect
var selected_product: int = 0
var direction_keys: Dictionary = {"up": false, "down": false, "left": false, "right": false}
var notice_duration: float = 0.0
var hud_clock: float = 0.0
var previous_walk_pos: Vector3
var walking_sfx_timer: float = 0.0

func _ready() -> void:
	name = "MerchantsCity"
	economy = preload("res://scripts/Economy.gd").new()
	add_child(economy)
	city = preload("res://scripts/City.gd").new()
	add_child(city)
	var traffic: Node3D = preload("res://scripts/Traffic.gd").new()
	add_child(traffic)
	avatar = preload("res://scripts/Avatar.gd").new()
	avatar.position = Vector3(0, 0.3, 0)
	add_child(avatar)
	camera = Camera3D.new()
	camera.name = "ThirdPersonCamera"
	camera.fov = 67.0
	camera.near = 0.1
	camera.far = 195.0
	camera.current = true
	add_child(camera)
	camera.position = avatar.position + Vector3(0, 8.3, 13.0)
	camera.look_at(avatar.position + Vector3(0, 1.0, 0))
	sound = preload("res://scripts/SoundFX.gd").new()
	add_child(sound)
	economy.changed.connect(_on_economy_changed)
	economy.event_posted.connect(_announce)
	_create_interface()
	_on_economy_changed()
	_start_credits()
	previous_walk_pos = avatar.position

func _process(delta: float) -> void:
	hud_clock -= delta
	if hud_clock <= 0.0:
		hud_clock = 0.25
		_update_hud()
	if notice_duration > 0.0:
		notice_duration -= delta
		if notice_duration <= 0.0:
			notice_label.text = ""
	var target: Vector3 = avatar.position + Vector3(0, 8.4, 13.0)
	camera.position = camera.position.lerp(target, minf(1.0, delta * 5.0))
	camera.look_at(avatar.position + Vector3(0, 1.1, 0))
	var move := Vector2(float(direction_keys["right"]) - float(direction_keys["left"]), float(direction_keys["down"]) - float(direction_keys["up"]))
	avatar.touch_move = move.normalized()
	if avatar.position.distance_to(previous_walk_pos) > 0.03:
		walking_sfx_timer += delta
		if walking_sfx_timer >= 0.52:
			sound.effect("step")
			walking_sfx_timer = 0.0
	previous_walk_pos = avatar.position

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E:
			_action("interact")
		elif event.keycode == KEY_F5:
			_action("save")
		elif event.keycode == KEY_ESCAPE:
			if pop_overlay != null:
				pop_overlay.visible = false
			if help_overlay != null:
				help_overlay.visible = false

func _create_interface() -> void:
	var layer := CanvasLayer.new()
	layer.name = "ArabicUI"
	add_child(layer)
	ui_root = Control.new()
	ui_root.name = "UIRoot"
	ui_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui_root)
	var ui_theme := Theme.new()
	var arabic := SystemFont.new()
	arabic.font_names = PackedStringArray(["Noto Naskh Arabic", "Noto Sans Arabic", "DejaVu Sans"])
	ui_theme.default_font = arabic
	ui_theme.default_font_size = 22
	ui_root.theme = ui_theme

	# Header strip: player progression.
	var header := _panel(Color(0.035, 0.095, 0.14, 0.92), 10)
	header.anchor_left = 0.01
	header.anchor_right = 0.99
	header.anchor_top = 0.01
	header.anchor_bottom = 0.01
	header.offset_bottom = 112
	ui_root.add_child(header)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 3)
	header.add_child(stack)
	hud = Label.new()
	hud.add_theme_font_size_override("font_size", 23)
	hud.add_theme_color_override("font_color", Color(1.0, 0.89, 0.61))
	hud.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(hud)
	location_info = Label.new()
	location_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	location_info.add_theme_font_size_override("font_size", 18)
	location_info.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0))
	stack.add_child(location_info)

	# Street minimap: roads, shops, suppliers, player and current heading.
	var mini_map := preload("res://scripts/Minimap.gd").new()
	mini_map.name = "StreetMinimap"
	mini_map.player_ref = avatar
	mini_map.city_ref = city
	mini_map.anchor_left = 0.015
	mini_map.anchor_right = 0.21
	mini_map.anchor_top = 0.19
	mini_map.anchor_bottom = 0.51
	ui_root.add_child(mini_map)

	# Product and competitor data.
	var product_panel := _panel(Color(0.045, 0.12, 0.17, 0.93), 10)
	product_panel.anchor_left = 0.30
	product_panel.anchor_right = 0.70
	product_panel.anchor_top = 0.19
	product_panel.anchor_bottom = 0.43
	ui_root.add_child(product_panel)
	var product_v := VBoxContainer.new()
	product_panel.add_child(product_v)
	var selection := HBoxContainer.new()
	selection.alignment = BoxContainer.ALIGNMENT_CENTER
	product_v.add_child(selection)
	var prev := _button("◀ السابق", Color(0.20, 0.33, 0.38))
	prev.pressed.connect(func() -> void: _choose_product(-1))
	selection.add_child(prev)
	var next := _button("التالي ▶", Color(0.20, 0.33, 0.38))
	next.pressed.connect(func() -> void: _choose_product(1))
	selection.add_child(next)
	product_info = Label.new()
	product_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	product_info.add_theme_font_size_override("font_size", 20)
	product_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	product_v.add_child(product_info)
	var prices := HBoxContainer.new()
	prices.alignment = BoxContainer.ALIGNMENT_CENTER
	product_v.add_child(prices)
	var lower := _button("خفض السعر −", Color(0.35, 0.25, 0.16))
	lower.pressed.connect(func() -> void: _action("price_down"))
	prices.add_child(lower)
	var higher := _button("رفع السعر +", Color(0.18, 0.37, 0.29))
	higher.pressed.connect(func() -> void: _action("price_up"))
	prices.add_child(higher)

	# Scrollable right-side action buttons.
	var side_panel := _panel(Color(0.045, 0.11, 0.16, 0.93), 10)
	side_panel.anchor_left = 0.74
	side_panel.anchor_right = 0.99
	side_panel.anchor_top = 0.20
	side_panel.anchor_bottom = 0.96
	ui_root.add_child(side_panel)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	side_panel.add_child(scroll)
	var commands := VBoxContainer.new()
	commands.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	commands.add_theme_constant_override("separation", 7)
	scroll.add_child(commands)
	_add_action(commands, "🤝 اشتغل عند التاجر", "work", Color(0.14, 0.39, 0.53))
	_add_action(commands, "📦 شراء 3 منتجات", "buy", Color(0.20, 0.38, 0.33))
	_add_action(commands, "💰 بيع منتج", "sell", Color(0.22, 0.43, 0.32))
	_add_action(commands, "🛒 شراء بسطة (250)", "stall", Color(0.52, 0.36, 0.15))
	_add_action(commands, "🏪 فتح محل (1750)", "shop", Color(0.49, 0.32, 0.17))
	_add_action(commands, "🚚 توصيل طلب", "deliver", Color(0.30, 0.25, 0.48))
	_add_action(commands, "👷 تعيين عامل (600)", "hire", Color(0.37, 0.30, 0.51))
	_add_action(commands, "✍ تعديل لوحة المحل", "sign", Color(0.20, 0.42, 0.46))
	_add_action(commands, "📈 أسعار المنافس", "rival", Color(0.44, 0.24, 0.26))
	_add_action(commands, "💾 حفظ التقدم", "save", Color(0.22, 0.35, 0.29))
	_add_action(commands, "❔ شرح اللعبة", "help", Color(0.25, 0.30, 0.40))

	# Direction controls: work on Android and desktop.
	var directions := GridContainer.new()
	directions.columns = 3
	directions.anchor_left = 0.02
	directions.anchor_right = 0.29
	directions.anchor_top = 0.65
	directions.anchor_bottom = 0.97
	directions.add_theme_constant_override("h_separation", 7)
	directions.add_theme_constant_override("v_separation", 7)
	ui_root.add_child(directions)
	_add_empty_cell(directions)
	_add_direction(directions, "▲", "up")
	_add_empty_cell(directions)
	_add_direction(directions, "◀", "left")
	_add_empty_cell(directions)
	_add_direction(directions, "▶", "right")
	_add_empty_cell(directions)
	_add_direction(directions, "▼", "down")
	_add_empty_cell(directions)

	var interact := _button("تفاعل  E", Color(0.64, 0.40, 0.16))
	interact.anchor_left = 0.43
	interact.anchor_right = 0.60
	interact.anchor_top = 0.84
	interact.anchor_bottom = 0.94
	interact.pressed.connect(func() -> void: _action("interact"))
	ui_root.add_child(interact)

	var message_panel := _panel(Color(0.03, 0.09, 0.13, 0.85), 8)
	message_panel.anchor_left = 0.29
	message_panel.anchor_right = 0.72
	message_panel.anchor_top = 0.64
	message_panel.anchor_bottom = 0.78
	ui_root.add_child(message_panel)
	notice_label = Label.new()
	notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	notice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice_label.add_theme_font_size_override("font_size", 19)
	message_panel.add_child(notice_label)

	_create_sign_popup()
	_create_help_popup()

func _panel(bg: Color, corner: int = 12) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(corner)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 9
	style.content_margin_bottom = 9
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _button(caption: String, bg: Color) -> Button:
	var button := Button.new()
	button.text = caption
	button.custom_minimum_size = Vector2(0, 47)
	button.add_theme_font_size_override("font_size", 18)
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 6
	style.content_margin_bottom = 6
	button.add_theme_stylebox_override("normal", style)
	var hover: StyleBoxFlat = style.duplicate()
	hover.bg_color = bg.lightened(0.15)
	button.add_theme_stylebox_override("hover", hover)
	var pressed: StyleBoxFlat = style.duplicate()
	pressed.bg_color = bg.darkened(0.24)
	button.add_theme_stylebox_override("pressed", pressed)
	return button

func _add_action(parent: VBoxContainer, caption: String, action: String, tint: Color) -> void:
	var button := _button(caption, tint)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(func() -> void: _action(action))
	parent.add_child(button)

func _add_empty_cell(grid: GridContainer) -> void:
	var placeholder := Control.new()
	placeholder.custom_minimum_size = Vector2(70, 54)
	placeholder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(placeholder)

func _add_direction(grid: GridContainer, caption: String, direction: String) -> void:
	var button := _button(caption, Color(0.10, 0.27, 0.36, 0.95))
	button.custom_minimum_size = Vector2(70, 54)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.button_down.connect(func() -> void: direction_keys[direction] = true)
	button.button_up.connect(func() -> void: direction_keys[direction] = false)
	grid.add_child(button)

func _create_sign_popup() -> void:
	pop_overlay = ColorRect.new()
	pop_overlay.color = Color(0.0, 0.02, 0.04, 0.87)
	pop_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pop_overlay.visible = false
	pop_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_root.add_child(pop_overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	pop_overlay.add_child(center)
	var card := _panel(Color(0.07, 0.17, 0.22), 18)
	card.custom_minimum_size = Vector2(520, 365)
	center.add_child(card)
	var vertical := VBoxContainer.new()
	card.add_child(vertical)
	var headline := Label.new()
	headline.text = "تعديل لوحة محلك بالعربية"
	headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	headline.add_theme_font_size_override("font_size", 28)
	vertical.add_child(headline)
	var label_name := Label.new()
	label_name.text = "اسم المحل"
	vertical.add_child(label_name)
	store_edit = LineEdit.new()
	store_edit.max_length = 32
	store_edit.text = economy.store_name
	vertical.add_child(store_edit)
	var label_road := Label.new()
	label_road.text = "اسم الشارع"
	vertical.add_child(label_road)
	road_edit = LineEdit.new()
	road_edit.max_length = 32
	road_edit.text = economy.street_name
	vertical.add_child(road_edit)
	var save_button := _button("✅ تأكيد وحفظ اللوحة", Color(0.16, 0.44, 0.29))
	save_button.pressed.connect(_save_sign)
	vertical.add_child(save_button)
	var cancel_button := _button("إلغاء", Color(0.43, 0.24, 0.26))
	cancel_button.pressed.connect(func() -> void: pop_overlay.visible = false)
	vertical.add_child(cancel_button)

func _create_help_popup() -> void:
	help_overlay = ColorRect.new()
	help_overlay.color = Color(0.0, 0.02, 0.04, 0.9)
	help_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	help_overlay.visible = false
	ui_root.add_child(help_overlay)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	help_overlay.add_child(center)
	var card := _panel(Color(0.08, 0.16, 0.21), 16)
	card.custom_minimum_size = Vector2(700, 420)
	center.add_child(card)
	var vertical := VBoxContainer.new()
	card.add_child(vertical)
	var information := Label.new()
	information.text = "مدينة التجار | Merchants City\nالمطور: Al-Qmishi\n\n١. اذهب إلى صاحب العمل (الأزرق) واكسب أجرك.\n٢. اشترِ بضاعة من المورد (الأخضر).\n٣. افتح البسطة بـ250 عملة ثم ابدأ البيع.\n٤. نافس الأسعار واكسب 1750 لفتح محل.\n٥. خصص اللوحة بالعربية، وظّف عاملًا، واحفظ التقدم.\n\nالحركة: الأسهم أو WASD / أزرار اللمس.\nالتفاعل: E أو زر تفاعل. جميع الأموال داخل اللعبة خيالية."
	information.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	information.add_theme_font_size_override("font_size", 22)
	vertical.add_child(information)
	var dismiss := _button("ابدأ اللعب", Color(0.17, 0.43, 0.30))
	dismiss.pressed.connect(func() -> void: help_overlay.visible = false)
	vertical.add_child(dismiss)

func _start_credits() -> void:
	var splash := ColorRect.new()
	splash.name = "DeveloperCredits"
	splash.color = Color(0.035, 0.085, 0.13, 0.98)
	splash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui_root.add_child(splash)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	splash.add_child(center)
	var vertical := VBoxContainer.new()
	vertical.alignment = BoxContainer.ALIGNMENT_CENTER
	vertical.add_theme_constant_override("separation", 15)
	center.add_child(vertical)
	for title in ["AL-QMISHI PRESENTS", "مدينة التجار", "MERCHANTS CITY", "Developed by Al-Qmishi", "© 2026 Al-Qmishi"]:
		var label := Label.new()
		label.text = title
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 43 if title == "مدينة التجار" else 26)
		label.add_theme_color_override("font_color", Color(0.94, 0.77, 0.43))
		vertical.add_child(label)
	var tween := create_tween()
	tween.tween_interval(2.5)
	tween.tween_property(splash, "modulate:a", 0.0, 0.9)
	tween.tween_callback(splash.queue_free)

func _choose_product(step: int) -> void:
	selected_product = posmod(selected_product + step, economy.PRODUCTS.size())
	sound.effect("coin")
	_update_hud()

func _on_economy_changed() -> void:
	if city != null:
		city.set_ownership(economy.stall_owned, economy.shop_owned, economy.store_name, economy.street_name)
	_update_hud()

func _announce(message: String) -> void:
	if notice_label != null:
		notice_label.text = message
		notice_duration = 5.0

func _update_hud() -> void:
	if hud == null:
		return
	hud.text = "مدينة التجار  |  %s  |  المال: %d  |  السمعة: %d  |  اليوم: %d" % [economy.stage_name(), economy.money, economy.reputation, economy.day]
	var loc: String = city.nearest_location(avatar.position, 9.5)
	var loc_text: String = city.LOCATION_LABELS.get(loc, "استكشف المدينة")
	location_info.text = "%s  |  %s" % [str(loc_text), economy.objective()]
	var item: Dictionary = economy.product(selected_product)
	product_info.text = "%s  |  مخزونك: %d\nسعر المورد: %d  |  سعرك: %d  |  سعر المنافس: %d" % [
		str(item["name"]), economy.stock_for(selected_product), economy.buy_cost(selected_product),
		economy.selling_price(selected_product), economy.competitor_price(selected_product)
	]

func _can_use(at: String) -> bool:
	return city.nearest_location(avatar.position, 8.5) == at

func _do_economic_result(message: String) -> void:
	_announce(message)
	var failure: bool = message.begins_with("لا ") or message.contains("أولاً") or message.contains("غير كاف") or message.contains("تحتاج")
	sound.effect("error" if failure else "coin")
	_update_hud()

func _action(action: String) -> void:
	var message: String = ""
	match action:
		"work":
			message = economy.work_shift() if _can_use("employer") else "اقترب من بسطة صاحب العمل الأزرق."
		"buy":
			message = economy.buy_stock(selected_product, 3) if _can_use("supplier") else "اذهب إلى المورد الأخضر في السوق."
		"sell":
			message = economy.sell_stock(selected_product, 1) if (_can_use("stall") or _can_use("shop")) else "اقترب من بسطة البيع أو محلك."
		"stall":
			message = economy.buy_stall() if _can_use("stall") else "اذهب إلى موقع البسطة الحمراء."
		"shop":
			message = economy.buy_shop() if _can_use("shop") else "اذهب إلى واجهة المحل."
		"deliver":
			message = economy.delivery_job() if _can_use("delivery") else "اذهب إلى نقطة التوصيل البنفسجية."
		"hire":
			message = economy.hire_worker() if _can_use("shop") else "اذهب إلى محلك لتعيين عامل."
		"sign":
			if economy.shop_owned and _can_use("shop"):
				store_edit.text = economy.store_name
				road_edit.text = economy.street_name
				pop_overlay.visible = true
				sound.effect("open")
				return
			message = "افتح محلاً واقترب منه أولاً لتغيير اللوحة."
		"rival":
			message = "المنافس يبيع %s بـ%d عملة. يمكنك رفع أو خفض سعرك." % [economy.product(selected_product)["name"], economy.competitor_price(selected_product)]
		"price_up":
			message = economy.change_price(selected_product, 1)
		"price_down":
			message = economy.change_price(selected_product, -1)
		"save":
			message = "تم حفظ تقدمك بنجاح." if economy.save_game() else "لم ينجح حفظ اللعبة."
		"help":
			help_overlay.visible = true
			return
		"interact":
			var location: String = city.nearest_location(avatar.position, 8.5)
			match location:
				"employer":
					_action("work")
				"supplier":
					_action("buy")
				"stall":
					_action("sell" if economy.stall_owned else "stall")
				"shop":
					_action("shop" if not economy.shop_owned else "sign")
				"rival":
					_action("rival")
				"delivery":
					_action("deliver")
				_:
					_announce("اقترب من أحد التجار أو المتاجر المعلّمة بلوحة عربية.")
			return
		_:
			message = "أمر غير معروف."
	_do_economic_result(message)

func _save_sign() -> void:
	_do_economic_result(economy.set_sign(store_edit.text, road_edit.text))
	economy.save_game()
	pop_overlay.visible = false
