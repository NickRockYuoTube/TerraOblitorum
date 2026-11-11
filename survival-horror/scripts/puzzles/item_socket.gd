# res://scripts/puzzles/item_socket.gd
extends PuzzleElement
class_name ItemSocket
## Место, куда нужно вставить предмет: предохранитель, деталь, медальон.

@export var interactable: Interactable
@export var required_item: ItemData
@export_range(1, 99) var required_amount: int = 1
@export var consume_item: bool = true
@export var placed_visual: Node3D          ## появляется после вставки (модель предмета на месте)
@export var examine_prompt: String = "Осмотреть"
@export var place_prompt: String = "Вставить: %s"
@export_multiline var missing_message: String = "Здесь чего-то не хватает."
@export var used_message: String = "Использовано: %s"


func _ready() -> void:
	super._ready()
	if placed_visual:
		placed_visual.hide()
	interactable.interacted.connect(_on_interacted)
	Inventory.changed.connect(_update_prompt)
	_update_prompt()


func _has_item() -> bool:
	return required_item != null and Inventory.has_item(required_item.id, required_amount)


func _update_prompt() -> void:
	if is_solved:
		return
	interactable.prompt_text = place_prompt % required_item.display_name if _has_item() else examine_prompt


func _on_interacted(_player: Player) -> void:
	if is_solved:
		return
	if not _has_item():
		GameEvents.show_message(missing_message)
		return
	if consume_item:
		Inventory.remove_item(required_item.id, required_amount)
	if placed_visual:
		placed_visual.show()
	interactable.enabled = false
	if solve_message == "":
		GameEvents.show_message(used_message % required_item.display_name)
	_set_solved(true)
