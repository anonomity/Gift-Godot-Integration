extends Control

@onready var config_manager:ConfigManager = ConfigManager.new()

@onready var client_id_edit: LineEdit = %ClientIdEdit
@onready var client_secret_edit: LineEdit = %ClientSecretEdit
@onready var channel_edit: LineEdit = %ChannelEdit

@onready var client_id_error: Label = %ClientIdError
@onready var client_secret_error: Label = %ClientSecretError
@onready var channel_error: Label = %ChannelError

@onready var cancel_button: Button = %CancelButton

var selection_scene: PackedScene = preload("res://scenes/ui/selection.tscn")

func _ready() -> void:
	client_id_error.text = ""
	client_secret_error.text = ""
	channel_error.text = ""
	
	%CancelButton.visible = GiftSingleton.has_config
	
	var existing_config = config_manager.data
	if existing_config and existing_config.has("twitch_auth"):
		var twitch_auth = existing_config["twitch_auth"]
		client_id_edit.text = twitch_auth["client_id"] if twitch_auth.has("client_id") else ""
		client_secret_edit.text = twitch_auth["client_secret"] if twitch_auth.has("client_secret") else ""
		channel_edit.text = twitch_auth["initial_channel"] if twitch_auth.has("initial_channel") else ""

func validate_text(le: LineEdit, min_length: int = 32) -> bool:
	return is_not_empty(le) && is_min_length(le, min_length) && is_alphanumeric(le)

func is_alphanumeric(control: LineEdit) -> bool:
	var regex = RegEx.create_from_string("[^a-zA-Z0-9]+")
	var result = regex.search(control.text)
	return result == null

func is_not_empty(control: LineEdit) -> bool:
	return !control.text.is_empty()

func is_min_length(control: LineEdit, min_length: int = 5) -> bool:
	return control.text.length() >= min_length

func _on_show_channel_pressed():
	channel_edit.secret = not channel_edit.secret

func _on_show_client_secret_pressed():
	client_secret_edit.secret = not client_secret_edit.secret

func _on_show_client_id_pressed():
	client_id_edit.secret = not client_id_edit.secret

func _on_cancel_button_pressed():
	if !GiftSingleton.has_config:
		return

	get_tree().change_scene_to_packed(selection_scene)

func _on_create_button_pressed():
	var has_errors: bool = false

	if not validate_text(client_id_edit, 30):
		client_id_error.text = "Must have 30 chars, only numbers and chars"
		has_errors = true
	else:
		client_id_error.text = " "

	if not validate_text(client_secret_edit, 30):
		client_secret_error.text = "Must have 30 chars, only numbers and chars"
		has_errors = true
	else:
		client_secret_error.text = " "


	if not validate_text(channel_edit, 0):
		channel_error.text = "Channel is invalid"
		has_errors = true
	else:
		channel_error.text = " "

	if has_errors:
		return

	config_manager.create_configuration({
		"twitch_auth": {
			"client_id": client_id_edit.text,
			"client_secret": client_secret_edit.text,
			"initial_channel": channel_edit.text
		}
	})

	GiftSingleton.start()
	get_tree().change_scene_to_packed(selection_scene)
