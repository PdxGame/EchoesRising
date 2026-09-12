extends Area2D
## 引导 NPC：玩家靠近后按 E 对话。台词统一从文本库读取，脚本只负责页数和索引。

const _dialogue_bank := preload("res://resources/npc_dialogue_bank.tres")

## 对话框标题，通常写 NPC 身份
@export var npc_name := "守梯人"
## NPC 使用台词库中的第几套台词，从 0 开始
@export var dialogue_index := 0

const GuideDialogueScene := preload("res://scenes/ui/guide_dialogue.tscn")

@onready var _prompt_label: Label = $PromptLabel

var _player_near := false
var _dialogue: CanvasLayer = null
var _pause_menu: CanvasLayer = null
var _pause_menu_previous_mode := Node.PROCESS_MODE_INHERIT


func _ready() -> void:
	_prompt_label.visible = false
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _physics_process(_delta: float) -> void:
	if _player_near and _dialogue == null and Input.is_action_just_pressed("interact"):
		_open_dialogue()


func _on_body_entered(body: Node2D) -> void:
	if body is CharacterBody2D:
		_player_near = true
		_prompt_label.visible = true


func _on_body_exited(body: Node2D) -> void:
	if body is CharacterBody2D:
		_player_near = false
		_prompt_label.visible = false


func _open_dialogue() -> void:
	if get_tree().paused:
		return
	var dialogue_lines := _get_dialogue_set(dialogue_index)
	if dialogue_lines.is_empty():
		return
	_dialogue = GuideDialogueScene.instantiate()
	add_child(_dialogue)
	_dialogue.setup(tr(npc_name), dialogue_lines)
	_dialogue.finished.connect(_close_dialogue)
	_pause_menu = get_tree().current_scene.get_node_or_null("PauseMenu") as CanvasLayer
	if _pause_menu != null:
		# 对话期间停用暂停菜单，避免 ESC 同时打开两个界面。
		_pause_menu_previous_mode = _pause_menu.process_mode
		_pause_menu.process_mode = Node.PROCESS_MODE_DISABLED
	get_tree().paused = true


func _close_dialogue() -> void:
	if _dialogue != null:
		_dialogue.queue_free()
		_dialogue = null
	if _pause_menu != null:
		_pause_menu.process_mode = _pause_menu_previous_mode
		_pause_menu = null
	Input.action_release("jump")
	Input.action_release("ui_accept")
	var player := get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("suppress_next_jump"):
		player.suppress_next_jump()
	get_tree().paused = false


func _get_dialogue_set(index: int) -> PackedStringArray:
	return _dialogue_bank.get_dialogue_set(index)
