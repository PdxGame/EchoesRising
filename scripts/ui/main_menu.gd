extends Control
## 主菜单：提供新游戏、继续游戏、设置和退出，并播放选择音效。


func _ready() -> void:
	var save_manager := get_node_or_null("/root/SaveManager")
	var continue_button := $CenterContainer/MenuPanel/MenuBox/ContinueButton as Button
	continue_button.disabled = save_manager == null or not save_manager.has_save
	if continue_button.disabled:
		$CenterContainer/MenuPanel/MenuBox/NewGameButton.grab_focus()
	else:
		continue_button.grab_focus()


func _on_new_game_button_pressed() -> void:
	var save_manager := get_node_or_null("/root/SaveManager")
	if save_manager != null and save_manager.has_method("clear_progress"):
		save_manager.clear_progress()
	await get_tree().create_timer(0.12).timeout
	if not is_inside_tree():
		return
	get_tree().change_scene_to_file("res://scenes/main/main.tscn")


func _on_continue_button_pressed() -> void:
	var save_manager := get_node_or_null("/root/SaveManager")
	if save_manager == null or not save_manager.has_save:
		return
	await get_tree().create_timer(0.12).timeout
	if not is_inside_tree():
		return
	get_tree().change_scene_to_file("res://scenes/main/main.tscn")


func _on_settings_button_pressed() -> void:
	var settings := get_node_or_null("/root/SettingsManager")
	if settings != null:
		settings.return_scene = "res://scenes/ui/main_menu.tscn"
	await get_tree().create_timer(0.12).timeout
	if not is_inside_tree():
		return
	get_tree().change_scene_to_file("res://scenes/ui/settings_menu.tscn")


func _on_quit_button_pressed() -> void:
	get_tree().quit()


func _play_ui_sound() -> void:
	var settings := get_node_or_null("/root/SettingsManager")
	if settings != null and settings.has_method("play_ui_sound"):
		settings.play_ui_sound()
		return
	var sound := get_node_or_null("UISound") as AudioStreamPlayer
	if sound != null:
		sound.play()


func _play_ui_hover_sound() -> void:
	var settings := get_node_or_null("/root/SettingsManager")
	if settings != null and settings.has_method("play_ui_hover_sound"):
		settings.play_ui_hover_sound()
