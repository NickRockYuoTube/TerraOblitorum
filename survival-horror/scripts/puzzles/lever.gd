# res://scripts/puzzles/lever.gd
extends PuzzleElement
class_name Lever
## Рычаг или выключатель. Решён, когда находится в нужном положении.

@export var interactable: Interactable
@export var handle: Node3D                 ## что поворачивается (ручка рычага)
@export var on_angle: float = -45.0        ## поворот ручки по X во включённом положении
@export var off_angle: float = 45.0
@export var move_time: float = 0.3
@export var start_on: bool = false
@export var required_state: bool = true    ## в каком положении рычаг считается «правильным»
@export var one_shot: bool = false         ## после первого переключения больше не двигается
@export var prompt_text: String = "Переключить"
@export var toggle_sound: AudioStream

var is_on: bool = false


func _ready() -> void:
	super._ready()
	is_on = start_on
	is_solved = is_on == required_state   # без вызова целей при старте
	if handle:
		handle.rotation_degrees.x = on_angle if is_on else off_angle
	interactable.prompt_text = prompt_text
	interactable.interacted.connect(_on_interacted)


func _on_interacted(_player: Player) -> void:
	is_on = not is_on
	if handle:
		var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tween.tween_property(handle, "rotation_degrees:x", on_angle if is_on else off_angle, move_time)
	_play(toggle_sound)
	if one_shot:
		interactable.enabled = false
	_set_solved(is_on == required_state)
