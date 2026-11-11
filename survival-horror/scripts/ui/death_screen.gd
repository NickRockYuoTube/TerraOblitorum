# res://scripts/ui/death_screen.gd
extends Control
class_name DeathScreen
## Экран смерти. Загружает последнее сохранение или начинает уровень заново.

@export var restart_button: Button
@export var fade_time: float = 2.0
@export var load_text: String = "Загрузить сохранение"
@export var restart_text: String = "Начать заново"


func _ready() -> void:
	if restart_button == null:
		restart_button = find_child("RestartButton", true, false) as Button
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	modulate.a = 0.0
	GameEvents.player_died.connect(_on_player_died)
	if restart_button:
		restart_button.pressed.connect(_on_restart_pressed)


func _on_player_died() -> void:
	if restart_button:
		restart_button.text = load_text if SaveManager.has_any_save() else restart_text
	show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, fade_time)
	tween.tween_callback(_pause_game)
	if restart_button:
		restart_button.grab_focus()


func _pause_game() -> void:
	get_tree().paused = true


func _on_restart_pressed() -> void:
	var slot := SaveManager.get_latest_slot()
	if slot >= 0:
		SaveManager.load_game(slot)
	else:
		SaveManager.restart_level()
