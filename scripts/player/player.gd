extends CharacterBody2D
## 玩家控制器：只处理水平移动、普通跳跃、重力，以及外部机关调用的一次性弹射。

## 最大水平移动速度（像素/秒）
@export var speed := 280.0
## 从静止加速到最大速度的快慢（像素/秒²），越大手感越跟手
@export var acceleration := 2200.0
## 松开方向键后停下的快慢（像素/秒²），越大越容易急停
@export var deceleration := 2800.0
## 起跳瞬间的向上速度（像素/秒）；负数越大跳得越高
@export var jump_velocity := -640.0
## 松开跳跃键后保留的上升速度比例；数值越小短跳越低
@export var jump_cut_multiplier := 0.45
## 垂直重力加速度（像素/秒²）
@export var gravity := 980.0
## 最大下落速度（像素/秒）
@export var max_fall_speed := 1200.0
## 玩家横向可移动的屏幕左边界
@export var left_limit := -620.0
## 玩家横向可移动的屏幕右边界
@export var right_limit := 620.0

# 只有与 up_direction 夹角足够小的碰撞才算脚底地面，避免把侧面碰到弹簧也算踩中。
const _FLOOR_NORMAL_THRESHOLD := 0.7

# 只有脚底接触普通地面时为 true；主动起跳后立即变为 false，弹簧不会让它变 true。
var can_jump := false

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _jump_sound: AudioStreamPlayer = $JumpSound

var _external_launch_timer := 0.0
var _was_on_floor := false
var _manual_jump_active := false
var _ignore_jump_frames := 0


func _ready() -> void:
	add_to_group("player")
	if _jump_sound != null:
		_jump_sound.add_to_group("sfx")
		var settings := get_node_or_null("/root/SettingsManager")
		if settings != null:
			settings.apply_sfx_volume(_jump_sound)


func _physics_process(delta: float) -> void:
	if _ignore_jump_frames > 0:
		_ignore_jump_frames -= 1
	if _external_launch_timer > 0.0:
		_external_launch_timer = maxf(0.0, _external_launch_timer - delta)
	_update_horizontal_velocity(delta)
	_apply_gravity(delta)
	_handle_jump()
	_handle_variable_jump_height()
	move_and_slide()
	var floor_now := is_on_floor()
	var spring_contact := _find_spring_floor_contact() if floor_now else null
	if not floor_now:
		can_jump = false
	elif spring_contact != null:
		can_jump = false
	elif _has_non_spring_floor_contact() or can_jump:
		can_jump = true
	if floor_now and not _was_on_floor and spring_contact != null:
		spring_contact.call("bounce_player", self)
	_was_on_floor = floor_now
	_apply_horizontal_limits()
	_update_facing()
	_update_animation()
	if velocity.y >= 0.0:
		_manual_jump_active = false


func suppress_next_jump() -> void:
	# 对话关闭时吞掉同一帧遗留的跳跃输入，避免按“继续”结束对话后角色自己跳一下。
	_ignore_jump_frames = 2


func launch_from_spring(launch_velocity: float) -> void:
	# 外部机关只施加速度，不修改 can_jump；弹簧是否算地面由真实碰撞接触决定。
	velocity.y = launch_velocity
	_external_launch_timer = 0.2
	_manual_jump_active = false


func is_feet_on_spring() -> bool:
	return _find_spring_floor_contact() != null


func _find_spring_floor_contact() -> Node2D:
	# move_and_slide 的真实碰撞已经包含接触位置和法线，边缘踩到弹簧也能拿到。
	for index in get_slide_collision_count():
		var collision := get_slide_collision(index)
		if collision.get_normal().dot(up_direction) <= _FLOOR_NORMAL_THRESHOLD:
			continue
		var collider: Node2D = collision.get_collider()
		if collider != null and collider.has_method("bounce_player"):
			return collider
	return null


func _has_non_spring_floor_contact() -> bool:
	# 普通地形、临时平台等没有 bounce_player 的碰撞体才会让 can_jump 变为 true。
	for index in get_slide_collision_count():
		var collision := get_slide_collision(index)
		if collision.get_normal().dot(up_direction) <= _FLOOR_NORMAL_THRESHOLD:
			continue
		var collider: Node2D = collision.get_collider()
		if collider != null and not collider.has_method("bounce_player"):
			return true
	return false


func _update_horizontal_velocity(delta: float) -> void:
	# 根据左右输入加速；没有输入时自然减速停下。
	var direction := Input.get_axis("move_left", "move_right")
	if direction != 0.0:
		velocity.x = move_toward(velocity.x, direction * speed, acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, deceleration * delta)


func _apply_gravity(delta: float) -> void:
	# 外部弹射刚生效时不能把速度清零，否则弹簧会被地面逻辑吞掉。
	if is_on_floor() and _external_launch_timer <= 0.0:
		velocity.y = 0.0
	else:
		velocity.y = minf(velocity.y + gravity * delta, max_fall_speed)


func _handle_jump() -> void:
	if _ignore_jump_frames > 0:
		return
	if not Input.is_action_just_pressed("jump") or not can_jump:
		return

	velocity.y = jump_velocity
	can_jump = false
	_manual_jump_active = true
	_jump_sound.play()


func _handle_variable_jump_height() -> void:
	# 起跳后提前松开跳跃键会削减上升速度，形成短跳。
	if _manual_jump_active and Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= jump_cut_multiplier
		_manual_jump_active = false


func _apply_horizontal_limits() -> void:
	# 玩家不能走出镜头可视范围，贴边时立即清空横向速度。
	var clamped_x := clampf(global_position.x, left_limit, right_limit)
	if clamped_x != global_position.x:
		global_position.x = clamped_x
		velocity.x = 0.0


func _update_facing() -> void:
	# 根据水平移动方向翻转角色贴图。
	if velocity.x > 0.0:
		_sprite.flip_h = false
	elif velocity.x < 0.0:
		_sprite.flip_h = true


func _update_animation() -> void:
	# 空中或正在上升时使用跳跃姿势；地面横向移动时使用走路动画。
	var next_animation := "idle"
	if not is_on_floor() or velocity.y < 0.0:
		next_animation = "jump"
	elif absf(velocity.x) > 10.0:
		next_animation = "walk"

	if _sprite.animation != StringName(next_animation):
		_sprite.play(next_animation)
