# res://scripts/ui/inventory_ui.gd
extends Control
class_name InventoryUI
## Окно инвентаря. Открывается по действию "inventory", ставит игру на паузу.

@export var grid: GridContainer
@export var name_label: Label
@export var description_label: Label
@export var use_button: Button            ## необязательно
@export var drop_button: Button           ## необязательно
@export var status_label: Label           ## необязательно: состояние здоровья
@export var slot_size: Vector2 = Vector2(96, 96)
@export var pause_game: bool = true

@export_group("Drop")
@export var drop_pickup_scene: PackedScene   ## сцена Pickup, в которой предмет ляжет на пол
@export var drop_distance: float = 1.0
@export var cannot_drop_message: String = "Это нельзя выбросить"
@export var dropped_message: String = "Выброшено: %s"

@export_group("Health Status")
@export var status_fine: String = "Состояние: Отлично"
@export var status_caution: String = "Состояние: Осторожно"
@export var status_danger: String = "Состояние: Опасность"
@export var color_fine: Color = Color(0.4, 0.8, 0.4)
@export var color_caution: Color = Color(0.9, 0.75, 0.2)
@export var color_danger: Color = Color(0.85, 0.2, 0.2)

var is_open: bool = false
var _buttons: Array[Button] = []
var _selected: int = -1
var _health_ratio: float = 1.0


func _ready() -> void:
	if grid == null:
		grid = _find("Grid", "GridContainer") as GridContainer
	if name_label == null:
		name_label = _find("NameLabel", "Label") as Label
	if description_label == null:
		description_label = _find("DescriptionLabel", "Label") as Label
	if use_button == null:
		use_button = find_child("UseButton", true, false) as Button
	if drop_button == null:
		drop_button = find_child("DropButton", true, false) as Button
	if status_label == null:
		status_label = find_child("StatusLabel", true, false) as Label
	if grid == null or name_label == null or description_label == null:
		set_process_unhandled_input(false)
		return

	process_mode = Node.PROCESS_MODE_ALWAYS  # работает даже на паузе
	hide()
	Inventory.changed.connect(_refresh)
	GameEvents.player_health_changed.connect(_on_player_health_changed)
	if use_button:
		use_button.pressed.connect(_on_use_pressed)
	if drop_button:
		drop_button.pressed.connect(_on_drop_pressed)
	_build_slots()
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory") and (is_open or not get_tree().paused):
		toggle()
		get_viewport().set_input_as_handled()
	elif is_open and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	if is_open:
		close()
	else:
		open()


func open() -> void:
	is_open = true
	show()
	if pause_game:
		get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh()
	if not _buttons.is_empty():
		_buttons[0].grab_focus()
		_select(0)


func close() -> void:
	is_open = false
	hide()
	if pause_game:
		get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# ---------- ЯЧЕЙКИ ----------
func _build_slots() -> void:
	for child in grid.get_children():
		child.queue_free()
	_buttons.clear()

	for i in Inventory.capacity:
		var button := Button.new()
		button.custom_minimum_size = slot_size
		button.expand_icon = true
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

		# Счётчик количества в правом нижнем углу ячейки
		var amount_label := Label.new()
		amount_label.name = "Amount"
		amount_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		amount_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
		amount_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 6)
		button.add_child(amount_label)

		# Клик или выбор с клавиатуры выделяет ячейку, наведение просто показывает описание
		button.focus_entered.connect(_select.bind(i))
		button.mouse_entered.connect(_show_details.bind(i))
		button.mouse_exited.connect(_on_slot_mouse_exited)
		grid.add_child(button)
		_buttons.append(button)


func _refresh() -> void:
	if _buttons.size() != Inventory.capacity:
		_build_slots()

	for i in _buttons.size():
		var button := _buttons[i]
		var stack := Inventory.slots[i]
		var amount_label := button.get_node("Amount") as Label
		if stack:
			button.icon = stack.item.icon
			# Нет иконки — показываем название текстом
			button.text = "" if stack.item.icon else stack.item.display_name
			amount_label.text = str(stack.amount) if stack.amount > 1 else ""
		else:
			button.icon = null
			button.text = ""
			amount_label.text = ""

	if _selected >= 0:
		_show_details(_selected)
	_update_buttons()
	_update_status()


func _select(index: int) -> void:
	_selected = index
	_show_details(index)
	_update_buttons()


func _on_slot_mouse_exited() -> void:
	if _selected >= 0:
		_show_details(_selected)


func _show_details(index: int) -> void:
	var stack := Inventory.slots[index]
	if stack:
		name_label.text = stack.item.display_name
		description_label.text = stack.item.description
	else:
		name_label.text = ""
		description_label.text = ""


# ---------- КНОПКИ ----------
func _selected_stack() -> ItemStack:
	if _selected < 0 or _selected >= Inventory.slots.size():
		return null
	return Inventory.slots[_selected]


func _update_buttons() -> void:
	var stack := _selected_stack()
	if use_button:
		var effect: ItemEffect = stack.item.use_effect if stack else null
		use_button.disabled = effect == null
		use_button.text = effect.get_use_text() if effect else "Использовать"
	if drop_button:
		drop_button.disabled = stack == null


func _on_use_pressed() -> void:
	if _selected < 0:
		return
	Inventory.use_item(_selected)
	_buttons[_selected].grab_focus()  # вернуть фокус на ячейку


func _on_drop_pressed() -> void:
	var stack := _selected_stack()
	if stack == null:
		return
	if not stack.item.can_discard:
		GameEvents.show_message(cannot_drop_message)
		return
	if drop_pickup_scene == null:
		push_error("InventoryUI: не назначена Drop Pickup Scene (сцена Pickup)")
		return
	var player := get_tree().get_first_node_in_group("player") as Player
	if player == null:
		return

	var item := stack.item
	var amount := Inventory.remove_at(_selected, stack.amount)
	_spawn_drop(item, amount, player)
	GameEvents.show_message(dropped_message % item.display_name)
	_buttons[_selected].grab_focus()


## Кладёт предмет на пол перед игроком
func _spawn_drop(item: ItemData, amount: int, player: Player) -> void:
	var pickup := drop_pickup_scene.instantiate() as Node3D
	if pickup is Pickup:
		pickup.item = item
		pickup.amount = amount

	var space := player.get_world_3d().direct_space_state
	var forward := -player.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var chest := player.global_position + Vector3.UP * 1.0
	var spot := chest + forward * drop_distance

	# Не класть за стену: если впереди стена, кладём перед ней
	var wall_query := PhysicsRayQueryParameters3D.create(chest, spot)
	wall_query.exclude = [player.get_rid()]
	var wall_hit := space.intersect_ray(wall_query)
	if not wall_hit.is_empty():
		spot = wall_hit.position - forward * 0.3

	# Опускаем на пол
	var floor_query := PhysicsRayQueryParameters3D.create(spot, spot + Vector3.DOWN * 3.0)
	floor_query.exclude = [player.get_rid()]
	var floor_hit := space.intersect_ray(floor_query)
	var drop_position := player.global_position
	if not floor_hit.is_empty():
		drop_position = floor_hit.position

	get_tree().current_scene.add_child(pickup)
	pickup.global_position = drop_position


# ---------- СОСТОЯНИЕ ЗДОРОВЬЯ ----------
func _on_player_health_changed(current: float, max_value: float) -> void:
	_health_ratio = current / max_value
	_update_status()


func _update_status() -> void:
	if status_label == null:
		return
	var text := status_fine
	var color := color_fine
	if _health_ratio <= 0.33:
		text = status_danger
		color = color_danger
	elif _health_ratio <= 0.66:
		text = status_caution
		color = color_caution
	status_label.text = text
	status_label.add_theme_color_override("font_color", color)


## Ищет узел по имени и проверяет его тип, объясняя ошибку
func _find(node_name: String, type_name: String) -> Node:
	var node := find_child(node_name, true, false)
	if node == null:
		push_error("InventoryUI: нет узла с именем '%s'" % node_name)
		return null
	if not node.is_class(type_name):
		push_error("InventoryUI: узел '%s' должен быть типа %s, а сейчас %s" % [node_name, type_name, node.get_class()])
		return null
	return node
