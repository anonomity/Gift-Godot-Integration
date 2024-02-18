@tool
class_name AdminWindowConsole
extends MarginContainer

@onready var output: TextEdit = %Output
@onready var input: LineEdit = %CommandInput

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass


func _on_send_button_pressed():
	send(input.text)
	input.text = ""

func autocomplete(typed: String) -> void:
	var command_dict: Dictionary = {}
	
	for key in command_dict.keys():
		# pou "poured, froum"
		if typed in command_dict[key]:
			# TODO: count how much in common with typed
			pass
			
	return 

func send(content: String) -> void:
	output.insert_line_at(output.get_line_count() - 1, content)
	
	# TODO: call command singleton with the content and listen to response

func focus_input(focus = true):
	if focus:
		input.grab_focus()
	else:
		input.release_focus()


func _on_command_input_text_submitted(new_text):
	send(new_text)
	input.text = ""
