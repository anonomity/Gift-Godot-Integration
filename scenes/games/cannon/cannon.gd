extends Node2D

const Actions = preload("res://scenes/games/cannon/game_constants.gd").Actions

enum GAME_STATE {WAITING, RUNNING, WINNER, PAUSED}

@export var bullet_scene: PackedScene = preload("res://scenes/games/cannon/bullet.tscn")
@export var default_countdown: float = 3.0
@export var minimum_distance: float = 300.0

var admin_menu_scene: PackedScene = load("res://scenes/games/cannon/cannon_admin_panel.tscn")
var autostart: bool = false:
	set(value):
		if value == autostart:
			return

		autostart = value
		preferences["autostart"] = autostart
		GamePreferencesHelper.save_preferences(preferences)

		if autostart and state != GAME_STATE.RUNNING:
			next_round()

var preferences: Dictionary = {}
var state: GAME_STATE = GAME_STATE.WAITING
var viewers: Dictionary = {}
var viewers_to_add: Array[Dictionary] = []

@onready var viewer_container: Node2D = $ViewerContainer
@onready var cannon: Node2D = $Cannon
@onready var cannon_sprite: Sprite2D = $Cannon/Sprite2D
@onready var target: Area2D = $Target

@onready var node_ui = $UI
@onready var join_next_round: Label = $UI/InstructionsContainer/VBoxContainer/JoinNextRound
@onready var how_to_play: Label = $UI/InstructionsContainer/VBoxContainer/HowToPlay
@onready var waiting: Label = $UI/Waiting
@onready var countdown: Label = $UI/Countdown
@onready var leaderboard: Leaderboard = $UI/LeaderboardPanel/MarginContainer/Leaderboard

func _ready() -> void:
	GameConfigManager.load_config()
	preferences = GamePreferencesHelper.load_preferences()

	SignalBus.ui_visibility_toggled.connect(_on_ui_visibility_toggled)

	GiftSingleton.viewer_joined.connect(on_viewer_joined)
	GiftSingleton.viewer_left.connect(on_viewer_left)
	GiftSingleton.user_left_chat.connect(on_viewer_left_chat)
	GiftSingleton.action_triggered.connect(on_action_triggered)

	# Command: !fire 90 100
	GiftSingleton.add_game_command("fire", on_viewer_fire, 2, 2)
	GiftSingleton.add_alias("fire", "f")

	GiftSingleton.streamer_start.connect(on_streamer_start)
	GiftSingleton.streamer_wait.connect(on_streamer_wait)

	change_state(GAME_STATE.WAITING)
	Transition.hide_transition()
	
	var active_viewers = GiftSingleton.active_viewers
	GiftSingleton.active_viewers = {}
	
	for viewer in active_viewers:
		var viewer_metadata = active_viewers[viewer]
		spawn_viewer(viewer, viewer_metadata)
	
	autostart = preferences.get("autostart", false) as bool

func _process(delta: float) -> void:	
	if Input.is_action_just_pressed("ui_cancel"):
		GameConfigManager.save_config()
		SceneSwitcher.change_scene_to(SceneSwitcher.selection_scene, true, null)

func change_state(new_state: GAME_STATE) -> void:
	state = new_state
	match state:
		GAME_STATE.WAITING:
			waiting.visible = true
			join_next_round.visible = false
		GAME_STATE.RUNNING:
			waiting.visible = false
			join_next_round.visible = true
		GAME_STATE.WINNER:
			pass
		GAME_STATE.PAUSED:
			pass

func next_round() -> void:
	change_state(GAME_STATE.RUNNING)

	for viewer_metadata in viewers_to_add:
		spawn_viewer(viewer_metadata.get("display_name").to_lower(), viewer_metadata)

	viewers_to_add.clear()

	change_positions()

func change_positions() -> void:
	cannon.global_position = Vector2(randf_range(150, 1800), randf_range(400, 900))
	while true:
		target.global_position = Vector2(randf_range(150, 1800), randf_range(100, 900))
		if target.global_position.distance_to(cannon.global_position) > minimum_distance:
			break
	target.rotation_degrees = randf_range(0.0, 360.0)

func fire_viewer(viewer_metadata: Dictionary, angle: float, power: float) -> void:
	var search_name: String = viewer_metadata.get("display_name").to_lower()
	if not viewers.has(search_name):
		await spawn_viewer(search_name, viewer_metadata)

	# Move the viewer
	viewers[search_name].start_move()
	viewers[search_name].set_deferred("global_position", cannon.global_position)

	# Rotate cannon
	# Adds - to angle to go from 0 to -180 and keep it positive for viewers
	cannon_sprite.rotation_degrees = -angle

	# Send viewer
	viewers[search_name].call_deferred("stop_move")
	var impulse: Vector2 = cannon_sprite.global_transform.x * remap(power, 0.0, 100.0, 0.0, 4000.0)
	viewers[search_name].call_deferred("apply_central_impulse", impulse)

	cannon.call_deferred("shoot")

func spawn_viewer(search_name: String, viewer_metadata: Dictionary) -> RigidBody2D:
	if viewers.has(search_name):
		return

	var instance: RigidBody2D = bullet_scene.instantiate()
	instance.name = "bullet-%s" % search_name
	instance.viewer_name = viewer_metadata.get("display_name", search_name)
	instance.metadata = viewer_metadata
#	instance.freeze = true
	viewer_container.call_deferred("add_child", instance)
	viewers[search_name] = instance
	await instance.ready
	instance.position.x += randf_range(-600, 600)
	push_bullet(instance)
	return instance

func push_bullet(obj: RigidBody2D) -> void:
	var push_vec: Vector2 = obj.global_transform.x.rotated(deg_to_rad(randi_range(0, 360)))
	push_vec *= 650.0
	obj.apply_central_impulse(push_vec)

func remove_viewer(viewer_name: String) -> void:
	var search_name: String = viewer_name.to_lower()
	if Viewers.is_joined(search_name):
		Viewers.remove(search_name)

	if not viewers.has(search_name):
		return

	viewers[search_name].queue_free()
	viewers.erase(search_name)

##### SIGNALS #####
func on_viewer_joined(display_name: String, color: String) -> void:
	var viewer_metadata: Dictionary = {
		"color": color,
		"display_name": display_name
	}

	#if state != GAME_STATE.WAITING:
		#viewers_to_add.append(viewer_metadata)
		#return

	spawn_viewer(display_name.to_lower(), viewer_metadata)

func on_viewer_left(viewer_name: String) -> void:
	remove_viewer(viewer_name)

func on_viewer_left_chat(sender_data: SenderData) -> void:
	remove_viewer(sender_data.user)

func on_action_triggered(action_id: String, user_name: String, at: int) -> void:
	var local_action_id = action_id.substr(action_id.find("::") + 2)
	var action = Actions.get(local_action_id, -1)
	match action:
		Actions.LEADERBOARD_RESET: leaderboard.clear()
		_: return

func on_viewer_fire(cmd_info : CommandInfo, arg_arr : PackedStringArray) -> void:
	if state != GAME_STATE.RUNNING: return
	if not arg_arr[0].is_valid_float(): return
	if not arg_arr[1].is_valid_float(): return

	var angle: float = fmod(float(arg_arr[0]), 360.0)
	var power: float = clampf(float(arg_arr[1]), 0, 100)
	var tags = cmd_info.sender_data.tags
	var viewer_metadata: Dictionary = {
		"color": tags["color"],
		"display_name": tags["display-name"]
	}
	fire_viewer(viewer_metadata, angle, power)

func on_streamer_start(arg_arr : PackedStringArray) -> void:
	var countdown_duration: float = default_countdown
	if not arg_arr.is_empty():
		if arg_arr[0].is_valid_float():
			countdown_duration = float(arg_arr[0])
	countdown.start(countdown_duration)

func on_streamer_wait(cmd_info : CommandInfo) -> void:
	change_state(GAME_STATE.WAITING)

func _on_target_body_entered(body: Node2D) -> void:
	if not body is CannonGameBullet:
		return

	target.activate()

	var viewer_name = body.viewer_name
	if typeof(viewer_name) == TYPE_STRING:
		self.leaderboard.add_points(viewer_name, 1)

	change_state(GAME_STATE.WINNER)
	next_round()

func _on_countdown_finished() -> void:
	next_round()

func _on_navigate_to_menu_button_scene_changing():
	var active_viewers: Dictionary = {}
	for key in viewers:
		var viewer = viewers[key]
		active_viewers[key] = viewer.get("metadata")
	GiftSingleton.set_active_viewers(active_viewers)
	print("Leaving %s scene with %d viewers" % [
		get_tree().current_scene.scene_file_path.get_file().get_basename(),
		GiftSingleton.active_viewers.size()
	])

func _on_ui_visibility_toggled(ui_visible: bool):
	node_ui.visible = ui_visible
