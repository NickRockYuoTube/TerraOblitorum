# res://scripts/ui/storage_ui.gd
extends Control
class_name StorageUI
## Окно сундука: слева инвентарь, справа хранилище.
## Клик по предмету перекладывает его на другую сторону.

@export var inventory_grid: GridContainer
@export var storage_grid: GridContainer
@export var name_label: Label
@export var description_label: Label
@export var slot_size: Vector2 = Vector2(80, 80)
@export var no_space_message: String = "Нет места"

var is_open: bool = false
var _inventory_buttons: Array[Button] = []
var _storage_buttons: Array[Button] = []


func _ready() -> void:
	if inventory_grid == null:
		inventory_grid = find_child("InventoryGrid", true, false) as GridContainer
	if storage_grid == null:
		storage_grid = find_child("StorageGrid", true, false) as GridContainer
	if name_label == null:
		name_label = find_child("NameLabel", true, false) as Label
	if description_label == null:
		description_label = find_child("DescriptionLabel", true, false) as Label
	if inventory_grid == null or storage_grid == null or name_label == null or description_label == null:
		push_error("StorageUI: не найдены InventoryGrid / StorageGrid / NameLabel / DescriptionLabel")
		set_process_unhandled_input(false)
		return

	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	Inventory.changed.connect(_refresh)
	Storage.changed.connect(_refresh)
	GameEvents.storage_requested.connect(open)
	_rebuild()


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("inventory") \
			or event.is_action_pressed("interact"):
		close()
		get_viewport().set_input_as_handled()


func open() -> void:
	if is_open or get_tree().paused:
		return
	is_open = true
	show()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	name_label.text = ""
	description_label.text = ""
	_refresh()


func close() -> void:
	is_open = false
	hide()
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# ---------- ЯЧЕЙКИ ----------
func _rebuild() -> void:
	_inventory_buttons = _build_grid(inventory_grid, Inventory, true)
	_storage_buttons = _build_grid(storage_grid, Storage, false)


func _build_grid(grid: GridContainer, container: ItemContainer, is_inventory: bool) -> Array[Button]:
	for child in grid.get_children():
		child.queue_free()
	var buttons: Array[Button] = []
	for i in container.capacity:
		var button := Button.new()
		button.custom_minimum_size = slot_size
		button.expand_icon = true
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.focus_mode = Control.FOCUS_NONE

		var amount_label := Label.new()
		amount_label.name = "Amount"
		amount_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		amount_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
		amount_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 4)
		button.add_child(amount_label)

		button.pressed.connect(_on_slot_pressed.bind(is_inventory, i))
		button.mouse_entered.connect(_show_details.bind(container, i))
		grid.add_child(button)
		buttons.append(button)
	return buttons


func _refresh() -> void:
	if _inventory_buttons.size() != Inventory.capacity or _storage_buttons.size() != Storage.capacity:
		_rebuild()
	_fill(_inventory_buttons, Inventory)
	_fill(_storage_buttons, Storage)


func _fill(buttons: Array[Button], container: ItemContainer) -> void:
	for i in buttons.size():
		var button := buttons[i]
		var stack := container.slots[i]
		var amount_label := button.get_node("Amount") as Label
		if stack:
			button.icon = stack.item.icon
			button.text = "" if stack.item.icon else stack.item.display_name
			amount_label.text = str(stack.amount) if stack.amount > 1 else ""
		else:
			button.icon = null
			button.text = ""
			amount_label.text = ""


func _show_details(container: ItemContainer, index: int) -> void:
	var stack := container.slots[index]
	if stack:
		name_label.text = stack.item.display_name
		description_label.text = stack.item.description
	else:
		name_label.text = ""
		description_label.text = ""


func _on_slot_pressed(is_inventory: bool, index: int) -> void:
	var from: ItemContainer = Inventory if is_inventory else Storage
	var to: ItemContainer = Storage if is_inventory else Inventory
	if from.slots[index] == null:
		return
	if not from.transfer_to(index, to):
		GameEvents.show_message(no_space_message)
	_show_details(from, index)
