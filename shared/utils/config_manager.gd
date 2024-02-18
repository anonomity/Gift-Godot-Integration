class_name ConfigManager
extends RefCounted

const PATH_APP_CONFIG_JSON: String = "res://app-config.json"

var config: ConfigFile
var config_file_name := "config.cfg"
var config_file_path: String
var config_file_locations := [
	"res://" + config_file_name,
	"user://" + config_file_name,
]

var data: Variant
var error: bool = false

## on config creation only allow these keys to be set
var allowed_start_config: Dictionary = {
	"twitch_auth": [
		"client_id",
		"client_secret"
	]
}

func _init(load_config: bool = true, prefer_cfg: bool = true) -> void:
	if load_config:
		_read_config(prefer_cfg)

##
## public
##

## get full config data
func get_config() -> Dictionary:
	return data

## get data from section
func get_section(section: String) -> Dictionary:
	if data and data.has(section):
		return data[section]

	return {}

## set data in section
func set_config_section(config_data: Dictionary, section: String) -> void:
	_update_config(config_data, section)

## creates a new configuration file
func create_configuration(config_data: Dictionary) -> void:
	config = ConfigFile.new()

	for section in config_data:
		for key in config_data[section]:
			if not allowed_start_config.has(section) && allowed_start_config[section].has(key):
				continue

			config.set_value(section, key, config_data[section][key])

	if OS.has_feature("editor"):
		_save(config_file_locations[0])
	else:
		_save(config_file_locations[1])

func reload_config() -> bool:
	return _read_config()

##
## private
##

## finds the first config file that exists and loads it
func _read_config(prefer_cfg: bool = true) -> bool:
	var actual_search_paths: Array[String] = []
	actual_search_paths.append_array(config_file_locations)
	if not prefer_cfg:
		actual_search_paths.insert(0, PATH_APP_CONFIG_JSON)

	for location in actual_search_paths:
		print("Loading config from %s" % location)
		data = _load_config_file(location)

		if not data.has("error"):
			config_file_path = location
			break
		else:
			var code = data.get("code", 1) as int
			push_error("Error loading config from %s (%d)" % [location, code])

	if data.has("error"):
		data = null
		return false

	return true

## update the config file with new data
func _update_config(config_data: Dictionary, section: String) -> void:
	for key in config_data:
		config.set_value(section, key, config_data[key])

	_save()
	data = _config_to_dictionary()

## loads a config file and returns the data
func _load_config_file(file: String) -> Dictionary:
	if file.ends_with(".json"):
		var app_config_file_access = FileAccess.open(file, FileAccess.READ)
		if not app_config_file_access:
			var error_code = FileAccess.get_open_error()
			push_error("Failed to read %s (%d)" % [file, error_code])
			return {
				"error": true,
				"code": error_code,
			}

		var raw_app_config = app_config_file_access.get_as_text()
		var json_parser = JSON.new()
		var parse_result = json_parser.parse(raw_app_config)
		if not parse_result == OK:
			push_error("Error parsing contents as JSON of %s (%d)" % [file, parse_result])
			return {
				"error": true,
				"code": parse_result,
			}

		if not json_parser.data is Dictionary:
			push_error("Contents of %s were not a dictionary" % file)
			return {
				"error": true,
				"code": -1,
			}

		return json_parser.data as Dictionary

	config = ConfigFile.new()
	var load_result = config.load(file)
	if load_result != OK:
		return {
			"error": true,
			"code": load_result,
		}

	return _config_to_dictionary()

## save config
func _save(file_path: String=config_file_path) -> void:
	config.save(file_path)

## create dictionary from config
func _config_to_dictionary() -> Dictionary:
	var config_dict: Dictionary = {}
	for section in config.get_sections():
		config_dict[section] = {}
		for key in config.get_section_keys(section):
			config_dict[section][key] = config.get_value(section, key)

	return config_dict
