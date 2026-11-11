# res://scripts/ui/code_lock_ui.gd
extends Control
class_name CodeLockUI
## Окно кодового замка: цифровая панель. Цифры можно вводить и с клавиатуры.

@export var title_label: Label
@export var display_label: Label
@export var buttons_grid: GridContainer
@export var button_size: Vector2 = Vector2(72, 72)
@export var auto_submit: bool = true       ## проверять код сразу, как только введены все цифры
@export var wrong_color: Color = Color(0.9, 0.2, 0.2)

var is_open: bool = false
var _lock: CodeLock
var _entered: String = ""


func _ready() -> void:
	if title_label == null:
		title_label = find_child("TitleLabel", true, false) as Label
	if display_label == null:
		display_label = find_child("Display", true, false) as Label
	if buttons_grid == null:
		buttons_grid = find_child("Buttons", true, false) as GridContainer
	if title_label == null or display_label == null or buttons_grid == null:
		push_error("CodeLockUI: не найдены узлы TitleLabel / Display / Buttons")
		set_process_unhandled_input(false)
		return

	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	GameEvents.code_lock_requested.connect(open)
	_build_buttons()


func _build_buttons() -> void:
	for child in buttons_grid.get_children():
		child.queue_free()
	buttons_grid.columns = 3
	for key in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "C", "0", "OK"]:
		var button := Button.new()
		button.text = key
		button.custom_minimum_size = button_size
		button.focus_mode = Control.FOCUS_NONE  # чтобы Enter/пробел не нажимали кнопки
		button.pressed.connect(_on_key.bind(key))
		buttons_grid.add_child(button)


func open(lock: CodeLock) -> void:
	if is_open:
		return
	_lock = lock
	_entered = ""
	title_label.text = lock.title
	_update_display()
	is_open = true
	show()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	is_open = false
	hide()
	_lock = null
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var key_event := event as InputEventKey
		if key_event.keycode == KEY_BACKSPACE:
			_entered = _entered.left(_entered.length() - 1)
			_update_display()
		elif key_event.keycode == KEY_ENTER or key_event.keycode == KEY_KP_ENTER:
			_submit()
		elif key_event.unicode >= 48 and key_event.unicode <= 57:  # цифры 0–9
			_on_key(char(key_event.unicode))
		else:
			return
		get_viewport().set_input_as_handled()


func _on_key(key: String) -> void:
	if _lock == null:
		return
	_lock.play_button_sound()
	match key:
		"C":
			_entered = ""
		"OK":
			_submit()
			return
		_:
			if _entered.length() < _lock.code.length():
				_entered += key
	_update_display()
	if auto_submit and _entered.length() == _lock.code.length():
		_submit()


func _submit() -> void:
	if _lock == null:
		return
	if _lock.submit_code(_entered):
		close()
		return
	# Неверно: дисплей мигает красным и сбрасывается
	_entered = ""
	display_label.modulate = wrong_color
	var tween := create_tween()
	tween.tween_property(display_label, "modulate", Color.WHITE, 0.5)
	_update_display()


func _update_display() -> void:
	var parts: PackedStringArray = []
	for i in _lock.code.length():
		parts.append(_entered[i] if i < _entered.length() else "_")
	display_label.text = " ".join(parts)
