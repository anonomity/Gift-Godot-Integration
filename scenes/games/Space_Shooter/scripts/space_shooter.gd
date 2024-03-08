extends Node2D
@onready var label = $Label

var angle_in_radians = 0
var speed = 100
var radius = 100
var MAX_RADIUS = 130

@onready var barrel: Node2D = $barrel
@onready var barrel_marker: Marker2D = $barrel/barrel_marker
@onready var can_bang_timer = $can_bang_timer

const BULLET_SCENE: PackedScene = preload("res://scenes/games/Space_Shooter/scenes/bullet.tscn")

var GM = 100000
var opposing_planet

var can_bang = true
var GROUP 

var viewer_name 
func _ready():
	var random_radius = randi_range(80, MAX_RADIUS)
	radius = random_radius
#	speed = (MAX_RADIUS - radius)+30
	speed = sqrt(GM / radius)
	

func init(name, _planet):
	viewer_name = str(name)
	label.text = str(name)
	opposing_planet = _planet
	if opposing_planet.planet_type == SpaceGlobals.PLANETS.MARS:
		add_to_group("JUPITER")
		GROUP = "JUPITER"
	else:
		add_to_group("MARS")
		GROUP = "MARS"
		
func update_angle(delta):
	angle_in_radians += deg_to_rad(speed) * delta
	
	
	
func update_position(): 
	var x = radius * cos(angle_in_radians) 
	var y = radius * sin(angle_in_radians)
	position = Vector2(x,y)

func _physics_process(delta):
	update_angle(delta)
	update_position()
	

		
func on_bang(view_name, deg):
	print("viewer ", viewer_name, " is banging")
	var radian_to_shoot = 0
	if deg.size() == 1:
		radian_to_shoot = deg_to_rad(float(deg[0]))
		var seconds_remaining = int(can_bang_timer.time_left)
		if not can_bang and seconds_remaining < 1:
			# Sometimes the timer doesn't appear to fire
			can_bang = true
		if can_bang:
			var bullet_instance: SpaceShooterBullet = BULLET_SCENE.instantiate()
			barrel.look_at(opposing_planet.global_position)
			opposing_planet.add_child(bullet_instance)
			bullet_instance.init(GROUP)
			bullet_instance.global_transform = barrel.global_transform
			bullet_instance.global_scale = Vector2(1, 1)

			can_bang = false
			can_bang_timer.start()
		else:
			var msg = "wow %s the idiot, wait %d seconds, OKAY?! " % [viewer_name, seconds_remaining]
			GiftSingleton.chat(msg)	
	else:
		var msg = "PUT THE DAMN DEGREES AFTER THE BANG, OK!?>!?! "+str(viewer_name) + " "

func _on_can_bang_timer_timeout():
	can_bang = true
	can_bang_timer.stop()

func destroy():
	print("DEAD")
	queue_free()
