class_name WindowSettings
extends Window

func _init() -> void:
	visible = false

func _on_close_requested() -> void:
	hide()

func _on_visibility_changed() -> void:
	_on_configuration_tabs_tab_changed(%Tabs.current_tab)

func _on_configuration_tabs_tab_changed(tab_index: int):
	var tab = %Tabs.get_tab_control(tab_index)
	if not tab is Control:
		return

	if tab.has_method("handle_tab_selected"):
		tab.handle_tab_selected()
