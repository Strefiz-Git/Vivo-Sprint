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
		var cog: Array = physics.get("centre_of_gravity", [0.0, -0.3, 0.0])
		center_of_mass = Vector3(cog[0], cog[1], cog[2])
	if _config.has("gears"):
		var gears: Dictionary = _config["gears"]
		_gear_ratios = gears.get("ratios", [])
		_final_drive = gears.get("final_drive", 3.8)


func _physics_process(delta: float) -> void:
	if _is_local():
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

	var moving_forward: bool = linear_velocity.dot(-global_transform.basis.z) > 0.5

	var effective_engine: float = _engine_force_max
	var effective_brake: float = _brake_force_max

	if throttle_input > 0.0:
		engine_force = -throttle_input * effective_engine
		brake = 0.0
	elif brake_input > 0.0 and moving_forward:
		engine_force = 0.0
		brake = brake_input * effective_brake
	elif brake_input > 0.0:
		engine_force = brake_input * _reverse_force_max
		brake = 0.0
	else:
		engine_force = 0.0
		brake = 0.0

	var steer_target: float = -steer_input * _steer_max
	steering = move_toward(steering, steer_target, STEER_SPEED * delta)


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
	if hud and hud.has_method("update_speed"):
		hud.update_speed(get_speed_kmh())
