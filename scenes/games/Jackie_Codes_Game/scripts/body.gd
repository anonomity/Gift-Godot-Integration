extends CharacterBody2D

@export var should_flip : bool = false
var speed = 100.0
const JUMP_VELOCITY = -400.0
@onready var name_label = $name_label
@onready var sprite_2d =$Node2D/Sprite2D 
@onready var explode = $explode
@onready var hat_sprite = $Node2D/Sprite2D/hat
@onready var node_2d = $Node2D
var tilemap : TileMap 
@onready var bone_text = $Node2D/Sprite2D/bone_text

var colors = [Color.AQUA, Color.BLUE_VIOLET, Color.DARK_SALMON, Color.ORANGE, Color.DODGER_BLUE]

var player_name = ""
# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var direction = 1

var crown_sprite = preload("res://scenes/games/Jackie_Codes_Game/assets/crown.png")
@export var hat_reversed : bool = false
var stop = false
var jumping = false
var digging = false


func _ready():
	bone_text.hide()
	hat_sprite.hide()
	if randi_range(0,1) == 0:
		direction = 1
	else:
		direction = -1	

func _physics_process(delta):
	# Add the gravity.
	if not is_on_floor():
		velocity.y += gravity * delta
	
	if is_on_floor() and jumping:
		velocity.y = JUMP_VELOCITY
		jumping = false
	
	if global_position.x > 1900:
		direction = direction * -1
		
	if global_position.x < 200.0:
		direction = direction * -1
	if should_flip:
		if direction > 0:
			node_2d.scale = Vector2(1, 1)
		else:
			node_2d.scale = Vector2(-1, 1)
	if digging == true:
		if tilemap:
			velocity = Vector2.ZERO
			var map_pos = tilemap.local_to_map(global_position)
			map_pos = Vector2(map_pos.x, map_pos.y )
			tilemap.erase_cell(0,map_pos)
			tilemap.set_cells_terrain_connect(0,[map_pos],0,-1)
			var tile_arr = GlobalTilemap.erase_tile(map_pos)
			
#			tilemap.set_cells_terrain_connect(0,tile_arr,0,0)
			digging = false
		else:
			digging = false
	if direction and !stop:
		velocity.x = direction * speed
	else:
		velocity.x = 0

	
	move_and_slide()

func leave():
	sprite_2d.hide()
	name_label.hide()
	explode.emitting = true
	await get_tree().create_timer(3.0).timeout
	queue_free()
	
func init(name, is_gifter = false, top_3 = false, _tilemap =false, is_mod = false):
	tilemap = _tilemap
	speed = randf_range(30.0, 50.0)
	player_name = name
	if top_3:
		scale = Vector2(3,3)
		hat_sprite.texture = crown_sprite
		hat_sprite.show()
		name_label.modulate =colors.pick_random()
	elif is_gifter:
		make_gifter()
	
	if is_mod:
		bone_text.show()
	name_label.text = name

func make_gifter():
	scale = Vector2(3,3)
	hat_sprite.show()
	name_label.modulate =colors.pick_random()

func transport_to_gulag(pos):
	stop = true
	global_position = pos
	sprite_2d.stop()

func dig():
	pass
#	digging = true

func jump():
	jumping = true
