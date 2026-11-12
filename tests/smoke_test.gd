extends SceneTree
## Non-visual automated check: load all scripts, test the buy/sell and saving loop.

func _initialize() -> void:
	call_deferred("_run_checks")

func _run_checks() -> void:
	var scripts := [
		"res://scripts/Economy.gd", "res://scripts/Avatar.gd",
		"res://scripts/City.gd", "res://scripts/Game.gd", "res://scripts/SoundFX.gd"
	]
	for path in scripts:
		var loaded = load(path)
		if loaded == null:
			push_error("Could not load game script: " + path)
			quit(1)
			return
	var game_system = load("res://scripts/Economy.gd").new()
	get_root().add_child(game_system)
	game_system.money = 10000
	var result: String = game_system.buy_stall()
	if not game_system.stall_owned:
		push_error("Stall purchase regression: " + result)
		quit(1)
		return
	result = game_system.buy_stock(0, 3)
	if game_system.stock_for(0) != 3:
		push_error("Inventory regression: " + result)
		quit(1)
		return
	var before: int = game_system.money
	result = game_system.sell_stock(0, 1)
	if game_system.stock_for(0) != 2 or game_system.money <= before:
		push_error("Sales regression: " + result)
		quit(1)
		return
	print("SMOKE PASS: Scripts load, stall, inventory, buying, selling and cash flow")
	quit()
