extends Node2D

@onready var mars = $Mars
@onready var jupiter = $Jupiter



var asteroid = preload("res://scenes/games/Space_Shooter/scenes/asteroid.tscn")
var binary = false

var viewers: Dictionary = {}
var players_arr = [] 
var player_obj_arr = []

func _ready() -> void:
	GameConfigManager.load_config()
	GiftSingleton.viewer_joined.connect(on_viewer_joined)
	GiftSingleton.viewer_left.connect(on_viewer_left)
	GiftSingleton.add_game_command("bang",on_bang,1,1)
	Transition.hide_transition()
	
	var active_viewers = GiftSingleton.active_viewers
	GiftSingleton.active_viewers = []
	
	for viewer in active_viewers:
		spawn_viewer(viewer)

func on_viewer_joined(viewer_name: String) -> void:	
	spawn_viewer(viewer_name)

func spawn_viewer(viewer_name: String):
	var name = viewer_name.to_lower()
	var is_in_arr= players_arr.find(name)
	if is_in_arr == -1:
		players_arr.append(name)
		var asteroid_spawn = asteroid.instantiate()
		if binary:
			mars.add_child(asteroid_spawn)
			asteroid_spawn.init(name, jupiter)
		else:
			jupiter.add_child(asteroid_spawn)
			asteroid_spawn.init(name, mars)
		player_obj_arr.append(asteroid_spawn)
		viewers[name] = {
			"name": viewer_name,
			"player": asteroid_spawn
		}
		binary = !binary
	
func on_viewer_left(viewer_name: String):
	var name = viewer_name.to_lower()
	viewers.erase(name)

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

static func _extract_viewer_name(viewer):
	if viewer == null:
		return null
	return viewer.name

static func _filter_non_null(value):
	return value != null


func _on_navigate_to_menu_button_scene_changing():
	var active_viewers: Array[String] = []
	active_viewers.append_array(viewers.values().map(_extract_viewer_name).filter(_filter_non_null))
	print("Leaving Space Shooter scene with %d viewers" % active_viewers.size())
	GiftSingleton.set_active_viewers(active_viewers)
