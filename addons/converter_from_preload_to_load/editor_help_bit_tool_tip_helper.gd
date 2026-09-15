extends RefCounted

var tooltip:PopupPanel
var panel:Panel

var editor_help_bit:Control
var title_label:RichTextLabel
var text_label:RichTextLabel

func _init(_tooltip:PopupPanel = null) -> void:
	##ツールチップ
	## 未公開のクラス EditorHelpBitTooltip
	if not _tooltip:return
	if _tooltip.get_class() != "EditorHelpBitTooltip":return
	tooltip = _tooltip
	
	if tooltip.has_meta(&"_triggered___helper"):
		panel = tooltip.get_meta(&"_triggered___helper___panel")
		editor_help_bit = tooltip.get_meta(&"_triggered___helper___editor_help_bit")
		title_label = tooltip.get_meta(&"_triggered___helper___title_label")
		text_label = tooltip.get_meta(&"_triggered___helper___text_label")
		return
	tooltip.set_meta(&"_triggered___helper", true)
	
	
	##背景としてのみの役割
	panel = tooltip.find_child("*Panel*", false, false)
	tooltip.set_meta(&"_triggered___helper___panel", panel)
	
	## 未公開のクラス EditorHelpBit
	##これが内容
	## 子ノードに RichTextLabelが0個以上
	editor_help_bit = tooltip.find_child("*EditorHelpBit*", false, false)
	tooltip.set_meta(&"_triggered___helper___editor_help_bit", editor_help_bit)
	
	
	title_label = editor_help_bit.get_child(0)
	tooltip.set_meta(&"_triggered___helper___title_label", title_label)
	
	text_label = editor_help_bit.get_child(1)
	tooltip.set_meta(&"_triggered___helper___text_label", text_label)
	
