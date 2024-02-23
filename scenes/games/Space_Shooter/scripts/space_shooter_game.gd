extends Node2D

@onready var mars = $Mars
@onready var jupiter = $Jupiter



var asteroid = preload("res://scenes/games/Space_Shooter/scenes/asteroid.tscn")
var binary = false

var players_arr = [] 
var player_obj_arr = []

func _ready() -> void:
	GameConfigManager.load_config()
	GiftSingleton.viewer_joined.connect(on_viewer_joined)
	GiftSingleton.viewer_left.connect(on_viewer_left)
	GiftSingleton.add_game_command("bang",on_bang,1,1)
	Transition.hide_transition()

func on_viewer_joined(viewer_name: String) -> void:	
	spawn_viewer(viewer_name)

func spawn_viewer(viewer_name):
	var is_in_arr= players_arr.find(viewer_name)
	if is_in_arr == -1:
		players_arr.append(viewer_name)
		var asteroid_spawn = asteroid.instantiate()
		if binary:
			mars.add_child(asteroid_spawn)
			asteroid_spawn.init(viewer_name, jupiter)
		else:
			jupiter.add_child(asteroid_spawn)
			asteroid_spawn.init(viewer_name, mars)
		player_obj_arr.append(asteroid_spawn)
		binary = !binary
	
func on_viewer_left(viewer_name):
	pass

func on_bang(obj, deg):
	var bj : SenderData = obj.sender_data
	var viewer_name = bj.user
	if deg.size() == 1:

		for player in player_obj_arr:
			if player.viewer_name == viewer_name:
				player.on_bang(viewer_name, deg)
	else:
		var msg = "PUT THE DAMN DEGREES AFTER THE BANG, OK!?>!?! "+str(viewer_name) + " "
		GiftSingleton.chat(msg, "jackie_codes")	
