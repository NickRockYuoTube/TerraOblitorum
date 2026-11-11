extends ItemEffect
class_name HealEffect
## Лечение: бинты, аптечки, травы.

@export var amount: float = 40.0
@export var used_message: String = "Здоровье восстановлено"
@export var full_health_message: String = "Здоровье в норме"


func apply(player: Player) -> bool:
	if player.health == null:
		return false
	if player.health.is_full():
		GameEvents.show_message(full_health_message)
		return false
	player.health.heal(amount)
	GameEvents.show_message(used_message)
	return true
