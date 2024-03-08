class_name JackieCodesGame
extends Node2D

var bodies = [
	preload ("res://scenes/games/Jackie_Codes_Game/scenes/body.tscn"),
	preload ("res://scenes/games/Jackie_Codes_Game/scenes/inhertired_body_2.tscn"),
	preload ("res://scenes/games/Jackie_Codes_Game/scenes/Inherited_body_3.tscn"),
	preload ("res://scenes/games/Jackie_Codes_Game/scenes/inherited_body_4.tscn"),
	preload ("res://scenes/games/Jackie_Codes_Game/scenes/inherited_body_5.tscn"),
	preload ("res://scenes/games/Jackie_Codes_Game/scenes/inherited_body_6.tscn")
]

const JAIL_RELEASE_INTERVAL_SECONDS: int = 10

@onready var marker_spawn = $spawn
@onready var player_container = $players
@onready var node_ui = $UI
@onready var prison = $prison
@onready var tile_map = $TileMap

var jail_time_seconds: int = 0
var jail_release_timer_remaining: float = 0
var preferences: JackieCodesGamePreferences = JackieCodesGamePreferences.new()
var viewers: Dictionary = {}

class JackieCodesGamePreferences:
	var bits: Array[Dictionary] = []
	var gifters: Dictionary = {}
	var jail: Array[Dictionary] = []
	var moderators: Dictionary = {}
	var top: Array[String] = []
	var vips: Dictionary = {}

	static func from_dictionary(dict: Dictionary) -> JackieCodesGamePreferences:
		var preferences = JackieCodesGamePreferences.new()
		preferences.bits.clear()
		preferences.bits.append_array(dict.get_or_add("bits", []))
		preferences.gifters.clear()
		preferences.gifters = dict.get_or_add("gifters", {})
		preferences.jail.clear()
		preferences.jail.append_array(dict.get_or_add("jail", []))
		preferences.moderators.clear()
		preferences.moderators = dict.get_or_add("moderators", {})
		preferences.top.clear()
		preferences.top.append_array(dict.get_or_add("top", []))
		preferences.vips.clear()
		preferences.vips = dict.get_or_add("vips", {})
		return preferences

	func to_dictionary() -> Dictionary:
		var dict: Dictionary = {}
		dict["bits"] = bits
		dict["gifters"] = gifters
		dict["jail"] = jail
		dict["moderators"] = moderators
		dict["top"] = top
		dict["vips"] = vips
		return dict

func _ready() -> void:
	GameConfigManager.load_config({
		"transparent_bg": true
	})
	load_preferences()

	SignalBus.ui_visibility_toggled.connect(_on_ui_visibility_toggled)

	GiftSingleton.viewer_joined.connect(on_viewer_joined)
	GiftSingleton.viewer_left.connect(on_viewer_left)
	GiftSingleton.moderator_changed.connect(on_twitch_moderator_changed)
	# Disabled until it can be tested
	#GiftSingleton.subscription_gifted.connect(on_twitch_subscription_gifted)

	GiftSingleton.add_game_command("jump", on_viewer_jump)
	GiftSingleton.add_game_command("dig", on_viewer_dig)

	GlobalTilemap.set_terrain_arr(tile_map.get_used_cells(0))

	Transition.hide_transition()

	var active_viewers = GiftSingleton.active_viewers
	GiftSingleton.active_viewers = []

	var moderators = await GiftSingleton.get_moderators()
	var vips = await GiftSingleton.get_vips()
	var twitch_subscriptions = await GiftSingleton.get_subscriptions()
	var bits_leaderboard_for_period = await GiftSingleton.get_bits_leaderboard()
	var bits_leaderboard_data = bits_leaderboard_for_period.get("data", [])
	var bits_leaderboard: Array = bits_leaderboard_data.map(_reduce_bits_leaderboard_entry).filter(_filter_nonempty_dictionary)
	bits_leaderboard.sort_custom(_sort_bits_leaderboard_entry)

	preferences.bits.clear()
	preferences.bits.append_array(bits_leaderboard)

	var twitch_moderators = preferences.moderators.get_or_add("twitch", []) as Array
	twitch_moderators.clear()
	twitch_moderators.append_array(moderators.map(sanitize_name))

	var twitch_vips = preferences.vips.get_or_add("twitch", []) as Array
	twitch_vips.clear()
	twitch_vips.append_array(vips.map(sanitize_name))

	var twitch_gifter_lookup: Dictionary = {}
	for subscription in twitch_subscriptions:
		var is_gift = subscription.get("is_gift", false)
		if not is_gift:
			continue
		var gifter_search_name = subscription.get("gifter_login", "")
		if gifter_search_name == "":
			continue
		var gifter_entry: Dictionary = twitch_gifter_lookup.get_or_add(gifter_search_name, {"name": gifter_search_name, "gifts": 0})
		gifter_entry["gifts"] += 1

	var twitch_gifter_array = twitch_gifter_lookup.values()
	twitch_gifter_array.sort_custom(_sort_gifter)
	var twitch_gifters = preferences.gifters.get_or_add("twitch", [])
	twitch_gifters.clear()
	twitch_gifters.append_array(twitch_gifter_array)

	var now = int(Time.get_unix_time_from_system())
	for jail_entry in preferences.jail:
		var entry_release_time = jail_entry.get("release_time", 1) as int
		if entry_release_time < 1:
			# < 1 is the "permanent jail" flag, skip
			continue

		if entry_release_time < now:
			preferences.jail.erase(jail_entry)

	save_preferences()

	for viewer in active_viewers:
		spawn_viewer(viewer)

func _process(delta: float) -> void:
	jail_release_timer_remaining -= delta
	if jail_release_timer_remaining < 0:
		jail_release_timer_remaining = JAIL_RELEASE_INTERVAL_SECONDS
		
		var now = int(Time.get_unix_time_from_system())
		var num_jail_entries = preferences.jail.size()
		for jail_entry in preferences.jail:
			var jail_entry_name = jail_entry.get("name", "") as String
			if jail_entry_name == "":
				preferences.jail.erase(jail_entry)
			var jail_release_time = jail_entry.get("release_time", 1) as int
			if jail_release_time < 1:
				continue
			if jail_release_time < now:
				preferences.jail.erase(jail_entry)
				set_imprisoned(jail_entry_name, false)

		if not num_jail_entries == preferences.jail.size():
			save_preferences()

static func _sort_gifter(a: Dictionary, b: Dictionary) -> bool:
	var gifts_a = a.get("gifts", 0)
	var gifts_b = b.get("gifts", 0)
	return gifts_a > gifts_b

static func _reduce_bits_leaderboard_entry(entry: Dictionary) -> Dictionary:
	if entry.keys().size() == 0:
		print_debug("Received bad bits leaderboard entry: %s" % [entry])
		return {}

	var name = entry.get("user_login")
	if not name:
		print_debug("Received bad bits leaderboard entry: %s" % [entry])
		return {}

	return {
		"score": entry.get("score", 0),
		"name": name
	}

static func _filter_gifts(dict: Dictionary) -> bool:
	return true

static func _filter_nonempty_dictionary(dict: Dictionary) -> bool:
	return dict.keys().size() > 0

static func _sort_bits_leaderboard_entry(a: Dictionary, b: Dictionary) -> bool:
	var score_a = a.get("score", 0)
	var score_b = b.get("score", 0)
	return score_a > score_b

static func find_index_of_bits_leaderboard_entry(viewer_name: String, leaderboard: Array[Dictionary]) -> int:
	var search_name = sanitize_name(viewer_name)
	for index in range(0, leaderboard.size()):
		if leaderboard[index].get("name", "") == search_name:
			return index
	return - 1

func load_preferences():
	var dict = GamePreferencesHelper.load_preferences(GamePreferencesHelper.suggest_name())
	preferences = JackieCodesGamePreferences.from_dictionary(dict)

func save_preferences():
	GamePreferencesHelper.save_preferences(GamePreferencesHelper.suggest_name(), preferences.to_dictionary())

func set_gifter(viewer_name: String, is_gifter: bool, persist: bool=true) -> void:
	if persist:
		var search_name = sanitize_name(viewer_name)
		var manual = preferences.gifters.get_or_add("manual", [])
		var index = manual.find(search_name)
		if !is_gifter and index > - 1:
			manual.remove_at(index)
			save_preferences()

		if is_gifter and index < 0:
			manual.append(search_name)
			save_preferences()

	# Mark already spawned player as a gifter
	var spawned_player = get_spawned_player(viewer_name)
	if spawned_player:
		spawned_player.set_gifter(is_gifter or self.is_gifter(viewer_name))

func set_moderator(viewer_name: String, is_moderator: bool, persist: bool=true) -> void:
	if persist:
		var search_name = sanitize_name(viewer_name)
		var manual = preferences.moderators.get_or_add("manual", [])
		var index = manual.find(search_name)
		if !is_moderator and index > - 1:
			manual.remove_at(index)
			save_preferences()

		if is_moderator and index < 0:
			manual.append(search_name)
			save_preferences()

	# Mark already spawned player as a moderator
	var spawned_player = get_spawned_player(viewer_name)
	if spawned_player:
		spawned_player.set_moderator(is_moderator or self.is_moderator(viewer_name))

func set_top(viewer_name: String, is_top: bool, persist: bool=true) -> void:
	if persist:
		var search_name = sanitize_name(viewer_name)
		var index = preferences.top.find(search_name)
		if !is_top and index > - 1:
			preferences.top.remove_at(index)
			save_preferences()

		if is_top and index < 0:
			preferences.top.append(search_name)
			save_preferences()

	# Mark already spawned player as a top gifter/bit donor
	var spawned_player = get_spawned_player(viewer_name)
	if spawned_player:
		spawned_player.set_top(is_top or self.is_top(viewer_name))

func _get_jail_index(viewer_id: String) -> int:
	for jail_entry_index in range(0, preferences.jail.size()):
		var jail_entry = preferences.jail[jail_entry_index]
		if not jail_entry is Dictionary:
			continue
		var entry_name = jail_entry.get("name", "") as String
		if entry_name == viewer_id:
			return jail_entry_index

	return -1

func set_imprisoned(viewer_name: String, is_imprisoned: bool) -> void:
	var search_name = sanitize_name(viewer_name)
	var index = _get_jail_index(search_name)
	if !is_imprisoned and index > - 1:
		preferences.jail.remove_at(index)
		save_preferences()

	if is_imprisoned:
		var release_time = jail_time_seconds
		if release_time > 0:
			var now = int(Time.get_unix_time_from_system())
			release_time += now

		if index < 0:
			preferences.jail.append({
				"name": search_name,
				"release_time": release_time,
			})
		else:
			var jail_entry = preferences.jail[index]
			jail_entry["release_time"] = release_time

		save_preferences()

	# Mark already spawned player as imprisoned
	var spawned_player = get_spawned_player(viewer_name)
	if spawned_player:
		if is_imprisoned:			
			spawned_player.transport_to_gulag(prison.global_position)
		else:
			spawned_player.release_from_gulag()

func get_spawned_player(viewer_name: String) -> Lemming:
	var search_name = sanitize_name(viewer_name)
	for player in player_container.get_children():
		if player.player_name == search_name:
			return player
	return null

func spawn_viewer(viewer_name: String):
	var search_name = sanitize_name(viewer_name)
	if viewers.has(search_name):
		return

	var player = bodies.pick_random().instantiate()
	player_container.add_child(player)

	player.init(
		search_name,
		is_gifter(search_name),
		is_moderator(search_name),
		is_top(viewer_name),
		tile_map
	)

	viewers[search_name] = {
		"name": viewer_name,
		"player": player
	}

	if is_imprisoned(viewer_name):
		player.transport_to_gulag(prison.global_position)
	else:
		player.global_position = marker_spawn.global_position
		player.global_position.x += randf_range( - 480, 480)

func is_bits(viewer_name: String) -> bool:
	var search_name = sanitize_name(viewer_name)
	for entry in preferences.bits:
		if entry.name == search_name:
			return true
	return false

func is_gifter(viewer_name: String) -> bool:
	return gifter_rank(viewer_name) > - 1

func is_imprisoned(viewer_name: String) -> bool:
	var search_name = sanitize_name(viewer_name)

	for jail_entry in preferences.jail:
		if not jail_entry is Dictionary:
			continue
		var entry_name = jail_entry.get("name", "") as String
		if not entry_name == search_name:
			continue
		var entry_release_time = jail_entry.get("release_time", 1) as int
		if entry_release_time < 1:
			# This is the permanent jail, just return true
			return true
		var now = int(Time.get_unix_time_from_system())
		if entry_release_time < now:
			# This is the temporary jail, don't update the preferences array in an is_*() function
			# just short circuit and return false since we matched the viewer name
			return false
		
	return false

func is_moderator(viewer_name: String) -> bool:
	var search_name = sanitize_name(viewer_name)

	var moderators = preferences.moderators
	for platform_moderators in moderators.values():
		var index = platform_moderators.find(search_name)
		if index > - 1:
			return true

	return false

func is_top(viewer_name: String) -> bool:
	var search_name = sanitize_name(viewer_name)
	var position = preferences.top.find(search_name)
	if position > - 1:
		return true

	position = find_index_of_bits_leaderboard_entry(viewer_name, preferences.bits)
	if position > - 1:
		return true

	position = gifter_rank(viewer_name)
	return position > - 1

func gifter_rank(viewer_name: String) -> int:
	var search_name = sanitize_name(viewer_name)

	var gifters = preferences.gifters
	for platform_gifters in gifters.values():
		for index in range(0, platform_gifters.size()):
			var gifter = platform_gifters[index]
			if gifter.get("name") == search_name:
				return index

	return - 1

func on_viewer_joined(viewer_name: String) -> void:
	spawn_viewer(viewer_name)

func on_viewer_left(viewer_name: String):
	var search_name = viewer_name.to_lower()
	var viewer = viewers.get(search_name)
	if viewer:
		viewer.player.leave()
	viewers.erase(search_name)

func on_viewer_jump(command_info: CommandInfo):
	var viewer_name = command_info.sender_data.user
	var search_name = viewer_name.to_lower()
	var player = get_spawned_player(viewer_name)
	if player:
		player.jump()

func on_twitch_moderator_changed(user_name: String, added: bool):
	on_moderator_changed("twitch", user_name, added)

func on_moderator_changed(service: String, user_name: String, added: bool):
	var search_name = sanitize_name(user_name)
	var moderators = preferences.moderators.get_or_add(service, [])
	var index = moderators.find(search_name)
	if added and index < 0:
		moderators.append(search_name)
	elif not added and index > - 1:
		moderators.remove_at(index)
	save_preferences()
	set_moderator(user_name, added, false)

func on_twitch_subscription_gifted(user_name: String, gifter: String, length: int):
	on_subscription_gifted("twitch", user_name, gifter, length)

func on_subscription_gifted(service: String, user_name: String, gifter: String, length: int):
	var search_name = sanitize_name(gifter)
	var gifters = preferences.gifters.get_or_add(service, []) as Array
	var index = gifter_rank(search_name)

	if index < 0:
		gifters.append({"name": search_name, "gifts": 0})
	gifters[index]["gifts"] += 1

	save_preferences()
	set_gifter(gifter, true, false)

func on_viewer_dig(command_info: CommandInfo):
	var viewer_name = command_info.sender_data.user
	var search_name = viewer_name.to_lower()
	var player = get_spawned_player(viewer_name)
	if player:
		player.dig()

func _on_navigate_to_menu_button_scene_changing():
	var active_viewers: Array[String] = []
	active_viewers.append_array(viewers.values().map(_extract_viewer_name).filter(_filter_non_null))
	GiftSingleton.set_active_viewers(active_viewers)
	print("Leaving %s scene with %d viewers" % [
		get_tree().current_scene.scene_file_path.get_file().get_basename(),
		GiftSingleton.active_viewers.size()
	])

func _on_ui_visibility_toggled(ui_visible: bool):
	node_ui.visible = ui_visible

func clear_viewers(all: bool = true):
	if all:
		for viewer in viewers.values():
			viewer.player.queue_free()
		viewers.clear()
	else:
		# TODO: implement clear gone
		pass

func _input(event):
	if Input.is_action_just_pressed("test"):
		GiftSingleton.chat("TEST", "jackie_codes")

static func _extract_viewer_name(viewer):
	if viewer == null:
		return null
	return viewer.name

static func _filter_non_null(value):
	return value != null

static func sanitize_name(viewer_name: String) -> String:
	if viewer_name == "":
		return viewer_name
	return viewer_name.strip_edges().to_lower()
