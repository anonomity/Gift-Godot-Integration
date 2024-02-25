extends Window

@onready var background: Control = $Background
@onready var console: AdminWindowConsole = $Contents/ContentScroller/Items/CollapsableConsole/Console
@onready var debug_menu: AdminWindowDebugMenu = $Contents/ContentScroller/Items/CollapsableDebugMenu/DebugMenu

func _ready():
	hide()

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
