extends Window

@onready var background: Control = $Background
@onready var console: AdminWindowConsole = $Contents/ContentScroller/Items/CollapsableConsole/Console
@onready var debug_menu: AdminWindowDebugMenu = $Contents/ContentScroller/Items/CollapsableDebugMenu/DebugMenu

func _init() -> void:
	visible = false

func _enter_tree() -> void:
	SignalBus.scene_changed.connect(_on_scene_changed)
	SignalBus.transparency_toggled.connect(_on_transparency_toggled)
	SignalBus.ui_visibility_toggled.connect(_on_ui_visibility_toggled)

func _exit_tree() -> void:
	SignalBus.scene_changed.disconnect(_on_scene_changed)
	SignalBus.transparency_toggled.disconnect(_on_transparency_toggled)
	SignalBus.ui_visibility_toggled.disconnect(_on_ui_visibility_toggled)

func _process(delta):
	if Input.is_action_just_pressed("admin"):
		if visible:
			hide()
		else:
			show()
		console.focus_input(visible)

## SIGNALS
func _on_close_requested():
	hide()
	console.focus_input(false)
	debug_menu.save_preferences()

func _on_focus_exited():
	if background:
		background.visible = false

func _on_focus_entered():
	if background:
		background.visible = true

func _on_scene_changed(current_scene_name: String):
	%ToggleBackgroundTransparency.button_pressed = SignalBus.transparent_bg
	%ToggleUIVisibility.button_pressed = SignalBus.ui_visible
	
	_add_scene_specific_submenu(current_scene_name)

func _add_scene_specific_submenu(current_scene_name: String):
	var existing_panels = %SceneMenu.find_children("*-admin_menu_scene", "", false, false)
	var c = %SceneMenu.get_children().map(func (node: Node): return node.name)
	print("nodes: %s" % [c])
	print("existing_panels: %s" % [existing_panels.map(func (node: Node): return node.name)])
	for existing_panel in existing_panels:
		%SceneMenu.remove_child.call_deferred(existing_panel)

	var current_scene = get_tree().current_scene
	if not current_scene:
		return

	var admin_menu_node_name = "%s-admin_menu_scene" % [current_scene_name]

	if not "admin_menu_scene" in current_scene:
		return

	var admin_menu_packed_scene = current_scene.admin_menu_scene as PackedScene
	if not admin_menu_packed_scene:
		return

	var admin_menu_instance = admin_menu_packed_scene.instantiate()
	admin_menu_instance.name = admin_menu_node_name
	
	if "scene_node" in admin_menu_instance:
		admin_menu_instance.scene_node = current_scene
	
	%SceneMenu.add_child(admin_menu_instance)

func _on_transparency_toggled(transparent: bool):
	%ToggleBackgroundTransparency.button_pressed = transparent

func _on_toggle_background_transparency_toggled(toggled_on: bool) -> void:
	SignalBus.toggle_transparency(toggled_on)

func _on_ui_visibility_toggled(ui_visibility: bool):
	%ToggleUIVisibility.button_pressed = ui_visibility

func _on_toggle_ui_visibility_toggled(toggled_on: bool) -> void:
	SignalBus.toggle_ui_visibility(toggled_on)
