extends Node

const KMH_PER_MS := 3.6

static func format_time(seconds: float, show_ms: bool = true) -> String:
	var total_ms := int(seconds * 1000.0)
	var mins := total_ms / 60000
	var secs := (total_ms / 1000) % 60
	var millis := total_ms % 1000
	if show_ms:
		return "%02d:%02d.%03d" % [mins, secs, millis]
	return "%02d:%02d" % [mins, secs]

static func format_speed(m_per_s: float, use_kmh: bool = true) -> String:
	var val := m_per_s * KMH_PER_MS if use_kmh else m_per_s
	var unit := "km/h" if use_kmh else "m/s"
	return "%d %s" % [round(val), unit]

static func lerp_angle_short(a: float, b: float, t: float) -> float:
	var diff := wrapf(b - a, -PI, PI)
	return a + diff * t

static func is_equal_approx(a: float, b: float, epsilon: float = 0.001) -> bool:
	return abs(a - b) < epsilon

static func random_range(from: float, to: float) -> float:
	return randf_range(from, to)

static func clamp_vector3(v: Vector3, min_val: float, max_val: float) -> Vector3:
	return Vector3(
		clampf(v.x, min_val, max_val),
		clampf(v.y, min_val, max_val),
		clampf(v.z, min_val, max_val)
	)

static func get_project_settings_dict() -> Dictionary:
	return {
		"name": ProjectSettings.get_setting("application/config/name"),
		"version": ProjectSettings.get_setting("application/config/version", "0.1.0")
	}
