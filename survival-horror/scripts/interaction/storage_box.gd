# res://scripts/interaction/storage_box.gd
extends Node3D
class_name StorageBox
## Сундук. Все сундуки открывают одно общее хранилище (Storage).

@export var interactable: Interactable
@export var prompt_text: String = "Открыть сундук"
@export var open_sound: AudioStream

var _audio: AudioStreamPlayer3D


func _ready() -> void:
	if interactable == null:
		interactable = Interactable.find_in(self)
	interactable.prompt_text = prompt_text
	interactable.interacted.connect(_on_interacted)
	_audio = AudioStreamPlayer3D.new()
	_audio.process_mode = Node.PROCESS_MODE_ALWAYS  # звук не глохнет из-за паузы
	add_child(_audio)


func _on_interacted(_player: Player) -> void:
	if open_sound:
		_audio.stream = open_sound
		_audio.play()
	GameEvents.open_storage()
