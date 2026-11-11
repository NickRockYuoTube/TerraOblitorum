# res://scripts/puzzles/code_lock.gd
extends PuzzleElement
class_name CodeLock
## Кодовый замок. При взаимодействии открывает цифровую панель.

@export var interactable: Interactable
@export var code: String = "1234"          ## только цифры
@export var title: String = "Кодовый замок"
@export var prompt_text: String = "Ввести код"
@export var wrong_message: String = "Неверный код"
@export var wrong_sound: AudioStream
@export var button_sound: AudioStream


func _ready() -> void:
	super._ready()
	interactable.prompt_text = prompt_text
	interactable.interacted.connect(_on_interacted)


func _on_interacted(_player: Player) -> void:
	if not is_solved:
		GameEvents.open_code_lock(self)


## Проверка кода. Вызывает окно замка.
func submit_code(entered: String) -> bool:
	if entered == code:
		interactable.enabled = false
		_set_solved(true)
		return true
	GameEvents.show_message(wrong_message)
	_play(wrong_sound)
	return false


func play_button_sound() -> void:
	_play(button_sound)
