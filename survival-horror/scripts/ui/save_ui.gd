# res://scripts/ui/save_ui.gd
extends Control
class_name SaveUI
## Окно сохранения: список слотов.

@export var title_label: Label
@export var slots_container: VBoxContainer
@export var cancel_button: Button
@export var slot_size: Vector2 = Vector2(460, 48)
@export var empty_slot_text: String = "Пусто"
@export var saved_message: String = "Игра сохранена"

var is_open: bool = false
var _point: SavePoint


func _ready() -> void:
	if title_label == null:
		title_label = find_child("TitleLabel", true, false) as Label
	if slots_container == null:
		slots_container = find_child("Slots", true, false) as VBoxContainer
	if cancel_button == null:
		cancel_button = find_child("CancelButton", true, false) as Button
	if slots_container == null:
		push_error("SaveUI: не найден узел Slots (VBoxContainer)")
		set_process_unhandled_input(false)
		return

	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	GameEvents.save_requested.connect(open)
	if cancel_button:
		cancel_button.pressed.connect(close)


func _unhandled_input(event: InputEvent) -> void:
	if is_open and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("interact")):
		close()
		get_viewport().set_input_as_handled()


func open(point: SavePoint) -> void:
	if is_open or get_tree().paused:
		return
	_point = point
	_build_slots()
	is_open = true
	show()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close() -> void:
	is_open = false
	hide()
	_point = null
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _build_slots() -> void:
	for child in slots_container.get_children():
		child.queue_free()
	for i in SaveManager.slot_count:
		var info := SaveManager.get_slot_info(i)
		var button := Button.new()
		button.custom_minimum_size = slot_size
		button.text = "Слот %d   —   %s" % [i + 1, _describe(info)]
		button.pressed.connect(_on_slot_pressed.bind(i))
		slots_container.add_child(button)


func _describe(info: Dictionary) -> String:
	if info.is_empty():
		return empty_slot_text
	return "%s   •   %s" % [info.level_name, info.datetime]


func _on_slot_pressed(slot: int) -> void:
	if _point and not _point.consume_cost():
		close()
		return
	if SaveManager.save_game(slot):
		GameEvents.show_message(saved_message)
	close()
