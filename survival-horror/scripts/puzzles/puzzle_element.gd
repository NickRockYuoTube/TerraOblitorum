# res://scripts/puzzles/puzzle_element.gd
extends Node3D
class_name PuzzleElement
## Базовый элемент головоломки. Когда решён — вызывает метод у всех целей.

signal solved
signal state_changed(is_solved: bool)

@export_group("On Solved")
@export var targets: Array[Node] = []      ## двери, объекты, преграды
@export var target_method: String = "unlock"  ## unlock, open, show, hide, queue_free...
@export var solve_message: String = ""
@export var reward_note: NoteData          ## запись в блокнот в награду
@export var solve_sound: AudioStream

var is_solved: bool = false
var _audio: AudioStreamPlayer3D


func _ready() -> void:
	_audio = AudioStreamPlayer3D.new()
	_audio.process_mode = Node.PROCESS_MODE_ALWAYS  # звук играет и на паузе (в окне замка)
	add_child(_audio)


func _set_solved(value: bool) -> void:
	if is_solved == value:
		return
	is_solved = value
	state_changed.emit(is_solved)
	if is_solved:
		_on_solved()


func _on_solved() -> void:
	solved.emit()
	for target in targets:
		if target == null:
			continue
		if target.has_method(target_method):
			target.call(target_method)
		else:
			push_warning("%s: у цели '%s' нет метода '%s'" % [name, target.name, target_method])

	var note_added := reward_note != null and Journal.add_note(reward_note)
	if solve_message != "":
		GameEvents.show_message(solve_message)
	elif note_added:
		GameEvents.show_message("Блокнот обновлён")
	_play(solve_sound)


func _play(stream: AudioStream) -> void:
	if stream:
		_audio.stream = stream
		_audio.play()
