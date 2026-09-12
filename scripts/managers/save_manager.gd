extends Node
## 全局存档管理器：统一读写退出位置和最高高度，供主菜单与游戏内 HUD 使用。

const SAVE_PATH := "user://festival_save.cfg"
const SAVE_FILE_NAME := "festival_save.cfg"

var has_save := false
var saved_position := Vector2.ZERO
var best_height_m := 0.0


func _ready() -> void:
	load_progress()


func load_progress() -> bool:
	## 读取用户目录里的存档；没有有效位置时按无存档处理。
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		_clear_memory()
		return false

	if not config.has_section_key("save", "current_x") or not config.has_section_key("save", "current_y"):
		_clear_memory()
		return false

	has_save = true
	saved_position = Vector2(
		float(config.get_value("save", "current_x", 0.0)),
		float(config.get_value("save", "current_y", 0.0))
	)
	best_height_m = maxf(0.0, float(config.get_value("save", "best_height_m", 0.0)))
	return true


func save_progress(position: Vector2, current_best_height_m: float) -> void:
	## 保存当前玩家位置与历史最高高度，新游戏时由主菜单调用 clear_progress() 清除。
	has_save = true
	saved_position = position
	best_height_m = maxf(0.0, current_best_height_m)

	var config := ConfigFile.new()
	config.set_value("save", "current_x", position.x)
	config.set_value("save", "current_y", position.y)
	config.set_value("save", "best_height_m", best_height_m)
	config.save(SAVE_PATH)


func clear_progress() -> void:
	## 删除旧存档并清空内存值，让新游戏从场景原始出生位置开始。
	_clear_memory()
	var dir := DirAccess.open("user://")
	if dir != null and dir.file_exists(SAVE_FILE_NAME):
		dir.remove(SAVE_FILE_NAME)


func _clear_memory() -> void:
	has_save = false
	saved_position = Vector2.ZERO
	best_height_m = 0.0
