extends Area3D
## Тестовая зона: пока игрок внутри, раз в interval секунд наносит урон
## (или лечит, если стоит галочка heal). Нужна только для проверки здоровья.
## Удары врагов из GDD: Искажённый 20, укус Хулеоса 20, плевок Хулеоса 40.
## Жидкость лечит 24.

@export var amount := 20
@export var heal := false
@export var interval := 1.5

var _target: Node = null
var _timer := 0.0


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_target = body
		_apply()
		_timer = interval


func _on_body_exited(body: Node) -> void:
	if body == _target:
		_target = null


func _process(delta: float) -> void:
	if _target == null:
		return
	_timer -= delta
	if _timer <= 0.0:
		_apply()
		_timer = interval


func _apply() -> void:
	var health := _target.get_node_or_null("Health") as Health
	if health == null:
		return
	if heal:
		health.heal(amount)
	else:
		health.take_damage(amount, self)
