# res://scripts/weapons/weapon_data.gd
extends Resource
class_name WeaponData
## Параметры оружия. Создаётся как ресурс .tres и заполняется в инспекторе.

@export var id: String = ""                ## уникальный ID, например "pistol"
@export var display_name: String = "Оружие"

@export_group("Damage")
@export var damage: float = 25.0           ## урон одной пули (дробины)
@export_range(1, 20) var pellets: int = 1  ## дробовик: 6–10
@export var max_range: float = 50.0
@export var impact_force: float = 3.0      ## толчок физических предметов

@export_group("Firing")
@export var automatic: bool = false        ## стрелять, пока зажата кнопка
@export var fire_rate: float = 3.0         ## выстрелов в секунду
@export var hip_spread: float = 3.0        ## разброс без прицеливания (градусы)
@export var aim_spread: float = 0.5        ## разброс при прицеливании (градусы)
@export var recoil: float = 2.0            ## подброс камеры при выстреле (градусы)
@export var noise_radius: float = 25.0     ## на каком расстоянии враги слышат выстрел

@export_group("Ammo")
@export var ammo_item: ItemData            ## пусто = бесконечные патроны
@export var magazine_size: int = 8
@export var starting_loaded: int = 8       ## сколько патронов в магазине при первой экипировке
@export var reload_time: float = 1.6
@export var auto_reload: bool = true       ## перезаряжать автоматически при пустом магазине

@export_group("Aiming")
@export var aim_fov: float = 55.0          ## поле зрения при прицеливании

@export_group("Visuals")
@export var view_model: PackedScene        ## модель в руках; пусто = серый брусок-заглушка
@export var view_position: Vector3 = Vector3(0.25, -0.22, -0.5)
@export var aim_position: Vector3 = Vector3(0.0, -0.15, -0.4)
@export var muzzle_offset: Vector3 = Vector3(0.0, 0.03, -0.3)  ## где вспышка выстрела
@export var impact_scene: PackedScene      ## эффект попадания; пусто = простая «дырка»

@export_group("Sounds")
@export var fire_sound: AudioStream
@export var reload_sound: AudioStream
@export var empty_sound: AudioStream
