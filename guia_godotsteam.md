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
9. [Voice Chat](#9-voice-chat)
10. [Convidar / Aceitar convites](#10-convidar-aceitar-convites)
11. [Networking — Ligar Jogadores (P2P)](#11-networking-ligar-jogadores-p2p)
12. [Otimização de Performance em Rede](#12-otimização-de-performance-em-rede)
13. [Servidores Dedicados (Game Servers)](#13-servidores-dedicados-game-servers)
14. [Rich Presence (Steam e Discord)](#14-rich-presence-steam-e-discord)
15. [Conquistas, Estatísticas e Horas de Jogo](#15-conquistas-estatísticas-e-horas-de-jogo)
16. [Workshop / UGC (Conteúdo Criado por Utilizadores)](#16-workshop-ugc-conteúdo-criado-por-utilizadores)
17. [Overlay do Steam](#17-overlay-do-steam)
18. [Segurança e Anti-Cheat](#18-segurança-e-anti-cheat)
19. [Outras funcionalidades úteis](#19-outras-funcionalidades-úteis)
20. [Erros comuns e dicas](#20-erros-comuns-e-dicas)
21. [Recursos extra](#21-recursos-extra)

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

Isto mapeia-se diretamente para as 4 opções que normalmente vês num menu de "Criar Sala" de qualquer jogo com multiplayer:

- **Pública** (`LOBBY_TYPE_PUBLIC`) → aparece na tua lista de lobbies (secção "Procurar/Listar lobbies" abaixo). É o modo típico de um menu "Servidores Públicos" / "Browse Games".
- **Só amigos** (`LOBBY_TYPE_FRIENDS_ONLY`) → não aparece a estranhos nas pesquisas, mas os amigos do dono conseguem vê-la nos seus próprios menus (ex: através de `getFriendGamePlayed()`, secção 6) e entrar diretamente, sem convite explícito.
- **Só convite** (*Invite Only*) → não é um `LobbyType` à parte; implementa-se normalmente como uma lobby **`LOBBY_TYPE_PRIVATE`** — só quem recebe o convite (via `activateGameOverlayInviteDialog()` ou um convite dentro do teu próprio jogo) consegue entrar, porque a lobby nunca aparece em pesquisas nem na lista de amigos.
- **Privada com password** (*Private/Password*) → o Steam não tem um conceito nativo de "password de lobby". Implementa-se por cima de uma lobby `LOBBY_TYPE_PUBLIC` (para poder aparecer nas pesquisas) combinada com uma verificação manual de password guardada em `setLobbyData()`. Ver subsecção seguinte.
- **Invisível** (`LOBBY_TYPE_INVISIBLE`) → usada mais para casos avançados (ex: lobbies "técnicas" que o teu jogo cria para agrupar servidores, sem interesse em aparecerem em lado nenhum a jogadores).

Um menu típico de "Criar Sala" costuma ter estas opções lado a lado (Pública / Só Amigos / Só Convite / Privada com Password), todas implementadas com o mesmo `createLobby()`, só variando o `LobbyType` escolhido e se ativas ou não a verificação de password.

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

### Lobbies com password

Como referido acima, o Steamworks **não tem** um sistema nativo de password para lobbies — tens de o implementares tu por cima do sistema de `LobbyData`. A ideia é simples: guardar a password (ou, melhor ainda, um hash dela) como um dado da lobby, e verificar antes de deixares o jogador "entrar de facto" no jogo (mesmo que a nível Steam ele já esteja tecnicamente dentro da lobby).

```gdscript
const PASSWORD_KEY: String = "pw_hash"

func create_password_lobby(max_players: int, password: String) -> void:
    Steam.createLobby(Steam.LOBBY_TYPE_PUBLIC, max_players)
    # guarda a password (com hash) depois de a lobby ser criada, em _on_lobby_created()
    _pending_password = password

func _on_lobby_created(connect_status: Steam.Result, lobby_id: int) -> void:
    if connect_status != Steam.Result.RESULT_OK:
        return
    Steamworks.lobby_id = lobby_id
    Steam.setLobbyData(lobby_id, "lobby_name", "Lobby do Jogador1")

    if not _pending_password.is_empty():
        var hash: String = _pending_password.sha256_text()
        Steam.setLobbyData(lobby_id, "has_password", "true")
        Steam.setLobbyData(lobby_id, PASSWORD_KEY, hash)
        _pending_password = ""
    else:
        Steam.setLobbyData(lobby_id, "has_password", "false")
```

**Nunca guardes a password em texto simples em `setLobbyData()`** — qualquer pessoa consegue ler dados de lobby pública através de `getLobbyData()`, mesmo sem lá entrar (é informação pública associada à lobby). Usa sempre um hash (`sha256_text()` é suficiente para este caso de uso, já que não estamos a proteger nada crítico como uma conta bancária).

Ao entrar, primeiro confirmas se a lobby tem password (mostrando um campo de texto na UI, se necessário), e só depois de o jogador escrever a password certa é que o deixas avançar para o jogo em si (mesmo que a nível Steam ele já tenha entrado na lobby com `joinLobby()`):

```gdscript
func try_join_lobby(lobby_id: int, password_attempt: String = "") -> bool:
    var has_password: bool = Steam.getLobbyData(lobby_id, "has_password") == "true"
    if has_password:
        var correct_hash: String = Steam.getLobbyData(lobby_id, PASSWORD_KEY)
        if password_attempt.sha256_text() != correct_hash:
            printerr("Password incorreta")
            return false
    Steam.joinLobby(lobby_id)
    return true
```

> Nota: como a verificação de password acontece do lado do cliente (o `getLobbyData()` é público), um jogador com um cliente modificado pode, em teoria, ler o hash e/ou saltar esta verificação. Para a maioria dos jogos isto é perfeitamente aceitável (a password serve para impedir que estranhos apareçam por acaso na tua pesquisa pública, não é uma barreira de segurança "séria"). Se precisares de verdade de controlo rigoroso de acesso, a única forma sólida é o **servidor/host recusar ativamente** ligações que não provem a password corretamente (por exemplo, exigindo que o cliente envie a password em texto claro por RPC assim que se liga, e o host desconecta-o se estiver errada) — ver também a secção 15 (Segurança).



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

### Construir um ecrã de "Servidores Públicos"

Só lobbies `LOBBY_TYPE_PUBLIC` (e `LOBBY_TYPE_FRIENDS_ONLY`, se fores amigo do dono) aparecem em `requestLobbyList()`. Lobbies `LOBBY_TYPE_PRIVATE` e `LOBBY_TYPE_INVISIBLE` nunca aparecem — é por isso que servem para "só convite". Um ecrã típico de lista de servidores usa a pesquisa da secção anterior e mostra, por cada resultado, os dados guardados com `setLobbyData()`:

```gdscript
func _on_lobby_match_list(lobbies: Array) -> void:
    for lobby_id in lobbies:
        var entry := {
            "id": lobby_id,
            "name": Steam.getLobbyData(lobby_id, "lobby_name"),
            "mode": Steam.getLobbyData(lobby_id, "mode"),
            "has_password": Steam.getLobbyData(lobby_id, "has_password") == "true",
            "players": Steam.getNumLobbyMembers(lobby_id),
            "max_players": Steam.getLobbyMemberLimit(lobby_id),
        }
        # popula a tua UI (ex: um ItemList ou uma lista de painéis),
        # mostrando um ícone de cadeado se entry["has_password"] for true
```

Ao clicar numa entrada com `has_password == true`, mostra um campo de password antes de chamares `try_join_lobby()` (secção anterior); nas restantes, entra logo com `joinLobby()`.

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

## 9. Voice Chat

O Steamworks tem um sistema de voz embutido (compressão, deteção de "está a falar", etc.) que podes usar sem depender de bibliotecas externas. As funções relevantes vivem em duas classes:

- **Friends**: `setInGameVoiceSpeaking()` — avisa a UI do Steam que estás a falar (para silenciar sons do overlay, etc.).
- **User**: `startVoiceRecording()`, `stopVoiceRecording()`, `getAvailableVoice()`, `getVoice()`, `decompressVoice()`, `getVoiceOptimalSampleRate()`.

O fluxo é: **captura local → comprime (Steam faz isto automaticamente) → envia pela tua rede (RPC/Steam Networking) → cada recetor descomprime e reproduz.**

### 1. Preparar os `AudioStreamPlayer`

Precisas de dois nós `AudioStreamPlayer` na cena, cada um com um `AudioStreamGenerator` como stream:

- `$Local` — usado opcionalmente para ouvires a tua própria voz (loopback), útil só para testes.
- `$Network` — reproduz a voz recebida dos outros jogadores.

```gdscript
var current_sample_rate: int = 48000
var has_loopback: bool = false
var local_playback: AudioStreamGeneratorPlayback = null
var local_voice_buffer: PackedByteArray = PackedByteArray()
var network_playback: AudioStreamGeneratorPlayback = null
var network_voice_buffer: PackedByteArray = PackedByteArray()
var packet_read_limit: int = 5

func _ready() -> void:
    $Local.play()
    $Network.play()
    local_playback = $Local.get_stream_playback()
    network_playback = $Network.get_stream_playback()
```

### 2. Começar/parar a gravar (ex: ao segurar uma tecla de "push to talk")

```gdscript
func record_voice(is_recording: bool) -> void:
    # Enquanto falas, isto silencia outros sons/vozes vindos da UI do Steam
    Steam.setInGameVoiceSpeaking(Steamworks.steam_id, is_recording)
    if is_recording:
        Steam.startVoiceRecording()
    else:
        Steam.stopVoiceRecording()
```

Podes ligar isto a um input tipo "push to talk" (`Input.is_action_pressed("push_to_talk")` no `_process()`), ou chamar `record_voice(true)` uma vez em `_ready()` para teres voz "sempre ativa" (dá a opção ao jogador de escolher).

### 3. Capturar e enviar o áudio comprimido

```gdscript
func _process(_delta: float) -> void:
    var available: Dictionary = Steam.getAvailableVoice()
    if available.get("result") != Steam.Result.RESULT_OK:
        return
    var voice_size: int = available.get("buffer", 0)
    if voice_size <= 0:
        return

    var voice_data: Dictionary = Steam.getVoice()
    if voice_data.get("result") != Steam.Result.RESULT_OK:
        return

    var compressed: PackedByteArray = voice_data["buffer"]

    # Envia o áudio comprimido para os outros jogadores.
    # Usa "unreliable" — se um pacote de voz se perder não vale a pena reenviar, só causaria atraso.
    receive_voice_packet.rpc_id(0, compressed)  # 0 = todos os peers, exceto tu

@rpc("any_peer", "call_remote", "unreliable")
func receive_voice_packet(compressed: PackedByteArray) -> void:
    var sender_id: int = multiplayer.get_remote_sender_id()
    var decompressed: Dictionary = Steam.decompressVoice(compressed, current_sample_rate)
    if decompressed.get("result") != Steam.Result.RESULT_OK:
        return
    network_voice_buffer.append_array(decompressed["uncompressed"])
```

### 4. Reproduzir a voz recebida

```gdscript
func _physics_process(_delta: float) -> void:
    if network_voice_buffer.is_empty():
        return
    var frames_available: int = network_playback.get_frames_available()
    if frames_available <= 0:
        return

    # Converte os bytes recebidos (PCM 16-bit) em frames estéreo para o AudioStreamGeneratorPlayback
    var frames_to_push: int = mini(frames_available, network_voice_buffer.size() / 2)
    for i in range(frames_to_push):
        var sample: int = network_voice_buffer.decode_s16(i * 2)
        var value: float = sample / 32768.0
        network_playback.push_frame(Vector2(value, value))

    network_voice_buffer = network_voice_buffer.slice(frames_to_push * 2)
```

### Notas importantes

- `has_loopback` (variável opcional) controla se te ouves a ti próprio — útil só para debug, desliga em produção.
- O `getVoiceOptimalSampleRate()` costuma ser referido nos tutoriais oficiais como "ideal", mas há relatos de a voz sair esganiçada com esse valor — testa com `44100` ou `48000` fixos se ouvires artefactos estranhos.
- A partir de certas versões do GodotSteam (4.16 a 4.18.1), `getAvailableVoice()` pode não existir — nesse caso salta essa verificação e tenta chamar `getVoice()` diretamente, tratando um resultado vazio como "sem dados disponíveis".
- Podes enviar os pacotes de voz por **RPC** (mais simples, como no exemplo acima) ou por **Steam Networking Messages/Sockets** (mais controlo de canais e prioridade) — a escolha depende de como já estás a fazer o resto do teu networking.
- Adiciona sempre uma opção de **mudo** (mutar um jogador específico do lado do cliente) e um indicador visual de "quem está a falar" (podes usar o retorno de `getAvailableVoice()`/`getVoice()` como sinal de "está a falar agora").

### Chat de Proximidade (Proximity Chat)

Chat de proximidade (tipo Among Us, Lethal Company, etc.) é a mesma base de voice chat acima, mas em vez de todos ouvirem todos ao mesmo volume, **atenuas o volume de cada jogador consoante a distância** entre ele e o jogador local. A forma mais simples é usar um `AudioStreamPlayer3D` **por cada jogador remoto**, em vez de um único `$Network` global — o Godot já trata da atenuação por distância automaticamente.

```gdscript
# Um AudioStreamPlayer3D por jogador remoto, filho do respetivo nó do jogador na cena
# (em vez de um único $Network partilhado)

func _on_player_spawned(player_node: Node3D, player_id: int) -> void:
    var voice_player := AudioStreamPlayer3D.new()
    voice_player.name = "VoicePlayer"
    voice_player.stream = AudioStreamGenerator.new()
    voice_player.max_distance = 15.0      # distância a partir da qual deixa de se ouvir
    voice_player.unit_size = 5.0          # controla a curva de atenuação
    player_node.add_child(voice_player)
    voice_player.play()
    voice_playbacks[player_id] = voice_player.get_stream_playback()

@rpc("any_peer", "call_remote", "unreliable")
func receive_voice_packet(compressed: PackedByteArray) -> void:
    var sender_id: int = multiplayer.get_remote_sender_id()
    var decompressed: Dictionary = Steam.decompressVoice(compressed, current_sample_rate)
    if decompressed.get("result") != Steam.Result.RESULT_OK:
        return
    # Em vez de empurrares para um buffer global, empurras para o playback
    # do AudioStreamPlayer3D correspondente a este jogador específico
    var playback: AudioStreamGeneratorPlayback = voice_playbacks.get(sender_id)
    if playback:
        push_voice_frames(playback, decompressed["uncompressed"])
```

Como o `AudioStreamPlayer3D` está anexado ao nó do jogador (que já se move pela cena via `MultiplayerSynchronizer`, secção 11), a atenuação e o efeito estéreo (esquerda/direita consoante a posição) acontecem automaticamente pelo motor de áudio do Godot — não precisas de calcular volume por distância manualmente.

Se quiseres um sistema **híbrido** (chat de proximidade normal + um "chat de equipa" sempre audível independentemente da distância, comum em jogos deste género), basta teres dois canais separados: um envia para o `AudioStreamPlayer3D` posicional (proximidade), o outro envia para um `AudioStreamPlayer` 2D normal só para os membros da mesma equipa, ignorando a distância.

---

## 10. Convidar / Aceitar convites

```gdscript
# Abre o painel do Steam para convidar amigos para a lobby atual
Steam.activateGameOverlayInviteDialog(lobby_id)
```

O fluxo de "aceitar convite" já foi coberto na secção 7 (`join_requested` e `+connect_lobby`).

---

## 11. Networking — Ligar Jogadores (P2P)

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

### Migração de Host (quando quem hospeda sai a meio do jogo)

Com `SteamMultiplayerPeer`, o servidor é sempre o **peer ID 1** — e se essa instância fechar o jogo ou perder a ligação, **todos os outros ficam desligados**, porque toda a comunicação passava por ela (especialmente se usaste `server_relay = true`). Ao contrário das lobbies (onde o Steam já trata de passar o `getLobbyOwner()` automaticamente para outro membro, secção 7), o `MultiplayerPeer` **não migra sozinho** — é preciso implementares isso tu.

O padrão mais usado é: **um novo host cria um novo `SteamMultiplayerPeer` e os restantes voltam a ligar-se a ele**, reaproveitando o estado que cada cliente já tinha guardado localmente.

```gdscript
func _ready() -> void:
    multiplayer.server_disconnected.connect(_on_host_disconnected)

func _on_host_disconnected() -> void:
    # 1) O Steam já escolheu um novo dono para a lobby automaticamente
    var new_owner_id: int = Steam.getLobbyOwner(Steamworks.lobby_id)

    if new_owner_id == Steam.getSteamID():
        # Fui escolhido como novo host: crio um novo peer como servidor
        become_new_host()
    else:
        # Não sou eu: espero um pouco para o novo host preparar o servidor,
        # depois volto a ligar-me a ele
        await get_tree().create_timer(1.0).timeout
        reconnect_to_new_host(new_owner_id)

func become_new_host() -> void:
    var peer := SteamMultiplayerPeer.new()
    peer.create_host(0)
    peer.server_relay = true
    multiplayer.set_multiplayer_peer(peer)
    # Aqui reconstróis o estado do jogo a partir do que tinhas guardado localmente
    # (posições, pontuação, inventários, etc.) já que perdeste a "verdade" que estava no host antigo

func reconnect_to_new_host(host_id: int) -> void:
    var peer := SteamMultiplayerPeer.new()
    peer.create_client(host_id, 0)
    peer.server_relay = true
    multiplayer.set_multiplayer_peer(peer)
```

Pontos importantes a teres em conta:

- **Perda de estado:** como o servidor antigo desapareceu, qualquer estado que só existia na memória dele (posições exatas, temporizadores em curso, etc.) perde-se. Para jogos onde isto importa, cada cliente deve manter uma cópia local recente do estado relevante (via `MultiplayerSynchronizer`, que já vais ter, ou guardando periodicamente um "snapshot") para o novo host poder reconstruir o jogo com a menor disrupção possível.
- **Janela de espera:** vale a pena mostrar um ecrã de "A reconectar..." enquanto a migração acontece, em vez de deixar o jogo parecer simplesmente travado.
- **Jogos competitivos/simétricos** (ex: cada jogador é igualmente capaz de ser host) lidam melhor com isto do que jogos onde o host tinha um papel muito especial (ex: um "mestre de jogo").
- Se a perda de progresso for inaceitável para o teu jogo, a alternativa mais robusta é mesmo teres um **servidor dedicado** (secção 12) em vez de um dos jogadores ser host — um servidor dedicado não desaparece quando um jogador fecha o jogo.

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

### Trocar de cena / mapa para todos os jogadores em simultâneo

Um caso muito comum: na sala de espera, o host escolhe o mapa/modo, e quando o jogo começa **todos** os clientes têm de carregar a mesma cena ao mesmo tempo. Isto não tem nada de mágico do Steam — usa-se `@rpc` normal do Godot, mas há uma ordem certa a seguir para evitar dessincronizações.

```gdscript
# --- No host: escolher e anunciar o mapa (ex: ao clicar um botão na lobby) ---
func host_select_map(map_path: String) -> void:
    if not multiplayer.is_server():
        return
    Steam.setLobbyData(Steamworks.lobby_id, "selected_map", map_path)  # opcional: também guarda na lobby, para quem entra depois ver logo qual é
    notify_map_selected.rpc(map_path)

@rpc("authority", "call_local", "reliable")
func notify_map_selected(map_path: String) -> void:
    # Todos os clientes (incluindo o host, por causa do call_local) atualizam a pré-visualização/UI
    %MapPreview.texture = load(map_path.get_basename() + ".png")
    %MapLabel.text = map_path.get_file()


# --- No host: começar o jogo, mandando todos mudar de cena ---
func host_start_game() -> void:
    if not multiplayer.is_server():
        return
    var map_path: String = Steam.getLobbyData(Steamworks.lobby_id, "selected_map")
    change_scene_for_all.rpc(map_path)

@rpc("authority", "call_local", "reliable")
func change_scene_for_all(map_path: String) -> void:
    get_tree().change_scene_to_file(map_path)
    # Depois de a cena carregar, é comum cada cliente avisar o servidor que está pronto,
    # e só aí o servidor faz o spawn dos jogadores (ver secção "Spawn de jogadores" acima)
    client_scene_ready.rpc_id(1)

@rpc("any_peer", "call_local", "reliable")
func client_scene_ready() -> void:
    if not multiplayer.is_server():
        return
    var sender_id: int = multiplayer.get_remote_sender_id()
    spawn_player(sender_id)
```

Pontos-chave deste padrão:

- **Só o servidor decide** qual é o mapa e quando o jogo começa (`@rpc("authority", ...)`) — nunca deixes um cliente qualquer mandar todos mudar de cena (seria fácil de abusar).
- `call_local` garante que o host também executa a troca de cena, em vez de teres de duplicar código "faz X no host, faz X nos outros".
- Depois da troca de cena, é boa prática esperar que **cada cliente confirme que já carregou** (`client_scene_ready`) antes de começares a colocar jogadores/objetos — evita bugs de "o jogador apareceu antes do cenário estar pronto".
- Para jogos com uma **UI de pré-visualização do mapa na sala de espera** (imagem do mapa, nome do modo, etc.), o padrão `notify_map_selected` acima é o suficiente — não precisas de trocar já de cena, só de sincronizar os dados a mostrar.
- Se quiseres uma barra de progresso de loading sincronizada (ex: "3/4 jogadores prontos"), soma quantos `client_scene_ready` já recebeste no servidor e faz `broadcast` da contagem a todos, também por RPC.

---

## 12. Otimização de Performance em Rede

Depois de teres o multiplayer básico a funcionar, o próximo problema real é: **quanta informação mandas, com que frequência, e a quem**. Mandar tudo, sempre, a toda a gente, funciona com 2 jogadores em teste local, mas degrada-se rapidamente com mais jogadores ou pior internet. Esta secção cobre as técnicas mais importantes, todas nativas do Godot (não são específicas do Steam, mas são essenciais para qualquer jogo que uses com o `SteamMultiplayerPeer`).

### 1. Fiável vs não-fiável (`reliable` vs `unreliable`)

Já foi referido, mas vale a pena destacar: usa **`unreliable`** (ou `unreliable_ordered`) para tudo o que é enviado muitas vezes por segundo e onde perder um pacote ocasional não é grave (posição, rotação, animação em curso) — porque, se se perder, o próximo pacote (que vem daqui a poucos milissegundos) já traz dados mais recentes na mesma. Usa **`reliable`** só para eventos discretos e importantes (alguém entrou, um item foi apanhado, uma porta abriu) — coisas que só acontecem uma vez e onde perder a mensagem causaria um bug permanente.

```gdscript
@rpc("any_peer", "unreliable_ordered")   # posição, muitas vezes por segundo
func update_position(pos: Vector3) -> void: ...

@rpc("authority", "reliable")             # evento único e importante
func item_collected(item_id: int) -> void: ...
```

### 2. `MultiplayerSynchronizer`: reduzir a frequência de replicação

No inspetor do `MultiplayerSynchronizer`, cada propriedade replicada pode ter o seu próprio **modo de sincronização** e podes ajustar o **`Replication Interval`** (intervalo entre atualizações, por defeito manda a cada frame de física). Para a maioria dos jogos não precisas de 60 atualizações por segundo de posição — algo como 10-20 vezes por segundo já é suficiente e reduz bastante o tráfego, especialmente com muitos jogadores.

```gdscript
# No código, também podes ajustar isto diretamente:
$MultiplayerSynchronizer.replication_interval = 0.05  # ~20 vezes por segundo
```

### 3. Interpolação no cliente

Se reduzires a frequência de atualização (ponto anterior), o movimento dos outros jogadores pode começar a parecer "aos saltos". A solução padrão é **interpolar** no cliente: em vez de "teleportares" o objeto para a última posição recebida, vais suavemente do valor antigo para o novo ao longo do tempo entre atualizações.

```gdscript
var target_position: Vector3
var previous_position: Vector3
var time_since_update: float = 0.0
const UPDATE_INTERVAL: float = 0.05  # tem de bater certo com o replication_interval

func _on_position_received(new_pos: Vector3) -> void:
    previous_position = global_position
    target_position = new_pos
    time_since_update = 0.0

func _process(delta: float) -> void:
    if is_multiplayer_authority():
        return  # o dono do nó não precisa de interpolar a si próprio
    time_since_update += delta
    var t: float = clampf(time_since_update / UPDATE_INTERVAL, 0.0, 1.0)
    global_position = previous_position.lerp(target_position, t)
```

### 4. "Relevância" / Area of Interest — não mandes tudo a todos

Em jogos maiores (muitos jogadores, mapas grandes), não faz sentido mandar a posição de **todos** os jogadores a **todos** os clientes — um jogador do outro lado do mapa não precisa de saber a posição exata de alguém que nunca vai ver. Isto também é uma medida de **segurança** (secção 16): não enviar dados de jogadores fora de alcance evita wallhacks, como referido nas recomendações da própria Valve.

Ideia simples de implementar:

```gdscript
# No servidor, antes de mandar atualizações de posição, filtra por distância/visibilidade
func broadcast_positions() -> void:
    for player_id in players:
        var player_pos: Vector3 = players[player_id].global_position
        for other_id in players:
            if other_id == player_id:
                continue
            var distance: float = player_pos.distance_to(players[other_id].global_position)
            if distance <= RELEVANCE_RADIUS:
                update_position.rpc_id(other_id, player_id, player_pos)
```

O `MultiplayerSynchronizer` mais recente do Godot também suporta **visibilidade por peer** (`set_visibility_for(peer_id, visible)`), que podes usar para ligar/desligar a replicação de um nó consoante a distância ou relevância para cada jogador específico, sem teres de gerir tudo manualmente por RPC.

### 5. Comprimir/simplificar os dados enviados

- Usa **`Vector3`/`float` com menos casas decimais** quando possível — não precisas de precisão total para posição visual.
- Prefere **deltas** (só a diferença desde a última atualização) a valores absolutos, quando a diferença costuma ser pequena.
- Agrupa várias mudanças pequenas num único pacote/RPC em vez de mandares um RPC separado por cada campo que mudou.
- Para inputs de jogador (o que normalmente é enviado do cliente para o servidor num jogo com física no servidor), envia só o **estado do input** (teclas premidas, direção do analógico) em vez da posição resultante — deixa o servidor calcular a física a partir disso (também ajuda com a segurança, secção 16).

### 6. Tick rate do servidor

Se estiveres a fazer física/lógica autoritativa no servidor (recomendado, secção 16), o servidor não precisa de correr a lógica de rede ao mesmo ritmo do `_physics_process()` visual (normalmente 60Hz). Muitos jogos usam um **tick rate de rede mais baixo** (ex: 20-30Hz) para a lógica que é replicada, enquanto a física/renderização local de cada cliente continua a 60Hz, suavizada por interpolação (ponto 3).

```gdscript
var network_tick_accumulator: float = 0.0
const NETWORK_TICK_RATE: float = 1.0 / 20.0  # 20 vezes por segundo

func _physics_process(delta: float) -> void:
    network_tick_accumulator += delta
    if network_tick_accumulator >= NETWORK_TICK_RATE:
        network_tick_accumulator = 0.0
        run_network_tick()  # aqui processas e envias o estado de rede
```

### Resumo rápido

| Técnica | Quando usar |
|---|---|
| `unreliable_ordered` | Posição, rotação, qualquer coisa enviada muitas vezes/segundo |
| `reliable` | Eventos únicos e importantes (item apanhado, porta aberta) |
| Reduzir `replication_interval` | Sempre que não precises de 60 atualizações/segundo |
| Interpolação no cliente | Sempre que reduzires a frequência de atualização, para não ficar "aos saltos" |
| Area of interest / relevância | Mapas grandes, muitos jogadores, ou preocupação com wallhacks |
| Deltas em vez de valores absolutos | Dados que mudam pouco entre atualizações |
| Tick rate de rede mais baixo que o visual | Jogos com física autoritativa no servidor |

---

## 13. Servidores Dedicados (Game Servers)

Isto responde à pergunta "como faço para os jogadores poderem correr o **próprio servidor** (tipo um servidor de Minecraft), em vez de um deles ter sempre de ficar com o jogo aberto a fazer de host?" É um padrão muito comum (Minecraft, Valheim, ARK, etc.): distribuis um **executável de servidor à parte**, sem gráficos, que corre num PC, numa VPS, ou num serviço de hosting, e os jogadores ligam-se a ele de fora.

Isto é bastante mais trabalho do que o P2P das secções anteriores, mas o Godot 4 já tem tudo o que precisas nativamente (modo *headless*), e o GodotSteam ajuda com a parte de listagem/autenticação via Steam.

### Porque é que isto é diferente do P2P

No P2P da secção 10, um dos **jogadores** é sempre o host — se ele fechar o jogo ou tiver má ligação, a partida acaba para todos, e a qualidade da ligação depende do PC/internet desse jogador. Um **servidor dedicado**:

- Corre continuamente, independente de qualquer jogador estar ou não a jogar;
- Não gasta os recursos gráficos de ninguém (corre sem janela, sem renderização);
- Pode ser alojado num PC próprio (ligado 24/7), num Raspberry Pi, numa VPS alugada (Hetzner, OVH, etc.), ou num container Docker.

> **Importante:** conforme referido, o `SteamMultiplayerPeer` do GodotSteam **ainda não suporta** builds de servidor dedicado. Para este cenário, a forma mais simples e mais usada na comunidade é fazer o networking com o **`ENetMultiplayerPeer`** nativo do Godot (TCP/UDP normais, sem passar pela camada Steam), e usar o Steam apenas como "vitrine" — para autenticar jogadores e/ou listar servidores publicamente. Cabe a ti decidir se precisas mesmo da parte do Steam aqui, ou se um servidor simples por IP:porta já resolve o teu caso.

### Passo 1 — Criar uma build "headless" (o executável de servidor)

Desde o Godot 4.0 **não precisas de um binário especial de "servidor"** como no Godot 3.x — usa-se o executável normal com a flag `--headless`, que desliga a janela, o renderizador gráfico e o driver de áudio.

1. No editor, cria um **preset de export dedicado ao servidor** (Project → Export → Add..., ex: "Linux Server").
2. No separador **Resources** desse preset, escolhe o modo de exportação **"Export as dedicated server"**. Isto:
   - Ativa automaticamente a *feature tag* `dedicated_server` no build exportado (para poderes detetar em código se estás a correr como servidor);
   - Permite-te marcar recursos (texturas, sons, etc.) como "Strip" ou "Remove", para o executável do servidor ficar muito mais pequeno, já que não precisa de nenhum conteúdo visual.
3. Exporta para Linux (o mais comum para hosting, incluindo VPS baratas) e/ou Windows, consoante onde os teus utilizadores vão querer correr o servidor.

No código, deteta se estás a correr como servidor logo no arranque:

```gdscript
# main.gd (autoload ou cena principal)
func _ready() -> void:
    if OS.has_feature("dedicated_server") or "--server" in OS.get_cmdline_args():
        start_dedicated_server()
    else:
        start_normal_game()
```

### Passo 2 — Ler configuração de um ficheiro (para o utilizador poder configurar o servidor)

Um servidor "tipo terminal" que distribuis para os utilizadores correrem deve ser configurável **sem precisarem de mexer em código**. O padrão mais comum é um ficheiro de configuração de texto (`.ini` ou `.cfg`) ao lado do executável, que o utilizador edita antes de o correr:

```ini
; server.cfg — coloca este ficheiro ao lado do executável do servidor
[server]
name = "Servidor do Fulano"
port = 27015
max_players = 16
password = ""
map = "res://maps/floresta.tscn"
public = true
```

```gdscript
# lido no arranque do servidor
var config := ConfigFile.new()

func load_server_config() -> Dictionary:
    var exe_dir: String = OS.get_executable_path().get_base_dir()
    var err := config.load(exe_dir.path_join("server.cfg"))
    if err != OK:
        print("server.cfg não encontrado, a usar valores por omissão")
        return {}
    return {
        "name": config.get_value("server", "name", "Servidor sem nome"),
        "port": config.get_value("server", "port", 27015),
        "max_players": config.get_value("server", "max_players", 8),
        "password": config.get_value("server", "password", ""),
        "map": config.get_value("server", "map", "res://maps/default.tscn"),
        "public": config.get_value("server", "public", false),
    }
```

Podes também suportar argumentos de linha de comandos, para quem preferir correr o servidor por script/Docker sem editar ficheiros:

```gdscript
func get_cli_arg(name: String, default_value):
    for arg in OS.get_cmdline_user_args():   # argumentos depois de "--" no lançamento
        if arg.begins_with("--%s=" % name):
            return arg.trim_prefix("--%s=" % name)
    return default_value

# uso: ./servidor.x86_64 --headless -- --port=27016 --max_players=32
var port: int = int(get_cli_arg("port", 27015))
```

### Passo 3 — Iniciar o servidor (rede + Steam Game Server)

```gdscript
func start_dedicated_server() -> void:
    var cfg: Dictionary = load_server_config()

    # 1) Rede base do Godot (ENet) — é isto que os clientes usam para trocar dados de jogo
    var peer := ENetMultiplayerPeer.new()
    var err := peer.create_server(cfg["port"], cfg["max_players"])
    if err != OK:
        printerr("Não foi possível abrir a porta %s" % cfg["port"])
        get_tree().quit(1)
        return
    multiplayer.set_multiplayer_peer(peer)
    print("Servidor '%s' a correr na porta %s (máx %s jogadores)" % [cfg["name"], cfg["port"], cfg["max_players"]])

    # 2) Opcional: login do Game Server no Steam, para aparecer listado / ter estatísticas
    #    (requer a build GodotSteam com suporte a Game Server; ver documentação da classe "Game Server")
    if cfg.get("public", false):
        register_with_steam(cfg)

    multiplayer.peer_connected.connect(_on_player_connected)
    multiplayer.peer_disconnected.connect(_on_player_disconnected)

func _on_player_connected(id: int) -> void:
    print("Jogador ligou-se: %s" % id)

func _on_player_disconnected(id: int) -> void:
    print("Jogador desligou-se: %s" % id)
```

O registo no Steam como *Game Server* (para aparecer no browser de servidores do Steam e teres VAC/estatísticas) usa a classe **Game Server** do GodotSteam (equivalente ao `steamInit`, mas do lado do servidor, com `serverInit()`/`logOn()` — consulta a documentação da classe para a versão exata que estiveres a usar, já que os nomes das funções têm variado um pouco entre releases).

### Passo 4 — O cliente ligar-se ao servidor

Se o jogador souber o IP/porta (o utilizador que hospeda partilha isso manualmente, ex: por Discord, tal como se faz em muitos jogos com servidores comunitários):

```gdscript
func connect_to_server(ip: String, port: int, password: String = "") -> void:
    var peer := ENetMultiplayerPeer.new()
    var err := peer.create_client(ip, port)
    if err != OK:
        printerr("Não foi possível ligar a %s:%s" % [ip, port])
        return
    multiplayer.set_multiplayer_peer(peer)
    multiplayer.connected_to_server.connect(func():
        if not password.is_empty():
            send_password.rpc_id(1, password)
    )

@rpc("any_peer", "call_remote", "reliable")
func send_password(attempt: String) -> void:
    if not multiplayer.is_server():
        return
    var sender_id: int = multiplayer.get_remote_sender_id()
    if attempt.sha256_text() != _server_password_hash:
        multiplayer.multiplayer_peer.disconnect_peer(sender_id)
```

> Repara que aqui a verificação de password **é feita no servidor**, ao contrário do exemplo de lobbies com password da secção 7 — porque agora o servidor é uma entidade separada e autoritativa que consegue mesmo recusar a ligação, em vez de ser só uma verificação cosmética do lado do cliente.

### Passo 5 — Distribuir o servidor aos utilizadores

O "pacote de servidor" que distribuis (ex: num `.zip` para download, ou uma imagem Docker) deve conter tipicamente:

```
meu-jogo-servidor/
├── servidor.x86_64        # o executável exportado com --headless / dedicated_server
├── servidor.pck           # os dados do jogo
├── server.cfg             # ficheiro de configuração editável (secção "Passo 2")
├── iniciar_servidor.sh    # (Linux) script simples: ./servidor.x86_64 --headless
├── iniciar_servidor.bat   # (Windows) script simples: servidor.exe --headless
└── LEIAME.txt             # instruções: portas a abrir no router/firewall, como editar o server.cfg, etc.
```

O `LEIAME.txt` deve explicar, em português simples, os passos que qualquer utilizador vai precisar:

1. Editar `server.cfg` com o nome do servidor, porta, password (opcional) e máximo de jogadores;
2. Abrir a porta escolhida (ex: `27015`) no firewall e, se for para ser acedido de fora da rede local, fazer **port forwarding** no router para o PC onde o servidor corre;
3. Correr o script (`iniciar_servidor.sh` / `.bat`);
4. Partilhar o IP público (ou usar um serviço de DNS dinâmico, se o IP mudar) e a porta com os amigos, ou (se marcares `public = true`) deixar que apareça automaticamente na lista de servidores dentro do jogo.

Para quem quiser algo mais "profissional" e sempre online, o mesmo pacote corre também dentro de um **container Docker** (basta uma imagem Linux com o executável headless lá dentro) — o que permite alojar em qualquer VPS ou serviço de cloud sem complicações de dependências.

### Listar servidores dedicados dentro do jogo

Tens três abordagens possíveis, da mais simples à mais avançada:

1. **IP:porta manual** — o jogador escreve o endereço à mão (mais simples de implementares, comum em jogos indie/comunitários).
2. **Lista própria (backend teu)** — o teu servidor "central" (uma API tua, fora do Steam) guarda que servidores estão online e os seus IPs, e o jogo consulta essa lista — dá-te controlo total, mas exiges infraestrutura própria.
3. **Steam Matchmaking Servers** — regista cada servidor dedicado com a classe **Game Server** do GodotSteam, e usa a classe **Matchmaking Servers** do lado do cliente (`requestInternetServerList()`, com callbacks de resposta) para obteres a lista de servidores públicos anunciados no Steam para o teu App ID, sem precisares de infraestrutura própria de listagem.

### Obter detalhes de um servidor guardado numa lobby

Uma alternativa mais simples, que mistura lobbies com um servidor externo (útil se não quiseres ir pelo caminho completo de "Game Server" acima), é guardar o IP/porta do servidor dedicado dentro dos dados da própria lobby Steam, e usar:

```gdscript
Steam.getLobbyGameServer(lobby_id)  # devolve dados do servidor de jogo associado à lobby
```

Isto permite, por exemplo, criares uma lobby normal (com chat, convites, etc., tudo o que já viste nas secções 7-9) que serve só para "anunciar" um servidor dedicado que já está a correr, e os jogadores usam a lobby só para descobrir o IP/porta a que se devem ligar, saindo depois da lobby e ligando-se ao servidor de facto via `ENetMultiplayerPeer`.

---

## 14. Rich Presence (Steam e Discord)

### Rich Presence do Steam

Rich Presence permite mostrar informação contextual no perfil Steam dos jogadores (ex: "A jogar no Mapa X, Nível 5" visível na lista de amigos, ou no que aparece quando passas o rato por cima do nome de alguém no Steam).

```gdscript
Steam.setRichPresence("status", "A jogar no Nível 3")
Steam.setRichPresence("connect", "+connect_lobby %s" % lobby_id)  # permite "Join Game" pelo Steam
Steam.clearRichPresence()
```

O valor de `"connect"` é especialmente importante: é o que faz o botão "Join Game" no Steam funcionar automaticamente, lançando o teu jogo com o argumento de linha de comandos `+connect_lobby <id>` (ver secção 7).

Chaves úteis comuns (podes definir as tuas próprias, mas estas têm significado especial no Steam):

| Chave | Efeito |
|---|---|
| `"status"` | Texto simples mostrado na lista de amigos (ex: "A explorar a Floresta") |
| `"connect"` | String usada para o "Join Game" (normalmente um comando `+connect_...`) |
| `"steam_display"` | Nome de um "localization token" definido no Steamworks para textos Rich Presence mais elaborados e traduzidos automaticamente (ex: `"#StatusFormat"`) |
| `"steam_player_group"` | Agrupa jogadores da mesma partida/equipa na lista de amigos, mostrando quantos estão juntos |

```gdscript
# Exemplo com agrupamento (mostra "3 amigos numa partida" na lista de amigos)
Steam.setRichPresence("steam_player_group", str(lobby_id))
Steam.setRichPresence("steam_player_group_size", str(Steam.getNumLobbyMembers(lobby_id)))
```

> Atualiza a Rich Presence sempre que o estado relevante mudar (entrar numa lobby, começar uma partida, mudar de mapa) — não precisas de a chamar em loop, só quando algo muda de facto.

### Rich Presence do Discord

Isto é **completamente separado do Steam** — é uma integração à parte com o Discord, para mostrar o que estás a jogar no teu perfil do Discord (o "A jogar [Jogo] há 12 minutos" que aparece ao lado do teu nome). O GodotSteam **não trata disto**; precisas de um addon à parte que fala com o cliente Discord local via IPC. O mais usado atualmente na comunidade Godot 4 é o **[discord-rpc-godot](https://github.com/vaporvee/discord-rpc-godot)**.

**Setup:**

1. Cria uma aplicação em [discord.com/developers/applications](https://discord.com/developers/applications) e copia o **Application ID**.
2. Instala o addon via AssetLib (procura "discord" no separador AssetLib do editor) ou descarrega o `.zip` do repositório e extrai para `addons/`.
3. Ativa o plugin em **Project Settings → Plugins → DiscordRPC**.

**Uso:**

```gdscript
# discord_manager.gd — autoload
func _ready() -> void:
    DiscordRPC.app_id = 123456789012345678  # o teu Application ID do Discord
    DiscordRPC.state = "Em partida"
    DiscordRPC.details = "A jogar no Mapa Floresta"
    DiscordRPC.large_image = "game_icon"     # nome de um "Art Asset" configurado no portal Discord
    DiscordRPC.start_timestamp = int(Time.get_unix_time_from_system())  # mostra "há X minutos"
    DiscordRPC.refresh()  # obrigatório sempre que mudas qualquer campo

func update_map(map_name: String) -> void:
    DiscordRPC.details = "A jogar no %s" % map_name
    DiscordRPC.refresh()

func clear_presence() -> void:
    DiscordRPC.clear()
```

Notas importantes:

- Tens de chamar `refresh()` sempre que alteras qualquer campo — as mudanças não são automáticas.
- O jogador precisa de ter o **cliente Discord aberto** e a definição "Partilhar a atividade detetada com outros" ativa (Definições do Discord → Privacidade de Atividade).
- Para convites/"Join Game" através do Discord (similar ao `connect` do Steam), o addon também suporta `party_id`, `party_size`, `join_secret`, etc. — consulta a documentação do addon para o formato exato, já que variam um pouco entre versões.
- Como isto é um addon de terceiros (não da Valve/Anthropic/Discord oficialmente mantido), confirma sempre a versão mais recente no repositório antes de integrares, e considera correr o teu jogo sem o Discord aberto para confirmares que o teu código não rebenta se a integração falhar (o addon deve falhar silenciosamente nesse caso, mas vale a pena testar).

---

## 15. Conquistas, Estatísticas e Horas de Jogo

### Conquistas (Achievements)

As conquistas têm de ser criadas primeiro no **painel do Steamworks** (App Admin → Stats & Achievements), onde defines o "API Name" de cada uma (ex: `ACH_FIRST_WIN`) — é esse nome que usas no código, não o nome público mostrado ao jogador.

```gdscript
func unlock_achievement(achievement_id: String) -> void:
    # Evita chamadas desnecessárias verificando primeiro se já está desbloqueada
    var current: Dictionary = Steam.getAchievement(achievement_id)
    if current.get("achieved", false):
        return

    if not Steam.setAchievement(achievement_id):
        printerr("Falha ao definir conquista: %s" % achievement_id)
        return

    # Obrigatório para a notificação aparecer e para ficar gravado no Steam
    if not Steam.storeStats():
        printerr("Falha ao guardar stats no Steam (deve ficar guardado localmente para retry)")
```

Para conquistas com progresso visível (ex: "Mata 50 inimigos: 23/50"), usa `indicateAchievementProgress()` — isto só mostra o popup de progresso, **não desbloqueia nada sozinho**; tens de continuar a atualizar o stat e chamar `setAchievement()` quando o progresso atingir o máximo:

```gdscript
func update_kill_progress(current_kills: int, target_kills: int) -> void:
    Steam.setStatInt("total_kills", current_kills)
    if current_kills >= target_kills:
        unlock_achievement("ACH_50_KILLS")
    else:
        Steam.indicateAchievementProgress("ACH_50_KILLS", current_kills, target_kills)
    Steam.storeStats()
```

> **Nota sobre rate limiting:** `storeStats()` deve ser chamado com moderação — a Valve recomenda espaçares estas chamadas por minutos, não segundos (ex: fim de ronda, troca de mapa, saída do servidor), e não a cada pequena alteração. Se o jogo fechar sem teres chamado `storeStats()`, o Steam trata de o fazer automaticamente por ti no encerramento.

### Estatísticas (Stats)

Stats são números simples (inteiros ou floats) associados ao jogador, geridos da mesma forma que as conquistas — também precisam de ser criados primeiro no painel Steamworks.

```gdscript
Steam.setStatInt("total_kills", 42)
Steam.setStatFloat("total_distance_walked", 1523.7)

var kills: int = Steam.getStatInt("total_kills")
var distance: float = Steam.getStatFloat("total_distance_walked")

Steam.storeStats()  # como sempre, obrigatório para persistir
```

Se também guardas estatísticas localmente (ex: para as mostrares offline, ou para as sincronizares mais tarde), é boa prática comparar o valor local com o do Steam ao arrancar, e usar sempre o **maior dos dois** — evita perder progresso se o jogador jogou offline entretanto:

```gdscript
func sync_stat(stat_name: String, local_value: int) -> int:
    var steam_value: int = Steam.getStatInt(stat_name)
    if local_value > steam_value:
        Steam.setStatInt(stat_name, local_value)
        return local_value
    return steam_value
```

> Desde o SDK 1.61, o Steam sincroniza automaticamente stats/achievements no arranque — já não é preciso chamar `requestCurrentStats()` (essa função e o callback `current_stats_received` foram removidos das versões mais recentes do GodotSteam).

### Horas de jogo (Playtime)

O **Steam já regista automaticamente** quantas horas cada jogador tem no teu jogo — isso aparece na biblioteca do utilizador sem precisares de fazer nada; é calculado a partir de quanto tempo o processo do jogo esteve aberto enquanto o Steam também estava a correr.

Se quiseres mostrar isto **dentro do teu próprio jogo** (ex: "Já jogaste 12h"), tens duas opções:

1. **Tempo total de todos os jogadores num App ID específico** (não é o do teu jogador local, mas de qualquer App ID/DLC que o utilizador possua):
   ```gdscript
   # Note: pode não estar disponível em todas as versões/plataformas do GodotSteam;
   # confirma na documentação da tua versão específica se getAppPlaytime ou equivalente existe.
   ```
2. **A tua própria contagem manual** (mais fiável e controlável) — regista o tempo de sessão como um **Stat** teu, incrementado periodicamente enquanto o jogo está aberto:
   ```gdscript
   var session_start_time: float = 0.0

   func _ready() -> void:
       session_start_time = Time.get_unix_time_from_system()

   func _on_game_closing() -> void:  # ex: chamado em NOTIFICATION_WM_CLOSE_REQUEST
       var session_seconds: int = int(Time.get_unix_time_from_system() - session_start_time)
       var total_seconds: int = Steam.getStatInt("total_playtime_seconds") + session_seconds
       Steam.setStatInt("total_playtime_seconds", total_seconds)
       Steam.storeStats()
   ```

Isto dá-te total controlo sobre o formato (ex: "tempo jogado neste modo específico", separado do tempo total que o Steam já mostra automaticamente).

---

## 16. Workshop / UGC (Conteúdo Criado por Utilizadores)

O **Steam Workshop** permite aos jogadores criarem e partilharem conteúdo para o teu jogo (mapas, mods, skins, etc.), tudo hospedado e distribuído gratuitamente pela infraestrutura do Steam. No GodotSteam, isto é gerido pela classe **UGC** (*User Generated Content*).

> Antes de mais, vale a pena ler a documentação oficial da Valve sobre [Workshop Implementation](https://partner.steamgames.com/doc/features/workshop/implementation) — o GodotSteam só expõe as funções, mas os conceitos (visibilidade de itens, tags, previews, etc.) são definidos pelo próprio Steamworks e aplicam-se a qualquer motor.

### Criar um novo item do Workshop

```gdscript
var is_new_item: bool = false
var published_file_id: int = 0
var update_handle: int = 0

func _ready() -> void:
    Steam.item_created.connect(_on_item_created)
    Steam.item_updated.connect(_on_item_updated)

func create_workshop_item() -> void:
    is_new_item = true
    Steam.createItem(Steam.getAppID(), Steam.WORKSHOP_FILE_TYPE_COMMUNITY)

func _on_item_created(result: Steam.Result, file_id: int, needs_agreement: bool) -> void:
    if result != Steam.Result.RESULT_OK:
        printerr("Falha ao criar item: %s" % result)
        return
    published_file_id = file_id
    if needs_agreement:
        Steam.showWorkshopEULA()  # mostra o acordo de licença do Workshop, se necessário
    # Subscreve automaticamente o próprio criador ao item (não é feito automaticamente pelo Steam)
    Steam.subscribeItem(file_id)
    start_item_update()
```

### Preencher e submeter os dados do item

```gdscript
func start_item_update() -> void:
    update_handle = Steam.startItemUpdate(Steam.getAppID(), published_file_id)
    Steam.setItemTitle(update_handle, "O Meu Mapa Incrível")
    Steam.setItemDescription(update_handle, "Um mapa feito por mim para testar o Workshop.")
    Steam.setItemVisibility(update_handle, Steam.REMOTE_STORAGE_PUBLISHED_FILE_VISIBILITY_PUBLIC)
    Steam.setItemTags(update_handle, ["mapa", "coop"])
    Steam.setItemContent(update_handle, "/caminho/para/a/pasta/do/conteudo")
    Steam.setItemPreview(update_handle, "/caminho/para/preview.png")
    Steam.submitItemUpdate(update_handle, "Primeira versão")

func _on_item_updated(result: Steam.Result, needs_agreement: bool) -> void:
    if result == Steam.Result.RESULT_OK:
        print("Item publicado com sucesso: %s" % published_file_id)
    else:
        printerr("Falha ao publicar item: %s" % result)
```

> **`setItemContent()`** aponta para uma **pasta local** com o conteúdo a publicar (ex: um `.tscn` exportado como recurso, ficheiros de configuração de um mapa, etc.) — o Steam faz o upload e o versionamento por ti. Tens de decidir tu que formato de ficheiros o teu jogo vai aceitar como "conteúdo de Workshop" (ex: um `.zip` com um mapa exportado, um ficheiro JSON de configuração, etc.), já que o Godot não tem um formato universal de "mod" pronto a usar.

### Procurar e subscrever itens existentes

```gdscript
func _ready() -> void:
    Steam.ugc_query_completed.connect(_on_query_completed)

func search_workshop_items() -> void:
    var query_handle: int = Steam.createQueryAllUGCRequest(
        Steam.UGC_QUERY_RANKED_BY_VOTE,
        Steam.UGC_MATCHING_UGC_TYPE_ITEMS,
        Steam.getAppID(),
        Steam.getAppID(),
        1  # página de resultados
    )
    Steam.sendQueryUGCRequest(query_handle)

func _on_query_completed(query_handle: int, result: Steam.Result, results_returned: int, _total_matching: int, _cached: bool) -> void:
    if result != Steam.Result.RESULT_OK:
        return
    for i in range(results_returned):
        var details: Dictionary = Steam.getQueryUGCResult(query_handle, i)
        print("Item: %s (%s)" % [details["title"], details["file_id"]])
        # mostra na tua UI de "Procurar Workshop", com botão de subscrever:

func subscribe_to_item(file_id: int) -> void:
    Steam.subscribeItem(file_id)  # o download começa automaticamente
```

### Carregar conteúdo subscrito

```gdscript
func _ready() -> void:
    Steam.item_installed.connect(_on_item_installed)

func load_subscribed_items() -> void:
    var subscribed: Array = Steam.getSubscribedItems()
    for file_id in subscribed:
        var install_info: Dictionary = Steam.getItemInstallInfo(file_id)
        if install_info.get("ret", false):
            var folder: String = install_info["folder"]
            # aqui carregas o conteúdo a partir desta pasta local (ex: um ficheiro de mapa)

func _on_item_installed(app_id: int, file_id: int) -> void:
    print("Item instalado/atualizado: %s" % file_id)
```

### Notas gerais sobre Workshop

- É preciso teres o Workshop **ativado no painel do Steamworks** para o teu App ID antes de qualquer destas funções funcionar.
- Itens têm um ciclo de vida: `createItem()` → preencher com `startItemUpdate()`/`setItem...()` → `submitItemUpdate()`. Atualizações futuras ao mesmo item repetem só os últimos 2 passos, reutilizando o `published_file_id`.
- `subscribeItem()` não é automático para o criador — subscreve-o tu manualmente depois de criares o item, se quiseres que ele o tenha instalado localmente.
- Trata sempre conteúdo de Workshop como **não fiável do ponto de vista de segurança** (é conteúdo de outros utilizadores) — nunca executes código arbitrário vindo de itens subscritos; limita-te a carregar dados/recursos (mapas, configs, texturas) de forma controlada. Ver também a secção 16 (Segurança).

---

## 17. Overlay do Steam

O overlay é o painel que aparece por cima do jogo (**Shift+Tab** por padrão no PC, botão dedicado no Steam Deck) com chat, amigos, loja, navegador, etc. — os jogadores já o conhecem de outros jogos Steam, por isso vale a pena garantir que funciona bem no teu.

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

### Detetar se o overlay está ativo (pausar o jogo automaticamente)

Muitos jogos pausam automaticamente (ou baixam o volume) quando o jogador abre o overlay com Shift+Tab. Isto é feito através do callback `overlay_toggled`:

```gdscript
func _ready() -> void:
    Steam.overlay_toggled.connect(_on_overlay_toggled)

func _on_overlay_toggled(active: bool, _user_initiated: bool, _app_id: int) -> void:
    if active:
        get_tree().paused = true   # opcional, dependendo do teu jogo
    else:
        get_tree().paused = false
```

> Confirma se `Steam.isOverlayEnabled()` devolve `true` antes de contares com isto — o **utilizador pode ter desativado o overlay** por completo nas definições do Steam para o teu jogo, e nesse caso `overlay_toggled` nunca dispara.

> **Cuidado:** com o renderer **Forward+** do Godot, o overlay do Steam pode não funcionar quando corres o jogo pelo editor, a menos que uses a auto-inicialização definida em Project Settings. Testar sempre pela build exportada, correndo através do cliente Steam, é mais fiável.

---

## 18. Segurança e Anti-Cheat

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

## 19. Outras funcionalidades úteis

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

## 20. Erros comuns e dicas

- **`status: 2` ao inicializar** → o cliente Steam não está aberto. Tens de ter o Steam a correr em segundo plano, mesmo em testes com App ID 480.
- **Lobby não aparece nas pesquisas** → verifica o `LobbyType` (não pode ser `LOBBY_TYPE_INVISIBLE`), se está `joinable` (`setLobbyJoinable`), e se não está cheia.
- **`run_callbacks()` nunca dispara sinais** → confirma que o nó/script onde está não pausa e que está mesmo a correr todos os frames.
- **Overlay não abre no editor** → experimenta correr a build exportada em vez do editor, especialmente com Forward+.
- **App ID 480 tem lobbies "lixo" de outros programadores a testar** → usa `setLobbyData()`/filtros de string para marcares as tuas lobbies com uma tag única (ex: `"game":"MeuJogo"`) e filtra só por essa tag ao pesquisar.
- **Testar P2P localmente** → normalmente precisas de duas instâncias do Steam com contas diferentes (ou usar uma segunda conta de teste), já que o Steam não permite o mesmo Steam ID ligado duas vezes em simultâneo à mesma sessão de forma trivial.
- **`steam_appid.txt` no build final** → remove sempre este ficheiro antes de publicares no Steam; serve só para testes locais sem passar pelo cliente Steam propriamente lançado pelo jogo.
- **Cliente a "confiar em si próprio"** → se alguma vez pensares "o cliente já validou isto, não preciso de validar outra vez no servidor", é quase sempre um sinal de alerta — revê a secção 15 (Segurança).

---

## 21. Recursos extra

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