class_name GamesManager extends RefCounted

const PATH_ROOT_CUSTOM: String = "res://custom"
const NAME_FILE_PROJECT: String = "project.godot-twitch-games.json"

const PATH_ROOT_GAMES = "res://scenes/games"
const NAME_FILE_GAME_ICON = "game_icon.png"
const NAME_FILE_GAME_ICON_SCENE = "game_icon.tscn"
const NAME_FILE_GAME_CONFIG = "game.cfg"
const NAME_FILE_GAME_CONSTANTS = "game_constants.gd"

var games: Array[Dictionary] = []

func get_all_actions() -> Array[String]:
	var actions: Array[String] = []

	for game in get_games():
		if not game.has("id"):
			continue

		var id = game["id"]

		if not game.has("constants"):
			continue

		var constants = game["constants"]
		if not constants:
			continue

		var action_keys = constants.Actions.keys()
		actions.append_array(action_keys.map(func (key): return "%s::%s" % [id, key]))

	return actions

func get_games(force: bool = false) -> Array:
	if games.size() > 0 and not force:
		return games

	var game_root_paths: Array[String] = [PATH_ROOT_GAMES]
	
	# TODO: Autoloads in custom folders
	# What's a good way to do this?
	# Can we accomplish this and still have in-editor autocomplete for a specific name?
	# var autoload_root_paths: Array[String] = []

	var da_custom := DirAccess.open(PATH_ROOT_CUSTOM)
	if da_custom:
		da_custom.list_dir_begin()
		var custom_name := da_custom.get_next()
		while custom_name != "":
			var path_dir_custom := "%s/%s" % [PATH_ROOT_CUSTOM, custom_name]
			var path_file_custom_project := "%s/%s" % [path_dir_custom, NAME_FILE_PROJECT]

			if da_custom.current_is_dir():
				if FileAccess.file_exists(path_file_custom_project):
					var path_dir_custom_games := "%s/games" %  [path_dir_custom]
					if DirAccess.dir_exists_absolute(path_dir_custom_games):
						game_root_paths.append(path_dir_custom_games)
					else:
						print("Not a valid custom games project games directory: %s" % path_dir_custom_games)
				else:
					print("Not a valid custom games project file: %s" % path_file_custom_project)
			else:
				print("Not a valid custom games directory: %s" % path_dir_custom)

			custom_name = da_custom.get_next()
		da_custom.list_dir_end()
	else:
		print("No custom resources directory: %s" % PATH_ROOT_CUSTOM)
	
	var search_games: Array[Dictionary] = []

	for path_root_games in game_root_paths:
		print("Searching for stream games in %s" % path_root_games)
		var da_games := DirAccess.open(path_root_games)
		if not da_games:
			push_warning("Invalid game root path: %s" % path_root_games)
			continue

		da_games.list_dir_begin()
		var game_name := da_games.get_next()
		while game_name != "":
			if not da_games.current_is_dir():
				print_verbose("Skipping %s because it is not a directory (in %s)" % [game_name, path_root_games])
			elif game_name.begins_with("_"):
				print_verbose("Skipping %s because it starts with '_' (in %s)" % [game_name, path_root_games])
			else:
				print("Loading game metadata for '%s' (from %s)" % [path_root_games, game_name])
				
				var path_dir_game := "%s/%s" % [path_root_games, game_name]
				var config := load_config(path_dir_game)
				config["id"] = game_name
				config["scene_path"] = "%s/%s.tscn" % [path_dir_game, game_name]
				config.get_or_add("name", game_name)
				config.get_or_add("order", search_games.size())

				var icon := load_icon(path_dir_game)
				if icon:
					config["icon"] = icon

				var icon_scene := load_icon_scene(path_dir_game)
				if icon_scene:
					config["icon_scene"] = icon_scene
				
				var constants := load_constants(path_dir_game)
				if constants:
					config["constants"] = constants

				search_games.append(config)
			
			game_name = da_games.get_next()

	search_games.sort_custom(sort_by_order)
	search_games.map(delete_order)

	games = search_games
	if search_games.is_empty():
		push_error("There are no games in %s or %s" % [PATH_ROOT_GAMES, PATH_ROOT_CUSTOM])
	
	return games

func load_constants(path_game: String) -> Script:
	var path_to_resource := "%s/%s" % [path_game, NAME_FILE_GAME_CONSTANTS]
	var has_resource = ResourceLoader.exists(path_to_resource)
	if !has_resource:
		return null

	return load(path_to_resource)

func load_icon(path_game: String) -> ImageTexture:
	var path_to_resource := "%s/%s" % [path_game, NAME_FILE_GAME_ICON]
	var has_resource = ResourceLoader.exists(path_to_resource, "CompressedTexture2D")
	if !has_resource:
		return null

	return ResourceLoader.load(path_to_resource, "CompressedTexture2D")

func load_icon_scene(path_game: String) -> PackedScene:
	var path_to_resource := "%s/%s" % [path_game, NAME_FILE_GAME_ICON_SCENE]
	var has_resource = ResourceLoader.exists(path_to_resource, "PackedScene")
	if !has_resource:
		return null

	return load(path_to_resource)

func load_config(path_game: String) -> Dictionary:
	var path_to_resource := "%s/%s" % [path_game, NAME_FILE_GAME_CONFIG]
	var config := ConfigFile.new()
	if config.load(path_to_resource) != OK:
		return {}

	var config_dict: Dictionary = {}
	for section in config.get_sections():
		for key in config.get_section_keys(section):
			config_dict[key] = config.get_value(section, key)

	return config_dict

func sort_by_order(a: Dictionary, b: Dictionary) -> bool:
	return a.order < b.order

func delete_order(dict: Dictionary) -> Dictionary:
	if dict.has("order"):
		dict.erase("order")

	return dict
