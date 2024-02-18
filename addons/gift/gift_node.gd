extends Node
class_name Gift

# The underlying websocket sucessfully connected to Twitch IRC.
signal twitch_connected
# The connection has been closed. Not emitted if Twitch IRC announced a reconnect.
signal twitch_disconnected
# The connection to Twitch IRC failed.
signal twitch_unavailable
# Twitch IRC requested the client to reconnect. (Will be unavailable until next connect)
signal twitch_reconnect
# User token from Twitch has been fetched.
signal user_token_received(token_data)
# User token is valid.
signal user_token_valid
# User token is no longer valid.
signal user_token_invalid
# The client tried to login to Twitch IRC. Returns true if successful, else false.
signal login_attempt(success)
# User sent a message in chat.
signal chat_message(sender_data, message)
# User sent a whisper message.
signal whisper_message(sender_data, message)
# Unhandled data passed through
signal unhandled_message(message, tags)
# A command has been called with invalid arg count
signal cmd_invalid_argcount(cmd_name, sender_data, cmd_data, arg_ary)
# A command has been called with insufficient permissions
signal cmd_no_permission(cmd_name, sender_data, cmd_data, arg_ary)
# Twitch IRC ping is about to be answered with a pong.
signal pong

# User joins chat
signal user_joined_chat(sender_data)
# User leaves chat
signal user_left_chat(sender_data)

# The underlying websocket sucessfully connected to Twitch EventSub.
signal events_connected
# The connection to Twitch EventSub failed.
signal events_unavailable
# The underlying websocket disconnected from Twitch EventSub.
signal events_disconnected
# The id has been received from the welcome message.
signal events_id(id)
# Twitch directed the bot to reconnect to a different URL
signal events_reconnect
# Twitch revoked a event subscription
signal events_revoked(event, reason)

# Refer to https://dev.twitch.tv/docs/eventsub/eventsub-reference/ data contained in the data dictionary.
signal event(type, data)

@export_category("IRC")

## Messages starting with one of these symbols are handled as commands. '/' will be ignored, reserved by Twitch.
@export var command_prefixes: Array[String] = ["!"]

## Time to wait in msec after each sent chat message. Values below ~310 might lead to a disconnect after 100 messages.
@export var chat_timeout_ms: int = 320

## Scopes to request for the token. Look at https://dev.twitch.tv/docs/authentication/scopes/ for a list of all available scopes.
@export var scopes: Array[String] = [
	"channel:read:ads",
	"chat:edit",
	"chat:read",
	"moderation:read",
	"channel:manage:redemptions",
	"channel:moderate",
	"channel:read:redemptions",
	"channel:read:subscriptions",
	"channel:read:vips",
	"bits:read"
]

@export_category("Emotes/Badges")

## If true, caches emotes/badges to disk, so that they don't have to be redownloaded on every restart.
## This however means that they might not be updated if they change until you clear the cache.
@export var disk_cache: bool = false

## Disk Cache has to be enbaled for this to work
@export_file var disk_cache_path: String = "user://gift/cache"

var client_id: String = ""
var client_secret: String = ""
var user_login: String = ""
var user: Dictionary = {}
var user_id: String = ""
var token: Dictionary = {}

var user_display_name: String:
	get: return user.get("display_name", user_login)

# Twitch disconnects connected clients if too many chat messages are being sent. (At about 100 messages/30s).
# This queue makes sure messages aren't sent too quickly.
var chat_queue: Array[String] = []
var last_msg: int = Time.get_ticks_msec()
# Mapping of channels to their channel info, like available badges.
var channels: Dictionary = {}
# Last Userstate of the bot for channels. Contains <channel_name> -> <userstate_dictionary> entries.
var last_state: Dictionary = {}
# Dictionary of commands, contains <command key> -> <Callable> entries.
var commands: Dictionary = {}

var websocket_eventsub: WebSocketPeer
var eventsub_messages: Dictionary = {}
var eventsub_connected: bool = false
var eventsub_restarting: bool = false
var eventsub_reconnect_url: String = ""
var session_id: String = ""
var keepalive_timeout: int = 0
var last_keepalive: int = 0

var websocket_irc: WebSocketPeer
var server: TCPServer = TCPServer.new()
var peer: StreamPeerTCP
var connected: bool = false
var user_regex: RegEx = RegEx.new()
var twitch_restarting: bool = false

var channel_caches: Dictionary = {}

const USER_AGENT_VALUE: String = "GIFT/4.1.4 (Godot Engine)"
const USER_AGENT: String = "User-Agent: %s" % USER_AGENT_VALUE

enum RequestType {
	EMOTE,
	BADGE,
	BADGE_MAPPING
}

var caches := {
	RequestType.EMOTE: {},
	RequestType.BADGE: {},
	RequestType.BADGE_MAPPING: {}
}

# Required permission to execute the command
enum PermissionFlag {
	EVERYONE = 0,
	VIP = 1,
	SUB = 2,
	MOD = 4,
	STREAMER = 8,
	# Mods and the streamer
	MOD_STREAMER = 12,
	# Everyone but regular viewers
	NON_REGULAR = 15
}

# Where the command should be accepted
enum WhereFlag {
	CHAT = 1,
	WHISPER = 2
}

func _init():
	user_regex.compile("(?<=!)[\\w]*(?=@)")
	if (disk_cache):
		for key in RequestType.keys():
			if (!DirAccess.dir_exists_absolute(disk_cache_path + "/" + key)):
				DirAccess.make_dir_recursive_absolute(disk_cache_path + "/" + key)

func get_cache(service: String, channel_name: String) -> JsonManager:
	var channel_id = channel_name.to_lower()
	var cache: JsonManager = channel_caches.get_or_add(channel_id, JsonManager.new("cache/" + service + "." + channel_id + ".json"))
	if cache.data == null:
		cache.data = {}
	return cache

func get_user_id(display_name: String) -> String:
	var user_name = display_name.to_lower()
	var cache = get_cache("twitch", user_name)
	if not cache.data.has("user_data"):
		cache.data["user_data"] = await user_data_by_name(user_name)
		cache.save()

	var user_data = cache.data["user_data"]
	assert(user_data != null and user_data.has("id"))

	return user_data.id

func load_token_blob() -> Dictionary:
	var file: FileAccess
	if is_token_blob_encrypted():
		file = FileAccess.open_encrypted_with_pass("user://gift/auth/user_token", FileAccess.READ, client_secret)
	else:
		file = FileAccess.open("user://gift/auth/user_token", FileAccess.READ)

	if file == null or file.get_position() >= file.get_length():
		print("No token on disk/empty token file")
		return {}

	var parser = JSON.new()
	var result = parser.parse(file.get_as_text())
	if not result == OK:
		printerr("Failed to parse token file %d @ %d: %s" % [result, parser.get_error_line(), parser.get_error_message()])
		return {}

	var token_blob = parser.data
	if not token_blob is Dictionary:
		printerr("Expected a dictionary to be in the token file but received %s" % [typeof(parser.data)])
		return {}

	return token_blob

func save_token_blob() -> void:
	if (!DirAccess.dir_exists_absolute("user://gift/auth")):
		DirAccess.make_dir_recursive_absolute("user://gift/auth")

	var file: FileAccess
	if is_token_blob_encrypted():
		file = FileAccess.open_encrypted_with_pass("user://gift/auth/user_token", FileAccess.WRITE, client_secret)
	else:
		file = FileAccess.open("user://gift/auth/user_token", FileAccess.WRITE)

	var token_json = JSON.stringify(token)
	file.store_string(token_json)

func is_token_blob_encrypted() -> bool:
	if not OS.is_debug_build():
		return true

	var file = FileAccess.open("user://gift/auth/user_token", FileAccess.READ)
	if file == null or file.get_position() >= file.get_length():
		return true

	if not file.get_8() == 0x7B:
		# This is probably encrypted, or is invalid
		return true

	file.seek(0)

	var file_text = file.get_as_text().strip_edges()
	if not (file_text.begins_with("{") and file_text.ends_with("}")):
		# This is probably encrypted, or is invalid
		return true

	var parser = JSON.new()
	var result = parser.parse(file_text)
	if not result == OK:
		printerr("Failed to parse token file %d @ %d: %s" % [result, parser.get_error_line(), parser.get_error_message()])
		return true

	var token_blob = parser.data
	if not token_blob is Dictionary:
		printerr("Expected a dictionary to be in the token file but received %s" % [typeof(parser.data)])
		return true

	return false

func validate_developer_integration(client_id: String, client_secret: String) -> String:
	var token_response = await request_http(
		"https://id.twitch.tv/oauth2/token",
		{},
		{
			"Content-Type": "application/x-www-form-urlencoded",
		},
		encode_form({
			"client_id": client_id,
			"client_secret": client_secret,
			"grant_type": "client_credentials",
		})
	)

	var response_code = token_response.get("response_code", 0) as int
	if response_code == 200:
		return ""

	var response_body = token_response.get("response_body") as PackedByteArray
	var response_body_text = response_body.get_string_from_utf8() if response_body else ""

	var response_headers = token_response.get("response_headers", []) as Array[String]
	for response_header in response_headers:
		var response_header_lower = response_header.to_lower()
		if not response_header_lower.begins_with("content-type:"):
			continue

		if response_header_lower.contains("application/json"):
			var parsed_body = JSON.parse_string(response_body_text)
			printerr("Invalid client configuration: %s" % [parsed_body])
			var message = parsed_body.get("message", "") as String
			if message:
				message = message.strip_edges()

			if message:
				return message

			return "Bad client configuration (no understood message from server)"

	printerr("Invalid client configuration: %s" % [response_body_text])
	var truncated_error_message = response_body_text.substr(0, min(response_body_text.length(), 30))
	return "Unexpected error: %s" % [truncated_error_message]

# Authenticate to authorize GIFT to use your account to process events and messages.
func authenticate(force: bool = false) -> bool:
	print("Checking token...")
	var token_blob = load_token_blob()
	
	if not force:
		if token_blob.is_empty():
			force = true
		elif not token_blob.has("scope"):
			force = true
		else:
			var token_scopes = token_blob["scope"]
			if scopes.size() != token_scopes.size():
				force = true
			else:
				for scope in scopes:
					if not token_scopes.has(scope):
						force = true

	if force:
		get_token()
		token = await user_token_received
	else:
		token = token_blob

	user_login = await get_token_user_login()
	
	var attempts = 0
	while user_login == "" and attempts < 3:
		attempts += 1
		if not await refresh_token():
			print("Invalid access token and failed to refresh, acquiring new token...")
			get_token()
			token = await (user_token_received)
		user_login = await get_token_user_login()

	if user_login == "":
		printerr("Failed to authenticate in 3 attempts")
		return false

	print("Token verified.")
	user_token_valid.emit()
	return true

func _get_token_thread(scope: String) -> void:
	OS.shell_open("https://id.twitch.tv/oauth2/authorize?response_type=code&client_id=" + client_id + "&redirect_uri=http://localhost:18297&scope=" + scope)

	if server and server.is_listening():
		server.stop()

	server.listen(18297)
	print("Waiting for user to login.")
	while (!peer):
		peer = server.take_connection()
		OS.delay_msec(100)
	while (peer.get_status() == peer.STATUS_CONNECTED):
		peer.poll()
		if (peer.get_available_bytes() > 0):
			var response = peer.get_utf8_string(peer.get_available_bytes())
			if (response == ""):
				print("Empty response. Check if your redirect URL is set to http://localhost:18297.")
				return
			var start: int = response.find("?")
			response = response.substr(start + 1, response.find(" ", start) - start)
			var data: Dictionary = {}
			for entry in response.split("&"):
				var pair = entry.split("=")
				data[pair[0]] = pair[1] if pair.size() > 0 else ""
			if (data.has("error")):
				var msg = "Error %s: %s" % [data["error"],data["error_description"]]
				print(msg)
				send_response(peer, "400 BAD REQUEST", msg.to_utf8_buffer())
				peer.disconnect_from_host()
				server.stop()
				break
			else:
				print("Success.")
				send_response(peer, "200 OK", "Success!".to_utf8_buffer())
				peer.disconnect_from_host()
				var authorization_code = data["code"]
				_request_access_token.call_deferred(authorization_code)
				server.stop()
				break
		OS.delay_msec(100)

func _request_access_token(authorization_code: String) -> void:
	var access_token_response = await request_http(
		"https://id.twitch.tv/oauth2/token",
		{},
		{
			"content-type": "application/x-www-form-urlencoded",
			"user-agent": USER_AGENT_VALUE,
		},
		encode_form({
			"client_id": client_id,
			"client_secret": client_secret,
			"code": authorization_code,
			"grant_type": "authorization_code",
			"redirect_uri": "http://localhost:18297"
		}),
		HTTPClient.METHOD_POST
	)

	var response_body_raw = access_token_response.get("response_body") as PackedByteArray
	assert(response_body_raw != null, "Invalid response body")
	
	var token_json = response_body_raw.get_string_from_utf8()
	var token = JSON.parse_string(token_json) as Dictionary
	assert(token != null, "Invalid token response")
	var expires_in = token.get("expires_in") as int
	var now = Time.get_unix_time_from_system()
	var expires_at = now + expires_in - 100
	token["expires_at"] = expires_at
	self.token = token

	save_token_blob()
	user_token_received.emit(token)

# Gets a new auth token from Twitch.
func get_token() -> void:
	print("Fetching new token.")
	var scope = ""
	for i in scopes.size() - 1:
		scope += scopes[i]
		scope += " "
	if (scopes.size() > 0):
		scope += scopes[scopes.size() - 1]
	scope = scope.uri_encode()
	Thread.new().start(_get_token_thread.bindv([scope]))
	var token = await user_token_received
	if token:
		print("Successfully acquired authentication tokens")
	else:
		print("Failed to acquire authentication tokens")

static func send_response(peer: StreamPeer, response: String, body: PackedByteArray) -> void:
	peer.put_data(("HTTP/1.1 %s\r\n" % response).to_utf8_buffer())
	peer.put_data("Server: GIFT (Godot Engine)\r\n".to_utf8_buffer())
	peer.put_data(("Content-Length: %d\r\n" % body.size()).to_utf8_buffer())
	peer.put_data("Connection: close\r\n".to_utf8_buffer())
	peer.put_data("Content-Type: text/plain; charset=UTF-8\r\n".to_utf8_buffer())
	peer.put_data("\r\n".to_utf8_buffer())
	peer.put_data(body)

# If the token is valid, returns the username of the token bearer.
func get_token_user_login() -> String:
	var access_token = token.get("access_token", "") as String
	if access_token == "":
		return ""

	var response = await request_http(
		"https://id.twitch.tv/oauth2/validate",
		{},
		{
			
			"User-Agent": USER_AGENT_VALUE,
			"Authorization": "OAuth %s" % [access_token],
		}
	)
	
	var response_code = response.get("response_code", 0) as int
	var response_body = response.get("response_body", null) as PackedByteArray
	if not response_code == 200:
		printerr("Unable to get authenticated user: %d" % [response_code])
		return ""
	
	if response_body == null:
		printerr("Invalid response body")
		return ""
	
	var response_body_text = response_body.get_string_from_utf8()
	var payload = JSON.parse_string(response_body_text)
	if payload == null:
		printerr("Failed to parse response body")
		return ""
	
	user_id = payload.get("user_id", "")
	var user_login = payload.get("login", "")
	return user_login

func refresh_token() -> bool:
	var to_remove: Array[String] = []
	for entry in eventsub_messages.keys():
		if (Time.get_ticks_msec() - eventsub_messages[entry] > 600000):
			to_remove.append(entry)
	for n in to_remove:
		eventsub_messages.erase(n)
	
	var token_blob = load_token_blob()
	var refresh_token = token_blob.get("refresh_token", null)
	if not refresh_token is String:
		return false

	var response = await request_http(
		"https://id.twitch.tv/oauth2/token",
		{},
		{
			"User-Agent": "",
			"Content-Type": "application/x-www-form-urlencoded",
		},
		encode_form({
			"client_id": client_id,
			"client_secret": client_secret,
			"grant_type": "refresh_token",
			"refresh_token": refresh_token,
		})
	)
	
	var response_code = response.get("response_code", 0) as int
	if not response_code == 200:
		printerr("Error refreshing token: %d" % [response_code])
		return false

	var response_body = response.get("response_body")
	var response_body_text = response_body.get_string_from_utf8()
	var new_token_blob = JSON.parse_string(response_body_text) as Dictionary
	assert(new_token_blob != null, "Invalid token response")
	var expires_in = new_token_blob.get("expires_in") as int
	var now = Time.get_unix_time_from_system()
	var expires_at = now + expires_in - 100
	new_token_blob["expires_at"] = expires_at

	if not new_token_blob.has("refresh_token"):
		new_token_blob["refresh_token"] = refresh_token

	token = new_token_blob

	save_token_blob()
	user_token_received.emit(token)
	return true

func _process(delta: float) -> void:
	if websocket_irc:
		websocket_irc.poll()
		var state := websocket_irc.get_ready_state()
		match state:
			WebSocketPeer.STATE_OPEN:
				if (!connected):
					twitch_connected.emit()
					connected = true
					print_debug("Connected to Twitch.")
				else:
					while websocket_irc.get_available_packet_count():
						data_received(websocket_irc.get_packet())
					if (!chat_queue.is_empty()&&(last_msg + chat_timeout_ms) <= Time.get_ticks_msec()):
						send(chat_queue.pop_front())
						last_msg = Time.get_ticks_msec()
			WebSocketPeer.STATE_CLOSED:
				if (!connected):
					twitch_unavailable.emit()
					print_debug("Could not connect to Twitch.")
					websocket_irc = null
				elif (twitch_restarting):
					print_debug("Reconnecting to Twitch...")
					twitch_reconnect.emit()
					connect_to_irc()
					await (twitch_connected)
					for channel in channels.keys():
						join_channel(channel)
					twitch_restarting = false
				else:
					print_debug("Disconnected from Twitch.")
					twitch_disconnected.emit()
					connected = false
					print_debug("Connection closed! [%s]: %s" % [websocket_irc.get_close_code(), websocket_irc.get_close_reason()])
	if websocket_eventsub:
		websocket_eventsub.poll()
		var state := websocket_eventsub.get_ready_state()
		match state:
			WebSocketPeer.STATE_OPEN:
				if (!eventsub_connected):
					events_connected.emit()
					eventsub_connected = true
					print_debug("Connected to EventSub.")
				else:
					while websocket_eventsub.get_available_packet_count():
						process_event(websocket_eventsub.get_packet())
			WebSocketPeer.STATE_CLOSED:
				if (!eventsub_connected):
					print_debug("Could not connect to EventSub.")
					events_unavailable.emit()
					websocket_eventsub = null
				elif eventsub_restarting:
					print_debug("Reconnecting to EventSub")
					websocket_eventsub.close()
					connect_to_eventsub(eventsub_reconnect_url)
					await (eventsub_connected)
					eventsub_restarting = false
				else:
					print_debug("Disconnected from EventSub.")
					events_disconnected.emit()
					eventsub_connected = false
					print_debug("Connection closed! [%s]: %s" % [websocket_irc.get_close_code(), websocket_irc.get_close_reason()])

func process_event(data: PackedByteArray) -> void:
	var msg: Dictionary = JSON.parse_string(data.get_string_from_utf8())
	if (eventsub_messages.has(msg["metadata"]["message_id"])):
		return
	eventsub_messages[msg["metadata"]["message_id"]] = Time.get_ticks_msec()
	var payload: Dictionary = msg["payload"]
	last_keepalive = Time.get_ticks_msec()
	match msg["metadata"]["message_type"]:
		"session_welcome":
			session_id = payload["session"]["id"]
			keepalive_timeout = payload["session"]["keepalive_timeout_seconds"]
			events_id.emit(session_id)
		"session_keepalive":
			if (payload.has("session")):
				keepalive_timeout = payload["session"]["keepalive_timeout_seconds"]
		"session_reconnect":
			eventsub_restarting = true
			eventsub_reconnect_url = payload["session"]["reconnect_url"]
			events_reconnect.emit()
		"revocation":
			events_revoked.emit(payload["subscription"]["type"], payload["subscription"]["status"])
		"notification":
			var event_data: Dictionary = payload["event"]
			event.emit(payload["subscription"]["type"], event_data)

# Connect to Twitch IRC. Make sure to authenticate first.
func connect_to_irc() -> bool:
	print("Connecting to Twitch IRC...")
	websocket_irc = WebSocketPeer.new()
	websocket_irc.connect_to_url("wss://irc-ws.chat.twitch.tv:443")
	await twitch_connected
	send("PASS oauth:%s" % [token["access_token"]], true)
	send("NICK " + user_login.to_lower())
	var success = await (login_attempt)
	if (success):
		connected = true
	return success

func disconnect_irc(reason: String = "Shutting down", code: int = 1000) -> void:
	if not websocket_irc:
		return

	print("Disconnecting from Twitch IRC...")
	websocket_irc.close(code, reason)
	websocket_irc = null

# Connect to Twitch EventSub. Make sure to authenticate first.
func connect_to_eventsub(url: String="wss://eventsub.wss.twitch.tv/ws") -> void:
	print("Connecting to Twitch EventSub...")
	websocket_eventsub = WebSocketPeer.new()
	websocket_eventsub.connect_to_url(url)
	await (events_id)
	events_connected.emit()

func disconnect_eventsub(reason: String = "Shutting down", code: int = 1000) -> void:
	if not websocket_eventsub:
		return

	print("Disconnecting from Twitch EventSub...")
	websocket_eventsub.close(code, reason)
	websocket_eventsub = null

# Refer to https://dev.twitch.tv/docs/eventsub/eventsub-subscription-types/ for details on
# which API versions are available and which conditions are required.
func subscribe_event(event_name: String, version: int, conditions: Dictionary) -> void:
	if not eventsub_connected:
		await connect_to_eventsub()

	var data: Dictionary = {}
	data["type"] = event_name
	data["version"] = str(version)
	data["condition"] = conditions
	data["transport"] = {
		"method": "websocket",
		"session_id": session_id
	}

	var request: HTTPRequest = HTTPRequest.new()
	add_child(request)
	request.request("https://api.twitch.tv/helix/eventsub/subscriptions", [USER_AGENT, "Authorization: Bearer " + token["access_token"], "Client-Id:" + client_id, "Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify(data))
	var reply: Array = await (request.request_completed)
	request.queue_free()
	var response: Dictionary = JSON.parse_string(reply[3].get_string_from_utf8())
	if (response.has("error")):
		print("Subscription failed for event '%s'. Error %s (%s): %s" % [event_name, response["status"], response["error"], response["message"]])
		return
	print("Now listening to '%s' events." % event_name)

# Request capabilities from twitch.
func request_caps(caps: String="twitch.tv/commands twitch.tv/tags twitch.tv/membership") -> void:
	send("CAP REQ :" + caps)

# Sends a String to Twitch.
func send(text: String, token: bool = false) -> void:
	if not websocket_irc:
		return

	websocket_irc.send_text(text)
	if (OS.is_debug_build()):
		if (!token):
			print("< " + text.strip_edges(false))
		else:
			print("< PASS oauth:******************************")

# Sends a chat message to a channel. Defaults to the only connected channel.
func chat(message: String, channel: String=""):
	var keys: Array = channels.keys()
	var primary_channel = channels.keys()[0]
	var state = last_state[primary_channel] if last_state.has(primary_channel) else {}
	var display_name = state["display-name"] if state.has("display-name") else ""

	if channel != "":
		if (channel.begins_with("#")):
			channel = channel.right( - 1)
	elif keys.size() == 1:
		channel = primary_channel
	else:
		print_debug("No channel specified.")
		return

	chat_queue.append("PRIVMSG #" + channel + " :" + message + "\r\n")
	chat_message.emit(SenderData.new(display_name, channel, state), message)

# Send a whisper message to a user by username. Returns a empty dictionary on success. If it failed, "status" will be present in the Dictionary.
func whisper(message: String, target: String) -> Dictionary:
	var user_data: Dictionary = await (user_data_by_name(target))
	if (user_data.has("status")):
		return user_data
	var response: int = await (whisper_by_uid(message, user_data["id"]))
	if (response != HTTPClient.RESPONSE_NO_CONTENT):
		return {"status": response}
	return {}

# Send a whisper message to a user by UID. Returns the response code.
func whisper_by_uid(message: String, target_id: String) -> int:
	var request: HTTPRequest = HTTPRequest.new()
	add_child(request)
	request.request("https://api.twitch.tv/helix/whispers", [USER_AGENT, "Authorization: Bearer " + token["access_token"], "Client-Id:" + client_id, "Content-Type: application/json"], HTTPClient.METHOD_POST, JSON.stringify({"from_user_id": user_id, "to_user_id": target_id, "message": message}))
	var reply: Array = await (request.request_completed)
	request.queue_free()
	if (reply[1] != HTTPClient.RESPONSE_NO_CONTENT):
		print("Error sending the whisper: " + reply[3].get_string_from_utf8())
	return reply[0]

class HelixApiResponse:
	var response_code: int
	var response_body: Dictionary

	func _init(response_code: int, response_body: Dictionary):
		self.response_code = response_code
		self.response_body = response_body

static func map_user_name(user_data: Dictionary) -> String:
	return user_data["user_name"] if user_data.has("user_name") else ""

static func filter_nonempty_string(str: String) -> bool:
	return str != ""

func validate_channel_id(channel: String = "") -> String:
	var channel_id = channel.strip_edges().to_lower()
	if not channel_id == "":
		return channel_id

	var keys = channels.keys()
	if keys.size() < 1:
		printerr("No channel")
		return ""
	
	for key in keys:
		channel_id = key.strip_edges().to_lower()
		if not channel_id == "":
			return channel_id

	printerr("All channels are invalid, this realistically should never be hit")
	return ""

func get_moderators(channel: String="", force: bool=false) -> Array[String]:
	var channel_id = validate_channel_id(channel)
	if channel_id == "":
		return []

	var cache = get_cache("twitch", channel_id)
	if !force and cache.data.has("moderators"):
		print("Cache hit on moderators channel=%s" % [channel_id])
		var array: Array[String] = []
		array.append_array(cache.data.get("moderators"))
		return array

	var broadcaster_id = await get_user_id(channel_id)
	var response: HelixApiResponse = await request_api("moderation/moderators", {
		"broadcaster_id": broadcaster_id,
	})

	if response.response_code != HTTPClient.RESPONSE_OK:
		return []

	var body = response.response_body
	if not body.has("data"):
		return []

	var data = body.get("data") as Array
	if data == null:
		return []

	var array: Array[String] = []
	array.append_array(data.map(map_user_name).filter(filter_nonempty_string))
	return array

func get_vips(channel: String="", force: bool=false) -> Array[String]:
	var channel_id = validate_channel_id(channel)
	if channel_id == "":
		return []

	var cache = get_cache("twitch", channel_id)
	if !force and cache.data.has("vips"):
		print("Cache hit on vips channel=%s" % [channel_id])
		var array: Array[String] = []
		array.append_array(cache.data.get("vips"))
		return array

	var broadcaster_id = await get_user_id(channel_id)
	var response: HelixApiResponse = await request_api("channels/vips", {
		"broadcaster_id": broadcaster_id,
	})

	if response.response_code != HTTPClient.RESPONSE_OK:
		return []

	var body = response.response_body
	if not body.has("data"):
		return []

	var data = body.get("data") as Array
	if data == null:
		return []

	var array: Array[String] = []
	array.append_array(data.map(map_user_name).filter(filter_nonempty_string))
	return array

func get_bits_leaderboard(channel: String="", period: String="week", force: bool=false) -> Dictionary:
	var channel_id = validate_channel_id(channel)
	if channel_id == "":
		return {}

	var cache = get_cache("twitch", channel_id)
	if !force and cache.data.has("bits_leaderboard"):
		var cache_level1 = cache.data.get("bits_leaderboard", {})
		if cache_level1.has(period):
			print("Cache hit on bits_leaderboard period=%s channel=%s" % [period, channel_id])
			return cache_level1.get(period, {})

	var broadcaster_id = await get_user_id(channel_id)

	var datetime_now = Time.get_datetime_string_from_system(true) + "Z"
	var response: HelixApiResponse = await request_api("bits/leaderboard", {
		"count": 100,
		"period": period,
		"started_at": datetime_now
	})

	var response_code = response.response_code
	if response_code != HTTPClient.RESPONSE_OK:
		return {}

	var data = response.response_body
	data["period"] = period
	return data

func create_channel_points_custom_reward() -> String:
	return ""

func get_channel_points_custom_rewards() -> Array[ChannelPointsReward]:
	var response = await request_api(
		"channel_points/custom_rewards",
		{
			"broadcaster_id": user_id,
			#"only_manageable_rewards": true,
		}
	)
	
	if response.response_code != 200 or not response.response_body is Dictionary:
		printerr("Error retrieving channel points rewards: %d %s" % [
			response.response_code,
			response.response_body
		])
		return []

	var data = response.response_body.get("data", []) as Array

	var rewards: Array[ChannelPointsReward] = []
	for item in data:
		var reward = ChannelPointsReward.new(item)
		rewards.append(reward)

	return rewards

func get_subscriptions(channel: String="", force: bool=false) -> Array[Dictionary]:
	var channel_id = validate_channel_id(channel)
	if channel_id == "":
		return []

	var cache = get_cache("twitch", channel_id)
	if !force and cache.data.has("subscriptions"):
		print("Cache hit on subscriptions channel=%s" % [channel_id])
		var array: Array[Dictionary] = []
		array.append_array(cache.data.get("subscriptions"))
		return array

	var subscriptions: Array[Dictionary] = []
	var broadcaster_id = await get_user_id(channel_id)
	var has_next_page: bool = true
	var next_page_cursor: String = ""
	while has_next_page:
		var conditions: Dictionary = {
			"broadcaster_id": broadcaster_id,
			"first": "100"
		}

		if next_page_cursor != "":
			conditions["after"] = next_page_cursor

		var response: HelixApiResponse = await request_api("subscriptions", conditions)

		if response.response_code != HTTPClient.RESPONSE_OK:
			break

		var body = response.response_body
		if not body.has("data"):
			break

		var data = body.get("data") as Array
		if data == null:
			break

		subscriptions.append_array(data)

		if not body.has("pagination"):
			break

		var pagination = body["pagination"]
		if not pagination.has("cursor"):
			break

		next_page_cursor = pagination["cursor"]
		has_next_page = (next_page_cursor != "")

	return subscriptions

func encode_form(params: Dictionary) -> String:
	var encoded = ""
	var keys = params.keys()
	for key in keys:
		if encoded.length() > 0:
			encoded += "&"
		var value = params[key]
		encoded += "%s=%s" % [str(key).uri_encode(), str(value).uri_encode()]
	return encoded

func request_http(uri: String, query_params: Dictionary = {}, headers: Dictionary = {}, request_body: Variant = null, request_method: HTTPClient.Method = HTTPClient.METHOD_GET) -> Dictionary:
	var request: HTTPRequest = HTTPRequest.new()
	add_child(request)

	if request_body != null and request_method == HTTPClient.METHOD_GET:
		request_method = HTTPClient.METHOD_POST
	
	var request_uri = uri
	
	var keys = query_params.keys()
	if keys.size() > 0:
		request_uri += "?"

	var query_param_string = encode_form(query_params)
	request_uri += query_param_string

	var has_user_agent: bool = false
	var request_headers: Array[String] = []
	for header_name in headers.keys():
		if header_name.to_lower() == "user-agent":
			has_user_agent = true
		var header_value = str(headers.get(header_name, ""))
		request_headers.append("%s: %s" % [header_name, header_value])

	if not has_user_agent:
		request_headers.append(USER_AGENT)

	request.request(
		request_uri,
		request_headers,
		request_method,
		"" if request_body == null else request_body
	)

	# result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray
	var reply: Array = await (request.request_completed)
	request.queue_free()

	return {
		"result": reply[0],
		"request_uri": request_uri,
		"request_headers": request_headers,
		"request_body": request_body,
		"request_method": request_method,
		"response_code": reply[1],
		"response_headers": reply[2],
		"response_body": reply[3]
	}

func request_api(api_path: String, query_params: Dictionary = {}, request_body = null, request_method = HTTPClient.METHOD_GET, fail_on_unauthorized: bool = false) -> HelixApiResponse:
	var serialized_request_body = JSON.stringify(request_body) if request_body != null else null
	var uri = "https://api.twitch.tv/helix/%s" % [api_path]

	var response = await request_http(
		uri,
		query_params,
		{
			"Authorization": "Bearer %s" % [token["access_token"]],
			"Client-Id": client_id,
			"Content-Type": "application/json",
		},
		serialized_request_body,
		request_method,
	)

	var response_code = response.get("response_code", 0) as int
	var response_body = response.get("response_body") as PackedByteArray

	match response_code:
		HTTPClient.RESPONSE_OK:
			print("Successfully requested %s" % api_path)
			var response_raw_json = response_body.get_string_from_utf8()
			var parser = JSON.new()
			if parser.parse(response_raw_json):
				printerr("Failed to parse response from %s: %s" % [api_path, response_raw_json])
				return HelixApiResponse.new(response_code, {})
			return HelixApiResponse.new(response_code, parser.data)
		HTTPClient.RESPONSE_BAD_REQUEST:
			printerr("Bad request to %s: %s" % [api_path, response_body.get_string_from_utf8() if response_body != null and response_body.size() > 0 else ""])
			return HelixApiResponse.new(response_code, {})
		HTTPClient.RESPONSE_UNAUTHORIZED:
			printerr("Unauthorized access to %s: %s" % [api_path, response_body.get_string_from_utf8() if response_body != null and response_body.size() > 0 else ""])
			if fail_on_unauthorized:
				return HelixApiResponse.new(response_code, {})
			await refresh_token()
			return await request_api(api_path, query_params, request_body, request_method, true)
		_:
			printerr("Unexpected response code %d when fetching api %s: %s" % [response_code, api_path, response_body.get_string_from_utf8() if response_body != null and response_body.size() > 0 else ""])
			return HelixApiResponse.new(response_code, {})

# Returns the response as Dictionary. If it failed, "error" will be present in the Dictionary.
func user_data_by_name(username: String) -> Dictionary:
	var request: HTTPRequest = HTTPRequest.new()
	add_child(request)
	request.request("https://api.twitch.tv/helix/users?login=" + username, [USER_AGENT, "Authorization: Bearer " + token["access_token"], "Client-Id:" + client_id, "Content-Type: application/json"], HTTPClient.METHOD_GET)
	var reply: Array = await (request.request_completed)
	var response: Dictionary = JSON.parse_string(reply[3].get_string_from_utf8())
	request.queue_free()
	if (response.has("error")):
		print("Error fetching user data: " + reply[3].get_string_from_utf8())
		return response
	else:
		return response["data"][0]

func get_emote(emote_id: String, scale: String="1.0") -> Texture2D:
	var texture: Texture2D
	var cachename: String = emote_id + "_" + scale
	var filename: String = disk_cache_path + "/" + RequestType.keys()[RequestType.EMOTE] + "/" + cachename + ".png"
	if !caches[RequestType.EMOTE].has(cachename):
		if (disk_cache&&FileAccess.file_exists(filename)):
			texture = ImageTexture.new()
			var img: Image = Image.new()
			img.load_png_from_buffer(FileAccess.get_file_as_bytes(filename))
			texture.create_from_image(img)
		else:
			var request: HTTPRequest = HTTPRequest.new()
			add_child(request)
			request.request("https://static-cdn.jtvnw.net/emoticons/v1/" + emote_id + "/" + scale, [USER_AGENT, "Accept: */*"])
			var data = await (request.request_completed)
			request.queue_free()
			var img: Image = Image.new()
			img.load_png_from_buffer(data[3])
			texture = ImageTexture.create_from_image(img)
			texture.take_over_path(filename)
			if (disk_cache):
				DirAccess.make_dir_recursive_absolute(filename.get_base_dir())
				texture.get_image().save_png(filename)
		caches[RequestType.EMOTE][cachename] = texture
	return caches[RequestType.EMOTE][cachename]

func get_badge(badge_name: String, channel_id: String="_global", scale: String="1") -> Texture2D:
	var badge_data: PackedStringArray = badge_name.split("/", true, 1)
	var texture: Texture2D
	var cachename = badge_data[0] + "_" + badge_data[1] + "_" + scale
	var filename: String = disk_cache_path + "/" + RequestType.keys()[RequestType.BADGE] + "/" + channel_id + "/" + cachename + ".png"
	if (!caches[RequestType.BADGE].has(channel_id)):
		caches[RequestType.BADGE][channel_id] = {}
	if (!caches[RequestType.BADGE][channel_id].has(cachename)):
		if (disk_cache&&FileAccess.file_exists(filename)):
			var img: Image = Image.new()
			img.load_png_from_buffer(FileAccess.get_file_as_bytes(filename))
			texture = ImageTexture.create_from_image(img)
			texture.take_over_path(filename)
		else:
			var map: Dictionary = caches[RequestType.BADGE_MAPPING].get(channel_id, await (get_badge_mapping(channel_id)))
			if (!map.is_empty()):
				if (map.has(badge_data[0])):
					var request: HTTPRequest = HTTPRequest.new()
					add_child(request)
					request.request(map[badge_data[0]]["versions"][badge_data[1]]["image_url_" + scale + "x"], [USER_AGENT, "Accept: */*"])
					var data = await (request.request_completed)
					var img: Image = Image.new()
					img.load_png_from_buffer(data[3])
					texture = ImageTexture.create_from_image(img)
					texture.take_over_path(filename)
					request.queue_free()
				elif channel_id != "_global":
					return await (get_badge(badge_name, "_global", scale))
			elif (channel_id != "_global"):
				return await (get_badge(badge_name, "_global", scale))
			if (disk_cache):
				DirAccess.make_dir_recursive_absolute(filename.get_base_dir())
				texture.get_image().save_png(filename)
		texture.take_over_path(filename)
		caches[RequestType.BADGE][channel_id][cachename] = texture
	return caches[RequestType.BADGE][channel_id][cachename]

func get_badge_mapping(channel_id: String="_global") -> Dictionary:
	if !caches[RequestType.BADGE_MAPPING].has(channel_id):
		var filename: String = disk_cache_path + "/" + RequestType.keys()[RequestType.BADGE_MAPPING] + "/" + channel_id + ".json"
		if (disk_cache&&FileAccess.file_exists(filename)):
			caches[RequestType.BADGE_MAPPING][channel_id] = JSON.parse_string(FileAccess.get_file_as_string(filename))["badge_sets"]
		else:
			var request: HTTPRequest = HTTPRequest.new()
			add_child(request)
			request.request("https://api.twitch.tv/helix/chat/badges" + ("/global" if channel_id == "_global" else "?broadcaster_id=" + channel_id), [USER_AGENT, "Authorization: Bearer " + token["access_token"], "Client-Id:" + client_id, "Content-Type: application/json"], HTTPClient.METHOD_GET)
			var reply: Array = await (request.request_completed)
			var response: Dictionary = JSON.parse_string(reply[3].get_string_from_utf8())
			var mappings: Dictionary = {}
			for entry in response["data"]:
				if (!mappings.has(entry["set_id"])):
					mappings[entry["set_id"]] = {"versions": {}}
				for version in entry["versions"]:
					mappings[entry["set_id"]]["versions"][version["id"]] = version
			request.queue_free()
			if (reply[1] == HTTPClient.RESPONSE_OK):
				caches[RequestType.BADGE_MAPPING][channel_id] = mappings
				if (disk_cache):
					DirAccess.make_dir_recursive_absolute(filename.get_base_dir())
					var file: FileAccess = FileAccess.open(filename, FileAccess.WRITE)
					file.store_string(JSON.stringify(mappings))
			else:
				print("Could not retrieve badge mapping for channel_id " + channel_id + ".")
				return {}
	return caches[RequestType.BADGE_MAPPING][channel_id]

func data_received(data: PackedByteArray) -> void:
	var messages: PackedStringArray = data.get_string_from_utf8().strip_edges(false).split("\r\n")
	var tags = {}
	for message in messages:
		if (message.begins_with("@")):
			var msg: PackedStringArray = message.split(" ", false, 1)
			message = msg[1]
			for tag in msg[0].split(";"):
				var pair = tag.split("=")
				tags[pair[0]] = pair[1]
		if (OS.is_debug_build()):
			print("> " + message)
		handle_message(message, tags)

# Registers a command on an object with a func to call, similar to connect(signal, instance, func).
func add_command(cmd_name: String, callable: Callable, max_args: int=0, min_args: int=0, permission_level: int=PermissionFlag.EVERYONE, where: int=WhereFlag.CHAT) -> void:
	commands[cmd_name] = CommandData.new(callable, permission_level, max_args, min_args, where)

# Removes a single command or alias.
func remove_command(cmd_name: String) -> void:
	commands.erase(cmd_name)

# Removes a command and all associated aliases.
func purge_command(cmd_name: String) -> void:
	var to_remove = commands.get(cmd_name)
	if (to_remove):
		var remove_queue = []
		for command in commands.keys():
			if (commands[command].func_ref == to_remove.func_ref):
				remove_queue.append(command)
		for queued in remove_queue:
			commands.erase(queued)

func add_alias(cmd_name: String, alias: String) -> void:
	if (commands.has(cmd_name)):
		commands[alias] = commands.get(cmd_name)

func add_aliases(cmd_name: String, aliases: PackedStringArray) -> void:
	for alias in aliases:
		add_alias(cmd_name, alias)

func handle_message(message: String, tags: Dictionary) -> void:
	if (message == "PING :tmi.twitch.tv"):
		send("PONG :tmi.twitch.tv")
		pong.emit()
		return
	var msg: PackedStringArray = message.split(" ", true, 3)
	match msg[1]:
		"NOTICE":
			var info: String = msg[3].right( - 1)
			if (info == "Login authentication failed"||info == "Login unsuccessful"):
				print_debug("Authentication failed.")
				login_attempt.emit(false)
			elif (info == "You don't have permission to perform that action"):
				print_debug("No permission. Check if access token is still valid. Aborting.")
				user_token_invalid.emit()
				set_process(false)
			else:
				unhandled_message.emit(message, tags)
		"001":
			print_debug("Authentication successful.")
			login_attempt.emit(true)
		"PRIVMSG":
			var sender_data: SenderData = SenderData.new(user_regex.search(msg[0]).get_string(), msg[2], tags)
			handle_command(sender_data, msg[3].split(" ", true, 1))
			chat_message.emit(sender_data, msg[3].right( - 1))
		"WHISPER":
			var sender_data: SenderData = SenderData.new(user_regex.search(msg[0]).get_string(), msg[2], tags)
			handle_command(sender_data, msg[3].split(" ", true, 1), true)
			whisper_message.emit(sender_data, msg[3].right( - 1))
		"RECONNECT":
			twitch_restarting = true
		"USERSTATE", "ROOMSTATE":
			var room = msg[2].right( - 1)
			if (!last_state.has(room)):
				last_state[room] = tags
			else:
				for key in tags:
					last_state[room][key] = tags[key]
		#### ADDED BY ME, MRELIPTIK
		"JOIN":
			var sender_data: SenderData = SenderData.new(user_regex.search(msg[0]).get_string(), msg[2], tags)
			user_joined_chat.emit(sender_data)
		"PART":
			var sender_data: SenderData = SenderData.new(user_regex.search(msg[0]).get_string(), msg[2], tags)
			user_left_chat.emit(sender_data)
		_:
			unhandled_message.emit(message, tags)

func handle_command(sender_data: SenderData, msg: PackedStringArray, whisper: bool=false) -> void:
	if (command_prefixes.has(msg[0].substr(1, 1))):
		var command: String = msg[0].right( - 2)
		var cmd_data: CommandData = commands.get(command)
		if (cmd_data):
			if (whisper == true&&cmd_data.where&WhereFlag.WHISPER != WhereFlag.WHISPER):
				return
			elif (whisper == false&&cmd_data.where&WhereFlag.CHAT != WhereFlag.CHAT):
				return
			var args = "" if msg.size() == 1 else msg[1]
			var arg_ary: PackedStringArray = PackedStringArray() if args == "" else args.split(" ")
			if (arg_ary.size() > cmd_data.max_args&&cmd_data.max_args != - 1||arg_ary.size() < cmd_data.min_args):
				cmd_invalid_argcount.emit(command, sender_data, cmd_data, arg_ary)
				print_debug("Invalid argcount!")
				return
			if (cmd_data.permission_level != 0):
				var user_perm_flags = get_perm_flag_from_tags(sender_data.tags)
				if (user_perm_flags&cmd_data.permission_level == 0):
					cmd_no_permission.emit(command, sender_data, cmd_data, arg_ary)
					print_debug("No Permission for command!")
					return

			if arg_ary.size() < 1 and cmd_data.max_args < 1:
				cmd_data.func_ref.call(CommandInfo.new(sender_data, command, whisper))
			else:
				cmd_data.func_ref.call(CommandInfo.new(sender_data, command, whisper), arg_ary)

func get_perm_flag_from_tags(tags: Dictionary) -> int:
	var flag = 0
	var entry = tags.get("badges")
	if (entry):
		for badge in entry.split(","):
			if (badge.begins_with("vip")):
				flag += PermissionFlag.VIP
			if (badge.begins_with("broadcaster")):
				flag += PermissionFlag.STREAMER
	entry = tags.get("mod")
	if (entry):
		if (entry == "1"):
			flag += PermissionFlag.MOD
	entry = tags.get("subscriber")
	if (entry):
		if (entry == "1"):
			flag += PermissionFlag.SUB
	return flag

func join_channel(channel: String) -> void:
	var lower_channel: String = channel.to_lower()
	channels[lower_channel] = {}
	send("JOIN #" + lower_channel)

func leave_channel(channel: String) -> void:
	var lower_channel: String = channel.to_lower()
	send("PART #" + lower_channel)
	channels.erase(lower_channel)
