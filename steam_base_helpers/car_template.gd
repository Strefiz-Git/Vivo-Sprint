## car_template.gd
## -----------------------------------------------------------------------
## Script MODELO para a cena do CARRO do jogador. Copia isto para o teu
## projeto e adapta os valores de física ao "feel" do teu simulador.
## Cobre:
##   - Atribuição de autoridade (multiplayer authority)
##   - Interpolação suave para os carros dos outros jogadores
##   - Condução básica com VehicleBody3D (acelerar, travar, direção)
##   - Registo automático no grupo "race_car" (usado por race_track.gd)
##
## Precisas de definir estas ações no Input Map (Project Settings > Input Map):
##   accelerate, brake, steer_left, steer_right
##
## Estrutura de nós esperada:
##   Car (VehicleBody3D, este script)
##   ├── WheelFL, WheelFR (VehicleWheel3D, use_as_steering = true)
##   ├── WheelRL, WheelRR (VehicleWheel3D, use_as_traction = true)
##   ├── SpringArm3D
##   │   └── Camera3D
##   ├── MultiplayerSynchronizer   <- sincroniza global_transform, etc.
##   └── ... (modelo 3D do carro, colisão)
## -----------------------------------------------------------------------
extends VehicleBody3D

const ENGINE_FORCE_MAX: float = 600.0
const BRAKE_FORCE_MAX: float = 60.0
const REVERSE_FORCE_MAX: float = 250.0
const STEER_MAX: float = 0.6
const STEER_SPEED: float = 3.0  # quão rápido o volante gira até ao máximo
const NETWORK_UPDATE_INTERVAL: float = 0.05  # ~20 vezes por segundo

var _target_transform: Transform3D
var _previous_transform: Transform3D
var _time_since_update: float = 0.0


func _enter_tree() -> void:
	# TEM de ser feito em _enter_tree(), antes do MultiplayerSynchronizer
	# sincronizar os valores iniciais (não é permitido mudar autoridade depois disso).
	set_multiplayer_authority(int(str(name)))


func _ready() -> void:
	add_to_group("race_car")

	_target_transform = global_transform
	_previous_transform = global_transform

	if is_multiplayer_authority():
		$SpringArm3D/Camera3D.current = true  # ajusta conforme a tua cena


func _physics_process(delta: float) -> void:
	if is_multiplayer_authority():
		_process_local_driving(delta)
	else:
		_interpolate_remote_transform(delta)


## Só corre na instância que É o dono deste carro (input local).
func _process_local_driving(delta: float) -> void:
	var throttle_input: float = Input.get_action_strength("accelerate")
	var brake_input: float = Input.get_action_strength("brake")
	var steer_input: float = Input.get_axis("steer_left", "steer_right")

	var moving_forward: bool = linear_velocity.dot(-global_transform.basis.z) > 0.5

	if throttle_input > 0.0:
		engine_force = throttle_input * ENGINE_FORCE_MAX
		brake = 0.0
	elif brake_input > 0.0 and moving_forward:
		engine_force = 0.0
		brake = brake_input * BRAKE_FORCE_MAX
	elif brake_input > 0.0:
		# já está parado ou a andar para trás: travão vira marcha-atrás.
		engine_force = -brake_input * REVERSE_FORCE_MAX
		brake = 0.0
	else:
		engine_force = 0.0
		brake = 0.0

	var steer_target: float = -steer_input * STEER_MAX
	steering = move_toward(steering, steer_target, STEER_SPEED * delta)


## Corre em todas as OUTRAS instâncias (não-autoritativas) para suavizar
## a posição/rotação recebida via MultiplayerSynchronizer.
func _interpolate_remote_transform(delta: float) -> void:
	_time_since_update += delta
	var t: float = clampf(_time_since_update / NETWORK_UPDATE_INTERVAL, 0.0, 1.0)
	global_transform = _previous_transform.interpolate_with(_target_transform, t)


## Liga isto ao sinal "synchronized" do MultiplayerSynchronizer, ou chama
## manualmente sempre que receberes um novo transform de rede.
func _on_networked_transform_received(new_transform: Transform3D) -> void:
	_previous_transform = global_transform
	_target_transform = new_transform
	_time_since_update = 0.0


## Usa isto para colocar o carro na grelha de partida (ver
## race_track.get_start_position()).
func teleport_to(new_transform: Transform3D) -> void:
	global_transform = new_transform
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	_target_transform = new_transform
	_previous_transform = new_transform
