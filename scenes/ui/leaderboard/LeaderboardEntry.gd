class_name LeaderboardEntry extends HBoxContainer

@export var number: int = 0:
	get:
		return number
	set(value):
		number = value
		if label_number != null:
			label_number.text = str(number)

@export var entry_name: String = "test":
	get:
		return entry_name
	set(value):
		entry_name = value
		if label_name != null:
			label_name.text = entry_name

@export var points: int = 7777777:
	get:
		return points
	set(value):
		points = value
		if label_points != null:
			label_points.text = str(points)

@onready var label_number: Label = $Number
@onready var label_name: Label = $Name
@onready var label_points: Label = $Points
