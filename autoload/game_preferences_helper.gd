extends Node

const PATH_DIRECTORY_PREFERENCES = "user://preferences/";

func ensure_directory_created():
	if not DirAccess.dir_exists_absolute(PATH_DIRECTORY_PREFERENCES):
		DirAccess.make_dir_absolute(PATH_DIRECTORY_PREFERENCES)

func get_preferences_file_path(name: String) -> String:
	return PATH_DIRECTORY_PREFERENCES + "game." + name + ".json"

func load_preferences(default: Dictionary = {}, name: String = "") -> Dictionary:
	if name == "":
		name = suggest_name()

	var path_for_game = get_preferences_file_path(name)
	var file: FileAccess = FileAccess.open(path_for_game, FileAccess.READ)
	if file and file.get_position() < file.get_length():
		var parser = JSON.new()
		parser.parse(file.get_as_text(true))
		return parser.data
	return default

func save_preferences(dict: Dictionary, name: String = "") -> void:
	if name == "":
		name = suggest_name()

	ensure_directory_created()
	var path_for_game = get_preferences_file_path(name)
	var file: FileAccess = FileAccess.open(path_for_game, FileAccess.WRITE)
	if file:
		var parser = JSON.new()
		var indent = "  " if OS.is_debug_build() else ""
		var json = parser.stringify(dict, indent)
		file.store_string(json)

func suggest_name() -> String:
	return get_tree().current_scene.scene_file_path.get_file().get_basename()
