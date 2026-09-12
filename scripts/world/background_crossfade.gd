@tool
extends CanvasLayer
## 距离背景层：按玩家爬升高度在三张全屏背景间平滑淡入淡出，不重复拼接背景图。

const _tree_texture := preload("res://assets/new_platformer_pack/Vector/Backgrounds/background_color_trees.svg")
const _cloud_texture := preload("res://assets/new_platformer_pack/Vector/Backgrounds/background_clouds.svg")
const _desert_texture := preload("res://assets/new_platformer_pack/Vector/Backgrounds/background_color_desert.svg")

## 树丛过渡到云层的中心爬升高度（像素）
@export var tree_to_cloud_height := 1900.0
## 云层过渡到沙漠的中心爬升高度（像素）
@export var cloud_to_desert_height := 5800.0
## 背景切换的过渡距离（像素），越大越柔和
@export var fade_distance := 700.0
## 背景相对玩家的慢速视差系数；越大背景移动越明显
@export_range(0.0, 0.1, 0.005) var parallax_factor := 0.025

var _tree_sprite: Sprite2D
var _cloud_sprite: Sprite2D
var _desert_sprite: Sprite2D
var _viewport_center := Vector2.ZERO
var _parallax_limit := 0.0


func _ready() -> void:
	layer = -100
	_ensure_sprites()
	_layout_sprites()
	_update_weights(0.0)


func _process(_delta: float) -> void:
	var height := 0.0
	var player := get_tree().get_first_node_in_group("player")
	if player != null:
		height = maxf(0.0, -player.global_position.y)
	_update_weights(height)
	_update_parallax(height)


func _ensure_sprites() -> void:
	_tree_sprite = _create_sprite("TreeBackground", _tree_texture)
	_cloud_sprite = _create_sprite("CloudBackground", _cloud_texture)
	_desert_sprite = _create_sprite("DesertBackground", _desert_texture)


func _create_sprite(sprite_name: String, texture: Texture2D) -> Sprite2D:
	var sprite := get_node_or_null(sprite_name) as Sprite2D
	if sprite == null:
		sprite = Sprite2D.new()
		sprite.name = sprite_name
		add_child(sprite)
	sprite.texture = texture
	return sprite


func _layout_sprites() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	_viewport_center = viewport_size * 0.5
	# 按每张背景的实际导入尺寸计算缩放，避免写死低分辨率基准。
	# 略放大到画面外，留出背景轻微偏移的空间，同时不重复拼接。
	var tree_scale := _fit_background(_tree_sprite, viewport_size)
	_fit_background(_cloud_sprite, viewport_size)
	_fit_background(_desert_sprite, viewport_size)
	var tree_size := _tree_sprite.texture.get_size()
	_parallax_limit = maxf(0.0, (tree_scale.y * tree_size.y - viewport_size.y) * 0.5)


func _fit_background(sprite: Sprite2D, viewport_size: Vector2) -> Vector2:
	# 使用纹理自身尺寸计算铺满缩放，导入分辨率变化时无需再改代码。
	var texture_size := sprite.texture.get_size()
	var display_scale := viewport_size / texture_size * 1.6
	sprite.position = _viewport_center
	sprite.scale = display_scale
	return display_scale


func _update_parallax(height: float) -> void:
	# 背景移动比玩家慢：近景树丛稍快，云层更慢，沙漠最慢，形成视差层次。
	var tree_offset := clampf(height * parallax_factor, -_parallax_limit, _parallax_limit)
	var cloud_offset := clampf(height * parallax_factor * 0.65, -_parallax_limit, _parallax_limit)
	var desert_offset := clampf(height * parallax_factor * 0.35, -_parallax_limit, _parallax_limit)
	_tree_sprite.position.y = _viewport_center.y + tree_offset
	_cloud_sprite.position.y = _viewport_center.y + cloud_offset
	_desert_sprite.position.y = _viewport_center.y + desert_offset


func _update_weights(height: float) -> void:
	var tree_weight := 1.0
	var cloud_weight := 0.0
	var desert_weight := 0.0

	var first_fade_start := tree_to_cloud_height - fade_distance * 0.5
	var first_fade_end := tree_to_cloud_height + fade_distance * 0.5
	var second_fade_start := cloud_to_desert_height - fade_distance * 0.5
	var second_fade_end := cloud_to_desert_height + fade_distance * 0.5

	if height <= first_fade_start:
		tree_weight = 1.0
	elif height < first_fade_end:
		var first_blend := inverse_lerp(first_fade_start, first_fade_end, height)
		tree_weight = 1.0 - first_blend
		cloud_weight = first_blend
	elif height <= second_fade_start:
		cloud_weight = 1.0
	elif height < second_fade_end:
		var second_blend := inverse_lerp(second_fade_start, second_fade_end, height)
		cloud_weight = 1.0 - second_blend
		desert_weight = second_blend
	else:
		desert_weight = 1.0

	_tree_sprite.modulate.a = tree_weight
	_cloud_sprite.modulate.a = cloud_weight
	_desert_sprite.modulate.a = desert_weight
