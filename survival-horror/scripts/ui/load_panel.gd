# res://scripts/ui/load_panel.gd
extends VBoxContainer
class_name LoadPanel
## Панель загрузки: список слотов. Используется в главном меню и в паузе.

signal back_pressed

@export var slot_size: Vector2 = Vector2(460, 48)
@export var empty_slot_text: String = "Пусто"


func _ready() -> void:
	add_theme_constant_override("separation", 12)
	refresh()


## Пересобрать список (вызывать при каждом открытии)
func refresh() -> void:
	# Убираем старые элементы сразу, а не в конце кадра
	for child in get_children():
		remove_child(child)
		child.queue_free()

	var title := Label.new()
	title.text = "Загрузить игру"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	add_child(title)

	for i in SaveManager.slot_count:
		var info := SaveManager.get_slot_info(i)
		var button := Button.new()
		button.custom_minimum_size = slot_size
		if info.is_empty():
			button.text = "Слот %d   —   %s" % [i + 1, empty_slot_text]
			button.disabled = true
		else:
			button.text = "Слот %d   —   %s   •   %s" % [i + 1, info.level_name, info.datetime]
		button.pressed.connect(_on_slot_pressed.bind(i))
		add_child(button)

	var back := Button.new()
	back.text = "Назад"
	back.custom_minimum_size = Vector2(320, 48)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func() -> void: back_pressed.emit())
	add_child(back)


func focus_first() -> void:
	for child in get_children():
		if child is Button and not child.disabled:
			child.grab_focus()
			return


func _on_slot_pressed(slot: int) -> void:
	SaveManager.load_game(slot)
