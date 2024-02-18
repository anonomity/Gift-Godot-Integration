extends Node

var config_manager := ConfigManager.new()

##
## public
##

## loads the config and apply it when possible
func load_config(defaults: Dictionary = DEFAULT_COMMON_CONFIG) -> Dictionary:
	var game_name = _get_scene_file_name()
	var data: Dictionary = config_manager.get_section(game_name)

	var missing_keys = defaults.keys().filter(func (key): return not data.has(key))
	if missing_keys.size():
		var config_with_defaults: Dictionary = {}
		config_with_defaults.merge(defaults, true)
		config_with_defaults.merge(data, true)
		data = config_with_defaults
		config_manager.set_config_section(config_with_defaults, game_name)

	for key in data:
		var method_name = "set_%s" % key
		if has_method(method_name):
			call(method_name, data[key])

	return data


## saves config
func save_config() -> void:
	var game_name = _get_scene_file_name()
	var updated_config : Dictionary = {}

	for key in game_config:
		var method_name = "set_%s" % key
		if has_method(method_name):
			updated_config[key] = call("get_%s" % key)

	config_manager.set_config_section(updated_config, game_name)

##
## private
##

const DEFAULT_COMMON_CONFIG: Dictionary = {
	"transparent_bg": false
}

var game_config: Array[String] = [
	"transparent_bg",
	"window_position",
	"window_size"
]

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_config()
		print("Config saved")
		get_tree().quit()


## we use the filename to not loose settings when renaming a Scene
func _get_scene_file_name() -> String:
	return get_tree().current_scene.scene_file_path.get_file().get_basename()


##
## config functions
## whenever a config has also a functin prepend with get/set it will be called
##


func set_window_position(pos: Vector2) -> void:
	get_window().position = pos


func get_window_position() -> Vector2:
	return get_window().position


func set_window_size(window_size: Vector2) -> void:
	get_window().size = window_size


func get_window_size() -> Vector2:
	return get_window().size

func get_transparent_bg() -> bool:
	return get_viewport().transparent_bg

func set_transparent_bg(transparent: bool) -> void:
	SignalBus.emit_transparency_toggled(transparent)
