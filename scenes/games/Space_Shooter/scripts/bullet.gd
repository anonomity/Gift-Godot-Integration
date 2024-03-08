class_name SpaceShooterBullet
extends Area2D

var speed = 100
var group 

func _process(delta):
	position += transform.x * speed * delta

func init(_group):
	group = _group

func _on_area_entered(area):
	if !area.is_in_group(group):
		area.destroy()

func _on_timer_timeout():
	queue_free()
