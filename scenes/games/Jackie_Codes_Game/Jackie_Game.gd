class_name JackieCodesGame
extends Node2D

var bodies = [
	preload("res://scenes/games/Jackie_Codes_Game/scenes/body.tscn"),
	preload("res://scenes/games/Jackie_Codes_Game/scenes/inhertired_body_2.tscn"),
	preload("res://scenes/games/Jackie_Codes_Game/scenes/Inherited_body_3.tscn"),
	preload("res://scenes/games/Jackie_Codes_Game/scenes/inherited_body_4.tscn"),
	preload("res://scenes/games/Jackie_Codes_Game/scenes/inherited_body_5.tscn"),
	preload("res://scenes/games/Jackie_Codes_Game/scenes/inherited_body_6.tscn")
]

@onready var marker_spawn = $spawn
@onready var player_container = $players
@onready var node_ui = $UI
@onready var prison = $prison
@onready var tile_map = $TileMap

var preferences: JackieCodesGamePreferences = JackieCodesGamePreferences.new()
var viewers: Dictionary = {}

class JackieCodesGamePreferences:
	var bits: Array[String] = []
	var gifters: Array[String] = []
	var jail: Array[String] = []
	var mods: Array[String] = []
	var top: Array[String] = []
	var vips: Array[String] = []
	
	static func from_dictionary(dict: Dictionary) -> JackieCodesGamePreferences:
		var preferences = JackieCodesGamePreferences.new()
		preferences.bits.clear()
		preferences.bits.append_array(dict.get_or_add("bits", []))
		preferences.gifters.clear()
		preferences.gifters.append_array(dict.get_or_add("gifters", []))
		preferences.jail.clear()
		preferences.jail.append_array(dict.get_or_add("jail", []))
		preferences.mods.clear()
		preferences.mods.append_array(dict.get_or_add("mods", []))
		preferences.top.clear()
		preferences.top.append_array(dict.get_or_add("top", []))
		preferences.vips.clear()
		preferences.vips.append_array(dict.get_or_add("vips", []))
		return preferences
	
	func to_dictionary() -> Dictionary:
		var dict: Dictionary = {}
		dict["bits"] = bits
		dict["gifters"] = gifters
		dict["jail"] = jail
		dict["mods"] = mods
		dict["top"] = top
		dict["vips"] = vips
		return dict

func _ready() -> void:
	GameConfigManager.load_config()
	load_preferences()
	
	GiftSingleton.viewer_joined.connect(on_viewer_joined)
	GiftSingleton.viewer_left.connect(on_viewer_left)
	GiftSingleton.add_game_command("jump", on_viewer_jump)
	GiftSingleton.add_game_command("dig", on_viewer_dig)
	GlobalTilemap.set_terrain_arr(tile_map.get_used_cells(0))

	Transition.hide_transition()
	
	var active_viewers = GiftSingleton.active_viewers
	GiftSingleton.active_viewers = []
	
	for viewer in active_viewers:
		spawn_viewer(viewer)

func load_preferences():
	var dict = GamePreferencesHelper.load_preferences(GamePreferencesHelper.suggest_name())
	preferences = JackieCodesGamePreferences.from_dictionary(dict)

func save_preferences():
	GamePreferencesHelper.save_preferences(GamePreferencesHelper.suggest_name(), preferences.to_dictionary())

func set_gifter(viewer_name: String, is_gifter: bool) -> void:
	var search_name = sanitize_name(viewer_name)
	var index = preferences.gifters.find(search_name)
	if !is_gifter and index > -1:
		preferences.gifters.remove_at(index)
		save_preferences()
	
	if is_gifter and index < 0:
		preferences.gifters.append(search_name)
		save_preferences()
	
	# Mark already spawned player as a gifter
	var spawned_player = get_spawned_player(viewer_name)
	if spawned_player:
		spawned_player.set_gifter(is_gifter)

func set_moderator(viewer_name: String, is_moderator: bool) -> void:
	var search_name = sanitize_name(viewer_name)
	var index = preferences.mods.find(search_name)
	if !is_moderator and index > -1:
		preferences.mods.remove_at(index)
		save_preferences()
	
	if is_moderator and index < 0:
		preferences.mods.append(search_name)
		save_preferences()
	
	# Mark already spawned player as a moderator
	var spawned_player = get_spawned_player(viewer_name)
	if spawned_player:
		spawned_player.set_moderator(is_moderator)

func set_top(viewer_name: String, is_top: bool) -> void:
	var search_name = sanitize_name(viewer_name)
	var index = preferences.top.find(search_name)
	if !is_top and index > -1:
		preferences.top.remove_at(index)
		save_preferences()
	
	if is_top and index < 0:
		preferences.top.append(search_name)
		save_preferences()
	
	# Mark already spawned player as a top gifter/bit donor
	var spawned_player = get_spawned_player(viewer_name)
	if spawned_player:
		spawned_player.set_top(is_top)

func set_imprisoned(viewer_name: String, is_imprisoned: bool) -> void:
	var search_name = sanitize_name(viewer_name)
	var index = preferences.jail.find(search_name)
	if !is_imprisoned and index > -1:
		preferences.jail.remove_at(index)
		save_preferences()
	
	if is_imprisoned and index < 0:
		preferences.jail.append(search_name)
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
		is_mod(search_name),
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
		player.global_position.x += randf_range(-480, 480)

func is_bits(viewer_name: String) -> bool:
	var search_name = sanitize_name(viewer_name)
	return preferences.bits.find(search_name) > -1

func is_gifter(viewer_name: String) -> bool:
	var search_name = sanitize_name(viewer_name)
	return preferences.gifters.find(search_name) > -1

func is_imprisoned(viewer_name: String) -> bool:
	var search_name = sanitize_name(viewer_name)
	return preferences.jail.find(search_name) > -1
	
func is_mod(viewer_name: String) -> bool:
	var search_name = sanitize_name(viewer_name)
	return preferences.mods.find(search_name) > -1

func is_top(viewer_name: String) -> bool:
	var search_name = sanitize_name(viewer_name)
	var position = preferences.top.find(search_name)
	return position > -1

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

func on_viewer_dig(command_info: CommandInfo):
	var viewer_name = command_info.sender_data.user
	var search_name = viewer_name.to_lower()
	var player = get_spawned_player(viewer_name)
	if player:
		player.dig()

func _on_navigate_to_menu_button_scene_changing():
	var active_viewers: Array[String] = []
	active_viewers.append_array(viewers.values().map(_extract_viewer_name).filter(_filter_non_null))
	print("Leaving lemmings scene with %d viewers" % active_viewers.size())
	GiftSingleton.set_active_viewers(active_viewers)

func _input(event):
	if Input.is_action_just_pressed("transparent"):
		node_ui.visible = !node_ui.visible
	if Input.is_action_just_pressed("test"):
		GiftSingleton.chat("TEST", "jackie_codes")

static func _extract_viewer_name(viewer):
	if viewer == null:
		return null
	return viewer.name

static func _filter_non_null(value):
	return value != null

static func sanitize_name(viewer_name: String) -> String:
	return viewer_name.to_lower()
