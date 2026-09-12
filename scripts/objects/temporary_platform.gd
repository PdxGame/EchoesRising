@tool
extends StaticBody2D
## 延迟机关：平台/桥默认隐藏、触发后延迟出现再消失；门默认可见、触发后延迟消失再恢复。

## 装置可见状态变化时发出；仅运行时发出，供按钮等关联节点同步隐藏/出现
signal device_visibility_changed(is_visible: bool)

enum DeviceMode {
	APPEAR_THEN_DISAPPEAR = 0,
	DISAPPEAR_THEN_APPEAR = 1,
}

## 装置时序：平台/桥用“出现后消失”，门用“消失后恢复”
@export_enum("出现后消失", "消失后恢复") var mode: int = DeviceMode.APPEAR_THEN_DISAPPEAR
## 按钮按下后到目标状态改变之间的延迟（秒）
@export var activation_delay := 1.0
## 平台保持出现的时间，或门保持打开/消失状态的时间（秒）
@export var visible_duration := 2.0
## 倒计时里显示的装置名称，例如“平台/桥/门”
@export var display_name := "平台"

var _sequence_active := false
var _state := ""
var _remaining := 0.0


func _ready() -> void:
	# 编辑器里统一显示，方便摆放；运行时再按模式决定初始状态。
	if Engine.is_editor_hint():
		_set_device_visible(true)
	else:
		_set_device_visible(mode == DeviceMode.DISAPPEAR_THEN_APPEAR)


func activate() -> void:
	# 同一个装置一次只跑一轮，避免按钮反复按下时把倒计时叠起来。
	if _sequence_active:
		return
	_sequence_active = true
	_state = "waiting"
	_remaining = activation_delay


func _process(delta: float) -> void:
	if not _sequence_active:
		return

	if _state == "waiting_for_clear":
		_wait_for_player_to_leave()
		return

	_remaining -= delta
	if _state == "waiting":
		var countdown_text := tr("%s 即将出现 %.1f 秒") % [
			tr(display_name), maxf(0.0, _remaining)
		]
		if mode == DeviceMode.DISAPPEAR_THEN_APPEAR:
			countdown_text = tr("%s 即将消失 %.1f 秒") % [
				tr(display_name), maxf(0.0, _remaining)
			]
		_show_countdown(countdown_text)
		if _remaining <= 0.0:
			if mode == DeviceMode.APPEAR_THEN_DISAPPEAR:
				if _player_overlaps_restored_shape():
					_state = "waiting_for_clear"
					_show_countdown(tr("%s 等待玩家离开") % tr(display_name))
				else:
					_set_device_visible(true)
					_state = "visible"
					_remaining = visible_duration
			else:
				_set_device_visible(false)
				_state = "opened"
				_remaining = visible_duration
	elif _state == "visible":
		_show_countdown(tr("%s 剩余 %.1f 秒") % [tr(display_name), maxf(0.0, _remaining)])
		if _remaining <= 0.0:
			_set_device_visible(false)
			_finish_sequence()
	elif _state == "opened":
		if _remaining > 0.0:
			_show_countdown(tr("%s 即将恢复 %.1f 秒") % [tr(display_name), maxf(0.0, _remaining)])
		else:
			_try_restore_after_open()


func _try_restore_after_open() -> void:
	# 门恢复前若玩家还站在门的位置，先保持打开，等玩家离开再恢复碰撞，避免把玩家卡进墙。
	if _player_overlaps_restored_shape():
		_state = "waiting_for_clear"
		_show_countdown(tr("%s 等待玩家离开") % tr(display_name))
		return
	_set_device_visible(true)
	_finish_sequence()


func _wait_for_player_to_leave() -> void:
	if _player_overlaps_restored_shape():
		_show_countdown(tr("%s 等待玩家离开") % tr(display_name))
		return
	if mode == DeviceMode.APPEAR_THEN_DISAPPEAR:
		_set_device_visible(true)
		_state = "visible"
		_remaining = visible_duration
	else:
		_set_device_visible(true)
		_finish_sequence()


func _player_overlaps_restored_shape() -> bool:
	if Engine.is_editor_hint() or not is_inside_tree():
		return false

	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return false

	var space := get_world_2d().direct_space_state
	for node in find_children("*", "CollisionShape2D", true, false):
		var collision_shape := node as CollisionShape2D
		if collision_shape == null or collision_shape.shape == null:
			continue
		var query := PhysicsShapeQueryParameters2D.new()
		query.shape = collision_shape.shape
		query.transform = collision_shape.global_transform
		query.collision_mask = 1
		query.exclude = [get_rid()]
		var hits := space.intersect_shape(query, 4)
		for hit in hits:
			var collider: Node2D = hit.collider
			if collider == player:
				return true
	return false


func _finish_sequence() -> void:
	# 一轮结束后把状态复位，下一轮才能再次被按钮触发。
	_state = ""
	_remaining = 0.0
	_sequence_active = false
	_hide_countdown()


func _set_device_visible(value: bool) -> void:
	# 根节点 visible 会隐藏所有贴图子节点，不依赖固定节点名。
	visible = value
	for collision_shape in find_children("*", "CollisionShape2D", true, false):
		collision_shape.set_deferred("disabled", not value)
	if not Engine.is_editor_hint():
		device_visibility_changed.emit(value)


func _show_countdown(text: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("show_countdown"):
		hud.show_countdown(text, self)


func _hide_countdown() -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("hide_countdown"):
		hud.hide_countdown(self)
