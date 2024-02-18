class_name ChannelPointsReward
extends RefCounted

var _data: Dictionary = {}

func _init(data: Dictionary = {}) -> void:
	_data = data

# The ID that uniquely identifies this custom reward.
var id: String:
	get: return _data.get("id", "") as String

# The title of the reward.
var title: String:
	get: return _data.get("title", "") as String

# The prompt shown to the viewer when they redeem the reward if user input is required (see the is_user_input_required field).
var prompt: String:
	get: return _data.get("prompt", "") as String

# The cost of the reward in Channel Points.
var cost: int:
	get: return _data.get("cost", 0) as int

var image_1x: String:
	get:
		var default_image = _data.get("default_image", {}) as Dictionary
		var raw_image = _data.get("image")
		var image = raw_image as Dictionary if raw_image else default_image
		return image.get("url_1x", default_image.get("url_1x", "")) as String

var image_4x: String:
	get:
		var default_image = _data.get("default_image", {}) as Dictionary
		var raw_image = _data.get("image")
		var image = raw_image as Dictionary if raw_image else default_image
		return image.get("url_4x", default_image.get("url_4x", "")) as String

# The background color to use for the reward. The color is in Hex format (for example, #00E5CB).
var background_color: String:
	get: return _data.get("background_color", "") as String

# A Boolean value that determines whether the reward is enabled. Is true if enabled; otherwise, false. Disabled rewards aren’t shown to the user.
var is_enabled: bool:
	get: return _data.get("is_enabled", false) as bool

# A Boolean value that determines whether the reward is currently paused. Is true if the reward is paused. Viewers can’t redeem paused rewards.
var is_paused: bool:
	get: return _data.get("is_paused", false) as bool

# A Boolean value that determines whether the user must enter information when redeeming the reward. Is true if the user is prompted.
var is_user_input_required: bool:
	get: return _data.get("is_user_input_required", false) as bool

# A Boolean value that determines whether the reward is currently in stock. Is true if the reward is in stock. Viewers can’t redeem out of stock rewards.
var is_in_stock: bool:
	get: return _data.get("is_in_stock", false) as bool

# The maximum number of redemptions allowed per live stream.
# 0 will disable cooldowns for this reward
var max_per_stream: int:
	get:
		var max_per_stream_setting = _data.get("max_per_stream_setting", {}) as Dictionary
		if max_per_stream_setting and max_per_stream_setting.get("is_enabled", false) as bool:
			return max_per_stream_setting.get("max_per_stream", 0) as int
		return 0

# The maximum number of redemptions allowed per user per live stream.
# 0 will disable cooldowns for this reward
var max_per_user_per_stream: int:
	get:
		var max_per_user_per_stream_setting = _data.get("max_per_user_per_stream_setting", {}) as Dictionary
		if max_per_user_per_stream_setting and max_per_user_per_stream_setting.get("is_enabled", false) as bool:
			return max_per_user_per_stream_setting.get("max_per_user_per_stream", 0) as int
		return 0

# The cooldown period, in seconds.
# 0 will disable cooldowns for this reward
var global_cooldown_seconds: int:
	get:
		var global_cooldown_setting = _data.get("global_cooldown_setting", {}) as Dictionary
		if global_cooldown_setting and global_cooldown_setting.get("is_enabled", false) as bool:
			return global_cooldown_setting.get("global_cooldown_seconds", 0) as int
		return 0
