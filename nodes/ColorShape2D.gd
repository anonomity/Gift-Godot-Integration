@tool
class_name ColorShape2D
extends Node2D

@export var color: Color = Color.WHITE:
	set(value):
		if color == value:
			return

		color = value

		print("Shape color changed")
		queue_redraw()

@export var shape: Shape2D:
	set(value):
		if shape == value:
			return

		if shape != null and shape.changed.is_connected(_on_shape_changed):
			shape.changed.disconnect(_on_shape_changed)

		shape = value

		if shape != null and not shape.changed.is_connected(_on_shape_changed):
			shape.changed.connect(_on_shape_changed)

		_on_shape_changed()

@export_group("Shape Transform")
@export var shape_transform_offset: Vector2 = Vector2(0.0, 0.0):
	set(value):
		if shape_transform_offset == value:
			return

		shape_transform_offset = value

		print("Shape transform offset changed")
		_update_shape()

@export_range(-360.0, 360.0, 0.1, "degrees") var shape_transform_rotation: float = 0.0:
	set(value):
		if shape_transform_rotation == value:
			return

		shape_transform_rotation = value

		print("Shape transform rotation changed")
		_update_shape()

@export var shape_transform_scale: Vector2 = Vector2(1.0, 1.0):
	set(value):
		if shape_transform_scale == value:
			return

		shape_transform_scale = value

		print("Shape transform scale changed")
		_update_shape()

var shape_canvas_item: RID

func _on_shape_changed() -> void:
	print("Shape changed")
	_update_shape()

func _update_shape(redraw: bool = true) -> void:
	if not shape_canvas_item:
		return

	var radians = deg_to_rad(shape_transform_rotation)
	var shape_transform = Transform2D.IDENTITY.rotated(radians).scaled(shape_transform_scale).translated(shape_transform_offset)
	RenderingServer.canvas_item_set_transform(shape_canvas_item, shape_transform)

	if redraw:
		queue_redraw()

func _enter_tree() -> void:
	shape_canvas_item = RenderingServer.canvas_item_create()
	RenderingServer.canvas_item_set_parent(shape_canvas_item, get_canvas_item())

	_update_shape(false)

func _exit_tree() -> void:
	RenderingServer.canvas_item_clear(shape_canvas_item)
	RenderingServer.free_rid(shape_canvas_item)
	shape_canvas_item = RID()

func _draw() -> void:
	if not shape or not shape_canvas_item:
		return

	RenderingServer.canvas_item_clear(shape_canvas_item)
	shape.draw(shape_canvas_item, color)
