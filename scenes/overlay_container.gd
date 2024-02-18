extends Control

var previous_input_state: Dictionary = {}

func _on_child_entered_tree(node: Node):
	if not node is Control:
		return

	var control = node as Control
	previous_input_state[control] = control.mouse_filter
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _on_child_exiting_tree(node: Node):
	if not node is Control:
		return

	var control = node as Control
	if not previous_input_state.has(control):
		return

	control.mouse_filter = previous_input_state[control]
