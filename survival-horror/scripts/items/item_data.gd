# res://scripts/items/item_data.gd
extends Resource
class_name ItemData
## Описание предмета. Создаётся как ресурс .tres и заполняется в инспекторе.

enum ItemType { MISC, KEY, CONSUMABLE, AMMO, WEAPON, PUZZLE }

@export var id: String = ""                ## уникальный ID, например "key_red"
@export var display_name: String = "Предмет"
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var type: ItemType = ItemType.MISC
@export var can_discard: bool = true       ## выключи для ключей и сюжетных предметов

@export_group("Stacking")
@export var stackable: bool = false
@export_range(1, 999) var max_stack: int = 1

@export_group("Use")
@export var use_effect: ItemEffect         ## пусто = предмет нельзя «использовать»
@export var consume_on_use: bool = true    ## тратится ли предмет при использовании

@export_group("Presentation")
@export var world_model: PackedScene       ## модель на полу; пусто = заглушка из сцены Pickup
