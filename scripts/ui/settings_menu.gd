extends Control
## 设置菜单：调节音乐/音效音量、切换全屏，并返回主菜单。


func _ready() -> void:
	var settings := get_node_or_null("/root/SettingsManager")
	if settings == null:
		return
	$CenterContainer/SettingsPanel/SettingsBox/MusicSlider.value = settings.music_volume_db
	$CenterContainer/SettingsPanel/SettingsBox/SfxSlider.value = settings.sfx_volume_db
	$CenterContainer/SettingsPanel/SettingsBox/FullscreenCheck.button_pressed = settings.fullscreen
	var language_option := $CenterContainer/SettingsPanel/SettingsBox/LanguageOption as OptionButton
	language_option.clear()
	language_option.add_item("中文")
	language_option.add_item("English")
	language_option.selected = 0 if settings.language_locale == "zh_CN" else 1
	var resolution_option := $CenterContainer/SettingsPanel/SettingsBox/ResolutionOption as OptionButton
	resolution_option.clear()
	resolution_option.add_item("1K 1920×1080")
	resolution_option.add_item("2K 2560×1440")
	resolution_option.add_item("4K 3840×2160")
	resolution_option.selected = settings.resolution_index
	$CenterContainer/SettingsPanel/SettingsBox/BackButton.grab_focus()


func _on_music_slider_value_changed(value: float) -> void:
	var settings := get_node_or_null("/root/SettingsManager")
	if settings != null:
		settings.set_music_volume_db(value)


func _on_sfx_slider_value_changed(value: float) -> void:
	var settings := get_node_or_null("/root/SettingsManager")
	if settings != null:
		settings.set_sfx_volume_db(value)


func _on_fullscreen_check_toggled(pressed: bool) -> void:
	var settings := get_node_or_null("/root/SettingsManager")
	if settings != null:
		settings.set_fullscreen(pressed)


func _on_language_option_item_selected(index: int) -> void:
	var settings := get_node_or_null("/root/SettingsManager")
	if settings != null:
		settings.set_language_locale("zh_CN" if index == 0 else "en")


func _on_resolution_option_item_selected(index: int) -> void:
	var settings := get_node_or_null("/root/SettingsManager")
	if settings != null:
		settings.set_resolution_index(index)


func _on_back_button_pressed() -> void:
	var settings := get_node_or_null("/root/SettingsManager")
	var return_path := "res://scenes/ui/main_menu.tscn"
	if settings != null:
		settings.play_ui_sound()
		return_path = settings.return_scene
		settings.return_scene = "res://scenes/ui/main_menu.tscn"
	get_tree().paused = false
	get_tree().change_scene_to_file(return_path)


func _play_ui_hover_sound() -> void:
	var settings := get_node_or_null("/root/SettingsManager")
	if settings != null and settings.has_method("play_ui_hover_sound"):
		settings.play_ui_hover_sound()
