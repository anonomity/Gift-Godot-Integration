extends Node

signal transparency_toggled(transparent: bool)

func emit_transparency_toggled(transparent: bool) -> void:
	transparency_toggled.emit(transparent)

func _process(delta):
	if Input.is_action_just_pressed("transparent"):
		SignalBus.emit_transparency_toggled(not get_viewport().transparent_bg)

func _ready():
	SignalBus.transparency_toggled.connect(on_transparency_toggled)

func on_transparency_toggled(transparent: bool) -> void:
	for node in get_tree().get_nodes_in_group("Background"):
		node.visible = not transparent
		get_viewport().transparent_bg = transparent
