extends TextureButton

@export var menu_packed_scene: PackedScene = load("res://scenes/ui/selection.tscn")

func _on_pressed():
	Transition.show_transition()
	await Transition.done
	get_tree().change_scene_to_packed(menu_packed_scene)
