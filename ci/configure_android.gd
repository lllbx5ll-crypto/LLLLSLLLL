extends SceneTree

func _initialize() -> void:
	var editor_settings: EditorSettings = EditorInterface.get_editor_settings()
	editor_settings.set_setting("export/android/android_sdk_path", OS.get_environment("ANDROID_HOME"))
	editor_settings.set_setting("export/android/java_sdk_path", OS.get_environment("JAVA_HOME"))
	print("Android SDK: ", editor_settings.get_setting("export/android/android_sdk_path"))
	print("Java SDK: ", editor_settings.get_setting("export/android/java_sdk_path"))
	quit()
