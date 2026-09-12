extends CanvasLayer
## 游戏内暂停菜单：按 ESC 打开/关闭，提供继续、设置、回主菜单和退出。


func _ready() -> void:
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not event.is_echo():
		if visible:
			resume_game()
		else:
			pause_game()


func pause_game() -> void:
	visible = true
	get_tree().paused = true
	$Root/CenterContainer/PausePanel/PauseBox/ContinueButton.grab_focus()


func resume_game() -> void:
	_play_ui_sound()
	visible = false
	get_tree().paused = false


func _on_continue_button_pressed() -> void:
	resume_game()


func _on_settings_button_pressed() -> void:
	_play_ui_sound()
	var settings := get_node_or_null("/root/SettingsManager")
	if settings != null:
		settings.return_scene = "res://scenes/main/main.tscn"
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/settings_menu.tscn")


func _on_main_menu_button_pressed() -> void:
	_play_ui_sound()
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func _on_quit_button_pressed() -> void:
	_play_ui_sound()
	get_tree().paused = false
	get_tree().quit()


func _play_ui_sound() -> void:
	var settings := get_node_or_null("/root/SettingsManager")
	if settings != null and settings.has_method("play_ui_sound"):
		settings.play_ui_sound()


func _play_ui_hover_sound() -> void:
	var settings := get_node_or_null("/root/SettingsManager")
	if settings != null and settings.has_method("play_ui_hover_sound"):
		settings.play_ui_hover_sound()
