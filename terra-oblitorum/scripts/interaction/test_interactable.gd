extends StaticBody3D
## Тестовый объект для проверки E: печатает в «Вывод» и поворачивается.
## Повесь на StaticBody3D (с CollisionShape3D и мешем внутри).

@export var interact_text := "Осмотреть"


func get_interact_text() -> String:
	return interact_text


func interact(_player: Node) -> void:
	print("Взаимодействие с: ", name)
	var tween := create_tween()
	tween.tween_property(self, "rotation:y", rotation.y + PI * 0.5, 0.25)
