extends Node2D

@export var marble: PackedScene = preload("res://scenes/marble/marble.tscn")

@onready var viewer_container: Node2D = $ViewerContainer
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var node_ui = $UI

var viewers: Dictionary = {}

func _ready() -> void:
	GameConfigManager.load_config()

	SignalBus.ui_visibility_toggled.connect(_on_ui_visibility_toggled)

	GiftSingleton.viewer_joined.connect(on_viewer_joined)
	GiftSingleton.viewer_left.connect(on_viewer_left)
	GiftSingleton.user_left_chat.connect(on_viewer_left_chat)

	Transition.hide_transition()

	var active_viewers = GiftSingleton.active_viewers
	for viewer in active_viewers:
		spawn_viewer(viewer)

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_accept"):
		animation_player.play("move")

	if Input.is_action_just_pressed("ui_cancel"):
		GameConfigManager.save_config()
		SceneSwitcher.change_scene_to(SceneSwitcher.selection_scene, true, null)

func spawn_viewer(viewer_name: String) -> void:
	if viewer_container.has_node(viewer_name): return

	var instance = marble.instantiate()
	instance.name = viewer_name
	instance.viewer_name = viewer_name
	viewer_container.call_deferred("add_child", instance)
	viewers[viewer_name] = instance

	await instance.ready
	push_marble(instance)

func remove_viewer(viewer_name: String) -> void:
	if not Viewers.is_joined(viewer_name): return
	
	if viewers.has(viewer_name):
		viewers.erase(viewer_name)

	for child in viewer_container.get_children():
		if child.viewer_name != viewer_name: continue
		child.queue_free()

func push_marble(obj: RigidBody2D) -> void:
	var push_vec: Vector2 = obj.global_transform.x.rotated(deg_to_rad(randi_range(0, 360)))
	push_vec *= 100.0
	obj.apply_central_impulse(push_vec)

##### SIGNALS #####
func on_viewer_joined(viewer_name: String, color: String) -> void:
	spawn_viewer(viewer_name)

func on_viewer_left(viewer_name: String) -> void:
	remove_viewer(viewer_name)

func on_viewer_left_chat(sender_data: SenderData) -> void:
	remove_viewer(sender_data.user)

func _on_navigate_to_menu_button_scene_changing():
	print("Leaving %s scene with %d viewers" % [
		get_tree().current_scene.scene_file_path.get_file().get_basename(),
		GiftSingleton.active_viewers.size()
	])

func _on_ui_visibility_toggled(ui_visible: bool):
	node_ui.visible = ui_visible
