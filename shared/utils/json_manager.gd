class_name JsonManager
extends RefCounted

var _file_name: String
var _parser = JSON.new()
var data: Variant
var error: bool = false

func _init(file_name: String, autoload: bool=true):
	assert(file_name != null)
	assert(file_name != "")

	_file_name = file_name
	if autoload:
		self.load()

func load() -> bool:
	var file = FileAccess.open("user://" + _file_name, FileAccess.READ)
	if not file:
		printerr("Failed to open for reading \"%s\": %d" % [_file_name, FileAccess.get_open_error()])
		error = true
		return false

	var json = file.get_as_text(true)
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
