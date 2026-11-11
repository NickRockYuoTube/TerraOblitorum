extends RayCast3D
class_name InteractionRay
## Луч из камеры игрока. Ищет Interactable перед собой.

signal focus_changed(interactable: Interactable)

@export var interact_distance: float = 2.0
@export var prompt_format: String = "[E] %s"

@onready var player: Player = owner

var current: Interactable = null
var _last_prompt: String = ""


func _ready() -> void:
	target_position = Vector3(0.0, 0.0, -interact_distance)
	add_exception(player)


func _physics_process(_delta: float) -> void:
	var found: Interactable = null
	if is_colliding():
		found = Interactable.find_in(get_collider() as Node)
		if found and not found.enabled:
			found = null

	# Объект мог быть удалён (например, подобранный предмет)
	if not is_instance_valid(current):
		current = null

	if found != current:
		if current:
			current.unfocused.emit()
		current = found
		if current:
			current.focused.emit()
		focus_changed.emit(current)

	_update_prompt()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and current and player.can_move:
		current.interact(player)
		get_viewport().set_input_as_handled()


func _update_prompt() -> void:
	var text := ""
	if current and player.can_move and current.get_prompt() != "":
		text = prompt_format % current.get_prompt()
	if text != _last_prompt:
		_last_prompt = text
		GameEvents.interaction_prompt_changed.emit(text)
