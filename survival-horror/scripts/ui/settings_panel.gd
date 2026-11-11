# res://scripts/ui/settings_panel.gd
extends VBoxContainer
class_name SettingsPanel
## Панель настроек. Строится кодом, используется в главном меню и в паузе.

signal back_pressed

@export var label_width: float = 280.0
@export var slider_width: float = 240.0


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	refresh()


## Пересобрать панель с актуальными значениями
func refresh() -> void:
	# Убираем старые элементы сразу, а не в конце кадра
	for child in get_children():
		remove_child(child)
		child.queue_free()

	_add_title("Настройки")
	_add_slider("Чувствительность мыши", 1.0, 10.0, 0.5, Settings.mouse_sensitivity / 0.0005,
		func(v: float) -> void: Settings.set_setting("mouse_sensitivity", v * 0.0005))
	_add_slider("Поле зрения", 60.0, 100.0, 1.0, Settings.fov,
		func(v: float) -> void: Settings.set_setting("fov", v))
	_add_slider("Громкость", 0.0, 100.0, 1.0, Settings.master_volume * 100.0,
		func(v: float) -> void: Settings.set_setting("master_volume", v / 100.0))
	_add_check("Покачивание камеры", Settings.head_bob,
		func(on: bool) -> void: Settings.set_setting("head_bob", on))
	_add_check("Полноэкранный режим", Settings.fullscreen,
		func(on: bool) -> void: Settings.set_setting("fullscreen", on))
	_add_check("Вертикальная синхронизация", Settings.vsync,
		func(on: bool) -> void: Settings.set_setting("vsync", on))

	var back := Button.new()
	back.text = "Назад"
	back.custom_minimum_size = Vector2(320, 48)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(_on_back_pressed)
	add_child(back)


func focus_first() -> void:
	for child in get_children():
		if child is HBoxContainer and child.get_child_count() > 1:
			(child.get_child(1) as Control).grab_focus()
			return


func _on_back_pressed() -> void:
	Settings.save_settings()
	back_pressed.emit()


func _add_title(text: String) -> void:
	var title := Label.new()
	title.text = text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	add_child(title)


func _add_slider(text: String, min_value: float, max_value: float, step: float,
		value: float, on_change: Callable) -> void:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = text
	label.custom_minimum_size.x = label_width

	var slider := HSlider.new()
	slider.min_value = min_value
	slider.max_value = max_value
	slider.step = step
	slider.value = value
	slider.custom_minimum_size.x = slider_width
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var value_label := Label.new()
	value_label.custom_minimum_size.x = 50
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.text = _format(value, step)

	# Подключаем после установки значения, чтобы не сработало при открытии
	slider.value_changed.connect(func(v: float) -> void:
		value_label.text = _format(v, step)
		on_change.call(v))

	row.add_child(label)
	row.add_child(slider)
	row.add_child(value_label)
	add_child(row)


func _add_check(text: String, value: bool, on_change: Callable) -> void:
	var row := HBoxContainer.new()
	var label := Label.new()
	label.text = text
	label.custom_minimum_size.x = label_width
	var check := CheckBox.new()
	check.button_pressed = value
	check.toggled.connect(on_change)
	row.add_child(label)
	row.add_child(check)
	add_child(row)


func _format(value: float, step: float) -> String:
	if step < 1.0:
		return "%.1f" % value
	return str(int(round(value)))
