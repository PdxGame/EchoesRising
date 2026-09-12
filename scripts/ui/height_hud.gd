extends CanvasLayer
## 正式高度 HUD：显示当前高度和历史最高高度，并在退出游戏时保存当前位置。

const VictoryDialogueScene := preload("res://scenes/ui/guide_dialogue.tscn")
const DialogueBank := preload("res://resources/npc_dialogue_bank.tres")

## 高度零点，通常是地图底部/起始地面所在的世界 Y
@export var origin_y := 64.0
## 玩家碰撞体的半高，用于从角色中心换算脚底高度
@export var feet_offset := 28.0
## 多少像素算 1 米
@export var pixels_per_meter := 10.0
## 达到该高度后触发登顶结局（米）
@export var victory_height_m := 1700.0
## 登顶结局使用的台词库索引
@export var victory_dialogue_index := 5

@onready var _player: CharacterBody2D = get_node("../Player")
@onready var _label: Label = $HeightLabel
@onready var _countdown_label: Label = $CountdownLabel

var _best_height_m := -INF
var _victory_started := false
# 以触发机关的实例 ID 为键，保存各自当前的提示文字，保证多个机关互不覆盖。
var _countdown_entries: Dictionary = {}


func _ready() -> void:
	add_to_group("hud")
	var save_manager := get_node_or_null("/root/SaveManager")
	if _player != null and save_manager != null and save_manager.has_save:
		_player.global_position = save_manager.saved_position
		_player.velocity = Vector2.ZERO
		_best_height_m = save_manager.best_height_m
	_update_best_height()
	_update_label()


func _process(_delta: float) -> void:
	_update_best_height()
	_update_label()
	_check_victory_height()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_current_position()
		get_tree().quit()


func _exit_tree() -> void:
	_save_current_position()


func _current_height_m() -> float:
	if _player == null:
		return 0.0
	var feet_y := _player.global_position.y + feet_offset
	return maxf(0.0, (origin_y - feet_y) / pixels_per_meter)


func _update_best_height() -> void:
	var current_height := _current_height_m()
	if current_height > _best_height_m:
		_best_height_m = current_height


func _update_label() -> void:
	_label.text = tr("当前 %.1f m    最高 %.1f m") % [_current_height_m(), _best_height_m]


func _save_current_position() -> void:
	if _player == null or _victory_started:
		return

	var save_manager := get_node_or_null("/root/SaveManager")
	if save_manager != null:
		save_manager.save_progress(_player.global_position, _best_height_m)


func _check_victory_height() -> void:
	if _victory_started or _current_height_m() < victory_height_m:
		return
	_start_victory_sequence()


func _start_victory_sequence() -> void:
	# 截停游戏逻辑并展示结局台词，防止玩家在对话期间继续移动或掉落。
	_victory_started = true
	get_tree().paused = true

	var pause_menu := get_node_or_null("../PauseMenu")
	if pause_menu != null:
		pause_menu.process_mode = Node.PROCESS_MODE_DISABLED

	var lines := DialogueBank.get_dialogue_set(victory_dialogue_index)
	if lines.is_empty():
		var settings := get_node_or_null("/root/SettingsManager")
		if settings != null and settings.has_method("finish_victory_and_return_to_menu"):
			settings.finish_victory_and_return_to_menu()
		return

	var dialogue := VictoryDialogueScene.instantiate()
	add_child(dialogue)
	dialogue.setup(tr("恭喜登顶"), lines, false)
	dialogue.finished.connect(_on_victory_dialogue_finished.bind(dialogue))


func _on_victory_dialogue_finished(dialogue: CanvasLayer) -> void:
	# 最后一段读完后交给全局设置管理器执行清档、黑场和返回主菜单。
	if dialogue != null:
		dialogue.queue_free()
	var settings := get_node_or_null("/root/SettingsManager")
	if settings != null and settings.has_method("finish_victory_and_return_to_menu"):
		settings.finish_victory_and_return_to_menu()


func show_countdown(text: String, source: Object = null) -> void:
	# 新机关追加到新的一行；同一机关后续更新时只替换自己原来那一行。
	var entry_id := _countdown_entry_id(source)
	_countdown_entries[entry_id] = text
	_refresh_countdown_label()


func hide_countdown(source: Object = null) -> void:
	# 只移除当前机关自己的提示，不影响其他仍在倒计时的机关。
	_countdown_entries.erase(_countdown_entry_id(source))
	_refresh_countdown_label()


func _countdown_entry_id(source: Object) -> int:
	return source.get_instance_id() if source != null else -1


func _refresh_countdown_label() -> void:
	var lines := PackedStringArray()
	for text in _countdown_entries.values():
		lines.append(str(text))
	_countdown_label.text = "\n".join(lines)
	_countdown_label.visible = not lines.is_empty()


func _on_gear_button_pressed() -> void:
	# 点击右上角齿轮按钮时，和按 ESC 一样打开暂停菜单。
	var settings := get_node_or_null("/root/SettingsManager")
	if settings != null and settings.has_method("play_ui_sound"):
		settings.play_ui_sound()
	var pause_menu := get_node_or_null("../PauseMenu")
	if pause_menu != null and pause_menu.has_method("pause_game"):
		pause_menu.pause_game()


func _play_ui_hover_sound() -> void:
	var settings := get_node_or_null("/root/SettingsManager")
	if settings != null and settings.has_method("play_ui_hover_sound"):
		settings.play_ui_hover_sound()
