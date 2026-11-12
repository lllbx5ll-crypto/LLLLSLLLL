extends SceneTree
## Initialize a real game scene in headless mode and detect critical startup regressions.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: PackedScene = load("res://scenes/Main.tscn")
	if scene == null:
		push_error("Main scene could not be loaded")
		quit(1)
		return
	var game: Node3D = scene.instantiate()
	get_root().add_child(game)
	await process_frame
	await process_frame
	if game.get_node_or_null("ProceduralCity") == null:
		push_error("World did not initialize")
		quit(1)
		return
	if game.get_node_or_null("Player") == null:
		push_error("Player did not initialize")
		quit(1)
		return
	if game.get_node_or_null("Traffic") == null:
		push_error("City traffic did not initialize")
		quit(1)
		return
	if game.get_node_or_null("ArabicUI") == null:
		push_error("Arabic HUD did not initialize")
		quit(1)
		return
	print("WORLD SMOKE PASS: scene, world, traffic, player and Arabic UI loaded")
	game.queue_free()
	await process_frame
	quit()
