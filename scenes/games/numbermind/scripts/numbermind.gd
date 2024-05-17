extends Node2D

@onready var results = %Results
@onready var instructions = %Instructions
@onready var node_ui = $UI

var secret: String
var length: int = 4
var active: bool = false

func _ready():
	GameConfigManager.load_config()

	SignalBus.ui_visibility_toggled.connect(_on_ui_visibility_toggled)

	GiftSingleton.add_game_command("guess", on_guess_made, 1, 1)

	reset()
	Transition.hide_transition()

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_cancel"):
		GameConfigManager.save_config()
		SceneSwitcher.change_scene_to(SceneSwitcher.selection_scene, true, null)

func reset():
	secret = ""
	for i in range(length):
		secret += str(randi_range(0, 10))
	active = true
	results.clear()
	results.append_text("A new round has started! – The code is %d digits long!\n" % length)
	instructions.text = "Use \"!guess 123456\" to make a guess! – The code is %d digits long!\n" % length

func run_guess(viewer: String, guess: String) -> void:
	var res: String = ""
	var correct: int = 0

	print("length: %d" % len(guess))

	for c in guess:
		if not c in "0123456789":
			results.append_text("[b]%s:[/b]\t<Invalid Guess>\n" % viewer)
			results.scroll_to_line(results.get_line_count())
			return

	for i in min(len(secret), len(guess)):
		if guess[i] == secret[i]:
			res += "[color=green]%s[/color]" % guess[i]
			correct += 1
		elif guess[i] in secret:
			res += "[color=yellow]%s[/color]" % guess[i]
		else:
			res += "[color=red]%s[/color]" % guess[i]

	results.append_text("[b]%s[/b]:\t%s\n" % [viewer, res])
	results.scroll_to_line(results.get_line_count())
	if correct == length:
		results.append_text("[color=gold][b]%s found the secret code![/b][/color]\n" % viewer)
		results.scroll_to_line(results.get_line_count())
		active = false
		await get_tree().create_timer(5).timeout
		reset()

func on_guess_made(cmd_info: CommandInfo, args : PackedStringArray) -> void:
	run_guess(cmd_info.sender_data.tags["display-name"], args[0])

func _on_navigate_to_menu_button_scene_changing():
	print("Leaving %s scene with %d viewers" % [
		get_tree().current_scene.scene_file_path.get_file().get_basename(),
		GiftSingleton.active_viewers.size()
	])

func _on_ui_visibility_toggled(ui_visible: bool):
	node_ui.visible = ui_visible
