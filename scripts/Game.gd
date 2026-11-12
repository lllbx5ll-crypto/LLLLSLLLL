extends Node3D
## Merchants City 3D - Al-Qmishi
## Arabic-first playable trading foundation and Android-friendly touch UI.

var economy: Node
var city: Node3D
var avatar: CharacterBody3D
var camera: Camera3D
var sound: Node
var customer_system: Node
var orbit_yaw: float = 0.0
var orbit_pitch: float = 0.32
var orbit_distance: float = 8.5
var look_finger: int = -1
var mouse_orbit: bool = false
var footstep_distance: float = 0.0
var ui_root: Control
var hud: Label
var product_info: Label
var location_info: Label
var notice_label: Label
var pop_overlay: ColorRect
var store_edit: LineEdit
var road_edit: LineEdit
var help_overlay: ColorRect
var trading_overlay: ColorRect
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
	camera.fov = 65.0
	camera.near = 0.1
	camera.far = 195.0
	camera.current = true
	add_child(camera)
	camera.position = avatar.position + Vector3(0, 4.5, 8.5)
	camera.look_at(avatar.position + Vector3(0, 1.0, 0))
	customer_system = preload("res://scripts/CustomerSystem.gd").new()
	customer_system.configure(economy, city)
	add_child(customer_system)
	sound = preload("res://scripts/SoundFX.gd").new()
	add_child(sound)
	economy.changed.connect(_on_economy_changed)
	economy.event_posted.connect(_announce)
	customer_system.customer_news.connect(_announce)
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
	if ui_root != null:
		var event_panel := ui_root.get_node_or_null("EventNoticePanel")
		if event_panel != null:
			event_panel.visible = notice_duration > 0.0
	# Orbit camera: swipe the right side of the screen, or hold right mouse button.
	var orbit_offset := Vector3(
		sin(orbit_yaw) * cos(orbit_pitch) * orbit_distance,
		sin(orbit_pitch) * orbit_distance + 1.5,
		cos(orbit_yaw) * cos(orbit_pitch) * orbit_distance
	)
	var target: Vector3 = avatar.global_position + orbit_offset
	camera.global_position = camera.global_position.lerp(target, minf(1.0, delta * 7.5))
	camera.look_at(avatar.global_position + Vector3(0, 1.45, 0))
	avatar.camera_yaw = orbit_yaw
	city.update_shop_roof(avatar.global_position)
	var move := Vector2(float(direction_keys["right"]) - float(direction_keys["left"]), float(direction_keys["down"]) - float(direction_keys["up"]))
	avatar.touch_move = move.normalized()
	# Footsteps are triggered by distance travelled, not frame rate.
	var moved: float = Vector2(avatar.position.x - previous_walk_pos.x, avatar.position.z - previous_walk_pos.z).length()
	footstep_distance += moved
	if moved > 0.015 and footstep_distance > 1.85:
		sound.effect("step")
		footstep_distance = 0.0
	if moved < 0.015:
		footstep_distance = minf(footstep_distance, 1.85)
	previous_walk_pos = avatar.position

func _input(event: InputEvent) -> void:
	if (trading_overlay != null and trading_overlay.visible) or (pop_overlay != null and pop_overlay.visible) or (help_overlay != null and help_overlay.visible):
		return
	var screen: Vector2 = get_viewport().get_visible_rect().size
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and look_finger == -1 and touch.position.x > screen.x * 0.27 and touch.position.y > screen.y * 0.22 and touch.position.y < screen.y * 0.77:
			look_finger = touch.index
		if not touch.pressed and touch.index == look_finger:
			look_finger = -1
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if drag.index == look_finger:
			_rotate_camera(drag.screen_relative)
	elif event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index == MOUSE_BUTTON_RIGHT:
			mouse_orbit = mouse_button.pressed
		elif mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_WHEEL_UP:
			orbit_distance = maxf(3.5, orbit_distance - 0.65)
		elif mouse_button.pressed and mouse_button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			orbit_distance = minf(13.0, orbit_distance + 0.65)
	elif event is InputEventMouseMotion and mouse_orbit:
		_rotate_camera((event as InputEventMouseMotion).relative)

func _rotate_camera(delta_pixels: Vector2) -> void:
	orbit_yaw = wrapf(orbit_yaw - delta_pixels.x * 0.0052, -PI, PI)
	orbit_pitch = clampf(orbit_pitch - delta_pixels.y * 0.0048, -0.12, 1.13)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E:
			_action("interact")
		elif event.keycode == KEY_TAB:
			_action("trade")
		elif event.keycode == KEY_F5:
			_action("save")
		elif event.keycode == KEY_ESCAPE:
			if trading_overlay != null:
				trading_overlay.visible = false
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
	var font_path: String = "res://assets/fonts/Cairo.ttf"
	if ResourceLoader.exists(font_path):
		ui_theme.default_font = load(font_path)
	else:
		var system_font := SystemFont.new()
		system_font.font_names = PackedStringArray(["Cairo", "Noto Sans Arabic", "DejaVu Sans"])
		ui_theme.default_font = system_font
	ui_theme.default_font_size = 19
	ui_root.theme = ui_theme

	# Only a slim HUD is visible during free exploration.
	var top_bar := _panel(Color(0.025, 0.075, 0.11, 0.91), 12)
	top_bar.anchor_left = 0.012
	top_bar.anchor_right = 0.985
	top_bar.anchor_top = 0.008
	top_bar.anchor_bottom = 0.101
	ui_root.add_child(top_bar)

	var brand := Label.new()
	brand.text = "مدينة التجار   •   AL-QMISHI"
	brand.anchor_left = 0.025
	brand.anchor_right = 0.32
	brand.anchor_top = 0.013
	brand.anchor_bottom = 0.091
	brand.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	brand.add_theme_font_size_override("font_size", 21)
	brand.add_theme_color_override("font_color", Color(0.99, 0.82, 0.52))
	ui_root.add_child(brand)

	hud = Label.new()
	hud.anchor_left = 0.33
	hud.anchor_right = 0.96
	hud.anchor_top = 0.013
	hud.anchor_bottom = 0.091
	hud.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hud.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hud.clip_text = true
	hud.add_theme_font_size_override("font_size", 21)
	hud.add_theme_color_override("font_color", Color(0.94, 0.97, 0.98))
	ui_root.add_child(hud)

	var objective_panel := _panel(Color(0.015, 0.087, 0.12, 0.79), 10)
	objective_panel.anchor_left = 0.275
	objective_panel.anchor_right = 0.76
	objective_panel.anchor_top = 0.125
	objective_panel.anchor_bottom = 0.20
	ui_root.add_child(objective_panel)
	location_info = Label.new()
	location_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	location_info.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	location_info.clip_text = true
	location_info.add_theme_font_size_override("font_size", 17)
	location_info.add_theme_color_override("font_color", Color(0.95, 0.93, 0.83))
	objective_panel.add_child(location_info)

	# A small street map in the corner, not a giant gameplay obstruction.
	var mini_map := preload("res://scripts/Minimap.gd").new()
	mini_map.name = "StreetMinimap"
	mini_map.player_ref = avatar
	mini_map.city_ref = city
	mini_map.anchor_left = 0.838
	mini_map.anchor_right = 0.98
	mini_map.anchor_top = 0.16
	mini_map.anchor_bottom = 0.40
	ui_root.add_child(mini_map)

	# The controls fit in the bottom corners. Keep streets and character visible.
	var directions := GridContainer.new()
	directions.columns = 3
	directions.anchor_left = 0.025
	directions.anchor_right = 0.25
	directions.anchor_top = 0.645
	directions.anchor_bottom = 0.965
	directions.add_theme_constant_override("h_separation", 5)
	directions.add_theme_constant_override("v_separation", 5)
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

	var interact := _button("تفاعل  E", Color(0.70, 0.46, 0.15))
	interact.anchor_left = 0.77
	interact.anchor_right = 0.96
	interact.anchor_top = 0.79
	interact.anchor_bottom = 0.87
	interact.add_theme_font_size_override("font_size", 22)
	interact.pressed.connect(func() -> void: _action("interact"))
	ui_root.add_child(interact)

	var trade := _button("إدارة التجارة  ☰", Color(0.08, 0.29, 0.36))
	trade.anchor_left = 0.77
	trade.anchor_right = 0.96
	trade.anchor_top = 0.885
	trade.anchor_bottom = 0.965
	trade.pressed.connect(func() -> void: _action("trade"))
	ui_root.add_child(trade)

	var message_panel := _panel(Color(0.018, 0.075, 0.105, 0.82), 9)
	message_panel.name = "EventNoticePanel"
	message_panel.anchor_left = 0.285
	message_panel.anchor_right = 0.735
	message_panel.anchor_top = 0.86
	message_panel.anchor_bottom = 0.964
	ui_root.add_child(message_panel)
	notice_label = Label.new()
	notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	notice_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	notice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice_label.add_theme_font_size_override("font_size", 18)
	message_panel.add_child(notice_label)

	_create_trade_popup()
	_create_sign_popup()
	_create_help_popup()
	var help_hint := Label.new()
	help_hint.text = "اسحب يمين الشاشة لتدوير الكاميرا ↑ ↓ ↔"
	help_hint.anchor_left = 0.285
	help_hint.anchor_right = 0.75
	help_hint.anchor_top = 0.81
	help_hint.anchor_bottom = 0.845
	help_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help_hint.add_theme_font_size_override("font_size", 16)
	help_hint.add_theme_color_override("font_color", Color(0.99, 0.93, 0.77))
	ui_root.add_child(help_hint)

func _create_trade_popup() -> void:
	trading_overlay = ColorRect.new()
	trading_overlay.name = "TradingMenu"
	trading_overlay.color = Color(0.015, 0.035, 0.045, 0.92)
	trading_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	trading_overlay.visible = false
	trading_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	ui_root.add_child(trading_overlay)

	var card := _panel(Color(0.06, 0.16, 0.19, 0.98), 16)
	card.anchor_left = 0.17
	card.anchor_right = 0.83
	card.anchor_top = 0.085
	card.anchor_bottom = 0.925
	trading_overlay.add_child(card)
	var main_v := VBoxContainer.new()
	main_v.add_theme_constant_override("separation", 10)
	card.add_child(main_v)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	main_v.add_child(header)
	var heading := Label.new()
	heading.text = "إدارة التجارة  |  City Business"
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_theme_font_size_override("font_size", 25)
	heading.add_theme_color_override("font_color", Color(0.98, 0.81, 0.48))
	header.add_child(heading)
	var close := _button("✕ إغلاق", Color(0.46, 0.24, 0.22))
	close.pressed.connect(func() -> void: trading_overlay.visible = false)
	header.add_child(close)

	var controls := HBoxContainer.new()
	controls.alignment = BoxContainer.ALIGNMENT_CENTER
	main_v.add_child(controls)
	var previous := _button("◀ السابق", Color(0.16, 0.34, 0.39))
	previous.pressed.connect(func() -> void: _choose_product(-1))
	controls.add_child(previous)
	var next := _button("التالي ▶", Color(0.16, 0.34, 0.39))
	next.pressed.connect(func() -> void: _choose_product(1))
	controls.add_child(next)

	product_info = Label.new()
	product_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	product_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	product_info.add_theme_font_size_override("font_size", 19)
	product_info.add_theme_color_override("font_color", Color(0.98, 0.97, 0.90))
	main_v.add_child(product_info)

	var price_tools := HBoxContainer.new()
	price_tools.alignment = BoxContainer.ALIGNMENT_CENTER
	main_v.add_child(price_tools)
	var cheaper := _button("− تخفيض سعر البيع", Color(0.43, 0.32, 0.18))
	cheaper.pressed.connect(func() -> void: _action("price_down"))
	price_tools.add_child(cheaper)
	var higher := _button("+ رفع سعر البيع", Color(0.17, 0.40, 0.30))
	higher.pressed.connect(func() -> void: _action("price_up"))
	price_tools.add_child(higher)

	var separator := HSeparator.new()
	main_v.add_child(separator)
	var action_scroll := ScrollContainer.new()
	action_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main_v.add_child(action_scroll)
	var action_grid := GridContainer.new()
	action_grid.columns = 2
	action_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_grid.add_theme_constant_override("h_separation", 10)
	action_grid.add_theme_constant_override("v_separation", 10)
	action_scroll.add_child(action_grid)
	_menu_action(action_grid, "العمل لدى التاجر", "work", Color(0.15, 0.36, 0.46))
	_menu_action(action_grid, "شراء ٣ منتجات", "buy", Color(0.13, 0.35, 0.29))
	_menu_action(action_grid, "محاسبة الزبون", "sell", Color(0.15, 0.44, 0.29))
	_menu_action(action_grid, "شراء بسطة: 250", "stall", Color(0.46, 0.32, 0.15))
	_menu_action(action_grid, "فتح محل: 1750", "shop", Color(0.46, 0.27, 0.17))
	_menu_action(action_grid, "توصيل الطلبات", "deliver", Color(0.31, 0.26, 0.43))
	_menu_action(action_grid, "توظيف عامل: 600", "hire", Color(0.27, 0.29, 0.44))
	_menu_action(action_grid, "تعديل لوحة المحل", "sign", Color(0.20, 0.39, 0.43))
	_menu_action(action_grid, "أسعار المنافسين", "rival", Color(0.46, 0.23, 0.27))
	_menu_action(action_grid, "حفظ التقدم", "save", Color(0.18, 0.35, 0.31))
	_menu_action(action_grid, "شرح اللعبة", "help", Color(0.22, 0.30, 0.38))

func _menu_action(parent: GridContainer, title: String, action: String, color: Color) -> void:
	var button := _button(title, color)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(func() -> void: _action(action))
	parent.add_child(button)

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
	information.text = "مدينة التجار | Merchants City\nالمطور: Al-Qmishi\n\n١. اذهب إلى صاحب العمل (الأزرق) واكسب أجرك.\n٢. اشترِ بضاعة من المورد (الأخضر).\n٣. افتح البسطة بـ250 عملة ثم ابدأ البيع.\n٤. نافس الأسعار واكسب 1750 لفتح محل.\n٥. خصص اللوحة بالعربية، وظّف عاملًا، واحفظ التقدم.\n\nالحركة: الأسهم أو WASD / أزرار اللمس.\nالتفاعل: E أو زر تفاعل. للمحاسبة انتظر وصول الزبائن للكاشير.\nالكاميرا: اسحب على يمين الشاشة أو زر الفأرة الأيمن؛ عجلة الفأرة للتقريب.\nجميع الأموال داخل اللعبة خيالية."
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
	hud.text = "%s     ◈  %d عملة     ★  %d     ☀  اليوم %d" % [economy.stage_name(), economy.money, economy.reputation, economy.day]
	var loc: String = city.nearest_location(avatar.position, 9.5)
	var loc_text: String = city.LOCATION_LABELS.get(loc, "استكشف المدينة")
	var queue_details: String = " | زبائن المحاسبة: %d" % customer_system.waiting_count() if customer_system != null else ""
	location_info.text = "%s  |  %s%s" % [str(loc_text), economy.objective(), queue_details]
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
		"trade":
			trading_overlay.visible = not trading_overlay.visible
			sound.effect("open")
			return
		"work":
			message = economy.work_shift() if _can_use("employer") else "اقترب من بسطة صاحب العمل الأزرق."
		"buy":
			message = economy.buy_stock(selected_product, 3) if _can_use("supplier") else "اذهب إلى المورد الأخضر في السوق."
		"sell":
			message = customer_system.checkout() if (_can_use("stall") or _can_use("shop")) else "اقترب من الكاشير في محلك أو من بسطتك."
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
					_action("shop" if not economy.shop_owned else "sell")
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
