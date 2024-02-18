extends Control

const SCENE_SETUP: PackedScene = preload("res://scenes/ui/setup.tscn")
const SCENE_GAME_SELECTION: PackedScene = preload("res://scenes/ui/selection.tscn")

func _init() -> void:
	DisplayServer.window_set_title("Godot Twitch Games")

func _ready() -> void:
	SceneSwitcher.run_with_loading_screen.call_deferred(_check_developer_integration_configuration)

static func _check_developer_integration_configuration(loading_screen: LoadingScreen) -> void:
	loading_screen.status_message = "Checking configuration"
	_wait_for_developer_integration_configuration.call_deferred()

static func _wait_for_developer_integration_configuration() -> void:
	GiftSingleton.emit_status(GiftSingleton.STATUS.INIT)

	if GiftSingleton.load_configuration():
		var validation_error_message = await GiftSingleton.validate_developer_integration(
			GiftSingleton.client_id,
			GiftSingleton.client_secret
		)
		if validation_error_message:
			printerr(
				"Failed to validate developer integration configuration, opening setup: %s" % [
				validation_error_message
			])
		else:
			print("Developer integration configuration validated successfully")
			SceneSwitcher.run_with_loading_screen.call_deferred(_check_authentication)
			return
	
	SceneSwitcher.change_scene_to(SCENE_SETUP)
	var success = await SignalBus.developer_integration_configured
	assert(success, "The application is not correctly configured and cannot start")

	SceneSwitcher.run_with_loading_screen.call_deferred(_check_developer_integration_configuration)

static func _check_authentication(loading_screen: LoadingScreen) -> void:
	loading_screen.status_message = "Authenticating"
	_wait_for_authentication.call_deferred(loading_screen)

static func _wait_for_authentication(loading_screen: LoadingScreen) -> void:
	GiftSingleton.emit_status(GiftSingleton.STATUS.AUTH_START)

	for attempt in range(0, 3):
		if await GiftSingleton.authenticate():
			_start_gift(loading_screen)
			return

	# Perhaps with a modal?
	assert(false, "Unable to authenticate, this should be handled more gracefully in the future")

static func _start_gift(loading_screen: LoadingScreen) -> void:
	loading_screen.status_message = "Connecting to Twitch"
	if await GiftSingleton.start():
		SceneSwitcher.change_scene_to(SCENE_GAME_SELECTION)
		return

	# Perhaps with a modal?
	assert(false, "Unable to start GIFT, this should be handled more gracefully in the future")
