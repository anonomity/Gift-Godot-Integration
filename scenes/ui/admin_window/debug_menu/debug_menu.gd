class_name AdminWindowDebugMenu extends VBoxContainer

@onready var toggle_restart_with_active_viewers: CheckButton = $ToggleRestartWithActiveViewers

const PATH_PREFERENCES_DEBUG = "user://preferences/debug.json";
var preferences: DebugPreferences = DebugPreferences.new()

func _ready():
	load_preferences()
	
	var viewers = preferences.active_viewers
	GiftSingleton.set_active_viewers(viewers)
	GiftSingleton.viewer_joined.connect(_on_viewer_joined)
	GiftSingleton.viewer_left.connect(_on_viewer_left)

func load_preferences():
	var file: FileAccess = FileAccess.open(PATH_PREFERENCES_DEBUG, FileAccess.READ)
	if file and file.get_position() < file.get_length():
		var parser = JSON.new()
		parser.parse(file.get_as_text(true))
		preferences = DebugPreferences.from_dictionary(parser.data)
	toggle_restart_with_active_viewers.button_pressed = preferences.restart_with_active_viewers

func save_preferences():
	if not DirAccess.dir_exists_absolute("user://preferences"):
		DirAccess.make_dir_absolute("user://preferences")
	var file: FileAccess = FileAccess.open(PATH_PREFERENCES_DEBUG, FileAccess.WRITE)
	if file:
		var parser = JSON.new()
		var json = parser.stringify(preferences.to_dictionary())
		file.store_string(json)

func _on_viewer_joined(display_name: String, color: String):
	var search_name = display_name.to_lower()
	preferences.active_viewers[search_name] = {
		"color": color,
		"display_name": display_name,
	}
	if preferences.restart_with_active_viewers:
		save_preferences()

func _on_viewer_left(display_name: String):
	var search_name = display_name.to_lower()
	var index = preferences.active_viewers.erase(search_name)
	if preferences.restart_with_active_viewers:
		save_preferences()

func _on_toggle_restart_with_active_viewers_toggled(toggled_on):
	preferences.restart_with_active_viewers = toggled_on
	save_preferences()

class DebugPreferences:
	var restart_with_active_viewers: bool = false
	var active_viewers: Dictionary = {}
	
	static func from_dictionary(dict: Dictionary) -> DebugPreferences:
		var preferences = DebugPreferences.new()
		preferences.restart_with_active_viewers = dict["restart_with_active_viewers"]
		if preferences.restart_with_active_viewers:
			var active_viewers_to_load = dict.get("active_viewers", {})
			for key in active_viewers_to_load:
				preferences.active_viewers[key] = active_viewers_to_load[key]
		return preferences
	
	func to_dictionary() -> Dictionary:
		var dict: Dictionary = {}
		dict["restart_with_active_viewers"] = restart_with_active_viewers
		if restart_with_active_viewers:
			dict["active_viewers"] = active_viewers
		return dict
	

