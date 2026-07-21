extends Control

@export var max_speed: float = 280.0
@export var gauge_radius: float = 80.0
@export var needle_length: float = 70.0

var _current_speed: float = 0.0
var _target_speed: float = 0.0

const ANGLE_MIN: float = -225.0
const ANGLE_MAX: float = 45.0
const SPEED_COLORS: Array[Color] = [
	Color.WHITE, Color(0.2, 1.0, 0.2),
	Color(1.0, 1.0, 0.0), Color(1.0, 0.3, 0.1)
]


func _ready() -> void:
	custom_minimum_size = Vector2(200, 200)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_speed(mps: float) -> void:
	_target_speed = units_manager.speed_to_display(mps)


func _process(delta: float) -> void:
	_current_speed = lerpf(_current_speed, _target_speed, 8.0 * delta)
	queue_redraw()


func _draw() -> void:
	var center := Vector2(gauge_radius + 20, gauge_radius + 20)
	_draw_background_circle(center)
	_draw_gauge_arc(center)
	_draw_tick_marks(center)
	_draw_speed_numbers(center)
	_draw_needle_shadow(center)
	_draw_needle(center)
	_draw_center_cap(center)
	_draw_digital_speed(center)


func _draw_background_circle(center: Vector2) -> void:
	var bg_radius: float = gauge_radius + 8.0
	draw_circle(center, bg_radius, Color(0.08, 0.1, 0.15, 0.85))
	draw_arc(center, bg_radius, 0, TAU, 64, Color(0.2, 0.25, 0.3, 0.6), 1.5, true)


func _draw_gauge_arc(center: Vector2) -> void:
	var start_angle: float = deg_to_rad(ANGLE_MIN)
	var end_angle: float = deg_to_rad(ANGLE_MAX)
	var segments := 64
	var arc_points: PackedVector2Array = PackedVector2Array()
	for i in range(segments + 1):
		var t: float = float(i) / float(segments)
		var angle: float = lerpf(start_angle, end_angle, t)
		arc_points.append(center + Vector2(cos(angle), sin(angle)) * gauge_radius)
	for i in range(arc_points.size() - 1):
		var t: float = float(i) / float(segments)
		var color_idx: int = int(t * (SPEED_COLORS.size() - 1))
		color_idx = clampi(color_idx, 0, SPEED_COLORS.size() - 2)
		var seg_t: float = fmod(t * (SPEED_COLORS.size() - 1), 1.0)
		var color: Color = SPEED_COLORS[color_idx].lerp(SPEED_COLORS[color_idx + 1], seg_t)
		draw_line(arc_points[i], arc_points[i + 1], color, 3.0, true)

	var arc_bg_inner: float = gauge_radius - 5.0
	for i in range(segments + 1):
		var t: float = float(i) / float(segments)
		var angle: float = lerpf(start_angle, end_angle, t)
		var p_inner := center + Vector2(cos(angle), sin(angle)) * arc_bg_inner
		var p_outer := center + Vector2(cos(angle), sin(angle)) * (gauge_radius + 2.0)
		var color_idx: int = int(t * (SPEED_COLORS.size() - 1))
		color_idx = clampi(color_idx, 0, SPEED_COLORS.size() - 2)
		var seg_t: float = fmod(t * (SPEED_COLORS.size() - 1), 1.0)
		var color: Color = SPEED_COLORS[color_idx].lerp(SPEED_COLORS[color_idx + 1], seg_t)
		draw_line(p_inner, p_outer, Color(color.r, color.g, color.b, 0.15), 2.0, true)


func _draw_tick_marks(center: Vector2) -> void:
	var start_angle: float = deg_to_rad(ANGLE_MIN)
	var end_angle: float = deg_to_rad(ANGLE_MAX)
	var major_ticks := int(max_speed / 20.0)
	for i in range(major_ticks + 1):
		var t: float = float(i) / float(major_ticks)
		var angle: float = lerpf(start_angle, end_angle, t)
		var inner_radius: float = gauge_radius - 10.0
		var p1 := center + Vector2(cos(angle), sin(angle)) * inner_radius
		var p2 := center + Vector2(cos(angle), sin(angle)) * (gauge_radius - 2.0)
		var speed_ratio: float = t
		var tick_color: Color = Color(1, 0.3, 0.1, 0.9) if speed_ratio > 0.8 else Color.WHITE
		draw_line(p1, p2, tick_color, 2.0, true)
	if major_ticks >= 2:
		var minor_per_major := 4
		var total_minor := major_ticks * minor_per_major
		for i in range(total_minor + 1):
			if i % minor_per_major == 0:
				continue
			var t: float = float(i) / float(total_minor)
			var angle: float = lerpf(start_angle, end_angle, t)
			var inner_radius: float = gauge_radius - 6.0
			var p1 := center + Vector2(cos(angle), sin(angle)) * inner_radius
			var p2 := center + Vector2(cos(angle), sin(angle)) * (gauge_radius - 2.0)
			draw_line(p1, p2, Color(1, 1, 1, 0.4), 1.0, true)


func _draw_speed_numbers(center: Vector2) -> void:
	var start_angle: float = deg_to_rad(ANGLE_MIN)
	var end_angle: float = deg_to_rad(ANGLE_MAX)
	var major_ticks := int(max_speed / 40.0)
	for i in range(major_ticks + 1):
		var t: float = float(i) / float(major_ticks)
		var angle: float = lerpf(start_angle, end_angle, t)
		var number_radius: float = gauge_radius - 24.0
		var pos := center + Vector2(cos(angle), sin(angle)) * number_radius
		var speed_val: int = int(t * max_speed)
		var font := ThemeDB.fallback_font
		var speed_ratio: float = t
		var text_color: Color = Color(1, 0.4, 0.2, 1.0) if speed_ratio > 0.8 else Color.WHITE
		draw_string(font, pos - Vector2(8, -4), str(speed_val), HORIZONTAL_ALIGNMENT_CENTER, -1, 11, text_color)


func _draw_needle_shadow(center: Vector2) -> void:
	var clamped_speed: float = clampf(_current_speed, 0.0, max_speed)
	var t: float = clamped_speed / max_speed
	var angle: float = deg_to_rad(lerpf(ANGLE_MIN, ANGLE_MAX, t))
	var shadow_offset := Vector2(2.0, 2.0)
	var tip := center + Vector2(cos(angle), sin(angle)) * needle_length + shadow_offset
	var perp := Vector2(-sin(angle), cos(angle))
	var base_left := center + perp * 3.0 + shadow_offset
	var base_right := center - perp * 3.0 + shadow_offset
	draw_colored_polygon(PackedVector2Array([base_left, tip, base_right]), Color(0, 0, 0, 0.35))


func _draw_needle(center: Vector2) -> void:
	var clamped_speed: float = clampf(_current_speed, 0.0, max_speed)
	var t: float = clamped_speed / max_speed
	var angle: float = deg_to_rad(lerpf(ANGLE_MIN, ANGLE_MAX, t))
	var needle_tip := center + Vector2(cos(angle), sin(angle)) * needle_length
	var perp := Vector2(-sin(angle), cos(angle))
	var base_left := center + perp * 4.0
	var base_right := center - perp * 4.0

	var speed_ratio: float = clamped_speed / max_speed
	var needle_color: Color
	if speed_ratio > 0.8:
		needle_color = Color(1.0, 0.15, 0.05)
	elif speed_ratio > 0.6:
		needle_color = Color(1.0, 0.6, 0.1)
	else:
		needle_color = Color.WHITE

	draw_colored_polygon(PackedVector2Array([base_left, needle_tip, base_right]), needle_color)

	var glow_radius: float = lerpf(4.0, 7.0, speed_ratio)
	draw_circle(center, glow_radius, Color(needle_color.r, needle_color.g, needle_color.b, 0.2))


func _draw_center_cap(center: Vector2) -> void:
	draw_circle(center, 7.0, Color(0.15, 0.15, 0.2))
	draw_arc(center, 7.0, 0, TAU, 32, Color(0.5, 0.5, 0.55, 0.8), 1.0, true)
	draw_circle(center, 5.0, Color(0.25, 0.25, 0.3))
	draw_arc(center, 5.0, 0, TAU, 32, Color(0.6, 0.6, 0.65, 0.6), 0.8, true)
	draw_circle(center, 2.0, Color(0.7, 0.7, 0.75))


func _draw_digital_speed(center: Vector2) -> void:
	var display_speed: int = int(_current_speed)
	var font := ThemeDB.fallback_font
	var text := "%d" % display_speed
	var unit_text := units_manager.speed_unit()
	draw_string(font, center + Vector2(-15, 30), text, HORIZONTAL_ALIGNMENT_CENTER, -1, 22, Color.WHITE)
	draw_string(font, center + Vector2(-12, 44), unit_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color(0.7, 0.7, 0.7))
