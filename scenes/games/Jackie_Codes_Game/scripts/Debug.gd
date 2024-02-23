extends CanvasLayer


@export var game_node : Node2D
var text = ""



func _on_line_edit_text_changed(new_text):
	text = new_text


func _on_button_pressed():
	game_node.add_to_gift_array(text)


func _on_button_2_pressed():
	print("button")
	game_node.add_degen_to_prison_array(text)
