extends MarginContainer

var loader = JsonManager.new("preferences/reward_mappings.json")
var rewards: Array[ChannelPointsReward] = []
var reward_mappings: Array[ChannelPointsRewardMapping] = []

func _init() -> void:
	reward_mappings = ChannelPointsRewardMapping.get_all()

func _ready() -> void:
	%ActionsList.clear()
	for action in GamesManager.new().get_all_actions():
		var item_index = %ActionsList.add_item(action)
		%ActionsList.set_item_metadata(item_index, {
			"id": action
		})

func handle_tab_selected() -> void:
	if visible:
		%FieldsContainer.visible = %RewardsList.get_selected_items().size() > 0
		refresh_rewards(rewards.size() < 1)

static func fetch_image(url: String) -> Variant:
	var response = await GiftSingleton.request_http(url)
	var response_code = response.get("response_code", 0) as int
	if not response_code == 200:
		return null

	var response_body = response.get("response_body") as PackedByteArray
	var image = Image.new()
	var error = image.load_png_from_buffer(response_body)
	if error:
		push_error("Failed to load PNG from %s (%d)" % [url, error])
		return null

	var texture = ImageTexture.new()
	texture.set_image(image)
	return texture

func get_selected_reward_id() -> String:
	var selected_id = ""
	var selected_items = %RewardsList.get_selected_items()
	if selected_items.size() > 0:
		var selected_index = selected_items[0]
		if selected_index >= 0 and rewards.size() > selected_index:
			selected_id = rewards[selected_index].id
	return selected_id

func get_selected_action_id() -> String:
	var selected_id = ""
	var selected_items = %ActionsList.get_selected_items()
	if selected_items.size() > 0:
		var selected_index = selected_items[0]
		if selected_index >= 0 and rewards.size() > selected_index:
			selected_id = %ActionsList.get_item_metadata(selected_index)["id"]
	return selected_id

func get_index_of_action(action_id: String) -> int:
	for index in range(0, %ActionsList.item_count):
		if action_id == %ActionsList.get_item_metadata(index)["id"]:
			return index
	return -1

func get_mapped_action_id_for_reward(reward_id: String) -> String:
	for mapping in reward_mappings:
		if mapping.reward_id == reward_id:
			return mapping.action
	return ""

func refresh_rewards(clear_immediately: bool = false) -> void:
	var selected_id = get_selected_reward_id()

	if clear_immediately:
		%RewardsList.clear()

	rewards = await GiftSingleton.get_channel_points_custom_rewards()

	var num_rewards = rewards.size()
	for reward_index in range(0, num_rewards):
		var reward = rewards[reward_index]
		var image_1x = await fetch_image(reward.image_1x)
		var index = reward_index
		if %RewardsList.item_count <= reward_index:
			index = %RewardsList.add_item(reward.title, image_1x)
		else:
			%RewardsList.set_item_icon(index, image_1x)
			%RewardsList.set_item_text(index, reward.title)

		%RewardsList.set_item_metadata(index, reward.id)

		if reward.id == selected_id:
			%RewardsList.select(index)
			_on_rewards_list_item_selected(index)

	while %RewardsList.item_count > num_rewards:
		%RewardsList.remove_item(%RewardsList.item_count - 1)

func _on_rewards_list_item_selected(index: int) -> void:
	if index < 0 or rewards.size() <= index:
		return

	var reward = rewards[index]
	if not reward:
		return
	
	%FieldsContainer.visible = true
	%Title.text = reward.title
	%Icon4x.texture = await fetch_image(reward.image_4x)
	%Cost.value = reward.cost
	var list = %IconPanel.get_property_list().map(func (v): return v.name)
	var style_box = %IconPanel["theme_override_styles/panel"] as StyleBoxFlat
	style_box.bg_color = Color.from_string(reward.background_color, Color.from_hsv(0, 0, 0.2))
	%IconPanel["theme_override_styles/panel"] = style_box
	var mapped_action = get_mapped_action_id_for_reward(reward.id)
	var action_index = get_index_of_action(mapped_action)
	if action_index < 0:
		%ActionsList.deselect_all()
	else:
		%ActionsList.select(action_index)
	#%IconPanel["theme_override_styles/panel/bg_color"] = Color.from_string(reward.background_color, Color.from_hsv(0, 0, 0.2))
	#%IconPanel.add_theme_stylebox_override("theme_override_styles/panel", style_box)

func _on_button_refresh_rewards_list_pressed() -> void:
	refresh_rewards()

func _on_actions_list_item_selected(index: int) -> void:
	var selected_id = get_selected_reward_id()
	var selected_action = get_selected_action_id()
	for mapping in reward_mappings:
		if not mapping.reward_id == selected_id:
			continue

		mapping.action = selected_action
		return

	reward_mappings.append(ChannelPointsRewardMapping.new(selected_action, selected_id))
	ChannelPointsRewardMapping.set_all(reward_mappings)

func _on_button_clear_actions_pressed():
	var selected_id = get_selected_reward_id()
	for mapping_index in range(reward_mappings.size() - 1, -1, -1):
		var mapping = reward_mappings[mapping_index]
		if mapping.reward_id == selected_id:
			reward_mappings.remove_at(mapping_index)

	%ActionsList.deselect_all()
	ChannelPointsRewardMapping.set_all(reward_mappings)
