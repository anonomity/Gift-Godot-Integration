class_name JsonManager
extends RefCounted

var _file_name: String
var _parser = JSON.new()
var data: Variant
var error: bool = false

func _init(
	p_file_name: String,
	p_autoload: bool = true,
	p_create_if_missing: bool = true,
):
	assert(p_file_name != null)
	assert(!p_file_name.is_empty())

	_file_name = p_file_name
	if p_autoload:
		self.load(p_create_if_missing)

func load(
	p_create_if_missing: bool = false,
) -> bool:
	var file_path := "user://" + _file_name
	if !FileAccess.file_exists(file_path):
		if p_create_if_missing:
			save()
		else:
			push_error("[JsonManager] File does not exist: \"%s\"" % [
				file_path,
			])
			return false
	
	var file = FileAccess.open("user://" + _file_name, FileAccess.READ)
	if file == null:
		var error_code := FileAccess.get_open_error()
		push_error("[JsonManager] Error (%d) opening \"%s\": %s" % [
			error_code,
			_file_name,
			error_string(error_code),
		])
		error = true
		return false

	var json = file.get_as_text()
	var result = _parser.parse(json)
	if result:
		printerr("Error parsing \"%s\"" % [_file_name])
		error = true
		return false

	data = _parser.data

	error = false
	return true

func save() -> bool:
	var separator = _file_name.rfind("/")
	if separator > - 1:
		var directory = _file_name.substr(0, separator)
		var qualified_directory_path = "user://" + directory
		if not DirAccess.dir_exists_absolute(qualified_directory_path):
			DirAccess.make_dir_recursive_absolute(qualified_directory_path)
	var file = FileAccess.open("user://" + _file_name, FileAccess.WRITE)
	if not file:
		printerr("Failed to open for writing \"%s\": %d" % [_file_name, FileAccess.get_open_error()])
		error = true
		return false

	var indent = "  " if OS.is_debug_build() else ""
	var json = JSON.stringify(data, indent)
	file.store_string(json)

	error = false
	return true
