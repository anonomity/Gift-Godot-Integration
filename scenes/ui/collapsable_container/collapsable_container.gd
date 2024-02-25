@tool
class_name CollapsableContainer extends VBoxContainer

@export var expanded: bool = true:
	get:
		return expanded
	set(value):
		if expanded == value:
			return
		expanded = value
		_synchronize_expanded()
		
@export var title: String = "Collapsable Container":
	get:
		return title
	set(value):
		if title == value:
			return
		title = value
		_synchronize_title()

@onready var titlebar: Container = $Titlebar
@onready var label_title: Label = $Titlebar/Margin/TitlebarItems/Title
@onready var collapse_trigger: BaseButton = $Titlebar/Margin/TitlebarItems/CollapseRegion/Trigger

func _synchronize_expanded():
	if collapse_trigger:
		collapse_trigger.rotation_degrees = 90 if expanded else 0
	var children = get_children()
	for child in children:
		if child != titlebar:
			child.visible = expanded

func _synchronize_title():
	if label_title:
		label_title.text = title

func _ready():
	_synchronize_expanded()
	_synchronize_title()

func _on_trigger_pressed():
	expanded = !expanded


func _on_titlebar_gui_input(event):
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		_on_trigger_pressed()
