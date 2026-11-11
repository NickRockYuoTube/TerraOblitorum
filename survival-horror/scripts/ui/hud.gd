# res://scripts/ui/hud.gd
extends CanvasLayer
## Интерфейс во время игры: подсказка взаимодействия, сообщения, патроны.

@export var prompt_label: Label
@export var message_label: Label
@export var ammo_label: Label        ## необязательно

var _message_tween: Tween


func _ready() -> void:
	if prompt_label == null:
		prompt_label = find_child("PromptLabel", true, false) as Label
	if message_label == null:
		message_label = find_child("MessageLabel", true, false) as Label
	if ammo_label == null:
		ammo_label = find_child("AmmoLabel", true, false) as Label
	if prompt_label == null or message_label == null:
		push_error("HUD: не найдены PromptLabel / MessageLabel")
		return

	prompt_label.hide()
	message_label.modulate.a = 0.0
	GameEvents.interaction_prompt_changed.connect(_on_prompt_changed)
	GameEvents.message_requested.connect(_on_message_requested)

	if ammo_label:
		ammo_label.hide()
		GameEvents.weapon_changed.connect(_on_weapon_changed)
		GameEvents.ammo_changed.connect(_on_ammo_changed)


func _on_prompt_changed(text: String) -> void:
	prompt_label.text = text
	prompt_label.visible = text != ""


func _on_message_requested(text: String, duration: float) -> void:
	message_label.text = text
	if _message_tween:
		_message_tween.kill()
	message_label.modulate.a = 1.0
	# Сообщения исчезают даже на паузе (например, в инвентаре)
	_message_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_message_tween.tween_interval(duration)
	_message_tween.tween_property(message_label, "modulate:a", 0.0, 0.5)


func _on_weapon_changed(weapon: WeaponData) -> void:
	ammo_label.visible = weapon != null


func _on_ammo_changed(in_magazine: int, reserve: int) -> void:
	var reserve_text := "∞" if reserve < 0 else str(reserve)
	ammo_label.text = "%d / %s" % [in_magazine, reserve_text]
