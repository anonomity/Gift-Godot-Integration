class_name SelectionMenu extends Control

@onready var button_container = %ButtonContainer
@onready var status_value: Label = %StatusValue
@onready var games: Array = GamesManager.new().get_games()
@onready var update_checker := UpdateChecker.new()

var button_scene = preload("res://scenes/ui/selection_button.tscn")

# TODO: move to translation file later
var status_messages = {
	NONE = tr("GiftSingleton.STATUS.NONE"),
	INIT = tr("GiftSingleton.STATUS.INIT"),
	AUTH_START = tr("GiftSingleton.STATUS.AUTH_START"),
	AUTH_FILE_NOT_FOUND = tr("GiftSingleton.STATUS.AUTH_FILE_NOT_FOUND"),
	CONNECTION_FAILED = tr("GiftSingleton.STATUS.CONNECTION_FAILED"),
	CONNECTING = tr("GiftSingleton.STATUS.CONNECTING"),
	CONNECTED = tr("GiftSingleton.STATUS.CONNECTED"),
	DISCONNECTED = tr("GiftSingleton.STATUS.DISCONNECTED"),
}

func _ready() -> void:
	GameConfigManager.load_config()
	Viewers.close()

	%LabelCurrentVersion.text = "v%s" % [ProjectSettings.get_setting("application/config/version")]

	add_child(update_checker)
	update_checker.get_latest_version()
	update_checker.release_parsed.connect(on_released_parsed)

	GiftSingleton.remove_game_commands()
	GiftSingleton.status.connect(on_status_changed)

	%ButtonReconnect.text = GiftSingleton.user_display_name

	# when we connect to late to get the last status, we pull the last status that was emited
	if GiftSingleton.last_status != GiftSingleton.STATUS.NONE:
		on_status_changed(GiftSingleton.last_status)

	# delete buttons - we need them only for layouting
	for c in button_container.get_children():
		c.queue_free()

	for game_config in games:
		var game_button = button_scene.instantiate()
		game_button.game_name = game_config.name
		game_button.scene_path = game_config.scene_path
		game_button.icon_scene = game_config.icon_scene if game_config.has("icon_scene") else null
		game_button.icon_texture = game_config.icon if game_config.has("icon") else null
		button_container.add_child(game_button)

		game_button.pressed.connect(on_btn_pressed.bind(game_button.scene))

	Transition.hide_transition()

func on_btn_pressed(scene: PackedScene) -> void:
	GameConfigManager.save_config()
	
	SceneSwitcher.change_scene_to(scene, true)

func on_status_changed(status_id: int) -> void:
	status_value.text = status_messages[GiftSingleton.STATUS.keys()[status_id]]

func on_released_parsed(release: Dictionary) -> void:
	print("Latest release: ", release["version"])

	if release["new"]:
		%ButtonVersion.text = "New version available: %s" % [release["version"]]
	else:
		%ButtonVersion.text = "You have the latest version!"
	%ButtonVersion.uri = release["url"]

func _on_button_reconnect_pressed() -> void:
	%LoadingModal.status_message = "Reconnecting to Twitch"
	%LoadingModalContainer.visible = true

	var previous_user_login = GiftSingleton.user_login
	var authentication_result = await GiftSingleton.authenticate(true)
	if authentication_result:
		if GiftSingleton.user_login == previous_user_login:
			print("Reconnected with the same user, no need to restart GIFT")
			$LoadingModalContainer.visible = false
			return
		else:
			# Ideally we do not have to restart, but this was not working :shrug:
			%RestartModalContainer.visible = true
			#GiftSingleton.stop("Reconnecting with a different user")
			#SceneSwitcher.change_scene_to(load("res://scenes/boot.tscn"))
	else:
		assert(false, "Error during reconnection")

func _on_button_shutdown_pressed() -> void:
	get_tree().quit()

func _on_button_open_settings_pressed() -> void:
	WindowConfigureChannelPoints.show()
	WindowConfigureChannelPoints.grab_focus()
