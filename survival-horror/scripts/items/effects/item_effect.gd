# res://scripts/items/effects/item_effect.gd
extends Resource
class_name ItemEffect
## Базовый эффект предмета. Чтобы сделать новый эффект,
## создай скрипт с "extends ItemEffect" и переопредели apply().


## Применить эффект. Вернуть true, если сработал.
func apply(_player: Player) -> bool:
	return false


## Тратится ли предмет после использования (оружие — нет)
func consumes_item() -> bool:
	return true


## Надпись на кнопке в инвентаре
func get_use_text() -> String:
	return "Использовать"
