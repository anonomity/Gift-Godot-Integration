class_name ChannelPointsRewardMapping
extends RefCounted

var action: String
var reward_id: String

func _init(p_action: String, p_reward_id: String) -> void:
	action = p_action
	reward_id = p_reward_id

func to_dictionary() -> Dictionary:
	return {
		"action": action,
		"reward_id": reward_id,
	}

static func from_dictionary(dictionary: Dictionary) -> ChannelPointsRewardMapping:
	return ChannelPointsRewardMapping.new(
		dictionary["action"],
		dictionary["reward_id"]
	)

static var _loader = JsonManager.new("preferences/reward_mappings.json")

static func get_action_for_reward_id(reward_id: String) -> String:
	var mappings = get_all()
	for mapping in mappings:
		if mapping.reward_id == reward_id:
			return mapping.action
	return ""

static func get_all() -> Array[ChannelPointsRewardMapping]:
	if not _loader.data is Array:
		return []
	var mappings: Array[ChannelPointsRewardMapping] = []
	mappings.append_array(_loader.data.map(func (dictionary: Dictionary): return ChannelPointsRewardMapping.from_dictionary(dictionary)))
	return mappings

static func set_all(mappings: Array[ChannelPointsRewardMapping]):
	_loader.data = mappings.map(func (mapping: ChannelPointsRewardMapping): return mapping.to_dictionary())
	_loader.save()
