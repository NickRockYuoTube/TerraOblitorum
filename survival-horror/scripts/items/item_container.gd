# res://scripts/items/item_container.gd
extends Node
class_name ItemContainer
## Общая логика ячеек с предметами. Её наследуют Inventory и Storage.

signal changed
signal item_added(item: ItemData, amount: int)
signal item_removed(id: String, amount: int)

var capacity: int = 8
var slots: Array[ItemStack] = []


func _ready() -> void:
	slots.resize(capacity)


## Добавляет предмет. Возвращает количество, которое НЕ поместилось.
func add_item(item: ItemData, amount: int = 1) -> int:
	var left := amount

	# Сначала докладываем в уже существующие стопки
	if item.stackable:
		for stack in slots:
			if left == 0:
				break
			if stack and stack.item.id == item.id and stack.amount < item.max_stack:
				var add := mini(left, item.max_stack - stack.amount)
				stack.amount += add
				left -= add

	# Потом занимаем пустые ячейки
	for i in slots.size():
		if left == 0:
			break
		if slots[i] == null:
			var add := mini(left, item.max_stack if item.stackable else 1)
			slots[i] = ItemStack.new(item, add)
			left -= add

	var added := amount - left
	if added > 0:
		item_added.emit(item, added)
		changed.emit()
	return left


## Убирает предметы по ID. Возвращает false, если их не хватает.
func remove_item(id: String, amount: int = 1) -> bool:
	if count(id) < amount:
		return false
	var left := amount
	for i in range(slots.size() - 1, -1, -1):
		var stack := slots[i]
		if stack and stack.item.id == id:
			var take := mini(left, stack.amount)
			stack.amount -= take
			left -= take
			if stack.amount == 0:
				slots[i] = null
			if left == 0:
				break
	item_removed.emit(id, amount)
	changed.emit()
	return true


## Убирает предметы из конкретной ячейки. Возвращает, сколько реально убрано.
func remove_at(index: int, amount: int) -> int:
	if index < 0 or index >= slots.size() or slots[index] == null:
		return 0
	var stack := slots[index]
	var take := mini(amount, stack.amount)
	var id := stack.item.id
	stack.amount -= take
	if stack.amount <= 0:
		slots[index] = null
	item_removed.emit(id, take)
	changed.emit()
	return take


## Переложить стопку из ячейки в другой контейнер. false = некуда класть.
func transfer_to(index: int, target: ItemContainer) -> bool:
	if index < 0 or index >= slots.size() or slots[index] == null:
		return false
	var stack := slots[index]
	var left := target.add_item(stack.item, stack.amount)
	var moved := stack.amount - left
	if moved == 0:
		return false
	remove_at(index, moved)
	return true


func count(id: String) -> int:
	var total := 0
	for stack in slots:
		if stack and stack.item.id == id:
			total += stack.amount
	return total


func has_item(id: String, amount: int = 1) -> bool:
	return count(id) >= amount


## Расширение (например, найденный рюкзак)
func set_capacity(new_capacity: int) -> void:
	if new_capacity <= capacity:
		return
	capacity = new_capacity
	slots.resize(capacity)
	changed.emit()


## Очистить (новая игра, рестарт)
func clear() -> void:
	slots.clear()
	slots.resize(capacity)
	changed.emit()
