# res://core/game_events.gd
extends Node
## Глобальная шина событий.
## Добавлена в Autoload под именем GameEvents.

@warning_ignore("unused_signal")
signal interaction_prompt_changed(text: String)
signal message_requested(text: String, duration: float)
signal note_open_requested(note: NoteData)

@warning_ignore("unused_signal")
signal player_health_changed(current: float, max_value: float)
@warning_ignore("unused_signal")
signal player_damaged(amount: float)
@warning_ignore("unused_signal")
signal player_died

@warning_ignore("unused_signal")
signal weapon_changed(weapon: WeaponData)       ## null = оружие убрано
@warning_ignore("unused_signal")
signal ammo_changed(in_magazine: int, reserve: int)  ## reserve = -1 значит бесконечно

signal noise_emitted(position: Vector3, radius: float)  ## враги слышат шум в этом радиусе
signal code_lock_requested(lock: CodeLock)
signal storage_requested
signal save_requested(point: SavePoint)


func show_message(text: String, duration: float = 2.5) -> void:
	message_requested.emit(text, duration)


func open_note(note: NoteData) -> void:
	note_open_requested.emit(note)


## Произвести шум: выстрел, бег, упавший предмет, разбитое стекло
func make_noise(position: Vector3, radius: float) -> void:
	noise_emitted.emit(position, radius)


func open_code_lock(lock: CodeLock) -> void:
	code_lock_requested.emit(lock)


func open_storage() -> void:
	storage_requested.emit()


func open_save(point: SavePoint) -> void:
	save_requested.emit(point)
