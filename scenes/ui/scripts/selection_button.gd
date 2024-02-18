extends Button

@onready var button_icon: TextureRect = %Icon

var game_name: String = "Game name":
	set(value):
		game_name = value
		%Label.text = game_name

var scene_path: String:
	set(value):
		scene_path = value
		scene = load(scene_path)

var icon_scene: PackedScene:
	set(value):
		if value == icon_scene:
			return

		icon_scene = value
		_use_icon_scene()

var icon_scene_node: Node
var icon_texture
var scene: PackedScene
var tween: Tween

func _ready() -> void:
	if icon_texture:
		button_icon.texture = icon_texture
	if icon_scene:
		_use_icon_scene(false)

func _use_icon_scene(recreate: bool = true) -> void:
	if icon_scene_node and recreate:
		remove_child(icon_scene_node)

	if not icon_scene:
		button_icon.visible = true
		return

	if not button_icon:
		return

	button_icon.visible = false

	if icon_scene_node and not recreate:
		return

	icon_scene_node = icon_scene.instantiate()
	button_icon.add_sibling(icon_scene_node)

func focus_on() -> void:
	pivot_offset = size / 2.0
	if tween and tween.is_running():
		tween.kill()
	tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "scale", Vector2(1, 1), 0.2)

func focus_off() -> void:
	pivot_offset = size / 2.0
	if tween and tween.is_running():
		tween.kill()
	tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(self, "scale", Vector2.ONE, 0.2)

func _on_mouse_entered():
	focus_on()

func _on_mouse_exited():
	focus_off()

func _on_focus_entered():
	focus_on()

func _on_focus_exited():
	focus_off()
