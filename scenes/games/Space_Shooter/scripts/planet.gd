extends Node2D



@onready var sprite_2d = $Sprite2D
@export var planet_type : SpaceGlobals.PLANETS
@export var sprite : Texture2D

func _ready():
	sprite_2d.texture = sprite
