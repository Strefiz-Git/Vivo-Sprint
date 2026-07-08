# Guia Completo do GodotSteam (Godot 4)

> Baseado na documentação oficial em [godotsteam.com](https://godotsteam.com) e no repositório [codeberg.org/godotsteam/godotsteam](https://codeberg.org/godotsteam/godotsteam). Este guia foca-se no essencial para um projeto normal em Godot 4: inicialização, lobbies, amigos, networking (P2P/MultiplayerPeer) e servidores dedicados.

---

## Índice

1. [O que é o GodotSteam](#1-o-que-é-o-godotsteam)
2. [Instalação e Setup Inicial](#2-instalação-e-setup-inicial)
3. [Inicializar o Steam](#3-inicializar-o-steam)
4. [Callbacks (`run_callbacks`)](#4-callbacks-run_callbacks)
5. [Dados básicos do utilizador](#5-dados-básicos-do-utilizador)
6. [Amigos (Friends)](#6-amigos-friends)
7. [Lobbies (Matchmaking)](#7-lobbies-matchmaking)
8. [Chat da Lobby](#8-chat-da-lobby)
9. [Convidar / Aceitar convites](#9-convidar--aceitar-convites)
10. [Networking — Ligar Jogadores (P2P)](#10-networking--ligar-jogadores-p2p)
11. [Servidores Dedicados (Game Servers)](#11-servidores-dedicados-game-servers)
12. [Rich Presence](#12-rich-presence)
13. [Conquistas e Estatísticas](#13-conquistas-e-estatísticas)
14. [Overlay do Steam](#14-overlay-do-steam)
15. [Segurança e Anti-Cheat](#15-segurança-e-anti-cheat)
16. [Outras funcionalidades úteis](#16-outras-funcionalidades-úteis)
17. [Erros comuns e dicas](#17-erros-comuns-e-dicas)
18. [Recursos extra](#18-recursos-extra)

---

## 1. O que é o GodotSteam

O **GodotSteam** é uma extensão (module, GDExtension ou GDNative, dependendo da versão) que expõe o SDK do Steamworks (a API oficial do Steam para programadores) dentro do Godot, através de um singleton chamado `Steam`. Basicamente permite ao teu jogo:

- Saber quem é o utilizador logado no Steam e os seus amigos;
- Criar e gerir **lobbies** (salas de espera antes de um jogo);
- Fazer **networking P2P** (ligar jogadores diretamente via Steam, sem precisares de gerir IPs/portas manualmente);
- Usar **conquistas**, **estatísticas**, **leaderboards**, **Workshop** (mods/conteúdo criado por utilizadores), **cloud saves**, **overlay do Steam**, etc.

Existem várias variantes do GodotSteam (module compilado no motor, GDExtension — a recomendada atualmente — e GDNative, mais antiga). Este guia assume que estás a usar a **GDExtension**, que é a forma standard de usar hoje em dia com Godot 4.

---

## 2. Instalação e Setup Inicial

1. Vai a [codeberg.org/godotsteam/godotsteam/releases](https://codeberg.org/godotsteam/godotsteam/releases) e descarrega a versão GDExtension correspondente à tua versão do Godot 4.
2. Extrai o conteúdo para a raiz do teu projeto Godot (deve criar uma pasta `addons/` ou similar, com os ficheiros `.gdextension`, `.dll`/`.so`/`.dylib`, etc.).
3. Reabre o Godot — o singleton `Steam` deve ficar automaticamente disponível globalmente (não precisas de o adicionar como Autoload, ele já vem registado pela extensão).
4. Precisas de um **App ID** válido do Steam. Para testes, podes usar o **480** (é o jogo de exemplo "Spacewar" da Valve, usado oficialmente para testes).

### Definir o App ID

Há 4 formas (escolhe uma):

- **Project Settings → Steam → Initialization** (a partir do GodotSteam 4.14): define o App ID diretamente nas definições do projeto.
- Passar como argumento à função de inicialização (ver secção seguinte).
- Definir variáveis de ambiente no `_init()` de um autoload:
  ```gdscript
  func _init() -> void:
      OS.set_environment("SteamAppId", str(480))
      OS.set_environment("SteamGameId", str(480))
  ```
- Criar um ficheiro `steam_appid.txt` na raiz do projeto/executável, contendo só o número do App ID (ex: `480`). **Não deves incluir este ficheiro quando publicas o jogo no Steam** — a Valve recomenda removê-lo no build final.

---

## 3. Inicializar o Steam

Recomenda-se criar um **script Autoload** (ex: `steamworks.gd`) responsável por tratar de tudo o que é Steam.

```gdscript
# steamworks.gd (Autoload / Singleton)
var lobby_id: int = 0
var steam_id: int = 0
var steam_username: String = ""

func _ready() -> void:
    initialize_steam()

func initialize_steam() -> void:
    var initialize_response: Dictionary = Steam.steamInitEx()
    print("Steam inicializou?: %s" % initialize_response)

    if initialize_response["status"] > Steam.STEAM_API_INIT_RESULT_OK:
        print("Falha ao inicializar o Steam: %s" % initialize_response)
        get_tree().quit()
        return

    steam_id = Steam.getSteamID()
    steam_username = Steam.getPersonaName()
```

### `steamInitEx()` vs `steamInit()`

- **`steamInitEx(app_id, embed_callbacks)`** → devolve um `Dictionary` com:
  - `"verbal"` — texto explicativo do resultado;
  - `"status"` — código:
    - `0` → inicializado com sucesso
    - `1` → outra falha qualquer
    - `2` → não conseguiu ligar ao Steam (o cliente Steam provavelmente não está aberto)
    - `3` → o cliente Steam está desatualizado
- **`steamInit(app_id, embed_callbacks)`** → devolve só um `bool` (mais simples, mas com menos detalhe de erro).

Ambos aceitam `app_id` (int, opcional) e `embed_callbacks` (bool, opcional) como argumentos.

> Nota: se vieres de versões antigas do GodotSteam (3.27/4.13 ou anteriores), o primeiro argumento booleano para sincronizar stats/achievements **já não existe** — o SDK trata disso automaticamente a partir da versão 1.61.

---

## 4. Callbacks (`run_callbacks`)

O Steam funciona por **callbacks assíncronos** — quando pedes algo (ex: criar lobby), a resposta não vem de imediato, vem por sinal (`Signal`) mais tarde. Para receberes esses sinais, precisas de "bombear" os callbacks continuamente.

Três formas de fazer isto:

1. **Project Settings → Steam → Initialization → Embed Callbacks** (automático).
2. Passar `true` como segundo argumento a `steamInitEx()` / `steamInit()`.
3. Manualmente, no `_process()` de um script global:
   ```gdscript
   func _process(_delta: float) -> void:
       Steam.run_callbacks()
   ```

**Importante:** este código deve estar num nó/script que **nunca pausa** (senão os callbacks deixam de disparar quando o jogo está em pausa).

---

## 5. Dados básicos do utilizador

Depois de inicializado, tens acesso imediato a informação do utilizador local:

```gdscript
var steam_id: int = Steam.getSteamID()               # ID único (64-bit) do utilizador
var steam_username: String = Steam.getPersonaName()  # Nome de utilizador Steam
var is_online: bool = Steam.loggedOn()                # Está online?
var is_owned: bool = Steam.isSubscribed()             # É dono do jogo?
var ui_language: String = Steam.getSteamUILanguage()
var is_on_steam_deck: bool = Steam.isSteamRunningOnSteamDeck()
var is_on_vr: bool = Steam.isSteamRunningInVR()
var game_language: String = Steam.getCurrentGameLanguage()
var app_owner: int = Steam.getAppOwner()
var build_id: int = Steam.getAppBuildId()
var install_dir: Dictionary = Steam.getAppInstallDir(app_id)
```

Podes usar `isSubscribed()` para bloquear o jogo se o utilizador não for dono (cuidado: isto também bloqueia quem usa Family Share ou Free Weekends, por isso pensa bem se queres mesmo fazer isto).

---

## 6. Amigos (Friends)

A classe **Friends** dá-te acesso à lista de amigos do utilizador e informação sobre eles.

### Listar amigos

```gdscript
# FRIEND_FLAG_IMMEDIATE = amigos "verdadeiros" (não conhecidos de jogos, clãs, etc.)
var num_friends: int = Steam.getFriendCount(Steam.FRIEND_FLAG_IMMEDIATE)

for i in range(num_friends):
    var friend_id: int = Steam.getFriendByIndex(i, Steam.FRIEND_FLAG_IMMEDIATE)
    var friend_name: String = Steam.getFriendPersonaName(friend_id)
    print("Amigo: %s (%s)" % [friend_name, friend_id])
```

> **Nota:** tens de chamar `getFriendCount()` **antes** de `getFriendByIndex()`, e usar sempre a mesma flag (`FriendFlags`) nas duas chamadas.

### Saber o que um amigo está a jogar (e se está numa lobby)

```gdscript
var game_info: Dictionary = Steam.getFriendGamePlayed(friend_id)
```

Devolve um dicionário (vazio se o amigo está offline ou não está a jogar nada) com:

| Chave | Tipo | Descrição |
|---|---|---|
| `id` | int | App ID do jogo que o amigo está a jogar |
| `lobby` | int **ou** String | ID da lobby (int) se estiver numa lobby visível, senão a string `"No valid lobby"` |
| `ip` | String | Normalmente `0` a menos que a lobby exponha isto |
| `game_port` | int | Idem |
| `query_port` | int | Idem |

### Encontrar lobbies de amigos que jogam o teu jogo

```gdscript
func get_lobbies_with_friends() -> Dictionary:
    var results: Dictionary = {}
    for i in range(Steam.getFriendCount(Steam.FRIEND_FLAG_IMMEDIATE)):
        var friend_id: int = Steam.getFriendByIndex(i, Steam.FRIEND_FLAG_IMMEDIATE)
        var game_info: Dictionary = Steam.getFriendGamePlayed(friend_id)
        if game_info.is_empty():
            continue

        var app_id: int = game_info["id"]
        var lobby = game_info["lobby"]

        # Só nos interessa se for o nosso jogo e se estiver mesmo numa lobby
        if app_id != Steam.getAppID() or lobby is String:
            continue

        if not results.has(lobby):
            results[lobby] = []
        results[lobby].append(friend_id)

    return results
```

Depois, para entrar, basta chamares `Steam.joinLobby(lobby_id)` com o ID escolhido.

### Verificar se um amigo ainda está numa lobby antes de entrar

Já que a informação pode estar desatualizada (o amigo pode ter saído entretanto), vale a pena confirmar antes de tentares entrar:

```gdscript
func is_friend_still_in_lobby(friend_id: int, lobby_id: int) -> bool:
    var game_info: Dictionary = Steam.getFriendGamePlayed(friend_id)
    if game_info.is_empty():
        return false
    return game_info["id"] == Steam.getAppID() and game_info["lobby"] is int and game_info["lobby"] == lobby_id
```

### Outras funções úteis de amigos

- `Steam.getPersonaName()` — nome do utilizador local.
- `Steam.getFriendPersonaName(steam_id)` — nome de outro utilizador (útil para mostrar quem enviou um convite, quem está na lobby, etc.).
- `Steam.activateGameOverlayToUser("steamid", steam_id)` — abre o perfil Steam de alguém no overlay.
- `Steam.activateGameOverlayToUser("achievements", steam_id)` — abre as conquistas de um jogador.
- `Steam.activateGameOverlayToUser("friendadd", steam_id)` — envia pedido de amizade.
- `Steam.activateGameOverlayInviteDialog(lobby_id)` — abre a caixa de diálogo de convite Steam para a lobby indicada.

---

## 7. Lobbies (Matchmaking)

As lobbies são o mecanismo padrão do Steam para reunir jogadores antes de um jogo (uma "sala de espera"), e servem também para obteres facilmente os Steam IDs necessários ao networking P2P.

### Tipos de lobby (`Steam.LobbyType`)

| Constante | Efeito |
|---|---|
| `LOBBY_TYPE_PRIVATE` | Só visível a quem for convidado |
| `LOBBY_TYPE_FRIENDS_ONLY` | Visível aos amigos do dono |
| `LOBBY_TYPE_PUBLIC` | Aparece nas pesquisas públicas |
| `LOBBY_TYPE_INVISIBLE` | Invisível a pesquisas (só entra quem tiver o ID) |

### Criar uma lobby

```gdscript
func _ready() -> void:
    Steam.lobby_created.connect(_on_lobby_created)

func create_lobby(lobby_type: Steam.LobbyType, max_players: int) -> void:
    Steam.createLobby(lobby_type, max_players)

func _on_lobby_created(connect_status: Steam.Result, lobby_id: int) -> void:
    if connect_status == Steam.Result.RESULT_OK:
        Steamworks.lobby_id = lobby_id
        print("Lobby criada: %s" % lobby_id)

        # Nome visível da lobby (usado nas listagens)
        Steam.setLobbyData(lobby_id, "lobby_name", "Lobby do Jogador1")

        # Podes guardar "tags" adicionais em pares chave:valor
        Steam.setLobbyData(lobby_id, "mode", "coop")
    else:
        printerr("Falha ao criar lobby: %s" % connect_status)
```

O máximo de jogadores permitido por lobby é **250**.

> Ao criar a lobby com sucesso, o Steam dispara também um callback **`lobby_joined`** — porque o anfitrião ("host") entra automaticamente na sua própria lobby.

### Procurar / Listar lobbies (filtros)

```gdscript
func _ready() -> void:
    Steam.lobby_match_list.connect(_on_lobby_match_list)

func search_lobbies() -> void:
    # Filtro de distância: LOBBY_DISTANCE_FILTER_CLOSE / _DEFAULT / _FAR / _WORLDWIDE
    Steam.addRequestLobbyListDistanceFilter(Steam.LOBBY_DISTANCE_FILTER_WORLDWIDE)

    # Só lobbies com pelo menos X vagas livres
    Steam.addRequestLobbyListFilterSlotsAvailable(1)

    # Máximo de resultados devolvidos (limite geral: 50)
    Steam.addRequestLobbyListResultCountFilter(50)

    # Procurar por uma tag exata definida com setLobbyData()
    Steam.addRequestLobbyListStringFilter("mode", "coop", Steam.LOBBY_COMPARISON_EQUAL)

    Steam.requestLobbyList()

func _on_lobby_match_list(lobbies: Array) -> void:
    if lobbies.is_empty():
        print("Nenhuma lobby encontrada")
        return
    for lobby_id in lobbies:
        var lobby_name: String = Steam.getLobbyData(lobby_id, "lobby_name")
        print("Lobby: %s (%s)" % [lobby_name, lobby_id])
```

**Importante:** só pode existir **uma pesquisa ativa de cada vez**; uma nova chamada a `requestLobbyList()` cancela a anterior. Os filtros são limpos a cada nova chamada, por isso tens de os voltar a definir sempre antes de pesquisar. A pesquisa pode demorar entre 300ms e 5s (timeout de 20s).

Filtros adicionais disponíveis:
- `addRequestLobbyListNearValueFilter()` — ordena por proximidade a um valor (não filtra, só influencia a ordem).
- `addRequestLobbyListNumericalFilter()` — filtra por comparação numérica (ex: nível mínimo).

### Entrar numa lobby

```gdscript
func _ready() -> void:
    Steam.lobby_joined.connect(_on_lobby_joined)

func join_lobby(lobby_id: int) -> void:
    Steam.joinLobby(lobby_id)

func _on_lobby_joined(lobby_id: int, _permissions: int, _locked: bool, response: Steam.ChatRoomEnterResponse) -> void:
    if response == Steam.ChatRoomEnterResponse.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
        Steamworks.lobby_id = lobby_id
        print("Entraste na lobby %s" % lobby_id)
        # Aqui trocas de cena para a cena da lobby
    else:
        match response:
            Steam.ChatRoomEnterResponse.CHAT_ROOM_ENTER_RESPONSE_DOESNT_EXIST:
                printerr("A lobby já não existe")
            Steam.ChatRoomEnterResponse.CHAT_ROOM_ENTER_RESPONSE_FULL:
                printerr("A lobby está cheia")
            Steam.ChatRoomEnterResponse.CHAT_ROOM_ENTER_RESPONSE_BANNED:
                printerr("Estás banido desta lobby")
            _:
                printerr("Falha a entrar na lobby: %s" % response)
```

### Entrar por convite Steam (sem usar a lista de lobbies)

Há dois cenários possíveis quando alguém aceita um convite ou clica "Join Game"/"Join Lobby" num amigo:

**1) O jogo já está aberto** → dispara o callback `join_requested`:

```gdscript
func _ready() -> void:
    Steam.join_requested.connect(_on_lobby_join_requested)

func _on_lobby_join_requested(lobby_id: int, friend_id: int) -> void:
    var friend_name: String = Steam.getFriendPersonaName(friend_id)
    print("A entrar na lobby de %s" % friend_name)
    Steam.joinLobby(lobby_id)
```

**2) O jogo NÃO está aberto** → o Steam lança o jogo com o argumento `+connect_lobby <lobby_id>` na linha de comandos. Como o Godot não entende isto nativamente, tens de tratar isso tu no arranque:

```gdscript
func check_command_line() -> void:
    var args: Array = OS.get_cmdline_args()
    if args.size() == 0 or args[0] != "+connect_lobby":
        return
    if int(args[1]) > 0:
        Steam.joinLobby(int(args[1]))
```

### Dados da lobby (`setLobbyData` / `getLobbyData`)

- `Steam.setLobbyData(lobby_id, key, value)` — define metadados na lobby inteira (nome, modo de jogo, etc.). Visível a todos que consultem a lobby.
- `Steam.getLobbyData(lobby_id, key)` — lê o valor associado a essa chave (devolve string vazia se não existir).
- `Steam.setLobbyMemberData(lobby_id, key, value)` — define dados específicos de **um jogador** (ex: "ready": "true"). Só o próprio jogador pode definir os seus dados.
- `Steam.getLobbyMemberData(lobby_id, member_id, key)` — lê dados de um membro específico.

Alterações a estes dados disparam o callback **`lobby_data_update`** em todos os membros.

### Info da lobby / membros

```gdscript
var num_members: int = Steam.getNumLobbyMembers(lobby_id)
for i in range(num_members):
    var member_id: int = Steam.getLobbyMemberByIndex(lobby_id, i)
    var member_name: String = Steam.getFriendPersonaName(member_id)

var owner_id: int = Steam.getLobbyOwner(lobby_id)  # dono atual da lobby
```

Se o dono sair, o Steam atribui automaticamente a posse a outro membro.

### Tornar a lobby (não) unível a novos membros

```gdscript
Steam.setLobbyJoinable(lobby_id, false)  # fecha a lobby a novos jogadores
```

### Sair da lobby

```gdscript
func leave_lobby() -> void:
    Steam.leaveLobby(Steamworks.lobby_id)
    Steamworks.lobby_id = 0
```

### Auto-Matchmaking (encontrar automaticamente uma lobby)

Ideia: pesquisar com filtros progressivamente mais largos (distância) até encontrar uma lobby com espaço; senão, criar uma nova.

Funções relevantes: `addRequestLobbyListDistanceFilter()`, `getLobbyData()`, `getNumLobbyMembers()`, `joinLobby()`, `requestLobbyList()`. A lógica típica é um "loop" que tenta distâncias `CLOSE → DEFAULT → FAR → WORLDWIDE`, e assim que aparecer uma lobby com espaço livre (`getNumLobbyMembers() < max`), chama `joinLobby()`. Se não encontrar nenhuma depois de esgotar as distâncias, cria uma lobby nova.

### Kick de jogadores

O Steamworks **não tem** um comando oficial de "kick". A convenção usada (inclusive pela Valve no exemplo SpaceWar) é enviar uma mensagem de chat especial que os clientes interpretam como comando:

```gdscript
# No host, ao clicar "Kick":
Steam.sendLobbyChatMsg(lobby_id, "/kick %s" % target_steam_id)

# Em todos os clientes, ao receberem lobby_message:
func _on_lobby_message(lobby_id, sender, message, chat_type) -> void:
    if message.begins_with("/") and sender == Steam.getLobbyOwner(lobby_id):
        var parts = message.split(" ", false)
        if parts[0] == "/kick" and Steamworks.steam_id == int(parts[1]):
            Steam.leaveLobby(lobby_id)
            # voltar ao menu / lista de lobbies
```

### Promover outro jogador a dono da lobby

```gdscript
Steam.setLobbyOwner(lobby_id, new_owner_steam_id)
```

### Todos os sinais (callbacks) relevantes de lobbies

| Sinal | Quando dispara |
|---|---|
| `lobby_created` | Depois de `createLobby()` |
| `lobby_joined` | Depois de `joinLobby()` (ou ao criar, o host recebe também este) |
| `lobby_match_list` | Depois de `requestLobbyList()` |
| `lobby_data_update` | Quando `setLobbyData()` / `setLobbyMemberData()` é chamado por alguém |
| `lobby_chat_update` | Quando alguém entra/sai da lobby |
| `lobby_message` | Quando alguém envia uma mensagem de chat na lobby |
| `join_requested` | Quando o jogador aceita um convite ou clica "Join" com o jogo já aberto |

---

## 8. Chat da Lobby

Enviar mensagens:

```gdscript
Steam.sendLobbyChatMsg(lobby_id, "Olá pessoal!")
```

Receber mensagens e atualizações de membros:

```gdscript
func _ready() -> void:
    Steam.lobby_chat_update.connect(_on_lobby_chat_update)
    Steam.lobby_message.connect(_on_lobby_message)

func _on_lobby_chat_update(lobby_id: int, user_changed_id: int, _making_change_id: int, chat_state: Steam.ChatMemberStateChange) -> void:
    var user_name: String = Steam.getFriendPersonaName(user_changed_id)
    if chat_state == Steam.ChatMemberStateChange.CHAT_MEMBER_STATE_CHANGE_ENTERED:
        print("%s entrou na lobby" % user_name)
    else:
        print("%s saiu da lobby" % user_name)
    # Boa prática: atualizar sempre a lista completa de membros aqui

func _on_lobby_message(lobby_id: int, sender: int, message: String, _chat_type: Steam.ChatEntryType) -> void:
    var sender_name: String = Steam.getFriendPersonaName(sender)
    print("%s: %s" % [sender_name, message])
```

---

## 9. Convidar / Aceitar convites

```gdscript
# Abre o painel do Steam para convidar amigos para a lobby atual
Steam.activateGameOverlayInviteDialog(lobby_id)
```

O fluxo de "aceitar convite" já foi coberto na secção 7 (`join_requested` e `+connect_lobby`).

---

## 10. Networking — Ligar Jogadores (P2P)

Depois de teres uma lobby, o passo seguinte é **ligar de facto os jogadores em rede**. O GodotSteam oferece várias formas:

1. **`SteamMultiplayerPeer`** — integra-se diretamente com o sistema `MultiplayerAPI` nativo do Godot (RPCs, `MultiplayerSpawner`, `MultiplayerSynchronizer`, etc.). **É a forma recomendada** para a maioria dos jogos, porque reaproveita tudo o que já conheces do multiplayer normal do Godot.
2. **Networking clássico (`Networking` class)** — API P2P mais "manual" e de baixo nível.
3. **Networking Messages / Networking Sockets** — APIs mais modernas do Steamworks para P2P, com mais controlo (canais, fiabilidade, etc.), mas mais trabalho manual.

Este guia foca-se na opção 1, por ser a mais direta.

### Conceito: Servidor, Peers e Autoridade

- O **servidor** é a instância do jogo à qual todas as outras se ligam. Tem sempre o `peer id` = **1**.
- Cada participante ligado (incluindo o servidor) é um **peer**, com um ID único atribuído na ligação.
- **Autoridade** é um conceito por nó: define que peer controla esse nó. Por padrão o servidor tem autoridade sobre tudo, a menos que uses `set_multiplayer_authority()` para a transferir.

> Nota: as builds de **servidor dedicado** do GodotSteam atualmente **não** têm suporte a `MultiplayerPeer` (está em desenvolvimento). Para servidores dedicados "clássicos" (sem serem só outro jogador), consulta a secção 11.

### Criar o Host (quem cria a lobby)

```gdscript
func _on_lobby_created(connect_status: Steam.Result, lobby_id: int) -> void:
    if connect_status == Steam.Result.RESULT_OK:
        var peer: MultiplayerPeer = SteamMultiplayerPeer.new()
        peer.create_host(0)
        peer.server_relay = true
        multiplayer.set_multiplayer_peer(peer)
```

### Ligar como Cliente (quem entra na lobby)

```gdscript
func _on_lobby_joined(lobby_id: int, _permissions, _locked, response: int) -> void:
    if response == Steam.CHAT_ROOM_ENTER_RESPONSE_SUCCESS:
        var owner_id: int = Steam.getLobbyOwner(lobby_id)
        if owner_id != Steam.getSteamID():
            var peer: MultiplayerPeer = SteamMultiplayerPeer.new()
            peer.create_client(owner_id, 0)
            peer.server_relay = true
            multiplayer.set_multiplayer_peer(peer)
```

> **`server_relay = true`** faz com que os clientes não comuniquem diretamente entre si — tudo passa pelo servidor. Isto simplifica a topologia da rede (cada cliente só precisa de ligação ao servidor, não a todos os outros) e evita problemas de sincronização quando alguém entra depois de a cena já estar carregada.

### Spawn de jogadores com `MultiplayerSpawner`

Estrutura de cena sugerida: um nó "Multiplayer" com um `MultiplayerSpawner` a apontar para um nó `%Players` (onde entram as instâncias de jogador).

```gdscript
func _ready() -> void:
    if not multiplayer.is_server():
        player_is_ready.rpc_id(1)
        return
    spawn_player(1)

@rpc("any_peer", "call_local", "reliable")
func player_is_ready() -> void:
    var sender_id: int = multiplayer.get_remote_sender_id()
    spawn_player(sender_id)

func spawn_player(id: int) -> void:
    var player := player_scene.instantiate()
    player.name = str(id)   # o nome tem de ser o peer id, para o MultiplayerSpawner sincronizar bem
    %Players.add_child(player)
```

### Dar controlo ao jogador certo (`MultiplayerSynchronizer`)

```gdscript
# No script do jogador
func _enter_tree() -> void:
    set_multiplayer_authority(int(name))
```

> Deve ser feito em `_enter_tree()` e não em `_ready()`, porque o `MultiplayerSynchronizer` sincroniza os valores iniciais entre `_enter_tree()` e `_ready()`, e não é permitido mudar a autoridade durante esse período.

Depois, adiciona um nó `MultiplayerSynchronizer` à cena do jogador e escolhe no separador "Replication" quais propriedades sincronizar (posição, rotação, animação, etc.).

```gdscript
func _physics_process(_delta: float) -> void:
    if not is_multiplayer_authority():
        return
    # só processa input/física se fores o dono deste jogador
```

### Remover jogadores desligados

```gdscript
func _ready() -> void:
    multiplayer.peer_disconnected.connect(remove_player)

func remove_player(id: int) -> void:
    if %Players.has_node(str(id)):
        %Players.get_node(str(id)).queue_free()
```

### RPCs (chamadas remotas)

Isto é standard do Godot, não específico do Steam — usa o decorador `@rpc`:

```gdscript
@rpc("any_peer", "call_local", "reliable")
func minha_funcao_remota(dados) -> void:
    ...

# Para chamar em todos os peers:
minha_funcao_remota.rpc(dados)

# Para chamar só num peer específico:
minha_funcao_remota.rpc_id(peer_id, dados)
```

Modos disponíveis no `@rpc`: `any_peer` (qualquer um pode chamar) vs `authority` (só quem tem autoridade); `call_local` (executa também localmente) vs `call_remote`; `reliable` (garante entrega, mais lento) vs `unreliable` / `unreliable_ordered` (mais rápido, pode perder pacotes — bom para posição em tempo real).

---

## 11. Servidores Dedicados (Game Servers)

Se o teu jogo precisar de **servidores dedicados reais** (não apenas "um jogador que também é host"), o GodotSteam tem uma variante compilada especificamente para isso, mais as classes:

- **Game Server** — regista o servidor no Steam, faz login como servidor, define nome, mapa, etc.
- **Game Server Stats** — estatísticas específicas de servidor.
- **Matchmaking Servers** — permite aos **clientes** procurar/listar servidores dedicados públicos (browser de servidores, tipo o clássico "server list" de jogos antigos).

### Fluxo típico de um servidor dedicado

1. Compilar/usar a build de **servidor** do GodotSteam.
2. No arranque, chamar as funções de login do `Game Server` (equivalente ao `steamInit`, mas do lado do servidor).
3. Definir dados do servidor: nome do mapa, número de jogadores, modo de jogo, etc. (via `Game Server` class).
4. Do lado do **cliente**, usar `Matchmaking Servers` para pedir a lista de servidores (`requestInternetServerList()`, `requestLANServerList()`, etc., consoante a versão) e depois ligar-se por IP/porta ou Steam ID do servidor, dependendo da configuração.

> Como referido na secção anterior, atualmente o `SteamMultiplayerPeer` **não** funciona nas builds de servidor dedicado — para esse cenário o networking tem de ser feito com as classes clássicas de Networking/Networking Sockets, ou com o `ENetMultiplayerPeer` do próprio Godot (ligação TCP/UDP normal), usando o Steam apenas para o browser de servidores e autenticação.

### Obter detalhes de um servidor guardado numa lobby

Uma alternativa mais simples (sem servidor dedicado "puro") é guardar o IP/porta ou Steam ID de um servidor de jogo dentro dos dados da própria lobby, e usar:

```gdscript
Steam.getLobbyGameServer(lobby_id)  # devolve dados do servidor de jogo associado à lobby
```

Isto é útil quando queres, por exemplo, um servidor que existe fora do ciclo de vida normal da lobby (ex: servidores persistentes que várias lobbies podem apontar).

---

## 12. Rich Presence

Rich Presence permite mostrar informação contextual no perfil Steam dos jogadores (ex: "A jogar no Mapa X, Nível 5" visível na lista de amigos).

```gdscript
Steam.setRichPresence("status", "A jogar no Nível 3")
Steam.setRichPresence("connect", "+connect_lobby %s" % lobby_id)  # permite "Join Game" pelo Steam
Steam.clearRichPresence()
```

O valor de `"connect"` é especialmente importante: é o que faz o botão "Join Game" no Steam funcionar automaticamente, lançando o teu jogo com o argumento de linha de comandos `+connect_lobby <id>` (ver secção 7).

---

## 13. Conquistas e Estatísticas

Rápido resumo (não é o foco principal deste guia, mas é muito comum ser necessário):

```gdscript
Steam.setAchievement("ACHIEVEMENT_API_NAME")
Steam.storeStats()  # obrigatório para gravar no servidor Steam

var unlocked: Array = Steam.getAchievement("ACHIEVEMENT_API_NAME")

Steam.setStatInt("stat_name", valor)
Steam.getStatInt("stat_name")
```

> Desde o SDK 1.61, o Steam sincroniza automaticamente stats/achievements no arranque — já não é preciso chamar `requestCurrentStats()` (essa função e o callback `current_stats_received` foram removidos).

---

## 14. Overlay do Steam

O overlay é o painel que aparece por cima do jogo (Shift+Tab por padrão) com chat, amigos, etc.

```gdscript
Steam.activateGameOverlay("friends")          # abre o painel de amigos
Steam.activateGameOverlay("community")
Steam.activateGameOverlay("players")
Steam.activateGameOverlay("settings")
Steam.activateGameOverlay("officialgamegroup")
Steam.activateGameOverlay("stats")
Steam.activateGameOverlay("achievements")

Steam.activateGameOverlayToUser("steamid", steam_id)     # perfil de um jogador
Steam.activateGameOverlayToUser("chat", steam_id)        # chat privado com um jogador
Steam.activateGameOverlayToUser("friendadd", steam_id)   # pedido de amizade
Steam.activateGameOverlayToUser("achievements", steam_id)

Steam.activateGameOverlayInviteDialog(lobby_id)           # convite direto para lobby
```

> **Cuidado:** com o renderer **Forward+** do Godot, o overlay do Steam pode não funcionar quando corres o jogo pelo editor, a menos que uses a auto-inicialização definida em Project Settings. Testar sempre pela build exportada, correndo através do cliente Steam, é mais fiável.

---

## 15. Segurança e Anti-Cheat

Multiplayer é uma das áreas onde é mais fácil cometer erros de segurança graves, porque estás literalmente a receber dados de máquinas que não controlas. Esta secção resume os princípios recomendados pela própria Valve (documentação oficial de Anti-Cheat do Steamworks) e boas práticas gerais de networking.

### O princípio fundamental: "nunca confies no cliente"

Qualquer dado que venha de um cliente (posição, vida, dinheiro, dano causado, inventário, etc.) **pode ter sido alterado**. Um jogador pode:

- Editar memória do processo em tempo real (Cheat Engine e semelhantes);
- Modificar o próprio código do jogo (decompilar/recompilar, patches binários);
- Enviar pacotes de rede fabricados manualmente, sem sequer correr o teu jogo verdadeiro;
- Automatizar inputs (bots/scripts).

A recomendação oficial da Valve é clara: **a lógica de jogo crítica deve ser autoritativa no servidor**, e o servidor só deve enviar aos clientes a informação estritamente necessária, no momento certo (ex: não enviar a posição de inimigos fora do alcance visual, para evitar "wallhacks").

Aplicado ao GodotSteam com `SteamMultiplayerPeer`, isto significa, na prática:

```gdscript
# ERRADO — o cliente diz "dei dano" e o servidor acredita cegamente
@rpc("any_peer", "call_local", "reliable")
func aplicar_dano(alvo_id: int, dano: int) -> void:
    get_node(str(alvo_id)).vida -= dano


# CERTO — o servidor calcula o dano, o cliente só pede a ação
@rpc("any_peer", "call_local", "reliable")
func pedir_ataque(alvo_id: int) -> void:
    if not multiplayer.is_server():
        return  # só o servidor processa isto
    var atacante_id: int = multiplayer.get_remote_sender_id()
    # o servidor verifica distância, cooldown, linha de visão, etc. antes de aplicar dano
    if not pode_atacar(atacante_id, alvo_id):
        return
    var dano: int = calcular_dano(atacante_id, alvo_id)  # calculado no servidor, não recebido do cliente
    aplicar_dano_no_servidor.rpc(alvo_id, dano)
```

Regra prática: **um `@rpc("any_peer")` deve normalmente pedir uma ação ("quero atacar", "quero apanhar o item"), nunca reportar um resultado ("dei 50 de dano", "apanhei o item")**. Quem decide o resultado é sempre o servidor.

### Autoridade e `MultiplayerSynchronizer`

- Só concedas `set_multiplayer_authority()` a um cliente sobre coisas que **ele realisticamente não consegue usar para fazer batota de forma grave** — tipicamente a posição/animação do seu próprio avatar (efeito puramente cosmético e corrigível pelo servidor), nunca a sua vida, moedas, inventário, ou o estado de outros jogadores.
- Para dados sensíveis (vida, moedas, progresso), usa sempre variáveis com autoridade do **servidor**, nunca do jogador a quem pertencem, e sincroniza-as só para leitura no cliente.
- Se usares `server_relay = true` (recomendado, ver secção 10), todos os pacotes passam pelo servidor — o que já te dá o ponto de estrangulamento ideal para validar tudo antes de reencaminhar.

### P2P sem servidor central: validação mútua

Se o teu jogo for mesmo P2P puro (sem um cliente "host autoritativo" claro, ex: um jogo onde qualquer peer pode agir como servidor), a Valve recomenda que **cada cliente valide os outros**, para que o host não consiga dominar sozinho o estado do jogo. Na prática isto costuma significar:

- Cada peer recalcula localmente ações críticas (ex: se alguém diz que ganhou uma corrida, os outros peers verificam se os checkpoints batem certo com o histórico de posições que já observaram);
- Discrepâncias grandes entre o que um peer afirma e o que os outros observaram localmente = sinal de possível cheat, e podem ser motivo para desconectar/reportar esse peer.

Isto é mais trabalhoso do que ter um servidor autoritativo único, por isso, sempre que possível, **prefere sempre ter um servidor/host claramente autoritativo** em vez de P2P totalmente distribuído.

### Validar identidade — Auth Session Tickets

Se tiveres um backend próprio (fora do Steam) — por exemplo para guardar progresso, rankings próprios, ou um servidor dedicado que não confia cegamente em quem se liga — usa os **Auth Session Tickets** do Steam para confirmares que quem está do outro lado é mesmo quem diz ser (e não alguém a falsificar um Steam ID):

```gdscript
# No cliente: gera um ticket para provar a identidade ao teu backend
var ticket_data: Dictionary = Steam.getAuthSessionTicket()

# Envia ticket_data["id"] / ticket_data["buffer"] ao teu servidor/backend próprio

# No servidor (via Steamworks Game Server API): valida o ticket recebido
# Steam.beginAuthSession(ticket, steam_id) e escuta o callback validate_auth_ticket_response
```

Isto evita que alguém simplesmente "diga" que é um determinado Steam ID sem o provar — importante se atribuis privilégios, guardas dados, ou dás recompensas com base no Steam ID recebido.

### Não confies nos dados da lobby nem no chat

`setLobbyData()`, `setLobbyMemberData()` e as mensagens de `sendLobbyChatMsg()` **podem ser escritas por qualquer membro da lobby**, incluindo alguém a usar um cliente modificado que nunca corre o teu jogo de verdade. Cuidados a ter:

- **Nunca interpretes dados de lobby como comandos de confiança absoluta.** Por exemplo, se usas mensagens tipo `/kick <id>` (secção 7), confirma sempre que quem enviou é realmente o dono da lobby (`sender == Steam.getLobbyOwner(lobby_id)`) antes de agir.
- **Sanitiza sempre texto livre** (nomes de lobby, mensagens de chat, nomes de personagem) antes de o mostrares na UI — nunca interpretes essas strings como BBCode/HTML/comandos do teu jogo sem escaping, para evitar injeções visuais ou, em casos extremos, exploits em parsers mal feitos.
- Usa a funcionalidade de **Text Filtering** do Steamworks para filtrar linguagem imprópria de acordo com a região do utilizador, em vez de manteres a tua própria lista de palavras proibidas.
- Limita o tamanho de strings guardadas em `setLobbyData`/`setLobbyMemberData` — não assumas que o cliente vai respeitar limites que só existes na tua UI.

### Rate limiting e spam

Um cliente malicioso pode chamar RPCs ou enviar mensagens de chat em loop, tentando sobrecarregar os outros jogadores ou o servidor. Boas práticas:

- Implementa um **cooldown do lado do servidor** para ações repetíveis (ataques, mensagens de chat, pedidos de troca, etc.) — nunca confies só num cooldown do lado do cliente, que pode ser ignorado por um cliente modificado.
- Considera desconectar/reportar automaticamente peers que excedem um limite razoável de mensagens/pacotes por segundo.

### Proteção de IP e DDoS

Em P2P direto (sem `server_relay`), os jogadores trocam pacotes diretamente entre si, o que expõe o IP de cada um aos outros — um vetor conhecido para ataques de DDoS direcionados a um jogador específico (comum em jogos competitivos). Como já foi referido na secção 10:

- Usa `server_relay = true` sempre que possível — os clientes só falam com o servidor, nunca diretamente uns com os outros, escondendo o IP de todos exceto o do host.
- Considera ativar `Steam.allowP2PPacketRelay(true)`, que permite ao Steam retransmitir tráfego P2P através dos seus próprios servidores (Steam Relay) quando a ligação direta falha ou quando queres esconder o IP dos jogadores, à custa de alguma latência extra.

### VAC (Valve Anti-Cheat)

O **VAC** é o sistema de deteção de batota da própria Valve, ativado a nível do jogo no Steamworks (não é algo que actives por código no GodotSteam diretamente — configura-se no painel do Steamworks para o teu App ID). Coisas a saber:

- O VAC funciona melhor como **camada adicional**, não como substituto de teres um servidor autoritativo — a Valve é explícita que a melhor defesa continua a ser não confiar no cliente.
- Se um jogo é marcado como "VAC Secure", certas ações (como certas ferramentas de debug/injeção de DLLs) podem despoletar banimentos — testa sempre com contas de teste, nunca com a tua conta principal, e evita ativar VAC em builds de desenvolvimento.
- Banimentos por VAC ou por batota devem ser comunicados claramente ao jogador dentro do próprio jogo (a Valve recomenda mensagens explícitas em vez de falhas silenciosas), para reduzir confusão e pedidos de suporte desnecessários.
- Para jogos com necessidades mais avançadas, existem soluções de terceiros (Easy Anti-Cheat, BattlEye, etc.) que se integram com o Steamworks, mas isso está fora do âmbito do GodotSteam em si.

### Resumo — checklist rápido de segurança

- [ ] Toda a lógica que afeta o resultado do jogo (dano, economia, progresso) é decidida no **servidor**, nunca no cliente.
- [ ] RPCs `any_peer` pedem ações, não reportam resultados.
- [ ] Autoridade de `MultiplayerSynchronizer` só é dada para dados cosméticos/não-críticos.
- [ ] Mensagens de lobby/chat interpretadas como comandos verificam sempre o remetente.
- [ ] Texto livre de outros jogadores é sempre sanitizado antes de ser mostrado ou interpretado.
- [ ] Há cooldowns/rate limiting do lado do servidor para ações repetíveis.
- [ ] `server_relay` está ativo, a menos que tenhas uma razão forte para não o usar.
- [ ] Se tens backend próprio, valida identidade com Auth Session Tickets em vez de confiares cegamente no Steam ID enviado pelo cliente.
- [ ] VAC (e/ou anti-cheat de terceiros) é tratado como camada extra, não como única linha de defesa.

---

## 16. Outras funcionalidades úteis

Coisas que provavelmente vais querer explorar mais tarde, com as respetivas classes GodotSteam:

| Funcionalidade | Classe | Para quê |
|---|---|---|
| Cloud Saves | **Remote Storage** | Guardar saves/ficheiros sincronizados na cloud Steam |
| Workshop / Mods | **UGC** (User Generated Content) | Publicar/subscrever conteúdo criado por utilizadores |
| Leaderboards | **User Stats** | Rankings globais |
| DLC | **Apps** | Verificar se o utilizador tem DLCs |
| Voz | **User** / funções de voice chat | Chat de voz integrado no Steam |
| Screenshots | **Screenshots** | Tirar/gerir screenshots in-game |
| Autenticação | **User** (`getAuthSessionTicket`, etc.) | Validar jogadores em servidores próprios (anti-cheat/backend) |
| Loja / Inventário | **Inventory** | Itens, skins, trading cards, etc. |
| Filtragem de texto | funções de **Text Filtering** | Censurar chat automaticamente conforme definições regionais do utilizador |

---

## 17. Erros comuns e dicas

- **`status: 2` ao inicializar** → o cliente Steam não está aberto. Tens de ter o Steam a correr em segundo plano, mesmo em testes com App ID 480.
- **Lobby não aparece nas pesquisas** → verifica o `LobbyType` (não pode ser `LOBBY_TYPE_INVISIBLE`), se está `joinable` (`setLobbyJoinable`), e se não está cheia.
- **`run_callbacks()` nunca dispara sinais** → confirma que o nó/script onde está não pausa e que está mesmo a correr todos os frames.
- **Overlay não abre no editor** → experimenta correr a build exportada em vez do editor, especialmente com Forward+.
- **App ID 480 tem lobbies "lixo" de outros programadores a testar** → usa `setLobbyData()`/filtros de string para marcares as tuas lobbies com uma tag única (ex: `"game":"MeuJogo"`) e filtra só por essa tag ao pesquisar.
- **Testar P2P localmente** → normalmente precisas de duas instâncias do Steam com contas diferentes (ou usar uma segunda conta de teste), já que o Steam não permite o mesmo Steam ID ligado duas vezes em simultâneo à mesma sessão de forma trivial.
- **`steam_appid.txt` no build final** → remove sempre este ficheiro antes de publicares no Steam; serve só para testes locais sem passar pelo cliente Steam propriamente lançado pelo jogo.
- **Cliente a "confiar em si próprio"** → se alguma vez pensares "o cliente já validou isto, não preciso de validar outra vez no servidor", é quase sempre um sinal de alerta — revê a secção 15 (Segurança).

---

## 18. Recursos extra

- Documentação oficial: [godotsteam.com](https://godotsteam.com/classes/main/)
- Repositório / releases: [codeberg.org/godotsteam/godotsteam](https://codeberg.org/godotsteam/godotsteam)
- Tutorial de Lobbies completo: [godotsteam.com/tutorials/lobbies](https://godotsteam.com/tutorials/lobbies/)
- Tutorial de Amigos/Lobbies: [godotsteam.com/tutorials/friends_lobbies](https://godotsteam.com/tutorials/friends_lobbies/)
- Tutorial de MultiplayerPeer: [godotsteam.com/tutorials/multiplayer_peer](https://godotsteam.com/tutorials/multiplayer_peer/)
- Tutorial de Inicialização: [godotsteam.com/tutorials/initializing](https://godotsteam.com/tutorials/initializing/)
- Projeto de exemplo oficial (em construção): [Skillet no Codeberg](https://codeberg.org/godotsteam/skillet)
- Kit de arranque com cenas prontas (lobbies, avatares, chat, etc.): **GodotSteamKit**, referido nos tutoriais oficiais.

---

*Guia compilado a partir da documentação oficial do GodotSteam (godotsteam.com), atualizado a Julho de 2026.*
