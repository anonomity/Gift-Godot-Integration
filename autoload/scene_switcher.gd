extends Node

@export var selection_scene: PackedScene = preload("res://scenes/ui/selection.tscn")

# Private variable
var _params = null

func _pre_change_scene(scene_name: String, transition: bool = false, params = null):
	if transition:
		Transition.show_transition()
		await Transition.done
	_params = params
	SignalBus.emit_scene_changing(scene_name)
	
func _post_change_scene(scene_name: String, transition: bool = false, params = null):
	await get_tree().process_frame
	SignalBus.emit_scene_changed(scene_name)

# Call this instead to be able to provide arguments to the next scene
func change_scene(next_scene: String, transition: bool = false, params = null):
	var scene_name = next_scene.get_file().get_basename()
	_pre_change_scene(scene_name, transition, params)
	get_tree().change_scene_to_file(next_scene)
	_post_change_scene(scene_name, transition, params)

func change_scene_to(next_scene: PackedScene, transition: bool = false, params = null):
	var scene_name = next_scene.resource_path.get_file().get_basename()
	await _pre_change_scene(scene_name, transition, params)
	await get_tree().change_scene_to_packed(next_scene)
	await _post_change_scene(scene_name, transition, params)

# In the newly opened scene, you can get the parameters by name
func get_param(name):
	if _params != null and _params.has(name):
		return _params[name]
	return null
