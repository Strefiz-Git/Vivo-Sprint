## race_track.gd
## -----------------------------------------------------------------------
## Script MODELO para a cena da PISTA. Copia isto para o nó raiz da tua
## pista e liga os 3 checkpoints no Inspector.
##
## Todas as pistas seguem a mesma estrutura: 3 setores, sendo o 3º
## sempre a linha de partida/meta (atravessá-la fecha a volta).
##
## Estrutura de nós esperada:
##   Track (Node3D, este script)
##   ├── Sector1 (Area3D)        <- checkpoints[0]
##   ├── Sector2 (Area3D)        <- checkpoints[1]
##   ├── StartFinishLine (Area3D) <- checkpoints[2] (partida = meta)
##   └── ... (estrada, cenário, grid de partida, etc.)
##
## Cada Area3D precisa de uma CollisionShape3D a cobrir a largura da
## pista nesse ponto, e de collision_layer/mask configurados para
## detetar os carros (grupo "race_car", ver car_template.gd).
##
## Os carros têm de atravessar os checkpoints por ORDEM (0 -> 1 -> 2);
## fora de ordem é ignorado pelo RaceManager (evita atravessar a meta
## ao contrário ou cortar caminho para "ganhar" um setor).
## -----------------------------------------------------------------------
extends Node3D

## Arrasta os 3 Area3D para aqui, pela ordem certa: setor 1, setor 2, meta.
@export var checkpoints: Array[NodePath] = []

## Nº de voltas desta pista por omissão (o host pode passar outro valor
## a start_race() na sala de espera, ex: escolhido num menu).
@export var default_laps: int = 3

## Pontos de partida (Marker3D/Node3D), um por carro. Ordem = grid de partida.
@export var start_positions: Array[NodePath] = []


func _ready() -> void:
	if checkpoints.size() != 3:
		printerr("[RaceTrack] Esta pista precisa de exatamente 3 checkpoints definidos no Inspector (tem %d)." % checkpoints.size())
		return

	for sector_index in range(checkpoints.size()):
		var area: Area3D = get_node(checkpoints[sector_index])
		if area:
			area.body_entered.connect(_on_checkpoint_entered.bind(sector_index))
		else:
			printerr("[RaceTrack] Checkpoint do setor %d não encontrado." % sector_index)


func _on_checkpoint_entered(body: Node, sector_index: int) -> void:
	# A deteção corre em todas as instâncias (a Area3D existe em todo
	# o lado), mas só o servidor deve decidir os tempos.
	if not multiplayer.is_server():
		return
	if not body.is_in_group("race_car"):
		return

	var car_id: int = body.get_multiplayer_authority()
	RaceManager.report_checkpoint_crossed(car_id, sector_index)


## ---------------------------------------------------------------------
## Arranque da corrida (chama isto do lado do host, ex: depois do
## countdown na sala de espera ou de todos os carros estarem spawnados)
## ---------------------------------------------------------------------

func start_race(laps: int = -1) -> void:
	if not multiplayer.is_server():
		return

	var laps_to_use: int = default_laps if laps < 0 else laps
	for car in get_tree().get_nodes_in_group("race_car"):
		RaceManager.register_car(car.get_multiplayer_authority())

	RaceManager.start_race(laps_to_use)


## Devolve a posição de grelha correspondente ao índice (0 = pole position).
## Útil quando spawnas os carros ao entrar na pista.
func get_start_position(grid_index: int) -> Transform3D:
	if grid_index < 0 or grid_index >= start_positions.size():
		return global_transform
	var marker: Node3D = get_node(start_positions[grid_index])
	return marker.global_transform if marker else global_transform
