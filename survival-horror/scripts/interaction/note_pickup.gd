extends Node3D
class_name NotePickup
## Записка в мире. При взаимодействии открывается и попадает в блокнот.

signal read(note: NoteData)

@export var interactable: Interactable
@export var note: NoteData
@export var read_prompt: String = "Читать"
@export var take_from_world: bool = false   ## true = записка исчезает после прочтения
@export var added_message: String = "Добавлено в блокнот: %s"


func _ready() -> void:
	if note == null:
		push_warning("NotePickup '%s': не назначена записка (note)" % name)
		return
	interactable.prompt_text = read_prompt
	interactable.interacted.connect(_on_interacted)


func _on_interacted(_player: Player) -> void:
	var is_new := Journal.add_note(note)
	GameEvents.open_note(note)
	if is_new:
		GameEvents.show_message(added_message % note.title)
	read.emit(note)
	if take_from_world:
		queue_free()
