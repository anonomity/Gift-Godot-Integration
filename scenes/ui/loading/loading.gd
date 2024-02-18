@tool
class_name LoadingScreen
extends Control

@export var ellipsis: String = "...":
	set(value):
		if value == ellipsis:
			return

		ellipsis = value

## Characters per second
@export var ellipsis_animation_rate: float = 2.0

@export var is_modal: bool = false:
	set(value):
		if value == is_modal:
			return

		is_modal = value
		_synchronize_is_modal()

@export var status_message: String = "Loading":
	set(value):
		if value == status_message:
			return

		status_message = value

		call_deferred("_synchronize_status_message")

@onready var label_status: Label = %LabelStatus
@onready var label_animated_ellipsis: Label

var progress: float = 0.0

func _ready() -> void:
	label_animated_ellipsis = %LabelEllipsis.duplicate()
	label_animated_ellipsis.self_modulate = Color.WHITE
	%EllipsisContainer.add_child(label_animated_ellipsis)

	if get_tree().current_scene == self:
		SignalBus.emit_loading_scene_ready()

	_synchronize_is_modal()
	_synchronize_status_message()

	label_animated_ellipsis.text = ""

func _synchronize_is_modal() -> void:
	if %Background:
		%Background.visible = !is_modal
	if %TextureLogo:
		%TextureLogo.visible = !is_modal
	if %LabelAppTitle:
		%LabelAppTitle.visible = !is_modal

func _synchronize_status_message() -> void:
	if label_status:
		label_status.text = status_message

func _process(delta: float) -> void:
	if not ellipsis:
		return

	progress = fmod(progress + delta * ellipsis_animation_rate, ellipsis.length() + 0.75)
	label_animated_ellipsis.text = ellipsis.substr(0, int(floor(0.25 + progress)))
