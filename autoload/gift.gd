extends Gift

signal viewer_joined(name)
signal viewer_left(name)
signal viewers_reset()

signal moderator_changed(user_name: String, added: bool)

signal streamer_start(args: Array)
signal streamer_wait()

signal status(status_id: STATUS)

enum STATUS {
	NONE,
	INIT,
	AUTH_START,
	AUTH_FILE_NOT_FOUND,
	CONNECTION_FAILED,
	CONNECTING,
	CONNECTED
}

var last_status := STATUS.NONE

var game_commands: Array = []

var setup_scene: PackedScene = preload ("res://scenes/ui/setup.tscn")

var active_viewers: Array[String] = []

var has_config: bool = false

func _ready() -> void:
	start()

## register a game command
func add_game_command(command: String, command_callback: Callable, max_args: int=0, min_args: int=0, permission: PermissionFlag=PermissionFlag.EVERYONE) -> void:
	game_commands.append(command)
	add_command(command, command_callback, max_args, min_args)

## remove all game_commands
func remove_game_commands() -> void:
	for command in game_commands:
		purge_command(command)
	game_commands.clear()

## set active viewers
func set_active_viewers(viewers: Array[String]) -> void:
	active_viewers.clear()
	active_viewers.append_array(viewers)

##
## private
##

static func dict_get_or_add(dict: Dictionary, key: String, default):
	if not dict.has(key):
		dict[key] = default
	return dict[key]

func change_scene_to_setup():
	get_tree().change_scene_to_packed(setup_scene)

## init chat connection
func start() -> void:
	emit_status(STATUS.INIT)

	var config = ConfigManager.new().data
	var twitch_auth = config["twitch_auth"] if config and config.has("twitch_auth") else null
	has_config = twitch_auth and twitch_auth.has("client_id") and twitch_auth.has("client_secret") and twitch_auth.has("initial_channel")

	if !has_config:
		emit_status(STATUS.AUTH_FILE_NOT_FOUND)
		change_scene_to_setup()
		return

	client_id = config.twitch_auth.client_id
	client_secret = config.twitch_auth.client_secret
	var initial_channel = config.twitch_auth.initial_channel

	cmd_no_permission.connect(no_permission)
	chat_message.connect(on_chat)
	event.connect(on_event)

	# When calling this method, a browser will open.
	# Log in to the account that should be used.
	emit_status(STATUS.AUTH_START)
	await authenticate(client_id, client_secret)

	emit_status(STATUS.CONNECTING)
	var success = await (connect_to_irc())
	if (success):
		request_caps()
		join_channel(initial_channel)
		emit_status(STATUS.CONNECTED)
	else:
		emit_status(STATUS.CONNECTION_FAILED)

	# await connect_to_eventsub()

	var channel_id = initial_channel.to_lower()
	var cache: JsonManager = dict_get_or_add(channel_caches, channel_id, JsonManager.new("cache/" + channel_id + ".json"))
	if cache.data == null:
		cache.data = {}

	var broadcaster_id = await get_user_id(channel_id)

	var mods = await GiftSingleton.get_mods()
	print("Found %d moderators: %s" % [mods.size(), mods])
	cache.data["mods"] = mods

	var vips = await GiftSingleton.get_vips()
	print("Found %d VIPs: %s" % [mods.size(), mods])
	cache.data["vips"] = vips

	cache.save()

	self.event.connect(_on_event)
	await subscribe_event("channel.moderator.add", 1, {"broadcaster_user_id": broadcaster_id})
	await subscribe_event("channel.moderator.remove", 1, {"broadcaster_user_id": broadcaster_id})
	#await subscribe_event("channel.vip.add", 1, {"broadcaster_user_id": broadcaster_id})
	#await subscribe_event("channel.vip.remove", 1, {"broadcaster_user_id": broadcaster_id})

	# Refer to https://dev.twitch.tv/docs/eventsub/eventsub-subscription-types/ for details on
	# what events exist, which API versions are available and which conditions are required.
	# Make sure your token has all required scopes for the event.
#	subscribe_event("channel.follow", 2, {"broadcaster_user_id": user_id, "moderator_user_id": user_id})

	# Adds a command with a specified permission flag.
	# All implementations must take at least one arg for the command info.
	# Implementations that recieve args requrires two args,
	# the second arg will contain all params in a PackedStringArray
	# This command can only be executed by VIPS/MODS/SUBS/STREAMER
#	add_command("test", command_test, 0, 0, PermissionFlag.NON_REGULAR)

	# user commands
	add_command("join", add_viewer_command)
	add_command("leave", remove_viewer_command)

	# streamer commands
	add_command("reset", streamer_reset_command, 0, 0, GiftSingleton.PermissionFlag.STREAMER)
	add_command("start", streamer_start_command, 2, 0, GiftSingleton.PermissionFlag.STREAMER)
	add_command("wait", streamer_wait_command, 0, 0, GiftSingleton.PermissionFlag.STREAMER)

	#add_command("guess", on_guess_made, 1, 1)
	#add_command("fire", on_viewer_fire, 2, 2)
	#add_alias("fire", "f")

	# Command that prints every arg seperated by a comma (infinite args allowed), at least 2 required
#	add_command("list", list, -1, 2)

	# Adds a command alias
#	add_alias("test","test1")
#	add_alias("test","test2")
#	add_alias("test","test3")

	# Now no "test" command is known

	# Send a chat message to the only connected channel (<channel_name>)
	# Fails, if connected to more than one channel.
#	chat("TEST")

	# Send a chat message to channel <channel_name>
#	chat("TEST", initial_channel)
	#chat("/vips", initial_channel)

	# Send a whisper to target user
#	whisper("TEST", initial_channel)

func _on_event(type: String, data: Dictionary):
	var current_channel = channels.keys()[0]
	var cache = get_cache(current_channel)
	match type:
		"channel.moderator.add":
			if not data.has("user_login"): print_debug("Bad event %s, missing user_login key" % [type])
			var user_name = data["user_login"]
			var mods = cache.data["mods"]
			var index = mods.find(user_name)
			if index < 0:
				mods.append(user_name)
				cache.save()
			moderator_changed.emit(user_name, true)
		"channel.moderator.remove":
			if not data.has("user_login"): print_debug("Bad event %s, missing user_login key" % [type])
			var user_name = data["user_login"]
			var mods = cache.data["mods"]
			var index = mods.find(user_name)
			if index > -1:
				mods.remove_at(index)
				cache.save()
			moderator_changed.emit(user_name, false)
			

func emit_status(new_status: STATUS) -> void:
	status.emit(new_status)
	last_status = new_status

func on_event(type: String, data: Dictionary) -> void:
	match (type):
		"channel.follow":
			print("%s followed your channel!" % data["user_name"])

func on_chat(_data: SenderData, _msg: String) -> void:
#	%ChatContainer.put_chat(data, msg)
	pass

func no_permission(_cmd_info: CommandInfo) -> void:
	chat("NO PERMISSION!")

func list(_cmd_info: CommandInfo, arg_ary: PackedStringArray) -> void:
	var msg = ""
	for i in arg_ary.size() - 1:
		msg += arg_ary[i]
		msg += ", "
	msg += arg_ary[arg_ary.size() - 1]
	chat(msg)

##
## custom commands
##

func add_viewer_command(cmd_info: CommandInfo) -> void:
	add_viewer(cmd_info.sender_data.tags["display-name"])

func add_viewer(display_name: String):
	viewer_joined.emit(display_name)

func remove_viewer_command(cmd_info: CommandInfo) -> void:
	remove_viewer(cmd_info.sender_data.tags["display-name"])

func remove_viewer(display_name: String):
	viewer_left.emit(display_name)

func streamer_reset_command(_cmd_info: CommandInfo) -> void:
	viewers_reset.emit()

func streamer_start_command(_cmd_info: CommandInfo, arg_ary: PackedStringArray=[]) -> void:
	streamer_start.emit(arg_ary)

func streamer_wait_command(_cmd_info: CommandInfo) -> void:
	streamer_wait.emit()
