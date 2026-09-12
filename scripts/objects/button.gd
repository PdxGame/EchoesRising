extends Area2D
## 彩色按钮交互物：玩家进入检测区时按下并立刻触发目标机关，离开时只负责松开状态。

# 按下/松开时发出信号，供其他高级机关监听；常规目标机关在按下瞬间激活。
signal pressed
signal released

## 玩家按下按钮后需要激活的延迟装置节点（平台/桥/弹簧/门），可在 Inspector 拖入
@export var temporary_platform_path: NodePath
## 按钮按下时使用的贴图，请选择与按钮颜色对应的 pressed 图
@export var pressed_texture: Texture2D
## 是否让按钮跟随目标机关一起隐藏/出现；仅用于“按钮嵌在地面里”的特殊机关，默认关闭
@export var hide_with_target := false

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _temporary_platform: Node = get_node_or_null(temporary_platform_path)

var _idle_texture: Texture2D
var _is_pressed := false
# 按钮重新出现时若玩家还站在检测区内，先保持静默，等玩家离开后再允许再次触发
var _suppress_until_exit := false


func _ready() -> void:
	# 场景 Sprite2D 上已放好对应颜色的普通图，按下前先保存它作为松开后的贴图。
	_idle_texture = _sprite.texture
	if hide_with_target and _temporary_platform != null \
			and _temporary_platform.has_signal("device_visibility_changed"):
		_temporary_platform.connect("device_visibility_changed", _on_target_visibility_changed)


func _on_body_entered(body: Node2D) -> void:
	# 只响应玩家角色，避免敌人或其他物体误触按钮。
	if _is_pressed or _suppress_until_exit or not body is CharacterBody2D:
		return
	_set_pressed(true)


func _on_body_exited(body: Node2D) -> void:
	# 玩家离开按钮后只恢复外观与按下状态，不再等待离开才触发机关。
	if not body is CharacterBody2D:
		return
	_suppress_until_exit = false
	if _is_pressed:
		_set_pressed(false)


func _on_target_visibility_changed(is_visible: bool) -> void:
	# 与目标机关同步隐藏/出现；隐藏时重置按压状态，重新出现前检查玩家是否仍占位。
	if is_visible:
		_suppress_until_exit = _player_overlaps_detection_shape()
	else:
		_suppress_until_exit = false
		_is_pressed = false
		_sprite.texture = _idle_texture
	visible = is_visible
	for collision_shape in find_children("*", "CollisionShape2D", true, false):
		collision_shape.set_deferred("disabled", not is_visible)


func _player_overlaps_detection_shape() -> bool:
	# 按钮本体不阻挡玩家，但重新出现时若玩家仍在检测区内，需要先静默避免连锁触发。
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


func _activate_target() -> void:
	# 只负责激活拖入的延迟装置；延迟装置自身会防止一轮流程内重复执行。
	if _temporary_platform != null and _temporary_platform.has_method("activate"):
		_temporary_platform.activate()


func _set_pressed(value: bool) -> void:
	# 同步贴图与信号；机关触发放在按下分支，让玩家踩下就有反应。
	_is_pressed = value
	_sprite.texture = pressed_texture if value and pressed_texture != null else _idle_texture
	if value:
		pressed.emit()
		_activate_target()
	else:
		released.emit()
