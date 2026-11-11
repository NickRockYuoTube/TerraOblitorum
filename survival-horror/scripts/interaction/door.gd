extends Node3D
class_name Door
## Дверь на петле. Hinge должен быть AnimatableBody3D.

signal opened
signal closed
signal locked_attempt
signal unlocked

@export_group("Nodes")
@export var hinge: Node3D
@export var interactable: Interactable

@export_group("Motion")
@export var open_angle: float = 95.0
@export var open_time: float = 0.9
@export var open_away_from_player: bool = true
@export var start_open: bool = false

@export_group("Lock")
@export var locked: bool = false
@export var required_key: ItemData        ## пусто = открывается только через unlock()
@export var consume_key: bool = true      ## забрать ключ после использования
@export_multiline var locked_message: String = "Заперто."
@export var unlock_message: String = "Использовано: %s"

@export_group("Text")
@export var open_prompt: String = "Открыть"
@export var close_prompt: String = "Закрыть"

@export_group("Sounds")
@export var open_sound: AudioStream
@export var close_sound: AudioStream
@export var locked_sound: AudioStream
@export var unlock_sound: AudioStream

var is_open: bool = false
var _busy: bool = false
var _audio: AudioStreamPlayer3D


func _ready() -> void:
	_audio = AudioStreamPlayer3D.new()
	add_child(_audio)
	interactable.interacted.connect(_on_interacted)
	if start_open:
		is_open = true
		hinge.rotation_degrees.y = open_angle
	_update_prompt()


func _on_interacted(player: Player) -> void:
	if _busy:
		return
	if locked:
		if required_key and Inventory.has_item(required_key.id):
			_unlock_with_key()
		else:
			_play(locked_sound)
			GameEvents.show_message(locked_message)
			locked_attempt.emit()
		return
	if is_open:
		close()
	else:
		open(player)


func _unlock_with_key() -> void:
	if consume_key:
		Inventory.remove_item(required_key.id)
	_play(unlock_sound)
	GameEvents.show_message(unlock_message % required_key.display_name)
	unlock()


func open(player: Player = null) -> void:
	var direction := 1.0
	if open_away_from_player and player:
		var local := to_local(player.global_position)
		direction = 1.0 if local.z > 0.0 else -1.0
	is_open = true
	_rotate_to(open_angle * direction)
	_play(open_sound)
	_update_prompt()
	opened.emit()


func close() -> void:
	is_open = false
	_rotate_to(0.0)
	_play(close_sound)
	_update_prompt()
	closed.emit()


## Отпереть без ключа (головоломки, рычаги, сюжет)
func unlock() -> void:
	if not locked:
		return
	locked = false
	unlocked.emit()


func _rotate_to(angle: float) -> void:
	_busy = true
	var tween := create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.set_process_mode(Tween.TWEEN_PROCESS_PHYSICS)
	tween.tween_property(hinge, "rotation_degrees:y", angle, open_time)
	tween.finished.connect(_on_tween_finished)


func _on_tween_finished() -> void:
	_busy = false


func _update_prompt() -> void:
	interactable.prompt_text = close_prompt if is_open else open_prompt


func _play(stream: AudioStream) -> void:
	if stream:
		_audio.stream = stream
		_audio.play()
