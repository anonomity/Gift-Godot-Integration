extends TextureButton

@export var menu_packed_scene: PackedScene = load("res://scenes/ui/selection.tscn")

signal scene_changing()

func _on_pressed():
	scene_changing.emit()
	SceneSwitcher.change_scene_to(menu_packed_scene, true)
