extends MarginContainer

const CannonGame = preload("res://scenes/games/cannon/cannon.gd")

@export var scene_node: CannonGame:
	set(value):
		if value == scene_node:
			return

		scene_node = value
		_synchronize_to_scene()

func _ready() -> void:
	_synchronize_to_scene()

func _synchronize_to_scene() -> void:
	if not scene_node:
		return

	if %ToggleAutostart:
		%ToggleAutostart.button_pressed = scene_node.autostart

func _on_button_reset_leaderboard_pressed() -> void:
	if scene_node:
		scene_node.leaderboard.clear()

func _on_toggle_autostart_toggled(toggled_on: bool) -> void:
	if scene_node:
		scene_node.autostart = toggled_on
