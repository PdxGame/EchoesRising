extends Resource
## NPC 文本库资源：整个文本库保存在一个多行文本字段里。

## 全部 NPC 台词内容；格式说明见 resources/npc_dialogue_bank.tres
@export_multiline var content := ""


func get_dialogue_set(index: int) -> PackedStringArray:
	## 按索引取出多页台词；=== 分隔页，--- 索引 --- 开始一套。
	var current_index := -1
	var pages := PackedStringArray()
	var page_lines := PackedStringArray()

	for raw_line in content.split("\n"):
		var line := raw_line.strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		if line.begins_with("--- ") and line.ends_with(" ---"):
			if not page_lines.is_empty():
				pages.append("\n".join(page_lines))
				page_lines = PackedStringArray()
			if not pages.is_empty() and current_index == index:
				return pages
			current_index = int(line.trim_prefix("--- ").trim_suffix(" ---"))
			pages = PackedStringArray()
			continue
		if line == "===":
			if not page_lines.is_empty():
				pages.append("\n".join(page_lines))
				page_lines = PackedStringArray()
			continue
		page_lines.append(line)

	if not page_lines.is_empty():
		pages.append("\n".join(page_lines))
	if not pages.is_empty() and current_index == index:
		return pages
	return PackedStringArray()
