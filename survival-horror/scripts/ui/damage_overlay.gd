extends ColorRect
class_name DamageOverlay
## Красная виньетка: вспышка при уроне и пульсация при низком здоровье.

@export var tint: Color = Color(0.5, 0.0, 0.0)
@export var flash_strength: float = 0.7        ## сила вспышки при ударе
@export var flash_fade_speed: float = 1.5      ## как быстро гаснет вспышка
@export_range(0.0, 1.0) var low_health_ratio: float = 0.35  ## ниже этого — края краснеют
@export var low_health_strength: float = 0.5
@export var pulse_speed: float = 4.0

const SHADER_CODE := """
shader_type canvas_item;
uniform vec4 tint : source_color = vec4(0.5, 0.0, 0.0, 1.0);
uniform float intensity = 0.0;
void fragment() {
	float d = distance(UV, vec2(0.5));
	float v = smoothstep(0.25, 0.75, d);
	COLOR = vec4(tint.rgb, v * intensity);
}
"""

var _flash: float = 0.0
var _low_health: float = 0.0
var _time: float = 0.0
var _material: ShaderMaterial


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shader := Shader.new()
	shader.code = SHADER_CODE
	_material = ShaderMaterial.new()
	_material.shader = shader
	_material.set_shader_parameter("tint", tint)
	material = _material
	GameEvents.player_damaged.connect(_on_player_damaged)
	GameEvents.player_health_changed.connect(_on_player_health_changed)


func _process(delta: float) -> void:
	_time += delta
	_flash = move_toward(_flash, 0.0, flash_fade_speed * delta)
	var pulse := _low_health * (0.75 + 0.25 * sin(_time * pulse_speed))
	_material.set_shader_parameter("intensity", clampf(_flash + pulse, 0.0, 1.0))


func _on_player_damaged(_amount: float) -> void:
	_flash = flash_strength


func _on_player_health_changed(current: float, max_value: float) -> void:
	var ratio := current / max_value
	if ratio < low_health_ratio:
		_low_health = low_health_strength * (1.0 - ratio / low_health_ratio)
	else:
		_low_health = 0.0
