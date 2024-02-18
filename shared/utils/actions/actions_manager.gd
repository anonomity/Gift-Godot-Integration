class_name ActionsManager
extends RefCounted

static var _loader = JsonManager.new("preferences/actions.json")

static func _get_actions_preferences() -> Dictionary:
	if not _loader.data is Dictionary:
		if not _loader.data == null:
			push_error("Actions preference file is in an invalid state: %s" % _loader._file_name)
			return {}
		_loader.data = {}

	return _loader.data as Dictionary

static func get_builtin() -> Array[Action]:
	var actions: Array[Action] = []
	for game_action in GamesManager.new().get_all_actions():
		var action = Action.new(game_action, game_action)
		actions.append(action)
	return actions

static func get_custom() -> Array[Action]:
	var preferences = _get_actions_preferences()
	var section_custom = preferences.get_or_add("custom", {}) as Dictionary

	var actions: Array[Action] = []
	for key in section_custom:
		var value = section_custom.get(key, {})
		if not value is Dictionary:
			push_error("The value for 'custom.%s' is not a dictionary", [key])
			continue
		
		var action = Action.from_dictionary(value)
		actions.append(action)

	return actions

static func get_all() -> Array[Action]:
	var actions: Array[Action] = []
	actions.append_array(get_builtin())
	actions.append_array(get_custom())
	return actions

static func add_custom(actions: Array[Action]):
	var preferences = _get_actions_preferences()
	var section_custom = preferences.get_or_add("custom", {}) as Dictionary

	for action in actions:
		section_custom[action.id] = action.to_dictionary()

	_loader.save()

static func set_custom(actions: Array[Action]):
	var preferences = _get_actions_preferences()
	var section_custom = {}
	preferences["custom"] = section_custom

	for action in actions:
		section_custom[action.id] = action.to_dictionary()

	_loader.save()
