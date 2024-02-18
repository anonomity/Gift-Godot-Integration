class_name Action
extends RefCounted

var id: String
var label: String
var metadata: ActionMetadata

func _init(p_id: String, p_label: String) -> void:
	id = p_id
	label = p_label

func to_dictionary() -> Dictionary:
	var dictionary = {}

	for property in self.get_property_list():
		var property_name = property["name"]
		var property_value = self.get(property_name)
		if property_value and property_value.has_method("to_dictionary"):
			property_value = property_value.to_dictionary()
		dictionary[property_name] = property_value

	return dictionary

static func from_dictionary(dictionary: Dictionary) -> Action:
	if dictionary == null:
		return null

	var id = dictionary["id"]
	var label = dictionary["label"]
	var action = Action.new(id, label)
	for property in action.get_property_list():
		var property_name = property["name"]
		var property_value = action.get(property_name)
		if property_value and property_value.has_method("to_dictionary"):
			property_value = property_value.to_dictionary()
		dictionary[property_name] = property_value

	return action
