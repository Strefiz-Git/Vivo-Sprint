## player_template.gd
## -----------------------------------------------------------------------
## Script MODELO para a cena do jogador. Copia isto para o teu projeto e
## adapta o movimento/física ao teu jogo. Cobre:
##   - Atribuição de autoridade (multiplayer authority)
##   - Interpolação suave para outros jogadores
##   - Onde ligar o AudioStreamPlayer3D para chat de proximidade
##
## Estrutura de nós esperada (CharacterBody3D, mas adapta como quiseres):
##   Player (CharacterBody3D, este script)
##   ├── MultiplayerSynchronizer   <- sincroniza global_position, etc.
##   ├── VoicePlayer (AudioStreamPlayer3D)  <- opcional, ver steam_voice.gd
##   └── ... (modelo, colisão, etc.)
## -----------------------------------------------------------------------
extends CharacterBody3D

const SPEED: float = 5.0
const NETWORK_UPDATE_INTERVAL: float = 0.05  # ~20 vezes por segundo

var _target_position: Vector3
var _previous_position: Vector3
var _time_since_update: float = 0.0


func _enter_tree() -> void:
	# TEM de ser feito em _enter_tree(), antes do MultiplayerSynchronizer
	# sincronizar os valores iniciais (não é permitido mudar autoridade depois disso).
	set_multiplayer_authority(int(str(name)))


func _ready() -> void:
	_target_position = global_position
	_previous_position = global_position

	if is_multiplayer_authority():
		$Camera3D.current = true  # ajusta conforme a tua cena


func _physics_process(delta: float) -> void:
	if is_multiplayer_authority():
		_process_local_movement(delta)
	else:
		_interpolate_remote_position(delta)


## Só corre na instância que É o dono deste jogador (input local).
func _process_local_movement(delta: float) -> void:
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var direction: Vector3 = (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	velocity.x = direction.x * SPEED
	velocity.z = direction.z * SPEED
	if not is_on_floor():
		velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta

	move_and_slide()


## Corre em todas as OUTRAS instâncias (não-autoritativas) para suavizar
## o movimento recebido via MultiplayerSynchronizer.
func _interpolate_remote_position(delta: float) -> void:
	_time_since_update += delta
	var t: float = clampf(_time_since_update / NETWORK_UPDATE_INTERVAL, 0.0, 1.0)
	global_position = _previous_position.lerp(_target_position, t)


## Liga isto ao sinal "synchronized" do MultiplayerSynchronizer, ou chama
## manualmente sempre que receberes uma nova posição de rede.
func _on_networked_position_received(new_pos: Vector3) -> void:
	_previous_position = global_position
	_target_position = new_pos
	_time_since_update = 0.0
