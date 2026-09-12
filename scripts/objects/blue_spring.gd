extends StaticBody2D
## 蓝色弹簧：独立物理层上的实体平台，只有玩家从上方落到顶部时才给一次向上力。

## 弹飞玩家的向上速度（像素/秒）；负值绝对值越大弹得越高
@export var bounce_velocity := -1350.0
## 压缩贴图保持的时长（秒），弹力在进入瞬间立即施加
@export var recover_delay := 0.12

const _extended_texture := preload("res://assets/new_platformer_pack/Vector/Tiles/spring_out.svg")
const _compressed_texture := preload("res://assets/new_platformer_pack/Vector/Tiles/spring.svg")
const _bounce_stream := preload("res://assets/new_platformer_pack/Sounds/sfx_jump-high.ogg")

@onready var _sprite: Sprite2D = $Sprite2D

var _is_bouncing := false


func _ready() -> void:
	_sprite.texture = _extended_texture


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
