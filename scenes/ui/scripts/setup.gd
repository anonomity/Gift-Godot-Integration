extends Control

const SCENE_SELECTION: PackedScene = preload ("res://scenes/ui/selection.tscn")

@onready var client_id_edit: LineEdit = %ClientIdEdit
@onready var client_secret_edit: LineEdit = %ClientSecretEdit

@onready var client_id_error: Label = %ClientIdError
@onready var client_secret_error: Label = %ClientSecretError

@onready var cancel_button: Button = %ButtonCancel

var error_count: int = 2
var force_show_errors: bool = false

func _ready() -> void:
	var has_configuration = GiftSingleton.load_configuration()
	%ButtonCancel.visible = has_configuration

	if has_configuration:
		client_id_edit.text = GiftSingleton.client_id
		client_secret_edit.text = GiftSingleton.client_secret

	if client_id_edit.text.length() > 0:
		validate_client_id()

	if client_secret_edit.text.length() > 0:
		validate_client_secret()

	_synchronize_buttons()

func validate_text(le: LineEdit, min_length: int=32) -> bool:
	var stripped = le.text.strip_edges()
	if stripped.length() != le.text.length():
		var current_index = le.caret_column
		le.text = stripped
		le.caret_column = min(current_index, stripped.length())
	return is_not_empty(le)&&is_min_length(le, min_length)&&is_alphanumeric(le)

func is_alphanumeric(control: LineEdit) -> bool:
	var regex = RegEx.create_from_string("[^a-zA-Z0-9]+")
	var result = regex.search(control.text)
	return result == null

func is_not_empty(control: LineEdit) -> bool:
	return !control.text.is_empty()

func is_min_length(control: LineEdit, min_length: int=5) -> bool:
	return control.text.length() >= min_length

func _on_show_client_secret_pressed():
	client_secret_edit.secret = not client_secret_edit.secret

func _on_show_client_id_pressed():
	client_id_edit.secret = not client_id_edit.secret

func _on_button_save_pressed() -> void:
	%LoadingModal.status_message = "Validating configuration"
	%LoadingModalContainer.visible = true

	var validation_message = await GiftSingleton.validate_developer_integration(
		client_id_edit.text,
		client_secret_edit.text
	)

	%LoadingModalContainer.visible = false

	%ClientCredentialsValidationError.visible = validation_message != ""

	if validation_message:
		%ClientCredentialsValidationError.text = "Error validating client id/secret: %s" % [validation_message]
		return

	GameConfigManager.config_manager.create_configuration({
		"twitch_auth": {
			"client_id": client_id_edit.text,
			"client_secret": client_secret_edit.text
		}
	})

	SignalBus.emit_developer_integration_configured(true)

func _on_button_cancel_pressed() -> void:
	if !GiftSingleton.has_config:
		return

	SignalBus.emit_developer_integration_configured(true)

func _on_client_id_edit_text_changed(new_text: String) -> void:
	force_show_errors = true
	validate_client_id()
	_synchronize_buttons()

func _on_client_secret_edit_text_changed(new_text: String) -> void:
	force_show_errors = true
	validate_client_secret()
	_synchronize_buttons()

func _synchronize_buttons() -> void:
	%ButtonSave.disabled = error_count > 0

func validate_client_id() -> void:
	error_count -= 1
	var is_valid = validate_text(client_id_edit, 30)
	if is_valid:
		client_id_error.visible = false
		return

	error_count += 1
	client_id_error.visible = client_secret_edit.text.length() > 0 or force_show_errors
	client_id_error.text = "Must have 30 chars, only numbers and chars"

func validate_client_secret() -> void:
	error_count -= 1
	var is_valid = validate_text(client_secret_edit, 30)
	if is_valid:
		client_secret_error.visible = false
		return

	error_count += 1
	client_secret_error.visible = client_secret_edit.text.length() > 0 or force_show_errors
	client_secret_error.text = "Must have 30 chars, only numbers and chars"
