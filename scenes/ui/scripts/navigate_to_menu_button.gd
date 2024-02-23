extends TextureButton

@export var menu_packed_scene: PackedScene = load("res://scenes/ui/selection.tscn")

signal scene_changing()

func _on_pressed():
	print("button")
	Transition.show_transition()
	await Transition.done
	scene_changing.emit()
	get_tree().change_scene_to_packed(menu_packed_scene)
