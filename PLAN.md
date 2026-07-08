# Vivo Sprint — Game Design & Development Plan

## 1. Visão Geral
Jogo de corridas multiplayer 3D com físicas realistas, suporte a múltiplos carros/pistas, condições meteorológicas dinâmicas e integração Steamworks (lobbies, amigos, conquistas, overlay).

**Motor**: Godot 4.x (GDScript)  
**Rede**: ENetMultiplayerPeer + Steamworks API (GodotSteam GDExtension)  
**Público-alvo**: PC (Steam)

---

## 2. Estrutura de Pastas

```
game/
├── assets/
│   ├── cars/           # Modelos .glb/.blend dos carros
│   ├── tracks/         # Modelos das pistas
│   ├── audio/          # SFX, música, motor, colisão
│   ├── textures/       # Materiais, skins, decals
│   └── skyboxes/       # Céus para cada condição climática
├── scenes/
│   ├── ui/             # MainMenu, Lobby, HUD, Pit Menu, Settings
│   ├── tracks/         # Cenas de cada pista (track_name.tscn)
│   ├── vehicles/       # Cenas de cada carro (car_name.tscn)
│   ├── world/          # Cena global (WorldEnvironment, iluminação, sistema meteorológico)
│   └── pitlane/        # Cena da box/pit-lane (entrada/saída, HUD de pit)
├── scripts/
│   ├── network/        # network_manager.gd, lobby_manager.gd
│   ├── race/           # race_manager.gd, qualifying_manager.gd, lap_timer.gd
│   ├── vehicles/       # car_controller.gd, car_stats.gd, tyre_system.gd
│   ├── weather/        # weather_system.gd, precipitation.gd, time_of_day.gd
│   ├── ui/             # Controladores de cada cena UI
│   └── steam/          # steam_manager.gd, steam_lobby.gd
├── addons/
│   └── godotsteam/     # GodotSteam GDExtension
├── shaders/            # Shaders custom (água, chuva, vidro, reflexos)
├── config/             # JSON de configuração (carros, pistas, pneus, setups)
└── project.godot
```

---

## 3. Carros / Veículos

### 3.1 Sistema de Pneus (Tyres)
| Tipo | Abrev. | Condição | Característica |
|------|--------|----------|----------------|
| Soft | SS | Seco | Máxima aderência, desgaste rápido |
| Medium | MD | Seco | Equilíbrio aderência/duração |
| Hard | HD | Seco | Menos aderência, longa duração |
| Intermedium | IM | Chuva leve/mista | Transição seco-molhado |
| Full Wet | FW | Chuva intensa | Máxima drenagem de água |
| Wet Extreme | WE | Chuva torrencial | Apenas para condições extremas |

- Desgaste progressivo afecta a aderência ao longo das voltas
- Temperatura dos pneus influencia desempenho (janela operacional)
- Trocas na pit-lane

### 3.2 Parâmetros de Cada Carro
- Potência (HP/Nm)
- Peso
- Downforce (asa dianteira/traseira ajustável)
- Tipo de tracção (FWD, RWD, AWD)
- Caixa de velocidades (número de relações)
- Centro de gravidade

### 3.3 Setup / Ajustes
- Pressão dos pneus
- Cambagem e convergência
- Altura ao solo
- Taxa de molas e amortecedores
- Balanço de travões
- Asa dianteira/traseira

---

## 4. Pistas (Tracks)

- Múltiplos mapas com diferentes layouts
- Pit-lane funcional com linha de entrada/saída
- Zona de largada/partida (grid)
- Sectors (3 sectores por volta)
- Linha de meta (start/finish line)
- Zonas de tempo (lap time, sector time)

---

## 5. Condições Meteorológicas e Hora do Dia

### 5.1 Estado de Pista
| Estado | Descrição | Efeito |
|--------|-----------|--------|
| Seco | Pista seca | Aderência máxima |
| Damp | Pista húmida | Aderência reduzida |
| Molhado | Chuvisco/chuva leve | Aquaplanagem ligeira |
| Muito Molhado | Chuva intensa | Aquaplanagem severa, visibilidade reduzida |
| Alagado | Chuva torrencial | Apenas pneus Wet Extreme |

### 5.2 Hora do Dia
- Amanhecer → Dia → Crepúsculo → Noite
- Transição suave com DirectionalLight + Sky
- Faróis dos carros obrigatórios à noite

### 5.3 Precipitação
- Chuva leve (partículas finas, pista damp)
- Chuva moderada (partículas médias, pista molhada)
- Chuva pesada (partículas densas, pista muito molhada + trovoada opcional)
- Intensidade variável ao longo da sessão (opcional)

---

## 6. Modos de Jogo

### 6.1 Modos de Corrida
| Modo | Descrição |
|------|-----------|
| Practice | Voltas livres sozinho ou com outros |
| Qualifying | Volta lançada cronometrada, define grelha |
| Race | Corrida com X voltas, boxes |
| Sprint Race | Corrida curta (~5 voltas) |
| Endurance | Corrida longa (X minutos ou voltas) |
| Time Attack | Melhor volta individual |
| Drift Challenge | Pontuação por drift |

### 6.2 Formato Típico de Sessão
1. **Practice** (opcional, X minutos)
2. **Qualifying** (volta lançada, ~15 min)
3. **Race** (voltas definidas no server)

---

## 7. Sistema Multiplayer (Steam + ENet)

### 7.1 Integração Steamworks
- **GodotSteam GDExtension** para acesso à API
- **Lobbies Steam**:
  - Público (qualquer um vê e entra)
  - Privado (só entra quem recebe convite)
  - Amigos (só amigos do host)
  - Invite Only (convite manual via Steam Friends)
- **Overlay Steam** para convites
- **Steam IDs** para identificar jogadores
- **Conquistas** (Steam Achievements)
- **Leaderboards** (Steam Leaderboards)

### 7.2 Arquitectura de Rede
- **Server-authoritative**: servidor decide posições, colisões, clima
- **Client prediction + reconciliation** nos carros
- **Host como server** (listen server) ou **dedicated server**
- **Networking**: ENetMultiplayerPeer + RPCs
- **Tick rate**: ~30-60 Hz para sincronização de carros

### 7.3 Sistema de Lobby
| Campo | Descrição |
|-------|-----------|
| Nome da sessão | Customizável |
| Modo | Practice, Quali, Race, etc. |
| Pista | Track selecionada |
| Condições meteorológicas | Seco, Chuva, Dinâmico |
| Hora do dia | Selecionável |
| Max jogadores | 2-20 |
| Voltas | Número de voltas |
| Pit-stops obrigatórios | Sim/Não |
| Dano | Nenhum, Reduzido, Realista |

---

## 8. UI / Interface

### 8.1 Ecras Principais
- **Main Menu**: Singleplayer, Multiplayer, Settings, Quit
- **Server Browser**: Lista de servidores públicos (Steam lobbies)
- **Lobby**: Jogadores conectados, selecção de carro, prontos, iniciar
- **Car Select**: Escolha de carro + cor
- **HUD de Corrida**:
  - Velocímetro / conta-rotações
  - Mapa da pista (minimapa)
  - Posição actual
  - Lap time actual + melhor volta
  - Sector times
  - Delta em relação ao líder ou ao melhor tempo
  - Estado dos pneus (temperatura, desgaste)
  - Combustível (se aplicável)
  - Mensagens do chat
  - Notificações (ultrapassagens, penalties)
- **Pit Menu**: Escolha de pneus, reparações, ajuste de asas
- **Results Screen**: Classificação final, melhores voltas
- **Settings**: Gráficos, áudio, controlos, teclas

---

## 9. Progressão / Conteúdo Planeado (Fases)

### Fase 1 — Core
- 1 pista
- 1 carro jogável
- Física básica do carro (RWD)
- Modo Time Attack singleplayer
- HUD básico

### Fase 2 — Multiplayer + Steam
- Lobbies Steam
- 2-4 jogadores em rede
- Sincronização de carros (server-authoritative)
- Chat

### Fase 3 — Carros + Pneus
- 3 carros
- Sistema completo de pneus (5 tipos)
- Desgaste e temperatura
- Setup de carro

### Fase 4 — Pistas + Meteorologia
- 3 pistas
- Sistema de chuva dinâmico
- Ciclo dia/noite
- 5 estados de pista

### Fase 5 — Modos de Jogo
- Qualifying + Race
- Pit-lane funcional
- Formato completo de sessão

### Fase 6 — Polimento
- Leaderboards Steam
- Conquistas
- Skins para carros
- Replay system
- Áudio profissional (motor, colisão, chuva, ambiente)
- Efeitos visuais (fumo, faíscas, spray de água)

---

## 10. Stack Técnico

| Componente | Tecnologia |
|------------|------------|
| Motor | Godot 4.x |
| Lenguagem | GDScript |
| Rede | ENetMultiplayerPeer (nativo Godot) |
| Steam | GodotSteam (GDExtension) |
| Modelos 3D | Blender → .glb |
| Som | FMOD (futuro) ou AudioStreamPlayer |
| Shaders | Godot Shading Language (VisualShader ou text shaders) |

---

## 11. Assets (Iniciais para Protótipo)

Usar assets temporários gratuitos do:
- **Kenney.nl** (carros low poly)
- **opengameart.org** (sons de motor)
- **Godot Asset Library** (skyboxes)

Substituir por modelos próprios/contratados na Fase 5.

---

## 12. Controlos (Teclado / Gamepad)

| Acção | Teclado | Gamepad |
|-------|---------|---------|
| Acelerar | W / Seta cima | RT / R2 |
| Travar | S / Seta baixo | LT / L2 |
| Virar | A/D ou Setas | Left Stick |
| Ligar/Desligar motor | E | — |
| Entrar Pit | P | D-Pad Up |
| Chat | T | — |
| Menu Pausa | Escape | Start |
| Câmaras | C | Y / Triangle |
| Flash Faróis | F | L3 |

---

## 13. Checklist de Desenvolvimento

- [ ] Projecto Godot configurado com Forward+ renderer
- [ ] GodotSteam instalado e configurado (steam_appid.txt)
- [ ] Carro base com física (VehicleBody3D)
- [ ] 1 pista com colisão e checkpoints
- [ ] HUD de corrida (velocidade, tempo, posição)
- [ ] Voltas e sector times
- [ ] Lobby Steam (criar, entrar, listar)
- [ ] Multiplayer funcional (2+ jogadores)
- [ ] Sincronização de carros em rede
- [ ] 5 tipos de pneus com desgaste
- [ ] Sistema meteorológico (seco → chuva)
- [ ] Ciclo dia/noite com transição
- [ ] Modo Qualifying
- [ ] Modo Race com grelha
- [ ] Pit-lane (entrada/saída, troca de pneus)
- [ ] Setup de carro (menu antes da corrida)
- [ ] Steam achievements
- [ ] Steam leaderboards
- [ ] 3+ carros selecionáveis
- [ ] 3+ pistas
- [ ] Polimento de áudio e VFX
