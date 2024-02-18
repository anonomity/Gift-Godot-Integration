class_name ActionMetadata
extends RefCounted

var icon: Texture2D
var type: String

func _init(p_type: String) -> void:
	type = p_type

func to_dictionary() -> Dictionary:
	var dictionary = {}
	dictionary["type"] = type
	return dictionary

static func from_dictionary(dictionary: Dictionary) -> ActionMetadata:
	var type = dictionary["type"]
	match type:
		PlaySound.TYPE:
			return PlaySound.from_dictionary(dictionary)
		_:
			assert(false, "Not yet implemented action metadata type %s" % type)
			return null

class PlaySound extends ActionMetadata:
	const TYPE: String = "action_play_sound"

	var path: String

	func _init(p_path: String) -> void:
		super._init(TYPE)
		path = p_path

	func to_dictionary() -> Dictionary:
		var dictionary = super.to_dictionary()

		for property in self.get_property_list():
			var property_name = property["name"]
			var property_value = self.get(property_name)
			if property_value and property_value.has_method("to_dictionary"):
				property_value = property_value.to_dictionary()
			dictionary[property_name] = property_value

		return dictionary

	static func from_dictionary(dictionary: Dictionary) -> ActionMetadata:
		var type = dictionary["type"]
		if type != TYPE:
			return ActionMetadata.from_dictionary(dictionary)

		var path = dictionary["path"] as String
		var metadata = PlaySound.new(path)
		return metadata
