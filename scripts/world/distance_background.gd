@tool
extends Node2D
## 距离背景：在指定世界 y 范围内，用固定尺寸重复贴背景图，避免把一张图纵向拉伸到整段关卡。

## 这一背景段使用的贴图
@export var texture: Texture2D
## 背景段顶部世界 y（更小/更负的 y）
@export var top_y := -1664.0
## 背景段底部世界 y（更大的 y）
@export var bottom_y := 128.0
## 每张背景在世界中的宽度（像素）
@export var tile_width := 1408.0
## 单张背景的参考高度（像素）；实际高度会根据段落总高度均分
@export var tile_height := 768.0


func _ready() -> void:
	_rebuild()


func _rebuild() -> void:
	# 编辑器/运行时都会重建，只生成显示用的 Sprite2D，不写入场景文件。
	for child in get_children():
		child.queue_free()
	if texture == null:
		return

	var span := maxf(0.0, bottom_y - top_y)
	var tile_count := maxi(1, ceili(span / tile_height))
	var actual_tile_height := span / tile_count
	for index in tile_count:
		var sprite := Sprite2D.new()
		sprite.name = "BackgroundTile%d" % index
		sprite.texture = texture
		sprite.position = Vector2(
			0.0,
			top_y + actual_tile_height * (index + 0.5)
		)
		sprite.scale = Vector2(tile_width / 256.0, actual_tile_height / 256.0)
		add_child(sprite)
