# res://scripts/items/effects/equip_weapon_effect.gd
extends ItemEffect
class_name EquipWeaponEffect
## Экипировать или убрать оружие. Ставится на предмет-оружие в инвентаре.

@export var weapon: WeaponData


func apply(_player: Player) -> bool:
	var manager := _get_manager()
	if manager == null or weapon == null:
		return false
	if manager.current == weapon:
		manager.unequip()
	else:
		manager.equip(weapon)
	return true


func consumes_item() -> bool:
	return false


func get_use_text() -> String:
	var manager := _get_manager()
	if manager and manager.current == weapon:
		return "Убрать"
	return "Экипировать"


func _get_manager() -> WeaponManager:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.get_first_node_in_group("weapon_manager") as WeaponManager
