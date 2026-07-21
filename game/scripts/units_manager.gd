extends Node

enum UnitSystem { METRIC, IMPERIAL }

var current_system: UnitSystem = UnitSystem.METRIC

func speed_to_display(mps: float) -> float:
	if current_system == UnitSystem.METRIC:
		return mps * 3.6
	return mps * 2.23694

func speed_unit() -> String:
	return "km/h" if current_system == UnitSystem.METRIC else "mph"

func distance_to_display(meters: float) -> float:
	if current_system == UnitSystem.METRIC:
		return meters / 1000.0
	return meters / 1609.34

func distance_unit() -> String:
	return "km" if current_system == UnitSystem.METRIC else "mi"

func temp_to_display(celsius: float) -> float:
	if current_system == UnitSystem.METRIC:
		return celsius
	return celsius * 9.0 / 5.0 + 32.0

func temp_unit() -> String:
	return "°C" if current_system == UnitSystem.METRIC else "°F"

func pressure_to_display(bar: float) -> float:
	if current_system == UnitSystem.METRIC:
		return bar * 14.5038
	return bar * 14.5038

func pressure_unit() -> String:
	return "psi"

func fuel_to_display(litres: float) -> float:
	if current_system == UnitSystem.METRIC:
		return litres
	return litres * 0.264172

func fuel_unit() -> String:
	return "L" if current_system == UnitSystem.METRIC else "gal"

func mass_to_display(kg: float) -> float:
	if current_system == UnitSystem.METRIC:
		return kg
	return kg * 2.20462

func mass_unit() -> String:
	return "kg" if current_system == UnitSystem.METRIC else "lb"

func format_time(ms: int) -> String:
	if ms <= 0:
		return "--:--.---"
	var total_seconds: float = ms / 1000.0
	var minutes: int = int(total_seconds) / 60
	var seconds: float = fmod(total_seconds, 60.0)
	return "%02d:%06.3f" % [minutes, seconds]
