# res://scripts/components/destructible.gd
extends Node
class_name Destructible
## Разрушает родительский объект, когда его здоровье кончается.
## Может оставить после себя предмет (например, патроны из ящика).

@export var health: Health
@export var drop_scene: PackedScene  ## сцена, которая появится на месте объекта


func _ready() -> void:
	if health == null:
		health = Health.find_in(get_parent())
	if health:
		health.died.connect(_on_died)
	else:
		push_warning("Destructible: рядом нет компонента Health")


func _on_died() -> void:
	var target := get_parent() as Node3D
	if target == null:
		return
	if drop_scene:
		var drop := drop_scene.instantiate() as Node3D
		drop.transform = target.transform  # тот же родитель, значит та же позиция
		target.get_parent().add_child.call_deferred(drop)
	target.queue_free()
