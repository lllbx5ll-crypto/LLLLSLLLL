extends SceneTree
## Real scene screenshot on CI's software OpenGL renderer.

func _initialize() -> void:
	call_deferred("_capture_game")

func _capture_game() -> void:
	var main_scene: PackedScene = load("res://scenes/Main.tscn")
	if main_scene == null:
		push_error("Cannot load scene for screenshot")
		quit(1)
		return
	get_root().add_child(main_scene.instantiate())
	await create_timer(4.0).timeout
	var picture: Image = get_root().get_texture().get_image()
	if picture == null or picture.is_empty():
		push_warning("Preview screenshot not available on current rendering backend")
		quit()
		return
	var code: int = picture.save_png("res://build/preview.png")
	if code != OK:
		push_warning("Preview image save failed: %d" % code)
	else:
		print("VISUAL PREVIEW SAVED")
	quit()
