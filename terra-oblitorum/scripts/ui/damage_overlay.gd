extends CanvasLayer
## Экранные эффекты здоровья. Вешается на CanvasLayer внутри игрока.
## Всё создаёт сам в коде — дочерние узлы добавлять не нужно.
##   • красная вспышка по краям экрана при ударе;
##   • постоянная виньетка в «Осторожно», пульсирующая в «Опасности»;
##   • затемнение экрана при смерти;
##   • отладочная строка с HP в углу (потом выключим).

@export var health: Health  ## можно не заполнять — найдёт соседний узел «Health» сам

@export_group("Виньетка")
@export var tint := Color(0.5, 0.0, 0.0)
@export var hit_flash := 0.6           ## сила вспышки при ударе
@export var hit_fade_speed := 1.2      ## как быстро гаснет вспышка
@export var caution_intensity := 0.15
@export var danger_intensity := 0.4
@export var danger_pulse := 0.1        ## размах пульсации в «Опасности»

@export_group("Смерть")
@export var death_fade_time := 1.5

@export_group("Отладка")
@export var show_debug := true

const VIGNETTE_SHADER := """
shader_type canvas_item;
uniform vec4 tint : source_color = vec4(0.5, 0.0, 0.0, 1.0);
uniform float intensity = 0.0;
void fragment() {
	float dist = length(UV - vec2(0.5)) * 1.414;   // 0 в центре, 1 в углах
	float edge = smoothstep(0.3, 1.0, dist);
	COLOR = vec4(tint.rgb, edge * intensity);
}
"""

var _vignette: ColorRect
var _fade: ColorRect
var _debug_label: Label
var _material: ShaderMaterial
var _flash := 0.0
var _time := 0.0


func _ready() -> void:
	if health == null:
		health = get_parent().get_node_or_null("Health") as Health
	if health == null:
		push_error("DamageOverlay: не найден узел Health рядом")
		return

	_build_ui()
	health.damaged.connect(_on_damaged)
	health.health_changed.connect(_on_health_changed)
	health.state_changed.connect(_on_state_changed)
	health.died.connect(_on_died)
	_update_debug.call_deferred()  # после того как Health проинициализируется


func _build_ui() -> void:
	var shader := Shader.new()
	shader.code = VIGNETTE_SHADER
	_material = ShaderMaterial.new()
	_material.shader = shader
	_material.set_shader_parameter("tint", tint)

	_vignette = ColorRect.new()
	_vignette.material = _material
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE  # не перехватывать мышь!
	add_child(_vignette)

	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)

	_debug_label = Label.new()
	_debug_label.position = Vector2(16, 12)
	_debug_label.visible = show_debug
	add_child(_debug_label)


func _process(delta: float) -> void:
	if _material == null:
		return
	_time += delta
	_flash = move_toward(_flash, 0.0, hit_fade_speed * delta)

	var base := 0.0
	match health.state:
		Health.State.CAUTION:
			base = caution_intensity
		Health.State.DANGER:
			base = danger_intensity + sin(_time * 3.0) * danger_pulse  # «сердцебиение»
		Health.State.DEAD:
			base = danger_intensity

	_material.set_shader_parameter("intensity", clampf(base + _flash, 0.0, 1.0))


func _on_damaged(_amount: int, _source: Node) -> void:
	_flash = hit_flash


func _on_health_changed(_current: int, _max: int) -> void:
	_update_debug()


func _on_state_changed(_state: Health.State) -> void:
	_update_debug()


func _on_died() -> void:
	var tween := create_tween()
	tween.tween_interval(0.4)
	tween.tween_property(_fade, "color:a", 1.0, death_fade_time)


func _update_debug() -> void:
	if _debug_label and health:
		_debug_label.text = "HP %d/%d · %s" % [health.current, health.max_health,
				Health.state_name(health.state)]
