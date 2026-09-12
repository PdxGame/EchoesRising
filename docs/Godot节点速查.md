# Godot 节点速查（个人学习笔记）

这份文档是给你自己看的 Godot 入门速查，不是项目约束。内容以纵向跳跃玩法实际会用到的节点为主，边做边补。

## 1. 先理解三个概念

- **节点（Node）**：Godot 的最小组成单位，相当于 Unity 的 GameObject。
- **场景（.tscn）**：一组节点保存成文件，相当于 Unity 的 Prefab，也能当 Unity 的 Scene 用。
- **场景树（SceneTree）**：运行时所有节点组成的树，游戏每一帧都会遍历它。

创建节点的两种方式：

编辑器里：场景面板右键 → Add Child Node → 搜索节点名。

代码里：

```gdscript
var marker := Marker2D.new()
marker.position = Vector2(100, 50)
add_child(marker)
```

## 2. 2D 世界基础节点

| 节点 | 作用 | 创建方式 | 本项目用途 |
| --- | --- | --- | --- |
| `Node2D` | 2D 节点的基类，有位置/旋转/缩放 | 编辑器或代码 | 主场景根节点 |
| `Marker2D` | 只记录一个位置，不显示 | 编辑器 | 出生点、平台锚点 |
| `Sprite2D` | 显示一张图片 | 编辑器拖入图片 | 角色/道具贴图 |
| `Polygon2D` | 用顶点画多边形 | 编辑器画点或代码 | 占位图形、视觉装饰 |
| `Line2D` | 画折线 | 编辑器 | 路径提示、视觉装饰 |
| `Camera2D` | 控制镜头 | 编辑器 | 纵向跟随玩家攀登的镜头 |

示例：让镜头跟随玩家

```gdscript
var camera := Camera2D.new()
camera.position_smoothing_enabled = true
add_child(camera)
```

## 3. 物理与碰撞

| 节点 | 作用 | 本项目用途 |
| --- | --- | --- |
| `CharacterBody2D` | 受代码控制的移动角色，自带 `move_and_slide()` | 玩家 |
| `StaticBody2D` | 不动的碰撞体 | 地面、平台、墙 |
| `RigidBody2D` | 受物理模拟的刚体 | 暂时不用 |
| `Area2D` | 侦测区域，不阻挡 | 拾取物、危险判定、弹跳垫触发 |
| `CollisionShape2D` | 给上面的 Body/Area 提供实际碰撞形状 | 每个 Body/Area 都要挂一个 |

玩家移动最小示例：

```gdscript
extends CharacterBody2D

@export var speed := 320.0

func _physics_process(delta: float) -> void:
	var dir := Input.get_axis("ui_left", "ui_right")
	velocity.x = dir * speed
	move_and_slide()
```

Area2D 触发示例（拾取物）：

```gdscript
extends Area2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		queue_free()
```

## 4. 地形：TileMapLayer + TileSet

- `TileSet`：瓦片集资源，定义有哪些瓦片。
- `TileMapLayer`：放在场景里，用瓦片刷出地形。

创建流程：

1. 准备一张瓦片图，例如 96x32，里面 3 个 32x32 瓦片。
2. 创建一个 `.tres` TileSet 资源，指定图片和瓦片尺寸。
3. 在关卡场景加 `TileMapLayer`，把 TileSet 赋给它。
4. 选中该节点，在底部 `TileMap` 面板选瓦片，在 2D 视口刷格子。

后面要做碰撞时，在 TileSet 里给瓦片加物理图层，这样刷出来的地形会自动有碰撞。

## 5. 计时与动画

| 节点 | 作用 | 本项目用途 |
| --- | --- | --- |
| `Timer` | 倒计时后触发信号 | 弹跳垫冷却、重生延迟 |
| `Tween` | 平台改变数值 | 平台移动、UI 反馈动画 |
| `AnimationPlayer` | 播放动画 | 角色动画 |

计时器示例（弹跳垫冷却）：

```gdscript
extends Node

@export var cooldown := 1.0
@onready var timer := $Timer
@onready var platform := $Platform

func _ready() -> void:
	timer.wait_time = cooldown
	timer.timeout.connect(_on_timeout)

func _on_triggered() -> void:
	platform.visible = false
	timer.start()

func _on_timeout() -> void:
	platform.visible = true
```

## 6. UI 节点

UI 节点都是 `Control` 的子类，通常放在 `CanvasLayer` 下，保证不随游戏镜头移动。

| 节点 | 作用 |
| --- | --- |
| `CanvasLayer` | 独立显示层，UI 放这里 |
| `Label` | 显示文字 |
| `Button` | 按钮 |
| `PanelContainer` | 带背景的容器 |
| `VBoxContainer` / `HBoxContainer` | 纵向/横向自动排列 |
| `ProgressBar` | 血条、能量条 |
| `CenterContainer` | 让内容居中 |

UI 创建后，锚点决定它停靠在哪：左上、全屏、底部等，可以在 Inspector 里设置。

## 7. 音频

| 节点 | 作用 |
| --- | --- |
| `AudioStreamPlayer` | 播放一段声音，非空间化 |
| `AudioStreamPlayer2D` | 2D 空间音效，距离越远越小声 |

示例：

```gdscript
@onready var jump_sound := $JumpSound

func _play_jump() -> void:
	jump_sound.pitch_scale = 1.0 + randf() * 0.1
	jump_sound.play()
```

## 8. 数据与复用

- `@export`：在 Inspector 里配置的变量，适合做场景参数。
- `Resource`（.tres）：存数据，例如平台配置、关卡配置。
- `PackedScene`：把一个 `.tscn` 变成可实例化的模板。
- `Autoload`：全局单例，例如我们的 EventManager。

实例化场景示例：

```gdscript
const PlatformScene := preload("res://scenes/player/player.tscn")

func spawn_platform(pos: Vector2) -> void:
	var platform := PlatformScene.instantiate()
	platform.position = pos
	add_child(platform)
```

## 9. 常用快捷键

- `Ctrl+A`：给选中节点添加子节点
- `Ctrl+S`：保存当前场景
- `F5`：运行主场景
- `F6`：运行当前打开的场景
- `Ctrl+D`：复制节点（Godot 4）

## 10. 项目内的目录约定

- `scenes/`：场景文件，按 main / player / levels / ui 分
- `scripts/`：脚本，按 managers / player / ui 分
- `assets/`：字体、角色素材（按需增长）
- `docs/`：文档；`docs/archive/` 为旧方案归档
