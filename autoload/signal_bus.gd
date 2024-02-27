extends Node

signal scene_changed(current_scene_name: String)
signal scene_changing(next_scene_name: String)
signal transparency_toggled(transparent: bool)
signal ui_visibility_toggled(ui_visible: bool)

var transparent_bg: bool:
	get:
		return get_viewport().transparent_bg

var ui_visible: bool = true

func _ready():
	SignalBus.scene_changed.connect(on_scene_changed)
	SignalBus.scene_changing.connect(on_scene_changing)
	SignalBus.transparency_toggled.connect(on_transparency_toggled)
	SignalBus.ui_visibility_toggled.connect(on_ui_visibility_toggled)

func _process(delta):
	if Input.is_action_just_pressed("transparent"):
		var will_be_transparent = not get_viewport().transparent_bg
		print_debug("Setting background to %s" % ["transparent" if will_be_transparent else "opaque"])
		SignalBus.emit_transparency_toggled(will_be_transparent)
	
	if Input.is_action_just_pressed("toggle_ui"):
		var ui_visibility = !ui_visible
		print_debug("Setting UI elements to be %s" %["visible" if ui_visibility else "hidden"])
		SignalBus.emit_ui_visibility_toggled(ui_visibility)

func emit_scene_changed(current_scene_name: String) -> void:
	scene_changed.emit(current_scene_name)

func on_scene_changed(current_scene_name: String) -> void:
	print("Changed scene to %s" % [current_scene_name])

func emit_scene_changing(next_scene_name: String) -> void:
	scene_changing.emit(next_scene_name)

func on_scene_changing(next_scene_name: String) -> void:
	print("Changing scene to %s" % [next_scene_name])

func emit_transparency_toggled(transparent: bool) -> void:
	transparency_toggled.emit(transparent)

func on_transparency_toggled(transparent: bool) -> void:
	get_viewport().transparent_bg = transparent
	GameConfigManager.save_config()
	for node in get_tree().get_nodes_in_group("Background"):
		node.visible = not transparent

func emit_ui_visibility_toggled(ui_visible: bool) -> void:
	self.ui_visible = ui_visible
	ui_visibility_toggled.emit(self.ui_visible)

func on_ui_visibility_toggled(ui_visible: bool):
	self.ui_visible = ui_visible
