extends Gift

signal ad_break_begin(started_at: int)

signal viewer_joined(name)
signal viewer_left(name)
signal viewers_reset()

signal moderator_changed(user_name: String, added: bool)
signal vip_changed(user_name: String, added: bool)

signal user_ban_status_changed(user_name: String, until: int, is_banned: bool)
signal reward_redemption(user_name: String, reward_id: String, redeemed_at: int)
signal action_triggered(action_id: String, user_name: String, at: int)

signal subscription(user_name: String, length: int)
signal subscription_gifted(user_name: String, total: int, cumulative_total: Variant, is_anonymous: bool)

signal cheer(user_name: String, bits: int)

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
	CONNECTED,
	DISCONNECTED,
}

var last_status := STATUS.NONE

var game_commands: Array = []

var setup_scene: PackedScene = preload ("res://scenes/ui/setup.tscn")

var active_viewers: Dictionary = {}

var has_config: bool = false

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
func set_active_viewers(viewers: Dictionary) -> void:
	active_viewers.clear()
	for key in viewers:
		active_viewers[key] = viewers[key]

##
## private
##

func change_scene_to_setup():
	get_tree().change_scene_to_packed(setup_scene)

static func is_configuration_missing() -> bool:
	var config = ConfigManager.new(true, false).data
	if not config or not config.has("twitch_auth"):
		return true
	
	var twitch_auth = config["twitch_auth"]
	if not twitch_auth:
		return true

	return !(twitch_auth.has("client_id") and twitch_auth.has("client_secret"))

func load_configuration() -> bool:
	if is_configuration_missing():
		printerr("Tried to load missing developer integration configuration")
		emit_status(STATUS.AUTH_FILE_NOT_FOUND)
		return false

	var config = ConfigManager.new(true, false).data
	var twitch_auth = config["twitch_auth"] if config and config.has("twitch_auth") else null
	if not (twitch_auth and twitch_auth.has("client_id") and twitch_auth.has("client_secret")):
		printerr("Configuration missing client id/sercret")
		emit_status(STATUS.AUTH_FILE_NOT_FOUND)
		return false

	client_id = config.twitch_auth.client_id
	client_secret = config.twitch_auth.client_secret
	return true

## init chat connection
func stop(reason: String = "Shutting down") -> void:
	for channel_id in channels.keys():
		leave_channel(channel_id)
	disconnect_eventsub(reason)
	disconnect_irc(reason)

	cmd_no_permission.disconnect(no_permission)
	chat_message.disconnect(on_chat)
	event.disconnect(on_event)

	session_id = ""
	token = {}
	user = {}
	user_login = ""

func start() -> bool:
	user = await user_data_by_name(user_login)

	cmd_no_permission.connect(no_permission)
	chat_message.connect(on_chat)
	event.connect(on_event)

	var channel_id = user_login.to_lower()

	emit_status(STATUS.CONNECTING)
	var success = await connect_to_irc()
	if success:
		request_caps()
		join_channel(channel_id)
		emit_status(STATUS.CONNECTED)
	else:
		emit_status(STATUS.CONNECTION_FAILED)

	var cache = get_cache("twitch", channel_id)

	var broadcaster_id = await get_user_id(channel_id)

	var moderators = await GiftSingleton.get_moderators(channel_id, true)
	print("Found %d moderators: %s" % [moderators.size(), moderators])
	cache.data["moderators"] = moderators

	var vips = await GiftSingleton.get_vips(channel_id, true)
	print("Found %d VIPs: %s" % [vips.size(), vips])
	cache.data["vips"] = vips

	var bits_leaderboard = await GiftSingleton.get_bits_leaderboard(channel_id, "week", true)
	print("Found %d leaderboard entries" % [bits_leaderboard.total])
	cache.data["bits_leaderboard"] = {
		bits_leaderboard.get("period"): bits_leaderboard
	}

	var subscriptions = await GiftSingleton.get_subscriptions(channel_id, true)
	print("Found %d subscriptions" % [subscriptions.size()])
	cache.data["subscriptions"] = subscriptions

	cache.save()

	await subscribe_event("channel.moderator.add", 1, {"broadcaster_user_id": broadcaster_id})
	await subscribe_event("channel.moderator.remove", 1, {"broadcaster_user_id": broadcaster_id})
	await subscribe_event("channel.cheer", 1, {"broadcaster_user_id": broadcaster_id})
	await subscribe_event("channel.subscribe", 1, {"broadcaster_user_id": broadcaster_id})
	await subscribe_event("channel.subscription.end", 1, {"broadcaster_user_id": broadcaster_id})
	await subscribe_event("channel.subscription.gift", 1, {"broadcaster_user_id": broadcaster_id})
	await subscribe_event("channel.ban", 1, {"broadcaster_user_id": broadcaster_id})
	await subscribe_event("channel.unban", 1, {"broadcaster_user_id": broadcaster_id})
	await subscribe_event("channel.channel_points_custom_reward_redemption.add", 1, {"broadcaster_user_id": broadcaster_id})
	await subscribe_event("channel.ad_break.begin", 1, {"broadcaster_user_id": broadcaster_id})

	for mod in moderators:
		moderator_changed.emit(mod, true)

	for vip in vips:
		vip_changed.emit(vip, true)

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

	return true

func on_event(type: String, data: Dictionary) -> void:
	var current_channel = channels.keys()[0]
	var cache = get_cache("twitch", current_channel)
	match type:
		"channel.ad_break.begin":
			var duration_seconds: int = int(data.get("duration_seconds", 0))
			var is_automatic: bool = data.get("is_automatic", false)
			var raw_started_at: String = data.get("started_at", null)
			if not raw_started_at:
				push_error("Invalid channel.ad_break.begin event: %s" % data)
				return
			var started_at = Time.get_unix_time_from_datetime_string(raw_started_at)
			var now = Time.get_unix_time_from_system()
			var starting_in = started_at - now
			var ad_break_type = "Automatic" if is_automatic else "Manual"
			if starting_in > 0:
				print("%s ad break starting in %d seconds" % [ad_break_type, starting_in])
			elif starting_in < 0:
				print("%s ad break started %d seconds ago" % [ad_break_type, abs(starting_in)])
			else:
				print("%s ad break starting now" % [ad_break_type])
			ad_break_begin.emit(started_at)
		"channel.follow":
			print("%s followed your channel!" % data["user_name"])
		"channel.moderator.add":
			if not data.has("user_login"): print_debug("Bad event %s, missing user_login key" % [type])
			var user_name = data["user_login"]
			var moderators = cache.data["moderators"]
			var index = moderators.find(user_name)
			if index < 0:
				moderators.append(user_name)
				cache.save()
			moderator_changed.emit(user_name, true)
		"channel.moderator.remove":
			if not data.has("user_login"): print_debug("Bad event %s, missing user_login key" % [type])
			var user_name = data["user_login"]
			var moderators = cache.data["moderators"]
			var index = moderators.find(user_name)
			if index > - 1:
				moderators.remove_at(index)
				cache.save()
			moderator_changed.emit(user_name, false)
		"channel.cheer":
			pass
		"channel.subscribe":
			pass
		"channel.subscription.end":
			pass
		"channel.subscription.gift":
			var user_login = data["user_login"]
			var total = data["total"]
			var cumulative_total = data["cumulative_total"]
			var is_anonymous = data["is_anonymous"]
			subscription_gifted.emit(user_login, total, cumulative_total, is_anonymous)
		"channel.ban":
			var user_login = data["user_login"]
			var is_permanent = data["is_permanent"]
			var ends_at = data["ends_at"]
			var until = Time.get_unix_time_from_datetime_string(ends_at) if not is_permanent else 0
			user_ban_status_changed.emit(user_login, until, true)
		"channel.unban":
			var user_login = data["user_login"]
			user_ban_status_changed.emit(user_login, 0, false)
		"channel.channel_points_custom_reward_redemption.add":
			var user_login = data["user_login"]
			var reward = data["reward"]
			var reward_id = reward["id"]
			var redeemed_at = Time.get_unix_time_from_datetime_string(data["redeemed_at"])
			reward_redemption.emit(user_login, reward_id, redeemed_at)

			var action_id = ChannelPointsRewardMapping.get_action_for_reward_id(reward_id)
			action_triggered.emit(action_id, user_login, redeemed_at)

func emit_status(new_status: STATUS) -> void:
	status.emit(new_status)
	last_status = new_status

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

func add_viewer_command(command_info: CommandInfo) -> void:
	var display_name: String = command_info.sender_data.tags["display-name"]
	var color: String = command_info.sender_data.tags["color"]
	add_viewer(display_name, color)

func add_viewer(display_name: String, color: String):
	viewer_joined.emit(display_name, color)

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
