extends CanvasLayer
## 引导 NPC 的对话层：按页显示文本，用跳跃键翻页，ESC 关闭并解除暂停。

signal finished

var _lines: PackedStringArray = []
var _line_index := 0
var _npc_name := ""
var _allow_cancel := true


func setup(npc_name: String, lines: PackedStringArray, allow_cancel := true) -> void:
	_npc_name = npc_name
	_lines = lines
	_line_index = 0
	_allow_cancel = allow_cancel
	_render_page()


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	if _allow_cancel and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_request_close()
		return
	if event.is_action_pressed("jump") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_advance_page()


func _advance_page() -> void:
	if _line_index < _lines.size() - 1:
		_line_index += 1
		_render_page()
		return
	_request_close()


func _request_close() -> void:
	finished.emit()


func _render_page() -> void:
	var title := $Root/CenterContainer/Panel/Box/TitleLabel as Label
	var body := $Root/CenterContainer/Panel/Box/BodyLabel as Label
	var page_hint := $Root/CenterContainer/Panel/Box/PageHint as Label
	title.text = _npc_name
	body.text = tr(_lines[_line_index]) if _lines.size() > 0 else ""
	var action_hint := tr("空格 / W 继续")
	if _line_index >= _lines.size() - 1:
		action_hint = tr("空格 / W 结束")
	var suffix := "    " + action_hint
	if _allow_cancel:
		suffix += "    " + tr("ESC 关闭")
	page_hint.text = "%d / %d%s" % [
		_line_index + 1,
		maxi(1, _lines.size()),
		suffix
	]
