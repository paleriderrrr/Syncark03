extends PanelContainer
class_name SynergyPanel

@onready var title_label: Label = %TitleLabel
@onready var list_label: RichTextLabel = %ListLabel

func set_summary(summary: Dictionary, role_name: String) -> void:
	title_label.text = "%s Synergy" % role_name
	var lines: PackedStringArray = []
	for entry in summary.get("entries", []):
		var prefix: String = "[On]" if bool(entry.get("active", false)) else "[Off]"
		lines.append("%s %s x%d" % [
			prefix,
			String(entry.get("category_name", "")),
			int(entry.get("count", 0)),
		])
	list_label.text = "\n".join(lines)
