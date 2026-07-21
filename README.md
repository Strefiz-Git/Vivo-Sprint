# Vivo Sprint

Jogo de corridas multiplayer 3D feito em Godot 4.7 com integração Steamworks (lobbies, matchmaking, overlay).

## Requisitos

- Godot 4.7+ (Forward+, Jolt Physics, Direct3D 12)
- **GodotSteam módulo** — usar o editor em `game/editor_steam/godotsteam.47.editor.win64.exe`
- Steam client em execução para funcionalidades online
- Windows x86_64 (único target suportado atualmente)

## Setup

```bash
git clone https://github.com/Strefiz/Vivo-Sprint.git
cd Vivo-Sprint

# Editor com suporte Steam
./game/editor_steam/godotsteam.47.editor.win64.exe

# Ou abrir a pasta game no Godot Launcher normal (sem Steam)
```

O `game/steam_appid.txt` contém o App ID **480** (Spacewar) para testes. Substituir pelo App ID real antes do lançamento.

## Exportar

```powershell
cd game
.\export.ps1                          # release
.\export.ps1 -Debug                   # modo debug
.\export.ps1 -OutputPath "out\j.exe"  # caminho customizado
```

O export usa templates custom com GodotSteam (`game/templates-export/win64/`).

## Estrutura

```
game/
├── addons/              # Plugins Godot
├── assets/              # Modelos, texturas, áudio, skyboxes
│   ├── audio/
│   ├── cars/
│   ├── skyboxes/
│   ├── textures/
│   └── tracks/
├── config/              # Dados (carros, pistas, pneus)
│   ├── cars/
│   ├── tracks/
│   └── tyres/
├── editor_steam/        # Editor Godot + GodotSteam
├── scenes/              # Cenas
│   ├── pitlane/
│   ├── tracks/
│   ├── ui/              # MainMenu, Lobby, HUD
│   ├── vehicles/
│   └── world/
├── scripts/             # Lógica
│   ├── network/         # network_manager.gd (ENet)
│   ├── race/            # Gestão de corrida
│   ├── steam/           # steam_manager.gd (Steamworks)
│   ├── ui/              # scene_manager, menus, lobby
│   ├── vehicles/        # Lógica de veículos
│   └── weather/         # Sistema meteorológico
├── shaders/             # Shaders custom
├── templates-export/    # Templates GodotSteam (win32/64, linux64/arm64)
├── export_presets.cfg   # Preset "Windows Desktop"
├── export.ps1           # Script de export
├── steam_api64.dll      # Steamworks SDK
├── steam_appid.txt      # App ID 480 (testes)
└── project.godot
```

## Autoloads (ordem de inicialização)

| Script | Função |
|---|---|
| `logger.gd` | Logging com níveis DEBUG/INFO/WARN/ERROR |
| `globals.gd` | Estado global da sessão, `PlayerInfo`, `SessionConfig` |
| `event_bus.gd` | Eventos de corrida (voltas, sectores, bandeiras, colisões) |
| `helpers.gd` | Funções utilitárias (formatação, math) |
| `settings.gd` | Definições de áudio/vídeo/input |
| `scene_manager.gd` | Transições entre cenas (goto_scene) |
| `steam_manager.gd` | Wrapper Steamworks: lobbies, callbacks, chat, friends, overlay |
| `steam_achievements.gd` | Conquistas, estatísticas, contagem de horas de jogo |
| `steam_voice.gd` | Chat de voz normal e chat de proximidade |
| `network_manager.gd` | ENetMultiplayerPeer + Steam P2P, host migration, scene sync |
| `locale_manager.gd` | Localização PT/EN |
| `resource_cache.gd` | Cache de recursos |

## Steamworks — Lobbies

O sistema de lobbies está implementado e funcional:

- **Navegação**: MainMenu → LobbyBrowser → LobbyCreate / LobbyScreen
- **Criação**: Nome, max jogadores (2-32), password, visibilidade (Público/Amigos/Privado/Convite)
- **Browser**: Pesquisa por nome, filtro por distância, filtro "sem password", refresh
- **Sala de espera**: Ready toggle, transferência de host, config do lobby, sair
- **Callbacks**: Tratamento de join/leave/kick/invite/falha com feedback na UI

### Notas importantes

- `lobby_data_update` do Steam tem **3 parâmetros** `(lobby_id, member_id, success)` — sem key/value
- O search chama `requestLobbyData()` por lobby e aguarda `lobby_data_update` (com fallback 3s)
- Lobbies "Amigos" (Friends Only) **não aparecem** na pesquisa para quem não é amigo
- `Steam.kickUserFromLobby()` não existe nesta build do GodotSteam — kick feito via chat message

### Friends & Overlay

- `get_friends_list()` — lista de amigos {id, name}
- `get_friend_lobbies()` — lobbies do jogo onde tens amigos
- `open_friends_overlay()` / `open_profile_overlay()` / `send_friend_request()`
- `open_invite_dialog()` — abre o overlay de convites da Steam

### Achievements & Stats

- `steam_achievements.gd` — `unlock_achievement()`, `set_stat_int()`, `sync_stat_int()`, contagem de horas
- API Names das conquistas/stats têm de existir primeiro no painel Steamworks

### Voice Chat

- `steam_voice.gd` — chat de voz global e chat de proximidade (via AudioStreamPlayer3D)
- Suporta push-to-talk ou voz sempre ativa

## Rede

O `network_manager.gd` suporta dois modos:
- **ENet** (para testes locais, `start_server()` / `connect_to_server()`)
- **Steam P2P** (`start_steam_host()` / `connect_to_steam()`) — integrado com lobbies

Funcionalidades de rede:
- **Host migration**: quando o host sai, o novo dono da lobby Steam assume automaticamente
- **Scene sync**: o host pode anunciar o mapa e iniciar o jogo para todos (`host_announce_map()`, `host_start_game()`)
- **Spawn/despawn**: sinais `player_spawn_requested` / `player_despawn_requested` para gerir jogadores

O `dedicated_server.gd` e `server_config.gd` em `scripts/network/` são para builds de servidor dedicado headless (não são autoloads normais).

## PLAN.md

Ver [`PLAN.md`](PLAN.md) para o documento de design completo com visão geral, mecânicas, física, áudio, roadmap, etc.

## Licença

MIT
