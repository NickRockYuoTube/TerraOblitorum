# res://core/inventory.gd
extends ItemContainer
## Инвентарь игрока. Добавлен в Autoload под именем Inventory.
## Вся логика ячеек — в ItemContainer, здесь только использование предметов.

signal item_used(item: ItemData)


func _init() -> void:
	capacity = 8


## Использует предмет из ячейки. Возвращает true, если эффект сработал.
func use_item(index: int) -> bool:
	if index < 0 or index >= slots.size():
		return false
	var stack := slots[index]
	if stack == null or stack.item.use_effect == null:
		return false
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null:
		return false
	if not stack.item.use_effect.apply(player):
		return false

	var item := stack.item
	if item.consume_on_use and item.use_effect.consumes_item():
		stack.amount -= 1
		if stack.amount <= 0:
			slots[index] = null
	item_used.emit(item)
	changed.emit()
	return true
