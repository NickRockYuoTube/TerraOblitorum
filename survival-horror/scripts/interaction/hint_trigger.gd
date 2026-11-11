extends Area3D
class_name HintTrigger
## Невидимая зона: когда игрок входит, в блокнот добавляется подсказка.

@export var note: NoteData
@export var message: String = "Блокнот обновлён"


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if not body is Player or note == null:
		return
	if Journal.add_note(note):
		GameEvents.show_message(message)
	set_deferred("monitoring", false)  # срабатывает один раз
