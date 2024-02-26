extends PanelContainer

@export var game_node: JackieCodesGame

var viewer_name: String = ""

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
