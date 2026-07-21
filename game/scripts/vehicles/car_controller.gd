extends VehicleBody3D

const STEER_SPEED: float = 3.0
const NETWORK_UPDATE_INTERVAL: float = 0.05

var _target_transform: Transform3D
var _previous_transform: Transform3D
var _time_since_update: float = 0.0

var _config: Dictionary = {}
var _engine_force_max: float = 1500.0
var _brake_force_max: float = 80.0
var _reverse_force_max: float = 600.0
var _steer_max: float = 0.6
var _current_gear: int = 0
var _gear_ratios: Array = []
var _final_drive: float = 3.8
var _damage_total: float = 0.0
var _fuel_litres: float = 60.0

var _top_speed_kmh: float = 200.0
var _drag_coefficient: float = 0.42
var _rolling_resistance: float = 30.0


func _enter_tree() -> void:
	if multiplayer.has_multiplayer_peer():
		var name_int: int = name.to_int() if name.is_valid_int() else 0
		if name_int != 0:
			set_multiplayer_authority(name_int)
	else:
		set_multiplayer_authority(1)


func _is_local() -> bool:
	return not multiplayer.has_multiplayer_peer() or is_multiplayer_authority()


func _ready() -> void:
	add_to_group("race_car")
	_target_transform = global_transform
	_previous_transform = global_transform
	_load_config()
	if _is_local():
		$SpringArm3D/Camera3D.current = true
		logger.info("CarController", "Local car active — peer %d" % multiplayer.get_unique_id())
	else:
		logger.warn("CarController", "Remote car — peer %d, authority=%s" % [multiplayer.get_unique_id(), get_multiplayer_authority()])


func _load_config() -> void:
	var config_path: String = "res://config/cars/base_car.json"
	if not FileAccess.file_exists(config_path):
		logger.warning("CarController", "Config not found: %s" % config_path)
		return
	var file := FileAccess.open(config_path, FileAccess.READ)
	if file:
		var json := JSON.new()
		var error := json.parse(file.get_as_text())
		if error == OK:
			_config = json.data
			_apply_config()
		else:
			logger.error("CarController", "JSON parse error: %s" % json.get_error_message())


func _apply_config() -> void:
	if _config.has("physics"):
		var physics: Dictionary = _config["physics"]
		_engine_force_max = physics.get("engine_force_max", 600.0)
		_brake_force_max = physics.get("brake_force_max", 60.0)
		_reverse_force_max = physics.get("reverse_force_max", 250.0)
		_steer_max = physics.get("steer_max", 0.6)
		mass = physics.get("mass", 1200.0)
		_top_speed_kmh = physics.get("top_speed_kmh", 200.0)
		_drag_coefficient = physics.get("drag_coefficient", 0.42)
		_rolling_resistance = physics.get("rolling_resistance", 30.0)
		var cog: Array = physics.get("centre_of_gravity", [0.0, -0.3, 0.0])
		center_of_mass = Vector3(cog[0], cog[1], cog[2])
	if _config.has("gears"):
		var gears: Dictionary = _config["gears"]
		_gear_ratios = gears.get("ratios", [])
		_final_drive = gears.get("final_drive", 3.8)


func _physics_process(delta: float) -> void:
	if _is_local():
		if race_manager.race_active:
			_process_local_driving(delta)
		_update_hud()
	else:
		_interpolate_remote_transform(delta)


var _input_debug_timer: float = 0.0


func _process_local_driving(delta: float) -> void:
	var throttle_input: float = Input.get_action_strength("accelerate")
	var brake_input: float = Input.get_action_strength("brake")
	var steer_input: float = Input.get_axis("steer_left", "steer_right")

	_input_debug_timer += delta
	if _input_debug_timer >= 1.0:
		_input_debug_timer = 0.0
		logger.info("CarController", "throttle=%.2f brake=%.2f steer=%.2f vel=%.1f pos=%s" % [
			throttle_input, brake_input, steer_input, get_speed_kmh(), global_position])

	var speed_ms: float = linear_velocity.length()
	var speed_kmh: float = speed_ms * 3.6
	var forward_dir: Vector3 = -global_transform.basis.z
	var moving_forward: bool = linear_velocity.dot(forward_dir) > 0.5

	var drag_force: float = _drag_coefficient * speed_ms * speed_ms
	var rolling_force: float = _rolling_resistance * speed_ms
	var total_resistance: float = drag_force + rolling_force

	var speed_ratio: float = clampf(speed_kmh / _top_speed_kmh, 0.0, 1.0)
	var power_curve: float = 1.0 - speed_ratio * speed_ratio

	if throttle_input > 0.0:
		var forward_force: float = throttle_input * _engine_force_max * power_curve
		var net_force: float = maxf(forward_force - total_resistance, 0.0)
		engine_force = -net_force
		brake = 0.0
	elif brake_input > 0.0 and moving_forward:
		var brake_scale: float = lerpf(1.0, 2.0, speed_ratio)
		engine_force = 0.0
		brake = brake_input * _brake_force_max * brake_scale
	elif brake_input > 0.0:
		engine_force = brake_input * _reverse_force_max
		brake = 0.0
	else:
		engine_force = 0.0
		var coast_brake: float = clampf(total_resistance * delta * 2.0, 0.0, _brake_force_max)
		brake = coast_brake

	var steer_target: float = -steer_input * _steer_max
	var speed_steer_factor: float = lerpf(1.0, 0.4, speed_ratio)
	steering = move_toward(steering, steer_target * speed_steer_factor, STEER_SPEED * delta)

	if speed_kmh > _top_speed_kmh:
		var cap_factor: float = _top_speed_kmh / speed_kmh
		linear_velocity *= cap_factor


func _interpolate_remote_transform(delta: float) -> void:
	_time_since_update += delta
	var t: float = clampf(_time_since_update / NETWORK_UPDATE_INTERVAL, 0.0, 1.0)
	global_transform = _previous_transform.interpolate_with(_target_transform, t)


func _on_networked_transform_received(new_transform: Transform3D) -> void:
	_previous_transform = global_transform
	_target_transform = new_transform
	_time_since_update = 0.0


func teleport_to(new_transform: Transform3D) -> void:
	global_transform = new_transform
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	_target_transform = new_transform
	_previous_transform = new_transform


func get_speed_kmh() -> float:
	return linear_velocity.length() * 3.6


func get_config() -> Dictionary:
	return _config


func _update_hud() -> void:
	var hud: CanvasLayer = get_tree().get_first_node_in_group("race_hud")
	if hud:
		if hud.has_method("update_speed_mps"):
			hud.update_speed_mps(linear_velocity.length())
		elif hud.has_method("update_speed"):
			hud.update_speed(get_speed_kmh())
