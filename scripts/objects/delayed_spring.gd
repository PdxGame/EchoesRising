extends StaticBody2D
## 延迟弹簧：默认隐藏，由按钮踩下后延迟出现，短暂可用后消失；踩到顶部时弹飞玩家。

## 弹飞玩家的向上速度（像素/秒）；负值绝对值越大弹得越高
@export var bounce_velocity := -1000.0
## 压缩贴图保持的时长（秒），弹力在踩中瞬间施加
@export var recover_delay := 0.12
## 按钮踩下到弹簧出现之间的延迟（秒）
@export var activation_delay := 1.0
## 弹簧出现后的可用时间（秒）
@export var visible_duration := 2.0
## 倒计时里显示的装置名称
@export var display_name := "弹簧"

const _extended_texture := preload("res://assets/new_platformer_pack/Vector/Tiles/spring_out.svg")
const _compressed_texture := preload("res://assets/new_platformer_pack/Vector/Tiles/spring.svg")
const _bounce_stream := preload("res://assets/new_platformer_pack/Sounds/sfx_jump-high.ogg")

@onready var _sprite: Sprite2D = $Sprite2D

var _is_bouncing := false
var _sequence_active := false
var _state := ""
var _remaining := 0.0


func _ready() -> void:
	_sprite.texture = _extended_texture
	_set_spring_visible(Engine.is_editor_hint())


func activate() -> void:
	# 一轮内只响应一次，避免按钮反复踩下时把延迟和存在时间叠起来。
	if _sequence_active:
		return
	_sequence_active = true
	_state = "waiting"
	_remaining = activation_delay


func bounce_player(player: CharacterBody2D) -> void:
	if _is_bouncing:
		return
	_is_bouncing = true
	_sprite.texture = _compressed_texture
	_play_bounce_sound()

	if player.has_method("launch_from_spring"):
		player.launch_from_spring(bounce_velocity)
	else:
		player.velocity.y = bounce_velocity

	await get_tree().create_timer(recover_delay).timeout
	if not is_inside_tree():
		return

	_sprite.texture = _extended_texture
	_is_bouncing = false


func _play_bounce_sound() -> void:
	# 优先使用场景里的 BounceSound；旧实例若没有该节点，则动态补一个，避免试玩时报错。
	var sound := get_node_or_null("BounceSound") as AudioStreamPlayer
	if sound == null:
		sound = AudioStreamPlayer.new()
		sound.name = "BounceSound"
		sound.stream = _bounce_stream
		add_child(sound)
	sound.add_to_group("sfx")
	var settings := get_node_or_null("/root/SettingsManager")
	if settings != null:
		settings.apply_sfx_volume(sound)
	sound.play()


func _process(delta: float) -> void:
	if not _sequence_active:
		return

	if _state == "waiting_for_clear":
		_wait_for_player_to_leave()
		return

	_remaining -= delta
	if _state == "waiting":
		_show_countdown(tr("%s 即将出现 %.1f 秒") % [tr(display_name), maxf(0.0, _remaining)])
		if _remaining <= 0.0:
			if _player_overlaps_spring_shape():
				_state = "waiting_for_clear"
				_show_countdown(tr("%s 等待玩家离开") % tr(display_name))
			else:
				_set_spring_visible(true)
				_state = "visible"
				_remaining = visible_duration
	elif _state == "visible":
		_show_countdown(tr("%s 剩余 %.1f 秒") % [tr(display_name), maxf(0.0, _remaining)])
		if _remaining <= 0.0:
			_set_spring_visible(false)
			_state = ""
			_remaining = 0.0
			_sequence_active = false
			_hide_countdown()


func _wait_for_player_to_leave() -> void:
	if _player_overlaps_spring_shape():
		_show_countdown(tr("%s 等待玩家离开") % tr(display_name))
		return
	_set_spring_visible(true)
	_state = "visible"
	_remaining = visible_duration


func _player_overlaps_spring_shape() -> bool:
	# 弹簧出现前先检查未来碰撞区，避免在玩家身体里生成并把玩家顶开。
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


func _set_spring_visible(value: bool) -> void:
	# 根节点 visible 控制贴图，碰撞形状单独关闭，避免隐藏时还挡着玩家。
	visible = value
	for collision_shape in find_children("*", "CollisionShape2D", true, false):
		collision_shape.set_deferred("disabled", not value)


func _show_countdown(text: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("show_countdown"):
		hud.show_countdown(text, self)


func _hide_countdown() -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("hide_countdown"):
		hud.hide_countdown(self)
