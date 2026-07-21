# Vivo Sprint — Plano de Implementação

## Estado Actual

Toda a infraestrutura multiplayer/Steam/UI está pronta. Falta o **gameplay core**: física do carro, simulação realista, pista funcional, bots, consola.

---

## Fase 1 — Simulação do Carro (telemetria completa)

### 1.1 Estrutura de Dados: `car_telemetry.gd`

Script anexado ao `VehicleBody3D` (junto ao `car_controller.gd`). Contém todo o estado simulado do carro:

```gdscript
# --- POR RODA (4 instâncias: FL, FR, RL, RR) ---
class WheelData:
    var temperature_external: float = 20.0   # °C (ambiente inicial)
    var temperature_internal: float = 20.0   # °C (calculada a partir da externa)
    var wear: float = 0.0                     # 0.0 = novo, 1.0 = destruído
    var pressure_psi: float = 26.0           # varia com temperatura
    var grip_modifier: float = 1.0           # calculado: compound * temp_window * wear
    var distance_km: float = 0.0             # distância percorrida

# --- COMBUSTÍVEL ---
var fuel_litres: float = 0.0
var fuel_capacity_litres: float = 0.0
var fuel_consumption_per_km: float = 0.0

# --- ESTADO DO CARRO (por área) ---
enum CarArea { ENGINE, GEARBOX, SUSPENSION_FRONT, SUSPENSION_REAR, AERO, CHASSIS }
var damage: Dictionary = {}  # CarArea -> float (0.0 = perfeito, 1.0 = destruído)

# --- PESO ---
var base_mass: float = 1200.0
var current_mass: float = 1200.0  # recalculado com combustível + dano

# --- Velocidade ---
var speed_kmh: float = 0.0
```

### 1.2 Modelo de Pneus: `scripts/vehicles/tire_model.gd`

Script dedicado à física dos pneus, chamado a cada `_physics_process`:

**Temperatura externa** — afectada por:
- Fricção com o chão (velocidade angular × grip × factor)
- Travagem (freio × factor)
- Aceleração (torque × factor)
- Ar ambiente (weather system futuro)
- Arrefecimento natural (Newton's Law of Cooling: `(temp - ambient) * cooling_rate`)

**Temperatura interna** — calculada a partir da externa:
- `internal = external + (external - ambient) * insulation_factor`
- Atraso térmico (thermal lag): a interna demora a acompanhar a externa

**Desgaste** — afectado por:
- Distância percorrida (base)
- Temperatura fora da janela óptima (compound.temperature_window)
- Temperatura interna alta (degradação acelerada)
- Travagem pesada (desgaste pontual)
- Aceleração forte (desgaste pontual)
- Piso (DRY/DAMP/WET — futuro)

**Pressão** — varia com temperatura interna:
- `pressure = base_pressure * (1 + thermal_expansion_coeff * (temp_internal - 20.0))`

**Grip efectivo** — combinado:
- `compound_base_grip × temperature_modifier × wear_modifier × pressure_modifier`

### 1.3 Modelo de Combustível: `scripts/vehicles/fuel_system.gd`

**Consumo** — baseado em:
- RPM do motor (mais RPM = mais consumo)
- Carga do motor (engine_force_actual / engine_force_max)
- Velocidade (arrasto aerodinâmico a alta velocidade)
- Fórmula simplificada: `consumption = base_rate × (1 + rpm_factor + load_factor) × delta_km`

**Peso do combustível** — afecta:
- Massa total do carro: `current_mass = base_mass + (fuel_litres × fuel_density_kg_per_litre)`
- Centro de massa (combustível no fundo = mais estável)
- Inércia (mais massa = mais lento a acelerar/frear)

### 1.4 Modelo de Dano: `scripts/vehicles/damage_model.gd`

**Áreas e efeitos:**

| Área | Efeitos do dano |
|---|---|
| ENGINE | Perda de potência max (engine_force_max × (1 - damage)) |
| GEARBOX | Atraso nas mudanças, perda de eficiência |
| SUSPENSION_FRONT | Menos grip dianteiro, steering mais pesado |
| SUSPENSION_REAR | Menos grip traseiro, sobreviragem |
| AERO | Menos downforce, menos estabilidade a alta velocidade |
| CHASSIS | Aumenta peso (deformação), perda generalizada |

**Como se aplica dano:**
- Colisões: `force = impact_velocity × mass_difference × damage_factor`
- Cada colisão afecta a área mais próxima (frontal → ENGINE, traseira → SUSPENSION_REAR, etc.)
- Dano acumula-se ao longo da corrida
- Dano é **server-authoritative** em multiplayer

### 1.5 Integração com `car_controller.gd`

O `car_controller.gd` actual lê os valores de `car_telemetry` em vez de usar constantes:

```gdscript
func _process_local_driving(delta: float) -> void:
    # Em vez de ENGINE_FORCE_MAX directo:
    var effective_force: float = telemetry.get_effective_engine_force()
    engine_force = throttle_input * effective_force

    # Em vez de BRAKE_FORCE_MAX directo:
    var effective_brake: float = telemetry.get_effective_brake_force()
    brake = brake_input * effective_brake

    # Steering afectado por dano de suspensão:
    var effective_steer: float = telemetry.get_effective_steer_max()
    steer_target = -steer_input * effective_steer
```

### 1.6 Ficheiro de Config: `config/cars/base_car.json` (atualizado)

```json
{
    "physics": { ... },
    "tyres": {
        "compound": "MEDIUM",
        "pressure_psi": 26.0,
        "thermal_insulation": 0.3,
        "thermal_expansion_coeff": 0.003,
        "cooling_rate": 0.02,
        "wear_base_km": 50.0
    },
    "fuel": {
        "capacity_litres": 60.0,
        "consumption_base_per_km": 0.04,
        "density_kg_per_litre": 0.75
    },
    "damage": {
        "collision_factor": 0.15,
        "area_decay_rates": { ... }
    }
}
```

---

## Fase 2 — Pista de Teste

### 2.1 Espera pelo modelo 3D

O utilizador está a procurar um modelo de pista. Enquanto isso:
- Criar uma **pista procedural oval** como placeholder funcional
- A pista real será substituída quando o modelo chegar

### 2.2 Pista Oval de Teste: `scenes/tracks/test_oval.tscn`

**Estrutura:**
```
TestOval (Node3D) — script: race_track.gd
├── TrackMesh (CSGBox3D ou MeshInstance3D) — chão da pista
├── Walls (StaticBody3D) — paredes laterais
├── Checkpoint1 (Area3D + CollisionShape3D) — Sector 1
├── Checkpoint2 (Area3D + CollisionShape3D) — Sector 2
├── Checkpoint3 (Area3D + CollisionShape3D) — Finish/Start
├── GridPositions (Node3D)
│   ├── Pos0 (Marker3D)
│   ├── Pos1 (Marker3D)
│   ├── Pos2 (Marker3D)
│   └── Pos3 (Marker3D)
├── RacingLine (Path3D) — para bots
│   └── (pontos ao longo da pista)
└── Environment (WorldEnvironment)
    ├── DirectionalLight3D
    └── WorldEnvironment (sky, ambient)
```

**Dimensões da pista oval:**
- 2 rectas de ~200m
- 2 curvas de 180° com raio ~50m
- Largura: 12m (3 carris)

### 2.3 Race Track Script — checkpoints

O `race_track.gd` já detecta `body_entered` nos checkpoints. Os checkpoints precisam de:
- `CollisionShape3D` com `BoxShape3D` (largura da pista × altura)
- `monitoring = true`
- `monitorable = true`

---

## Fase 3 — Bots de Corrida

### 3.1 Arquitectura

```
scripts/vehicles/ai_driver.gd        — herda de car_controller, adiciona IA
scripts/race/bot_manager.gd          — spawning, config, multiplayer sync
config/bot_presets.json              — perfis de dificuldade
```

### 3.2 AI Driver: `scripts/vehicles/ai_driver.gd`

Extends `car_controller.gd`. Usa Path3D para racing line:

**Comportamento:**
- Look-ahead: calcula ponto alvo 10-20 unidades à frente no Path3D
- Steering: calcula ângulo entre heading actual e ponto alvo → steer_input
- Velocidade: acelera em rectas, freia antes de curvas (baseado no ângulo de curvatura)
- Rubber-banding: ajusta velocidade alvo para manter corrida competitiva

**Personalidade (por bot):**

| Parâmetro | Efeito |
|---|---|
| `aggressiveness` | Racing line mais fechada (corta curvas), menos espaço para outros |
| `skill_level` | Erros de trajetória (desvio aleatório), precisão de travagem |
| `max_speed_factor` | Velocidade máxima relativa (0.75 = lento, 1.05 = rápido) |
| `brake_timing` | Quando começa a travar (mais tarde = mais agressivo) |
| `error_margin` | Ruído aleatório no steering (0.0 = perfeito, 0.3 = muitos erros) |

### 3.3 Bot Manager: `scripts/race/bot_manager.gd`

**Responsabilidades:**
- Criar/destruir bots (só no host)
- Registar bots no race_manager (IDs negativos: -1, -2, ...)
- Enviar posições via RPC para clientes
- Receber posições dos clientes e interpolar

**Integração com lobby:**
- `lobby_screen.gd` ganha slider "Bots" (0-31) e dropdown "Dificuldade"
- Valores guardados na lobby data do Steam
- Quando host inicia corrida, cria bots em todos os clientes

### 3.4 Config de Bots: `config/bot_presets.json`

```json
{
    "easy": { "max_speed_factor": 0.75, "aggressiveness": 0.3, "skill_level": 0.4, "error_margin": 0.3 },
    "medium": { "max_speed_factor": 0.9, "aggressiveness": 0.5, "skill_level": 0.6, "error_margin": 0.15 },
    "hard": { "max_speed_factor": 1.0, "aggressiveness": 0.8, "skill_level": 0.85, "error_margin": 0.05 },
    "pro": { "max_speed_factor": 1.05, "aggressiveness": 0.95, "skill_level": 0.95, "error_margin": 0.0 }
}
```

---

## Fase 4 — Consola de Comandos

Baseado no `plano_consola_godot.md` existente.

### 4.1 Estrutura

```
scripts/console/
├── console.gd              # Autoload principal (UI + lógica)
├── console_ui.tscn         # Cena da UI (CanvasLayer)
├── command.gd              # Classe Command
└── commands/
    ├── base_commands.gd    # /help, /clear, /quit, /echo, /fps
    ├── race_commands.gd    # /start_race, /add_bot, /set_laps, /respawn
    └── admin_commands.gd   # /kick, /teleport, /god
```

### 4.2 Comandos Planeados

#### Core (sempre disponíveis)
| Comando | Descrição |
|---|---|
| `/help [cmd]` | Lista comandos ou mostra detalhe |
| `/clear` | Limpa output |
| `/echo <texto>` | Ecoa texto |
| `/quit` | Fecha o jogo |
| `/fps` | Toggle overlay FPS |
| `/version` | Mostra versão |

#### Race (host-only em multiplayer)
| Comando | Descrição |
|---|---|
| `/start_race [laps]` | Inicia corrida com X voltas |
| `/add_bot [qty] [difficulty]` | Adiciona bots |
| `/remove_bot <id>` | Remove um bot |
| `/set_laps <n>` | Define número de voltas |
| `/respawn` | Respawn do carro na grelha |
| `/reset_race` | Reinicia a corrida |

#### Admin (host-only)
| Comando | Descrição |
|---|---|
| `/kick <steam_id>` | Expulsa jogador |
| `/whoami` | Mostra Steam ID e peer ID |
| `/teleport <x> <y> <z>` | Teleporta carro |
| `/god` | Toggle invencibilidade |

### 4.3 Permissões

```gdscript
enum Permission { NONE, PLAYER, HOST, ADMIN }
```

- HOST tem sempre permissão de HOST
- Comandos de race/admin verificam permissão antes de executar

### 4.4 Integração Multiplayer

- Comandos de "mundo" só executam no servidor
- Servidor envia RPC para clientes executarem efeito localmente
- Consola local mostra sempre o resultado

---

## Ordem de Implementação

| # | Tarefa | Dependências | Prioridade |
|---|---|---|---|
| 1 | `physics_ticks_per_second = 120` no project.godot | Nenhuma | Alta |
| 2 | `car_telemetry.gd` (estrutura de dados) | Nenhuma | Alta |
| 3 | `tire_model.gd` (temp externa/interna, desgaste, pressão, grip) | #2 | Alta |
| 4 | `fuel_system.gd` (consumo, peso) | #2 | Alta |
| 5 | `damage_model.gd` (6 áreas, efeitos) | #2 | Alta |
| 6 | Atualizar `car_controller.gd` (ler de telemetry) | #2-5 | Alta |
| 7 | Configurar suspensão no `base_car.tscn` | #6 | Alta |
| 8 | Pista oval de teste (`test_oval.tscn`) | Nenhuma | Alta |
| 9 | Ligação HUD ↔ telemetry (velocidade, temp pneus, combustível, dano) | #2-8 | Alta |
| 10 | **TESTE: carro + pista sozinho** | #1-9 | Alta |
| 11 | `ai_driver.gd` (Path3D, steering, personalidade) | #6, #8 | Média |
| 12 | `bot_manager.gd` (spawning, sync) | #11 | Média |
| 13 | Adicionar Path3D à pista de teste | #8 | Média |
| 14 | **TESTE: carro + bots** | #11-13 | Média |
| 15 | `console.gd` (autoload) + UI | Nenhuma | Média |
| 16 | Comandos base | #15 | Média |
| 17 | Comandos de race | #15, #12 | Média |
| 18 | Comandos admin | #15 | Média |
| 19 | **TESTE: consola + bots + corrida completa** | #1-18 | Média |
| 20 | Substituir pista oval por modelo 3D real | Modelo do utilizador | Baixa |

---

## Ficheiros a Criar

| Ficheiro | Tipo | Descrição |
|---|---|---|
| `scripts/vehicles/car_telemetry.gd` | Script | Estrutura de dados central do carro |
| `scripts/vehicles/tire_model.gd` | Script | Física de pneus por roda |
| `scripts/vehicles/fuel_system.gd` | Script | Sistema de combustível |
| `scripts/vehicles/damage_model.gd` | Script | Sistema de dano por áreas |
| `scripts/vehicles/ai_driver.gd` | Script | IA de condução |
| `scripts/race/bot_manager.gd` | Script | Gestão de bots |
| `scripts/console/console.gd` | Script | Autoload da consola |
| `scripts/console/command.gd` | Script | Classe Command |
| `scripts/console/commands/base_commands.gd` | Script | Comandos base |
| `scripts/console/commands/race_commands.gd` | Script | Comandos de corrida |
| `scripts/console/commands/admin_commands.gd` | Script | Comandos admin |
| `scenes/tracks/test_oval.tscn` | Cena | Pista de teste oval |
| `config/bot_presets.json` | Config | Perfis de bots |

## Ficheiros a Modificar

| Ficheiro | Mudança |
|---|---|
| `game/project.godot` | physics_ticks=120, input toggle_console, autoload console |
| `scripts/vehicles/car_controller.gd` | Ler de telemetry, COM, gravity |
| `scenes/vehicles/base_car.tscn` | Suspensão wheel3d, CollisionShape3D |
| `scenes/tracks/base_track.tscn` | CollisionShape3D nos checkpoints |
| `scripts/ui/race_hud.gd` | Mostrar telemetria (temp pneus, fuel, dano) |
| `scripts/ui/lobby_screen.gd` | Opção de bots |
| `config/cars/base_car.json` | Expandir com tyre/fuel/damage params |

---

## Nota: Pista 3D

O utilizador está a procurar um modelo de pista. Quando tiver:
- Substituir `test_oval.tscn` pela cena com o modelo real
- Adaptar Path3D do racing line ao novo traçado
- Ajustar checkpoints à nova geometria
- O sistema de telemetria e bots funciona com qualquer pista
