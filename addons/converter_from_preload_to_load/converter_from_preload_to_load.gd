@tool
extends EditorPlugin

func _enable_plugin() -> void:
	# Add autoloads here.
	pass


func _disable_plugin() -> void:
	# Remove autoloads here.
	pass


func _enter_tree() -> void:
	# Initialization of the plugin goes here.
	pass
	
	initialized()



func _exit_tree() -> void:
	# Clean-up of the plugin goes here.
	pass


#####################################
#####################################



func _is_preload(tooltip_helper:EditorHelpBitToolTipHelper) -> bool:
	return tooltip_helper.title_label.get_parsed_text().ends_with("@GDScript.preload(path: String) -> Resource")



func _get_path(line: int, column: int, code_edit:CodeEdit, tooltip_helper:EditorHelpBitToolTipHelper) -> String:
	
	if not _is_preload(tooltip_helper):
		return ""
	
	var text := code_edit.get_line(line)
	
	var regex_match := _search_preload_syntax(text)
	if not regex_match:
		return ""
	
	var syntax := _crop_text_by_regex_match(text, regex_match)
	
	
	if syntax.get_slice_count("\"") != 3:return ""
	var resource_path:String = syntax.get_slice("\"", 1)
	if not ResourceLoader.exists(resource_path):return ""
	
	return resource_path

func _is_scene(line: int, column: int, code_edit:CodeEdit, tooltip_helper:EditorHelpBitToolTipHelper) -> bool:
	var resource_path:String = _get_path(line, column, code_edit, tooltip_helper)
	if resource_path.is_empty():return false
	
	return ClassDB.is_parent_class(_get_type(resource_path), &"PackedScene")

func _get_type(resource_path:String) -> String:
	##4.8
	#return ResourceLoader.get_resource_type(resource_path)
	return load(resource_path).get_class()



#####################################
#####################################


func _get_action_text_for_resource() -> String:
	match TranslationServer.get_tool_locale():
		"ja":
			return "リソースとしてpreloadからloadに変換"
		_:
			return "Convert from “preload” to “load” for Resource."
	return "Error text"

func _get_action_text_for_scene() -> String:
	match TranslationServer.get_tool_locale():
		"ja":
			return "シーンとしてpreloadからloadに変換"
		_:
			return "Convert from “preload” to “load” for Scene."
	return "Error text"

#####################################
#####################################

func initialized() -> void:
	var script_editor:ScriptEditor = EditorInterface.get_script_editor()
	if not script_editor.is_node_ready():
		await script_editor.ready
	
	script_editor.editor_script_changed.connect(update_code_edits.bind(script_editor).unbind(1))
	update_code_edits(script_editor)

const EditorHelpBitToolTipHelper = preload("uid://8nx3oo2048ro")
const _ACTION_RESOURCE_META:String = "resource"
const _ACTION_SCENE_META:String = "scene"


func _on_symbol_hovered(symbol: String, line: int, column: int, code_edit:CodeEdit) -> void:
	if code_edit == null:return
	
	##表示時のみノードが生成されるのでホバーごとにトリガー
	##ツールチップを取得
	var tooltip_node:PopupPanel = code_edit.find_child("*EditorHelpBitTooltip*", false, false)
	if tooltip_node == null:return
	
	
	var tooltip_helper:EditorHelpBitToolTipHelper = EditorHelpBitToolTipHelper.new(tooltip_node)
	
	if tooltip_helper.tooltip.has_meta(&"_triggered___plugin_converter_from_preload_to_load"):return
	tooltip_helper.tooltip.set_meta(&"_triggered___plugin_converter_from_preload_to_load", true)
	
	
	var resource_path:String = _get_path(line, column, code_edit, tooltip_helper)
	if resource_path.is_empty():return
	
	
	_trigger(symbol, line, column, code_edit, tooltip_helper, resource_path)


func _trigger(symbol: String, line: int, column: int, code_edit:CodeEdit, tooltip_helper:EditorHelpBitToolTipHelper, path:String) -> void:
	var action_quantity:int = 0
	
	_add_action(
		_ACTION_RESOURCE_META,
		EditorInterface.get_base_control().get_theme_icon(&"Object", &"EditorIcons"),
		_get_action_text_for_resource(),
		tooltip_helper
	)
	action_quantity += 1
	
	
	if _is_scene(line, column, code_edit, tooltip_helper):
		_add_action(
		_ACTION_SCENE_META,
		EditorInterface.get_base_control().get_theme_icon(&"PackedScene", &"EditorIcons"),
		_get_action_text_for_scene(),
		tooltip_helper
		)
		action_quantity += 1
	
	tooltip_helper.text_label.meta_clicked.connect(_on_meta_clicked.bind(symbol, line, column, code_edit, tooltip_helper, path))
	
	if not tooltip_helper.text_label.is_finished():
		await tooltip_helper.text_label.finished
	
	for i in range(action_quantity, 0, -1):
		tooltip_helper.tooltip.size.y += tooltip_helper.text_label.get_line_height(tooltip_helper.text_label.get_line_count() - i)
	
	tooltip_helper.tooltip.size.y += tooltip_helper.text_label.get_line_height(tooltip_helper.text_label.get_line_count() - 1)


func _on_meta_clicked(meta:Variant, symbol: String, line: int, column: int, code_edit:CodeEdit, tooltip_helper:EditorHelpBitToolTipHelper, path:String) -> void:
	if meta == _ACTION_RESOURCE_META:
		_action_resource(symbol, line, column, code_edit, tooltip_helper, path)
	if meta == _ACTION_SCENE_META:
		_action_scene(symbol, line, column, code_edit, tooltip_helper, path)


func _add_action(meta:Variant, icon:Texture2D, text:String, tooltip_helper:EditorHelpBitToolTipHelper) -> void:
	tooltip_helper.text_label.newline()
	tooltip_helper.text_label.push_meta(meta, RichTextLabel.META_UNDERLINE_ON_HOVER)
	
	tooltip_helper.text_label.add_image(icon)
	tooltip_helper.text_label.add_text("  ")
	
	tooltip_helper.text_label.add_text(text)
	
	
	tooltip_helper.text_label.pop()



func _action_resource(symbol: String, line: int, column: int, code_edit:CodeEdit, tooltip_helper:EditorHelpBitToolTipHelper, path:String) -> void:
	code_edit.begin_complex_operation()
	
	var text := code_edit.get_line(line)
	
	var regex_match := _search_preload_syntax(text)
	if not regex_match:
		return
	
	var syntax := _crop_text_by_regex_match(text, regex_match)
	
	
	var property_name:String = syntax.get_slice(" ", 1).to_snake_case()
	
	var convert:String = "var " + property_name + ":" + _get_type(path) + " = load(\"" + path + "\")"
	
	code_edit.remove_text(line, regex_match.get_start(), line, regex_match.get_end())
	code_edit.insert_text(convert, line, regex_match.get_start())
	
	code_edit.end_complex_operation()


func _action_scene(symbol: String, line: int, column: int, code_edit:CodeEdit, tooltip_helper:EditorHelpBitToolTipHelper, path:String) -> void:
	code_edit.begin_complex_operation()
	
	var text := code_edit.get_line(line)
	
	var regex_match := _search_preload_syntax(text)
	if not regex_match:
		return
	
	var syntax := _crop_text_by_regex_match(text, regex_match)
	
	
	var property_name:String = syntax.get_slice(" ", 1).to_snake_case()
	
	var scene:PackedScene = load(path)
	var scene_root_type:StringName = scene.get_state().get_node_type(0)
	
	
	##カスタムタイプ-------------
	var script_type_syntax:String = ""
	for i in scene.get_state().get_node_property_count(0):
		if scene.get_state().get_node_property_name(0, i) == "script":
			var script:Script = scene.get_state().get_node_property_value(0, i)
			
			if script.is_built_in():
				break
			
			var script_type_name:String
			if script.get_global_name():
				script_type_name = script.get_global_name()
			else:
				script_type_name = script.resource_path.get_file().get_basename().to_pascal_case()
				script_type_syntax = "const " + script_type_name + " = preload(\"" + script.resource_path + "\")\n"
				
				var indent:String
				for j in text:
					if j == " " or j == "	":
						indent += j
					else:
						break
				
				script_type_syntax += indent
				
			
			scene_root_type = script_type_name
			break
	##------------------------
	
	
	var convert:String = script_type_syntax + "var " + property_name + ":" + scene_root_type + " = (load(\"" + path + "\") as " + _get_type(path) + ").instantiate()"
	
	code_edit.remove_text(line, regex_match.get_start(), line, regex_match.get_end())
	code_edit.insert_text(convert, line, regex_match.get_start())
	
	code_edit.end_complex_operation()


func _crop_text_by_regex_match(text:String, regex_match:RegExMatch) -> String:
	text = text.left(regex_match.get_end())
	if regex_match.get_start() > 0:
		text = text.right(-regex_match.get_start())
	return text

func _search_preload_syntax(text:String) -> RegExMatch:
	var regex := RegEx.create_from_string("const\\s*\\w+\\s*=\\s*preload\\s*\\(\\s*\\\".+(\\\"\\s*\\))")
	if not regex.is_valid():
		print("error")
		return null
	return regex.search(text)


func update_code_edits(script_editor:ScriptEditor) -> void:
	if script_editor.get_current_editor() == null:
		return
	var control:Control = script_editor.get_current_editor().get_base_editor()
	if control is not CodeEdit:return
	var code_edit:CodeEdit = control
	
	if not code_edit.symbol_hovered.is_connected(_on_symbol_hovered):
		code_edit.symbol_hovered.connect(_on_symbol_hovered.bind(code_edit))
