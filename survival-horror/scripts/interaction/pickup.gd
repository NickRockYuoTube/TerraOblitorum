# res://scripts/interaction/pickup.gd
extends Node3D
class_name Pickup
## Подбираемый предмет. Кладёт ItemData в инвентарь.

signal picked_up(item: ItemData, amount: int)

@export var interactable: Interactable
@export var item: ItemData
@export_range(1, 999) var amount: int = 1
@export var pickup_sound: AudioStream
@export var default_visual: Node3D        ## заглушка; скрывается, если у предмета есть World Model


func _ready() -> void:
	if interactable == null:
		interactable = Interactable.find_in(self)
	if item == null:
		push_warning("Pickup '%s': не назначен предмет (item)" % name)
		return
	_apply_world_model()
	_update_prompt()
	interactable.interacted.connect(_on_interacted)


func _apply_world_model() -> void:
	if item.world_model == null:
		return
	add_child(item.world_model.instantiate())
	if default_visual:
		default_visual.hide()


func _update_prompt() -> void:
	var text := "Подобрать: %s" % item.display_name
	if amount > 1:
		text += " (%d)" % amount
	interactable.prompt_text = text


func _on_interacted(_player: Player) -> void:
	var left := Inventory.add_item(item, amount)
	var taken := amount - left
	if taken == 0:
		GameEvents.show_message("Нет места в инвентаре")
		return

	var message := "Получено: %s" % item.display_name
	if taken > 1:
		message += " ×%d" % taken
	GameEvents.show_message(message)
	_play_sound()
	picked_up.emit(item, taken)

	# Если поместилось не всё, остаток остаётся лежать
	if left > 0:
		amount = left
		_update_prompt()
	else:
		queue_free()


func _play_sound() -> void:
	if pickup_sound == null:
		return
	# Звук живёт отдельно, потому что сам предмет сейчас удалится
	var audio := AudioStreamPlayer.new()
	audio.stream = pickup_sound
	get_tree().root.add_child(audio)
	audio.play()
	audio.finished.connect(audio.queue_free)
