extends Area3D
class_name DamageZone
## Зона урона: огонь, шипы, ядовитый газ. Наносит урон всем, у кого есть Health.

@export var damage: float = 10.0
@export var interval: float = 1.0       ## как часто бьёт, пока стоишь внутри
@export var instant_kill: bool = false  ## пропасть, мясорубка и т.п.

var _targets: Array[Health] = []
var _timer: float = 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node3D) -> void:
	var health := Health.find_in(body)
	if health and not _targets.has(health):
		_targets.append(health)
		_apply(health)
		_timer = interval


func _on_body_exited(body: Node3D) -> void:
	var health := Health.find_in(body)
	if health:
		_targets.erase(health)


func _physics_process(delta: float) -> void:
	if _targets.is_empty():
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = interval
		for health in _targets:
			_apply(health)


func _apply(health: Health) -> void:
	if instant_kill:
		health.kill()
	else:
		health.take_damage(damage)
