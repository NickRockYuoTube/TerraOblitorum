extends RefCounted
class_name ItemStack
## Одна занятая ячейка инвентаря: предмет и его количество.

var item: ItemData
var amount: int


func _init(p_item: ItemData, p_amount: int = 1) -> void:
	item = p_item
	amount = p_amount
