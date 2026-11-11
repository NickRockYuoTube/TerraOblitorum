extends Node
## Блокнот игрока. Добавлен в Autoload под именем Journal.

signal note_added(note: NoteData)
signal changed

var notes: Array[NoteData] = []


## Добавляет запись. Возвращает false, если она уже есть.
func add_note(note: NoteData) -> bool:
	if note == null or has_note(note.id):
		return false
	notes.append(note)
	note_added.emit(note)
	changed.emit()
	return true


func has_note(id: String) -> bool:
	for note in notes:
		if note.id == id:
			return true
	return false


## Очистить блокнот (новая игра, рестарт)
func clear() -> void:
	notes.clear()
	changed.emit()
