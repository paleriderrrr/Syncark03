@tool
extends RefCounted
class_name NumericEditorTableModel


var key: String = ""
var title: String = ""
var columns: Array[Dictionary] = []
var rows: Array[Dictionary] = []
var editable: bool = true


func setup(p_key: String, p_title: String, p_columns: Array[Dictionary], p_rows: Array[Dictionary], p_editable: bool = true) -> NumericEditorTableModel:
	key = p_key
	title = p_title
	columns = p_columns.duplicate(true)
	rows = p_rows.duplicate(true)
	editable = p_editable
	return self


func duplicate_rows() -> Array[Dictionary]:
	return rows.duplicate(true)
