extends PanelContainer

@export var game_node: JackieCodesGame

var viewer_name: String = ""

func _ready():
	_on_jail_time_value_changed(%JailTime.value)

func _on_input_name_text_changed(new_text):
	viewer_name = new_text

func _on_imprison_pressed():
	game_node.set_imprisoned(viewer_name, true)

func _on_free_pressed():
	game_node.set_imprisoned(viewer_name, false)

func _on_add_gifter_pressed():
	game_node.set_gifter(viewer_name, true)

func _on_remove_gifter_pressed():
	game_node.set_gifter(viewer_name, false)

func _on_button_set_moderator_pressed():
	game_node.set_moderator(viewer_name, true)

func _on_button_set_not_moderator_pressed():
	game_node.set_moderator(viewer_name, false)

func _on_add_top_pressed():
	game_node.set_top(viewer_name, true)

func _on_remove_top_pressed():
	game_node.set_top(viewer_name, false)

func _on_clear_gone_pressed():
	game_node.clear_viewers(false)

func _on_clear_all_pressed():
	game_node.clear_viewers(true)

func _on_jail_time_value_changed(value: float) -> void:
	var minutes = int(value)
	game_node.jail_time_seconds = minutes * 60
