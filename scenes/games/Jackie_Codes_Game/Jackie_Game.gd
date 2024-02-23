extends Node2D

var body1 = preload("res://scenes/games/Jackie_Codes_Game/scenes/body.tscn")
var body2 =preload("res://scenes/games/Jackie_Codes_Game/scenes/inhertired_body_2.tscn")
var body3 =preload("res://scenes/games/Jackie_Codes_Game/scenes/Inherited_body_3.tscn")
var body4 =preload("res://scenes/games/Jackie_Codes_Game/scenes/inherited_body_4.tscn")
var body5 = preload("res://scenes/games/Jackie_Codes_Game/scenes/inherited_body_5.tscn")
var body6 = preload("res://scenes/games/Jackie_Codes_Game/scenes/inherited_body_6.tscn")
var bodies = [body1, body2, body3,body4,body5,body6]
@onready var spawn = $spawn
@onready var players = $players
@onready var control = $Debug/Control
@onready var prison = $prison

var players_arr = [] 
@onready var tile_map = $TileMap

#var gifters = ["razielbyo","ghostlupo86", "mudbound_dragon","justinhhorner", "FutileEd", "Frumious__Bandersnatch", "Ashing87", "SlaterUSA", "Pandacoder", "dawdle", "invisiblematter"]
var gifters = []

var top_3_arr = [ "
solarlabyrinth","
robotech83", "pandacoder", "ghostlupo86", "snoeyz"]
var mods = ["frumious__bandersnatch", "robotech83"]
func _ready() -> void:
	GameConfigManager.load_config()
	
	GiftSingleton.viewer_joined.connect(on_viewer_joined)
	GiftSingleton.viewer_left.connect(on_viewer_left)
	GiftSingleton.add_game_command("jump", on_viewer_jump)
	GiftSingleton.add_game_command("dig", on_viewer_dig)
	GlobalTilemap.set_terrain_arr(tile_map.get_used_cells(0))
#	GiftSingleton.user_left_chat.connect(on_viewer_left_chat)

#	SignalBus.transparency_toggled.connect(on_transparency_toggled)

	Transition.hide_transition()

func add_to_gift_array(name):
	gifters.append(name)
	#check if the player is already in the game
	for player in players.get_children():
		if player.player_name == name:
			player.make_gifter()
	

func on_viewer_joined(viewer_name: String) -> void:

	spawn_viewer(viewer_name)

func spawn_viewer(name:String):
	
	
	
	name = name.to_lower()
	var is_in_arr= players_arr.find(name)
	if is_in_arr == -1:
		players_arr.append(name)
		var is_gifter = false
		var top_3_bool = false
		var is_mod = false
		var player = bodies.pick_random().instantiate()
		players.add_child(player)
		if gifters.find(name) != -1:
			is_gifter = true
		if top_3_arr.find(name) != -1:
			top_3_bool = true
		if mods.find(name) != -1:
			is_mod = true
		player.init(name, is_gifter,top_3_bool, tile_map, is_mod)
		player.global_position = spawn.global_position

func _input(event):
	if Input.is_action_just_pressed("transparent"):
		control.visible = !control.visible
	if Input.is_action_just_pressed("test"):
		GiftSingleton.chat("TEST", "jackie_codes")	
	

func on_viewer_left(name):
	for pl in players.get_children():
		if pl.player_name == name:
			players_arr.erase(name)
			pl.leave()
	
func on_viewer_jump(name):
	for player in players.get_children():
		var name_sender : SenderData = name.sender_data
	
		if player.player_name == name_sender.user:
			player.jump()
			
func on_viewer_dig(name):
	for player in players.get_children():
		var name_sender : SenderData = name.sender_data
	
		if player.player_name == name_sender.user:
			player.dig()
func add_degen_to_prison_array(name):
	name = name.to_lower()
	#check if the player is already in the game
	for player in players.get_children():
		if player.player_name == name:
			player.transport_to_gulag(prison.global_position)
