extends Node
class_name Interactable
## Компонент: делает родительский объект интерактивным.
## Добавь дочерним узлом к объекту с коллизией (StaticBody3D, AnimatableBody3D и т.п.).

signal interacted(player: Player)
@warning_ignore("unused_signal")
signal focused
@warning_ignore("unused_signal")
signal unfocused

@export var prompt_text: String = "Использовать"
@export var enabled: bool = true
@export var one_shot: bool = false  ## после первого использования отключается


func interact(player: Player) -> void:
	if not enabled:
		return
	interacted.emit(player)
	if one_shot:
		enabled = false


func get_prompt() -> String:
	return prompt_text


## Ищет компонент Interactable среди детей узла
static func find_in(node: Node) -> Interactable:
	if node == null:
		return null
	for child in node.get_children():
		if child is Interactable:
			return child
	return null
