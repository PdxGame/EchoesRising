extends Node
## 全局设置管理器：负责读取/保存音量与全屏选项，并应用到音乐/音效节点。

const SAVE_PATH := "user://settings.cfg"
const MIN_VOLUME_DB := -30.0
const MUTED_VOLUME_DB := -80.0
const _ui_click_stream := preload("res://assets/new_platformer_pack/Sounds/sfx_select.ogg")
const _ui_hover_stream := preload("res://assets/new_platformer_pack/Sounds/sfx_gem.ogg")
const _menu_music_stream := preload("res://assets/music/game_bgm.ogg")
const _game_music_stream := preload("res://assets/music/flowerbed_fields.ogg")
# 预载翻译资源：既保证导出时被打包，也避免重复注册同一个资源对象。
const _translations: Array[Translation] = [
	preload("res://localization/en.po"),
]
const WINDOW_WIDTHS := [1920, 2560, 3840]
const WINDOW_HEIGHTS := [1080, 1440, 2160]
const VICTORY_FADE_OUT_DURATION := 1.2
const VICTORY_BLACK_HOLD_DURATION := 0.3
const VICTORY_FADE_IN_DURATION := 1.5
const VICTORY_MUSIC_RESUME_ALPHA := 0.62

enum TransitionPhase {
	NONE,
	FADE_OUT,
	HOLD,
	FADE_IN,
}

var music_volume_db := -10.0
var sfx_volume_db := -8.0
var fullscreen := false
var resolution_index := 0
var language_locale := "zh_CN"
## 设置界面返回目标，默认回到主菜单；暂停菜单进入设置时改为回到游戏
var return_scene := "res://scenes/ui/main_menu.tscn"

var _ui_click_sound: AudioStreamPlayer
var _ui_hover_sound: AudioStreamPlayer
var _music_player: AudioStreamPlayer
var _active_music_stream: AudioStream
var _transition_layer: CanvasLayer
var _transition_rect: ColorRect
var _transition_phase := TransitionPhase.NONE
var _transition_alpha := 0.0
var _transition_timer := 0.0
var _music_suppressed := false
var _menu_music_resumed := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for translation in _translations:
		if translation != null and not TranslationServer.has_translation(translation):
			TranslationServer.add_translation(translation)
	_load_settings()
	_apply_language()
	_apply_window_mode()
	_create_ui_sound()
	_create_music_player()
	_create_transition_overlay()
	_set_music(_menu_music_stream)


func _process(delta: float) -> void:
	_update_transition(delta)
	if _music_player == null or _music_suppressed:
		return
	_update_scene_music()


func _update_scene_music() -> void:
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return
	var scene_path := current_scene.scene_file_path
	var desired_stream: AudioStream = _menu_music_stream
	if scene_path == "res://scenes/main/main.tscn":
		desired_stream = _game_music_stream
	elif scene_path == "res://scenes/ui/settings_menu.tscn":
		desired_stream = _game_music_stream if return_scene == "res://scenes/main/main.tscn" else _menu_music_stream
	if desired_stream != _active_music_stream:
		_set_music(desired_stream)
	elif not _music_player.playing:
		_music_player.play()


func play_ui_sound() -> void:
	# 音效节点挂在全局管理器上，不会被换场景立即释放。
	if _ui_click_sound != null:
		_ui_click_sound.play()


func play_ui_hover_sound() -> void:
	# 悬停反馈用更轻、稍高的音色，避免和点击音效混成同一种声音。
	if _ui_hover_sound != null:
		_ui_hover_sound.stop()
		_ui_hover_sound.play()


func is_music_playing() -> bool:
	return _music_player != null and _music_player.playing


func finish_victory_and_return_to_menu() -> void:
	## 登顶收尾：清除存档与全部音频，黑场切回主菜单，主菜单渐显后再恢复 BGM。
	if _transition_phase != TransitionPhase.NONE:
		return
	var save_manager := get_node_or_null("/root/SaveManager")
	if save_manager != null and save_manager.has_method("clear_progress"):
		save_manager.clear_progress()
	stop_all_audio()
	_music_suppressed = true
	_menu_music_resumed = false
	_transition_phase = TransitionPhase.FADE_OUT
	_transition_timer = 0.0
	_set_transition_alpha(0.0)
	if _transition_rect != null:
		_transition_rect.visible = true
		_transition_rect.mouse_filter = Control.MOUSE_FILTER_STOP


func stop_all_audio() -> void:
	## 停止全局音乐、UI 音效，以及当前场景中所有音频播放器。
	if _music_player != null:
		_music_player.stop()
	if _ui_click_sound != null:
		_ui_click_sound.stop()
	if _ui_hover_sound != null:
		_ui_hover_sound.stop()

	for node in get_tree().get_nodes_in_group("sfx"):
		if node is AudioStreamPlayer:
			node.stop()
	var current_scene := get_tree().current_scene
	if current_scene != null:
		for node in current_scene.find_children("*", "AudioStreamPlayer", true, false):
			var player := node as AudioStreamPlayer
			if player != null:
				player.stop()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_settings()
		get_tree().quit()


func set_music_volume_db(value: float) -> void:
	music_volume_db = value
	_save_settings()
	if _music_player != null:
		_music_player.volume_db = _volume_db_or_muted(music_volume_db)
	for node in get_tree().get_nodes_in_group("music"):
		if node is AudioStreamPlayer:
			node.volume_db = _volume_db_or_muted(music_volume_db)


func set_sfx_volume_db(value: float) -> void:
	sfx_volume_db = value
	_save_settings()
	if _ui_click_sound != null:
		_ui_click_sound.volume_db = _volume_db_or_muted(sfx_volume_db)
	if _ui_hover_sound != null:
		_ui_hover_sound.volume_db = _volume_db_or_muted(sfx_volume_db, -8.0)
	for node in get_tree().get_nodes_in_group("sfx"):
		if node is AudioStreamPlayer:
			node.volume_db = _volume_db_or_muted(sfx_volume_db)


func set_fullscreen(value: bool) -> void:
	fullscreen = value
	_save_settings()
	_apply_window_mode()


func set_resolution_index(value: int) -> void:
	resolution_index = clampi(value, 0, WINDOW_WIDTHS.size() - 1)
	_save_settings()
	_apply_window_mode()


func set_language_locale(value: String) -> void:
	## 切换界面与台词语言，中文为源文本，英文由翻译资源提供。
	language_locale = value if value in ["zh_CN", "en"] else "zh_CN"
	_save_settings()
	_apply_language()


func apply_music_volume(node: AudioStreamPlayer) -> void:
	if node != null:
		node.volume_db = _volume_db_or_muted(music_volume_db)


func apply_sfx_volume(node: AudioStreamPlayer) -> void:
	if node != null:
		node.volume_db = _volume_db_or_muted(sfx_volume_db)


func _create_ui_sound() -> void:
	_ui_click_sound = AudioStreamPlayer.new()
	_ui_click_sound.name = "UIClickSound"
	_ui_click_sound.stream = _ui_click_stream
	_ui_click_sound.volume_db = _volume_db_or_muted(sfx_volume_db)
	_ui_click_sound.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_ui_click_sound)

	_ui_hover_sound = AudioStreamPlayer.new()
	_ui_hover_sound.name = "UIHoverSound"
	_ui_hover_sound.stream = _ui_hover_stream
	_ui_hover_sound.pitch_scale = 1.15
	_ui_hover_sound.volume_db = _volume_db_or_muted(sfx_volume_db, -8.0)
	_ui_hover_sound.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_ui_hover_sound)


func _create_music_player() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.name = "MusicPlayer"
	_music_player.volume_db = _volume_db_or_muted(music_volume_db)
	_music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_music_player)
	_music_player.add_to_group("music")


func _create_transition_overlay() -> void:
	# 全局黑场层挂在 autoload 下，因此切换场景时不会随旧场景一起销毁。
	_transition_layer = CanvasLayer.new()
	_transition_layer.name = "VictoryTransitionLayer"
	_transition_layer.layer = 100
	_transition_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_transition_layer)

	_transition_rect = ColorRect.new()
	_transition_rect.name = "FadeRect"
	_transition_rect.anchor_right = 1.0
	_transition_rect.anchor_bottom = 1.0
	_transition_rect.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_transition_rect.grow_vertical = Control.GROW_DIRECTION_BOTH
	_transition_rect.color = Color(0, 0, 0, 0)
	_transition_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_transition_rect.visible = false
	_transition_layer.add_child(_transition_rect)


func _update_transition(delta: float) -> void:
	match _transition_phase:
		TransitionPhase.FADE_OUT:
			_set_transition_alpha(_transition_alpha + delta / VICTORY_FADE_OUT_DURATION)
			if _transition_alpha >= 1.0:
				_set_transition_alpha(1.0)
				_transition_phase = TransitionPhase.HOLD
				_transition_timer = 0.0
		TransitionPhase.HOLD:
			_transition_timer += delta
			if _transition_timer >= VICTORY_BLACK_HOLD_DURATION:
				_begin_main_menu_after_victory()
		TransitionPhase.FADE_IN:
			_set_transition_alpha(_transition_alpha - delta / VICTORY_FADE_IN_DURATION)
			if not _menu_music_resumed and _transition_alpha <= VICTORY_MUSIC_RESUME_ALPHA:
				_menu_music_resumed = true
				_music_suppressed = false
				_set_music(_menu_music_stream)
			if _transition_alpha <= 0.0:
				_set_transition_alpha(0.0)
				_transition_phase = TransitionPhase.NONE
				if _transition_rect != null:
					_transition_rect.visible = false
					_transition_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _begin_main_menu_after_victory() -> void:
	# 全黑时切场景；先解除暂停，确保新主菜单可以正常响应输入和按钮动画。
	get_tree().paused = false
	_transition_phase = TransitionPhase.FADE_IN
	_transition_timer = 0.0
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")


func _set_transition_alpha(value: float) -> void:
	_transition_alpha = clampf(value, 0.0, 1.0)
	if _transition_rect != null:
		_transition_rect.color = Color(0, 0, 0, _transition_alpha)


func _set_music(stream: AudioStream) -> void:
	if _music_player == null or stream == null:
		return
	if stream == _active_music_stream:
		if not _music_player.playing:
			_music_player.play()
		return
	_active_music_stream = stream
	_music_player.stream = stream
	var ogg_stream := stream as AudioStreamOggVorbis
	if ogg_stream != null:
		ogg_stream.loop = true
	_music_player.play()


func _volume_db_or_muted(value: float, offset := 0.0) -> float:
	if value <= MIN_VOLUME_DB:
		return MUTED_VOLUME_DB
	return clampf(value + offset, MIN_VOLUME_DB, 0.0)


func _apply_window_mode() -> void:
	if fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		var target_size := Vector2i(
			WINDOW_WIDTHS[resolution_index],
			WINDOW_HEIGHTS[resolution_index]
		)
		DisplayServer.window_set_size(target_size)
		DisplayServer.window_set_position(
			DisplayServer.screen_get_position() +
			(DisplayServer.screen_get_size() - target_size) / 2
		)


func _apply_language() -> void:
	# 显式启用主翻译域并锁定到目标语言；编辑器环境下该域可能被禁用。
	var main_domain := TranslationServer.get_or_add_domain("")
	if main_domain != null:
		main_domain.set_enabled(true)
		main_domain.set_locale_override(language_locale)
	TranslationServer.set_locale(language_locale)
	if is_inside_tree():
		get_tree().root.propagate_notification(Node.NOTIFICATION_TRANSLATION_CHANGED)


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	music_volume_db = float(config.get_value("settings", "music_volume_db", music_volume_db))
	sfx_volume_db = float(config.get_value("settings", "sfx_volume_db", sfx_volume_db))
	fullscreen = bool(config.get_value("settings", "fullscreen", fullscreen))
	language_locale = str(config.get_value("settings", "language_locale", language_locale))
	if language_locale not in ["zh_CN", "en"]:
		language_locale = "zh_CN"
	resolution_index = clampi(
		int(config.get_value("settings", "resolution_index", resolution_index)),
		0,
		WINDOW_WIDTHS.size() - 1
	)


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("settings", "music_volume_db", music_volume_db)
	config.set_value("settings", "sfx_volume_db", sfx_volume_db)
	config.set_value("settings", "fullscreen", fullscreen)
	config.set_value("settings", "language_locale", language_locale)
	config.set_value("settings", "resolution_index", resolution_index)
	config.save(SAVE_PATH)
