extends Camera2D
## 纵向跟随相机：只跟随玩家 Y 轴，X 固定在场景中线。

## 相机跟随的目标节点（通常指向玩家）
@export var target_path: NodePath
## 相机中心相对目标的垂直偏移（像素）；负值表示相机略高于玩家
@export var vertical_offset := -80.0

@onready var _target: Node2D = get_node_or_null(target_path) as Node2D


func _ready() -> void:
	# 开场时直接吸附到玩家位置，避免镜头从原点滑过来。
	if _target:
		global_position = Vector2(0.0, _target.global_position.y + vertical_offset)


func _physics_process(_delta: float) -> void:
	# 每物理帧读取玩家 Y，位置实时跟随；X 始终归零。
	if not is_instance_valid(_target):
		return

	var target_camera_y := _target.global_position.y + vertical_offset
	global_position.y = target_camera_y

	global_position.x = 0.0
