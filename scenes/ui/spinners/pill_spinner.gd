@tool
extends Control

@export var pill_color: Color = Color.WHITE

@export var pill_count: int = 16:
	set(value):
		if value == pill_count:
			return

		pill_count = value
		_recompute_shapes()

@export var pill_expansion: float = 2.0

@export var pill_length: float = 4.0:
	set(value):
		if value == pill_length:
			return

		pill_length = value
		_recompute_shapes()

@export var pill_width: float = 2.0:
	set(value):
		if value == pill_width:
			return

		pill_width = value
		_recompute_shapes()

@export var progress_rate: float = 2.0

var canvas_items: Array[RID] = []
var in_tree: bool = false
var progress: float = 0.0
var shapes: Array[Shape2D] = []

func _enter_tree() -> void:
	in_tree = true
	_recompute_shapes()

func _exit_tree() -> void:
	in_tree = false
	for canvas_item in canvas_items:
		RenderingServer.canvas_item_clear(canvas_item)
		RenderingServer.free_rid(canvas_item)
	canvas_items.clear()

func _recompute_shapes() -> void:
	if not in_tree:
		return

	if canvas_items.size() > pill_count:
		for index in range(pill_count, canvas_items.size()):
			RenderingServer.free_rid(canvas_items[index])
		canvas_items.resize(pill_count)
		shapes.resize(pill_count)

	while canvas_items.size() < pill_count:
		var canvas_item = RenderingServer.canvas_item_create()
		RenderingServer.canvas_item_set_parent(canvas_item, get_canvas_item())
		canvas_items.push_back(canvas_item)

	while shapes.size() < pill_count:
		shapes.push_back(CapsuleShape2D.new())

	_compute_distance_multiplier()

	var angle_per_pill = TAU / pill_count
	var distance_from_center = pill_length * pill_count / 8.0

	for index in range(0, pill_count):
		var canvas_item = canvas_items[index]
		if not canvas_items:
			continue

		var shape = shapes[index] as CapsuleShape2D
		if not shape:
			continue

		var angle_rad = angle_per_pill * index
		var transform = Transform2D.IDENTITY.rotated(angle_rad).translated(Vector2(0.0, -distance_from_center))
		RenderingServer.canvas_item_set_transform(canvas_item, transform)

		shape.height = pill_length
		shape.radius = pill_width / 2.0

	queue_redraw()

func _process(delta: float) -> void:
	progress = fmod(progress + delta * progress_rate, TAU)

	queue_redraw()

func _compute_distance_multiplier() -> float:
	return sqrt(pill_count / 8.0) * log(pill_width) / log(10.0)

func _get_minimum_size() -> Vector2:
	var distance_multiplier = _compute_distance_multiplier()
	var scaled_pill_length = _compute_length(0.0)
	var base_distance_from_center = pill_length
	var distance_from_center = base_distance_from_center * distance_multiplier + scaled_pill_length / 2.0
	var quadrant_size = distance_from_center + scaled_pill_length / 2.0
	return Vector2(quadrant_size, quadrant_size) * 2.0

func _compute_length(angle_difference: float) -> float:
	var expansion = max(0, cos(angle_difference))
	expansion = pow(expansion, 8)
	var scale = 1.0 + (pill_expansion - 1.0) * expansion
	var scaled_pill_length = pill_length * scale
	return scaled_pill_length

func _draw() -> void:
	var angle_per_pill = TAU / pill_count
	var distance_multiplier = _compute_distance_multiplier()

	var center = self.size / 2.0

	#RenderingServer.canvas_item_add_circle(get_canvas_item(), center, pill_length * 2.0, Color.LIGHT_CORAL)

	for index in range(0, pill_count):
		if index >= canvas_items.size():
			continue

		if index >= shapes.size():
			continue

		var canvas_item = canvas_items[index]
		if not canvas_item:
			continue

		var shape = shapes[index] as CapsuleShape2D
		if not shape:
			continue

		var angle_rad = angle_per_pill * index
		var angle_difference = angle_rad - progress
		var scaled_pill_length = _compute_length(angle_difference)
		shape.height = scaled_pill_length
		var base_distance_from_center = pill_length
		var distance_from_center = base_distance_from_center * distance_multiplier + scaled_pill_length / 2.0

		var transform = Transform2D.IDENTITY.translated(Vector2(0.0, -distance_from_center)).rotated(angle_rad).translated(center)

		RenderingServer.canvas_item_clear(canvas_item)
		RenderingServer.canvas_item_set_transform(canvas_item, transform)
		shape.draw(canvas_item, pill_color)
		#RenderingServer.canvas_item_add_rect(canvas_item, Rect2(-pill_width / 2.0, -scaled_pill_length / 2.0, pill_width, scaled_pill_length), Color(Color.CORNFLOWER_BLUE, 0.5))
