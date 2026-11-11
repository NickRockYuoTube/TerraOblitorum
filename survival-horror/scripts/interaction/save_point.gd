# res://scripts/interaction/save_point.gd
extends Node3D
class_name SavePoint
## Точка сохранения (как печатная машинка в Resident Evil).

@export var interactable: Interactable
@export var prompt_text: String = "Сохранить игру"
@export var required_item: ItemData        ## расходник для сохранения; пусто = бесплатно
@export_multiline var missing_item_message: String = "Нечем сделать запись..."


func _ready() -> void:
	if interactable == null:
		interactable = Interactable.find_in(self)
	interactable.prompt_text = prompt_text
	interactable.interacted.connect(_on_interacted)


func _on_interacted(_player: Player) -> void:
	if required_item and not Inventory.has_item(required_item.id):
		GameEvents.show_message(missing_item_message)
		return
	GameEvents.open_save(self)


## Списать расходник. Вызывается окном сохранения в момент записи.
func consume_cost() -> bool:
	if required_item == null:
		return true
	return Inventory.remove_item(required_item.id, 1)
