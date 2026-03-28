extends PanelContainer
class_name SynergyPanel

@onready var title_label: Label = %TitleLabel
@onready var list_label: RichTextLabel = %ListLabel

func set_summary(summary: Dictionary, role_name: String) -> void:
	title_label.text = "%s 连携" % role_name
	var lines: PackedStringArray = []
	for entry in summary.get("entries", []):
		var prefix: String = "[激活]" if bool(entry.get("active", false)) else "[未激活]"
		lines.append("%s %s %d - %s" % [
			prefix,
			String(entry.get("category_name", "")),
			int(entry.get("count", 0)),
			String(entry.get("synergy_name", "")),
		])
		lines.append("  %s" % String(entry.get("effect_text", "")))
	list_label.text = "\n".join(lines)
