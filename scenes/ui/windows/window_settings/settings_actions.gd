extends MarginContainer

@onready var list_builtin_actions: ItemList = %ListBuiltinActions
@onready var list_custom_actions: ItemList = %ListCustomActions

var builtin_actions: Array[Action] = []
var custom_actions: Array[Action] = []

static func _populate_list(list: ItemList, actions: Array[Action]) -> void:
	for action in actions:
		var metadata: ActionMetadata = action.metadata
		var icon: Texture2D = metadata.icon if metadata else null
		var item_index = list.add_item(action.label, icon)
		list.set_item_metadata(item_index, action)

func _init() -> void:
	builtin_actions = ActionsManager.get_builtin()
	custom_actions = ActionsManager.get_custom()

func _ready():
	_populate_list(list_builtin_actions, builtin_actions)
	_populate_list(list_custom_actions, custom_actions)
