# Ficheiros base do GodotSteam

Conjunto de scripts prontos a copiar para o teu projeto Godot 4, cobrindo a parte de Steam/multiplayer descrita no guia geral. Cada ficheiro é comentado no topo a explicar o que faz.

## Ficheiros incluídos

| Ficheiro | O que faz |
|---|---|
| `steam_helpers.gd` | Inicialização do Steam, dados do utilizador, amigos, overlay |
| `steam_lobbies.gd` | Criar/procurar/entrar em lobbies, password, chat, kick |
| `steam_networking.gd` | Host/cliente P2P, spawn de jogadores, migração de host, troca de cena sincronizada |
| `player_template.gd` | Script modelo para a cena do jogador (autoridade + interpolação) |
| `steam_voice.gd` | Voice chat normal e chat de proximidade |
| `steam_achievements.gd` | Conquistas, estatísticas, horas de jogo |
| `steam_workshop.gd` | Criar/publicar/procurar/subscrever itens do Workshop |
| `dedicated_server.gd` | Script principal de um servidor dedicado headless |
| `server_config.gd` | Leitor de `server.cfg` + argumentos de linha de comandos |
| `server.cfg.example` | Ficheiro de configuração de exemplo para distribuir com o servidor |

## Como instalar

1. Copia todos os ficheiros `.gd` para uma pasta no teu projeto, ex: `res://autoloads/`.
2. Vai a **Project Settings → Autoload** e adiciona, **por esta ordem** (a ordem importa, porque uns dependem dos outros):

   | Path | Nome |
   |---|---|
   | `res://autoloads/steam_helpers.gd` | `SteamHelpers` |
   | `res://autoloads/steam_lobbies.gd` | `SteamLobbies` |
   | `res://autoloads/steam_networking.gd` | `SteamNetworking` |
   | `res://autoloads/steam_voice.gd` | `SteamVoice` |
   | `res://autoloads/steam_achievements.gd` | `SteamAchievements` |
   | `res://autoloads/steam_workshop.gd` | `SteamWorkshop` |

3. `player_template.gd` **não** é um autoload — copia-o para o script da cena do teu jogador (`player.tscn`) e adapta o movimento à física do teu jogo.
4. `dedicated_server.gd` e `server_config.gd` só são usados na build de **servidor dedicado** (ver secção 13 do guia geral) — não precisam de estar na build normal do jogo. Podes adicionar `server_config.gd` como autoload `ServerConfig` só no preset de export do servidor, ou simplesmente chamar `ServerConfig.load_config()` diretamente a partir de `dedicated_server.gd` sem o registares como autoload (já está escrito para funcionar como classe estática).

## Fluxo típico de utilização (sala de espera → jogo)

```gdscript
# 1) Ligar aos sinais relevantes, normalmente num menu principal
SteamLobbies.lobby_created_successfully.connect(_on_lobby_ready)
SteamLobbies.lobby_joined_successfully.connect(_on_lobby_ready)

# 2) Criar ou entrar numa lobby
SteamLobbies.create_lobby(Steam.LOBBY_TYPE_PUBLIC, 8, "Sala do Fulano", "coop", "1234")
# ou
SteamLobbies.try_join_lobby(lobby_id, "1234")

func _on_lobby_ready(id: int) -> void:
    if SteamLobbies.is_local_player_owner():
        SteamNetworking.start_as_host()
    else:
        SteamNetworking.start_as_client(SteamLobbies.get_lobby_owner())

# 3) Na sala de espera, o host escolhe o mapa
SteamNetworking.host_announce_map("res://maps/floresta.tscn")

# 4) Quando todos estiverem prontos, o host começa o jogo
SteamNetworking.host_start_game()
```

## Coisas que ainda precisas de adaptar ao teu jogo

- `player_scene_path` em `steam_networking.gd` — aponta para a tua cena de jogador real.
- O spawn de jogadores (`player_spawn_requested` / `player_despawn_requested`) — liga estes sinais a uma função tua que instancia/remove a cena do jogador de facto (o autoload só emite o pedido, não sabe qual é a tua cena).
- `App ID` em `steam_helpers.gd` (`TEST_APP_ID`) — troca para o teu App ID real antes de publicares.
- Achievements/stats — os "API Names" usados (`ACH_...`, `total_kills`, etc.) têm de existir primeiro no painel do Steamworks.
- `dedicated_server.gd` assume que a lógica de jogo (física, spawn de inimigos, etc.) é adicionada por ti por cima — este ficheiro só trata da parte de rede/configuração/autenticação.

Para explicações mais detalhadas de cada função, consulta o guia geral em Markdown que já tens.
