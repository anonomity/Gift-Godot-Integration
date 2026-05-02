extends CanvasLayer

signal done()

@export var shown: bool = false

@onready var animation_player = $AnimationPlayer

func show_transition() -> void:
	if shown:
		print_debug("Transition already shown")
		return

	print_verbose("Showing transition")
	animation_player.play("show")

func hide_transition() -> void:
	if not shown:
		print_debug("Transition already shown")
		return

	print_verbose("Hiding transition")
	animation_player.play("hide")
