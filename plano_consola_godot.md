# Plano de Implementação — Consola de Comandos (Godot 4)

Guia genérico para adicionar uma consola de debug/comandos a **qualquer** projeto Godot 4, reutilizável entre jogos (ex: UniCooking). O objetivo é teres um sistema modular, fácil de estender, que não obrigue a tocar no resto do código sempre que queiras adicionar um comando novo.

---

## 1. Objetivos e Arquitetura

**Objetivos:**
- Consola invocável por tecla (ex: `` ` `` ou `~`), sobreposta ao jogo.
- Sistema de comandos extensível — qualquer script pode "registar" um comando novo sem editar a consola.
- Autocomplete, histórico de comandos (setas cima/baixo), scroll de output.
- Fácil de desativar em builds de release (ou proteger com flag/senha).

**Arquitetura (peças principais):**

```
Console (Autoload/Singleton)
 ├── ConsoleUI (CanvasLayer, sempre no topo)
 │    ├── Panel/Background
 │    ├── RichTextLabel (output/log)
 │    └── LineEdit (input)
 ├── CommandRegistry (Dictionary: nome -> Callable/CommandData)
 └── CommandParser (interpreta texto -> nome + args)
```

Ideia central: a Consola é um **Autoload** (singleton global), assim qualquer script do jogo consegue aceder-lhe via `Console.print(...)` ou registar comandos via `Console.register_command(...)`.

---

## 2. Estrutura de Ficheiros Sugerida

```
res://addons/console/            (ou res://scripts/console/)
 ├── console.gd            # Autoload principal, gere UI + lógica
 ├── console_ui.tscn        # Cena da UI (CanvasLayer)
 ├── command.gd              # Classe/Resource que representa um comando
 └── commands/
      ├── base_commands.gd   # /help, /clear, /quit, /echo...
      └── debug_commands.gd  # /god, /tp, /give, /fps, etc. (específicos do jogo)
```

Separar "core" da consola dos "comandos específicos do jogo" é o que te vai permitir copiar a pasta `console/` para outro projeto Godot sem alterações.

---

## 3. A Cena da Consola (UI) — Criar no Editor Passo a Passo

Esta é a base visual de tudo. Vamos criar `console_ui.tscn` com uma hierarquia de nodes bem definida, configurando tamanhos e anchors diretamente no editor (não por código), para ficar tudo visível e ajustável no Inspector.

### 3.1 Hierarquia de Nodes

```
ConsoleUI (CanvasLayer)                 ← layer = 100
 └── Root (Control)                     ← full rect, mouse_filter = Ignore
      └── PanelContainer (Panel)        ← fundo + moldura da consola
           └── MarginContainer          ← margens internas (padding)
                └── VBoxContainer        ← empilha output + input
                     ├── RichTextLabel   ← área de output/log
                     └── LineEdit        ← campo de escrita
```

Cria a cena assim: **Scene → New Scene → Other Node → CanvasLayer** como raiz, depois vais adicionando os filhos com o botão `+` no painel de Scene, um dentro do outro pela ordem acima.

### 3.2 Configurar cada node (Inspector)

**`ConsoleUI` (CanvasLayer)**
- `Layer`: `100` (garante que fica por cima de HUD, menus, etc.)
- Vai ser aqui que anexas o script `console.gd` (ou um script secundário só de UI, se separares lógica de UI da lógica de comandos).

**`Root` (Control)**
- No canto superior esquerdo do editor 2D, com o node `Root` selecionado, abre o menu **Layout** (ou o ícone de "âncoras" na toolbar) e escolhe **Full Rect**. Isto define automaticamente:
  - `Anchors Preset`: Full Rect (anchor_left/top = 0, anchor_right/bottom = 1)
  - Assim o `Root` ocupa sempre o ecrã inteiro, independentemente da resolução.
- `Mouse Filter`: `Ignore` — importante para que, quando a consola está fechada (ou nas zonas vazias), os cliques passem através para o jogo por baixo.

**`PanelContainer` (Panel)** — este é o retângulo visível da consola
- Não precisa de ocupar o ecrã todo. Sugestão típica: metade superior do ecrã (estilo CS/Source engine) ou um retângulo central.
- No Inspector, em **Layout → Anchors Preset**, escolhe por exemplo **Top Wide**:
  - `anchor_left = 0`, `anchor_right = 1`, `anchor_top = 0`, `anchor_bottom = 0` (bordas soltas)
  - Depois ajusta `offset_bottom` manualmente (ex: `400` px) para definires a altura da consola arrastando a alça azul no editor 2D, ou escrevendo o valor diretamente em **Layout → Transform → Size**.
- Alternativa mais simples se não quiseres lidar com anchors: define `Custom Minimum Size` (ex: `x=0, y=400`) e usa anchors **Top Wide**, deixando a largura automática e só a altura fixa.
- `Modulate` ou uma `StyleBoxFlat` no `Theme Override → Styles → Panel` para dares cor de fundo semi-transparente (ex: preto a 80% opacidade — define o alpha do `Color` no StyleBox).
- `Mouse Filter`: `Stop` (para que cliques dentro da consola não "vazem" para o jogo por baixo).

**`MarginContainer`**
- `Anchors Preset`: **Full Rect** (para preencher o `PanelContainer` todo).
- No **Theme Override → Constants**, define `margin_left`, `margin_top`, `margin_right`, `margin_bottom` (ex: `12` px cada) — isto dá o "padding" interno, para o texto não colar às bordas do painel.

**`VBoxContainer`**
- Não precisas de mexer em anchors (herda o espaço do `MarginContainer` automaticamente).
- No **Theme Override → Constants → Separation**, define espaçamento entre o output e o input (ex: `6` px).

**`RichTextLabel`** (output/log)
- Em **Layout → Container Sizing**, marca `Vertical → Expand` e `Size Flags Vertical = Fill/Expand` (com valor de stretch `1`), para que ocupe **todo o espaço restante** do `VBoxContainer`, empurrando o `LineEdit` para o fundo.
- `BBCode Enabled`: `true` (para cores no texto, ex: `[color=red]Erro![/color]`).
- `Scroll Follow`: `true` (mantém o scroll sempre no fim, tipo consola real).
- `Selection Enabled`: `true` (útil para copiares texto de erro).
- `Custom Minimum Size`: opcional, ex: `y=200`, como salvaguarda se o painel for muito pequeno.
- Fonte: usa **Theme Override → Fonts → Normal Font** para definires uma fonte monoespaçada (ex: importar uma `.ttf` tipo "JetBrains Mono" ou "Courier"), o que dá muito mais aspeto de consola do que a fonte default.

**`LineEdit`** (input de comandos)
- `Size Flags Vertical`: `Fill` (não `Expand` — queres que tenha só a altura de uu texto, não que cresça).
- `Custom Minimum Size`: ex: `y=32`, para ter uma altura confortável de clicar/ler.
- `Placeholder Text`: `"Escreve um comando... (/help)"`.
- `Context Menu Enabled`: mantém `true` (copiar/colar continua a funcionar).
- Liga o sinal `text_submitted(text: String)` ao script (dispara quando o jogador carrega Enter) — é esse sinal que vais ligar ao `parse_input()` da secção 6.

### 3.3 Testar tamanhos sem sair do editor

- Podes clicar no botão **"Play Scene" (F6)** só nesta cena (`console_ui.tscn`) isoladamente, sem correr o jogo todo, para veres o layout a render em várias resoluções (usa o dropdown de resolução no canto superior do editor 2D, ou testa redimensionando a janela).
- Ativa temporariamente `visible = true` na raiz para a veres no editor 2D enquanto ajustas os anchors — o Godot já mostra o retângulo dela mesmo sem correr o jogo, mas ver "ao vivo" com F6 ajuda a confirmar proporções.

### 3.4 Resumo dos tamanhos sugeridos (ponto de partida)

| Node | Anchor Preset | Tamanho/Offset sugerido |
|---|---|---|
| `Root` | Full Rect | — (ecrã inteiro) |
| `PanelContainer` | Top Wide | altura `offset_bottom ≈ 400px` (ajusta à tua resolução base) |
| `MarginContainer` | Full Rect (dentro do Panel) | margens `12px` |
| `RichTextLabel` | Expand vertical | mínimo `y=200px` |
| `LineEdit` | Fill vertical | altura fixa `y=32px` |

Estes valores são um ponto de partida — ajusta conforme a resolução base do teu projeto (`Project Settings → Display → Window → Size`) e o quanto de ecrã queres que a consola tape.

### 3.5 Animação (opcional)

- Animação simples de slide (podes reaproveitar a técnica que já usaste no menu — `AnimationPlayer` criado em runtime — para abrir/fechar a consola, animando `offset_top`/`position.y` do `PanelContainer` entre fora do ecrã e a posição final).
- A cena começa **escondida** (`visible = false`, ou fora do ecrã se animares) e o Autoload trata de a mostrar/esconder.

---

## 4. Toggle / Input — Definir o Botão que Abre/Fecha a Consola

**Nunca hardcodes a tecla no código** (ex: `if event.keycode == KEY_QUOTELEFT`). Usa sempre uma **Input Action** definida no Project Settings, para que seja remapeável e consistente com o resto do input do jogo.

### Passo a passo (Project Settings)

1. Abre **Project → Project Settings → Input Map**.
2. No campo de texto em baixo, escreve o nome da action: `toggle_console` e clica **Add**.
3. Na linha da nova action, clica no `+` para lhe atribuires uma tecla física.
4. Escolhe a tecla — sugestões comuns:
   - `` ` `` (crase/til, "QuoteLeft") — standard em quase todos os jogos com consola (Source Engine, Unreal, etc.)
   - `F1` ou `F12` — alternativa se o teclado PT-PT tiver a crase num sítio incômodo.
   - Podes adicionar **duas** teclas à mesma action (ex: `` ` `` e `F1`) — o Input Map aceita múltiplos eventos por action.
5. Grava o projeto. A partir daqui, `Input.is_action_just_pressed("toggle_console")` ou `event.is_action_pressed("toggle_console")` já funciona em qualquer script.

> Nota PT-PT: no layout de teclado português, a tecla `` ` `` está normalmente ao lado do `1`/acima do `Tab`, mas em portáteis pode estar mapeada de forma diferente. Testa sempre no teu teclado real antes de fixares a tecla por defeito — ou dá a opção de remapear no menu de definições do jogo (reaproveitando o padrão que já usaste no menu "Definições").

### Código do toggle

```gdscript
func _unhandled_input(event: InputEvent) -> void:
    if event.is_action_pressed("toggle_console"):
        toggle()
        get_viewport().set_input_as_handled()

func toggle() -> void:
    visible = !visible
    if visible:
        line_edit.grab_focus()
        get_tree().paused = pause_game_when_open  # opcional
    else:
        line_edit.release_focus()
        get_tree().paused = false
```

Notas importantes:
- Se pausares o jogo (`get_tree().paused = true`), lembra-te de marcar o `process_mode` da consola como `PROCESS_MODE_ALWAYS`, senão ela também congela e não consegues voltar a fechá-la.
- Bloqueia o `toggle_console` de propagar para o resto do jogo (`set_input_as_handled()`), para não disparares outras ações ao mesmo tempo (ex: abrir inventário na mesma tecla).
- Se a consola estiver aberta, convém **consumir todo o input de texto** (`set_input_as_handled()` também nos outros eventos de teclado) para que letras como `W`, `A`, `S`, `D` não movam o jogador enquanto escreves um comando.
- Opcional: permitir fechar também com `Esc`, além da tecla de toggle.

---

## 5. Ter a Consola Disponível em Todas as Cenas (sem fechar/reiniciar ao mudar de cena)

Isto é o ponto-chave para a consola "simplesmente funcionar" em qualquer cena do jogo, do menu principal ao gameplay.

### Porque um Autoload resolve isto automaticamente

Quando marcas `console.gd` (com a UI incluída, ou instanciando a `console_ui.tscn` dentro dele) como **Autoload** em **Project → Project Settings → Autoload**, o Godot:

- Cria essa node **uma única vez**, na raiz da árvore de cenas (`/root/Console`), **antes** de qualquer cena carregar.
- **Não a destrói nem recria** quando trocas de cena com `get_tree().change_scene_to_file(...)` — só a cena "normal" (a que aparece na raiz como filha, ex: `/root/Main`) é substituída. O Autoload fica sempre lá.

Ou seja: **desde que a consola seja Autoload, ela já sobrevive a mudanças de cena automaticamente** — não precisas de fazer nada de especial para isso. O erro mais comum é teres a consola como node normal dentro da cena principal (`Main.tscn`), o que a faz desaparecer sempre que trocas de cena.

### Passo a passo para configurar o Autoload

1. Cria a cena `console_ui.tscn` com script `console.gd` anexado à raiz.
2. **Project → Project Settings → Autoload**.
3. No campo "Path", seleciona `console_ui.tscn` (não o `.gd` sozinho — assim já vem com a UI incluída).
4. Node Name: `Console` (é o nome que vais usar em código, ex: `Console.print_line(...)`).
5. Ativa a checkbox e clica **Add**.
6. Confirma que aparece na lista, no topo (ordem de autoloads importa se um depender doutro).

### Cuidados para manter o estado consistente entre cenas

- **Histórico e log não se perdem**: como a node nunca é destruída, o `history` (Array) e o texto do `RichTextLabel` mantêm-se tal e qual como estavam ao mudar de cena — é o comportamento desejado (tipo consola do CS:GO).
- **Comandos registados por scripts da cena**: se um `player.gd` regista `/give` no `_ready()`, e a cena for descarregada (ex: voltar ao menu), esse comando fica "órfão" no dicionário `commands` — o `Callable` aponta para um objeto já destruído, o que pode causar erro ao tentar chamá-lo.
  - Solução: no `_exit_tree()` do script que registou o comando, chama `Console.unregister_command("give")` para o remover.
  ```gdscript
  func _exit_tree() -> void:
      Console.unregister_command("give")
  ```
  - Implementa `unregister_command` no `console.gd`:
  ```gdscript
  func unregister_command(name: String) -> void:
      commands.erase(name)
  ```
- **Visibilidade ao mudar de cena**: decide se queres que a consola **feche automaticamente** ao mudar de cena (ex: ir para o menu principal) ou se **mantém-se aberta** se já estava aberta. Sugestão: fechar sempre ao entrar numa cena nova, para evitar estar aberta por cima de um ecrã de loading:
  ```gdscript
  func _ready() -> void:
      get_tree().node_added.connect(_on_node_added)

  func _on_node_added(node: Node) -> void:
      if node == get_tree().current_scene:
          close()  # fecha a consola sempre que uma nova cena raiz entra
  ```
- **`get_tree().paused`**: se a consola pausa o jogo ao abrir, garante que ao mudar de cena o pause é sempre reposto a `false` (senão a próxima cena pode arrancar já pausada por engano).
- **CanvasLayer com layer alto**: mantém a consola sempre visualmente por cima de qualquer UI de cena (menus, HUD, ecrãs de loading), porque ao ser Autoload ela é adicionada à raiz da árvore, fora da hierarquia da cena atual — isto já dá prioridade de desenho correta na maioria dos casos, mas confirma o valor de `layer` (ex: 100) se outras UIs também usarem CanvasLayer com valores altos.

---

## 6. Parsing de Comandos

Formato sugerido: `/comando arg1 arg2 "argumento com espaços"`.

```gdscript
func parse_input(text: String) -> void:
    text = text.strip_edges()
    if text.is_empty():
        return

    add_to_history(text)
    print_line("> " + text, Color.GRAY)

    if text.begins_with("/"):
        text = text.substr(1)

    var parts := _tokenize(text)   # respeita aspas
    if parts.is_empty():
        return

    var cmd_name := parts[0].to_lower()
    var args := parts.slice(1)

    execute_command(cmd_name, args)
```

`_tokenize` deve ser um pequeno parser manual (ou regex) que respeita strings entre aspas, para permitir `/say "boa noite pessoal"`.

---

## 7. Registo de Comandos (o coração do sistema)

Define uma pequena classe/Resource `Command` para representar cada comando registado:

```gdscript
class_name Command
extends RefCounted

var name: String
var description: String
var usage: String            # ex: "/tp <x> <y>"
var min_args: int = 0
var callback: Callable
```

No Autoload `Console`:

```gdscript
var commands: Dictionary = {}   # nome -> Command

func register_command(name: String, description: String, usage: String,
        callback: Callable, min_args: int = 0) -> void:
    var cmd := Command.new()
    cmd.name = name
    cmd.description = description
    cmd.usage = usage
    cmd.callback = callback
    cmd.min_args = min_args
    commands[name] = cmd

func execute_command(name: String, args: Array) -> void:
    if not commands.has(name):
        print_error("Comando desconhecido: '%s'. Escreve /help para a lista." % name)
        return

    var cmd: Command = commands[name]
    if args.size() < cmd.min_args:
        print_error("Uso: %s" % cmd.usage)
        return

    # callback recebe sempre o Array de args
    cmd.callback.call(args)
```

Qualquer script do jogo (ex: `player.gd`, `cafe.gd`) pode registar-se assim, tipicamente em `_ready()`:

```gdscript
func _ready() -> void:
    Console.register_command(
        "give",
        "Dá um item ao jogador.",
        "/give <item_id> [quantidade]",
        _cmd_give,
        1
    )

func _cmd_give(args: Array) -> void:
    var item_id := args[0]
    var qty := int(args[1]) if args.size() > 1 else 1
    Inventory.add_item(item_id, qty)
    Console.print_line("Deste %d x %s" % [qty, item_id])
```

Isto é o que torna o sistema **extensível sem tocar no core** — cada sistema do jogo (inventário, spawner, economia...) trata dos seus próprios comandos.

---

## 8. Comandos Base a Incluir (core, universais)

| Comando | Descrição |
|---|---|
| `/help [comando]` | Lista todos os comandos, ou mostra detalhe/uso de um específico |
| `/clear` | Limpa o output da consola |
| `/echo <texto>` | Escreve o texto de volta (útil para testar parsing/aspas) |
| `/quit` ou `/exit` | Fecha o jogo (`get_tree().quit()`) |
| `/list` | Lista todos os comandos disponíveis (nomes só) |
| `/fps` | Mostra o FPS atual / toggle de overlay de FPS |
| `/history` | Mostra o histórico de comandos usados |
| `/version` | Mostra versão do build/jogo |
| `/reload` ou `/restart_scene` | Recarrega a cena atual (`get_tree().reload_current_scene()`) |

### Exemplo — `/help`

```gdscript
func _cmd_help(args: Array) -> void:
    if args.is_empty():
        print_line("Comandos disponíveis:", Color.CYAN)
        var names := commands.keys()
        names.sort()
        for n in names:
            var c: Command = commands[n]
            print_line("  /%s — %s" % [n, c.description])
        print_line("Usa /help <comando> para mais detalhe.")
    else:
        var name: String = args[0]
        if commands.has(name):
            var c: Command = commands[name]
            print_line("%s\nUso: %s" % [c.description, c.usage])
        else:
            print_error("Comando '%s' não existe." % name)
```

Regista-o assim no `_ready()` do próprio `console.gd`:

```gdscript
register_command("help", "Mostra esta lista de comandos.", "/help [comando]", _cmd_help)
```

---

## 9. Comandos de Debug/Gameplay (específicos do jogo, exemplos)

Estes vivem em `debug_commands.gd` ou em scripts próprios de cada sistema:

- `/god` — toggle de invencibilidade
- `/tp <x> <y>` — teleporta o jogador
- `/give <item> [qtd]` — dá item ao inventário
- `/set <var> <valor>` — altera uma variável de estado do jogo (ex: dinheiro, reputação)
- `/spawn <entidade> [x] [y]` — instancia uma entidade na cena
- `/timescale <valor>` — altera `Engine.time_scale`
- `/skip_day` — (no caso do UniCooking) avança para o dia seguinte

Regra de ouro: comandos que alteram o **estado do jogo** devem chamar as mesmas funções que o jogo normal usaria (ex: `Inventory.add_item()`), nunca escrever lógica duplicada só para a consola.

---

## 10. Autocomplete e Histórico

**Histórico** (fácil, array + índice):

```gdscript
var history: Array[String] = []
var history_index: int = -1

func _on_line_edit_gui_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed:
        if event.keycode == KEY_UP:
            history_index = clamp(history_index - 1, 0, history.size() - 1)
            line_edit.text = history[history_index] if history.size() > 0 else ""
        elif event.keycode == KEY_DOWN:
            history_index = clamp(history_index + 1, 0, history.size())
            line_edit.text = history[history_index] if history_index < history.size() else ""
```

**Autocomplete** (Tab): procura comandos cujo nome comece pelo texto atual e completa (ou mostra sugestões se houver mais que uma correspondência).

```gdscript
func _try_autocomplete() -> void:
    var partial := line_edit.text.replace("/", "")
    var matches := commands.keys().filter(func(n): return n.begins_with(partial))
    if matches.size() == 1:
        line_edit.text = "/" + matches[0] + " "
        line_edit.caret_column = line_edit.text.length()
    elif matches.size() > 1:
        print_line("Sugestões: " + ", ".join(matches))
```

---

## 11. Output / Logging

- `print_line(texto, cor)` — adiciona ao `RichTextLabel` com `push_color`/`pop`.
- Considera também capturar `print()` normais do motor, redirecionando para a consola (opcional, mais avançado — podias usar um autoload "Logger" central que tanto o `print()` normal como a consola consultam).
- Cores sugeridas: erros a vermelho, avisos a amarelo, sucesso a verde, comandos ecoados a cinza.

---

## 12. Segurança / Builds de Release

Não queres que qualquer jogador destrave `/god` ou `/give` num jogo lançado publicamente (a menos que seja intencional, tipo sandbox mode). Opções:

1. **Compilar fora**: usar `if OS.is_debug_build():` para só registar comandos "perigosos" em debug builds.
2. **Flag de consola**: uma variável `console_enabled` controlada por um autoload de config, desativável em produção.
3. **Password/unlock**: comando `/unlock <password>` que ativa um `cheats_enabled = true` antes de permitir comandos sensíveis — útil se quiseres deixar a consola ativa mas os cheats trancados.

Para Steam multiplayer (GodotSteam) — importante: comandos que alterem estado do jogo devem correr **só no host/servidor**, ou ser replicados via RPC. Não deixes cada cliente executar `/give` localmente sem sincronizar, ou vais ter dessincronização de estado entre peers.

---

## 13. Integração com GodotSteam / Multiplayer (nota para o teu projeto)

Se a consola for usada em sessão multiplayer:
- Regista os comandos "de mundo" (spawn, give, set) para só executarem se `multiplayer.is_server()` for `true`, e faz o efeito propagar por RPC (`@rpc("authority", "call_local")`) para os clientes.
- Comandos puramente locais/cosméticos (`/fps`, `/clear`, `/timescale` local) podem correr sem RPC.
- Podes adicionar um comando `/whoami` que mostra `multiplayer.get_unique_id()` — útil para debug de sessões Steam.

---

## 14. Como Planear Comandos (antes de implementares)

Antes de abrires o editor e começares a escrever `func _cmd_x`, vale a pena planear cada comando numa tabela — evita comandos redundantes, nomes inconsistentes, e obriga-te a pensar em multiplayer/segurança antes de codificar.

### Categorias de comandos

Separa sempre os comandos em categorias claras (ajuda a organizar os ficheiros da secção 2 e a decidir o que fica escondido em release):

| Categoria | Exemplos | Disponível em release? |
|---|---|---|
| **Core / utilidade** | `/help`, `/clear`, `/echo`, `/history` | Sim |
| **Sistema/motor** | `/fps`, `/version`, `/quit`, `/reload` | Sim |
| **Debug de gameplay** | `/god`, `/tp`, `/give`, `/set`, `/spawn` | Só debug builds |
| **Admin/multiplayer** | `/kick`, `/ban`, `/whoami`, `/broadcast` | Depende (host-only) |
| **Específicos do projeto** | `/skip_day` (UniCooking) | Depende |

### Convenção de nomes

- Tudo em **minúsculas**, sem acentos, sem espaços (`/give`, não `/Dá` ou `/dar_item`).
- Verbos no infinitivo sem "to"/"-r" quando possível: `/give`, `/spawn`, `/tp` (em vez de `/dar`, `/criar`) — mantém consistência mesmo escrevendo o resto do jogo em português, porque é o padrão que qualquer jogador reconhece de outros jogos (Minecraft, CS, etc.).
- Aliases curtos quando fizer sentido (`/tp` para `/teleport`), mas regista sempre o nome completo como principal e o curto como alias:
  ```gdscript
  register_command("teleport", "...", "...", _cmd_tp)
  register_alias("tp", "teleport")
  ```

### Ficha de planeamento (usa isto por cada comando novo)

Antes de implementar, preenche mentalmente (ou num bloco de notas) esta ficha:

```
Nome:            /give
Alias:           (nenhum)
Descrição:       Dá um item ao inventário do jogador.
Uso:             /give <item_id> [quantidade]
Args mínimos:    1
Args:            item_id (String, obrigatório) | quantidade (int, opcional, default 1)
Sistema afetado: Inventory (autoload)
Efeito:          Inventory.add_item(item_id, quantidade)
Multiplayer:     Só no host; replicar via RPC para o cliente-alvo
Só debug?        Sim
Validações:      item_id existe na tabela de items? quantidade > 0?
```

Isto obriga-te a responder a três perguntas-chave **antes** de escrever código:
1. **Que sistema já existente** vou chamar? (nunca dupliques lógica só para a consola — chama sempre a mesma função que o jogo usaria normalmente, ex: o mesmo `Inventory.add_item()` que um evento de gameplay chamaria).
2. **Que argumentos são obrigatórios vs. opcionais**, e que valor por defeito faz sentido para os opcionais?
3. **Precisa de validação**? (ex: `/tp` com coordenadas fora do mapa, `/give` com um item_id que não existe — a consola deve dar erro claro, não crashar o jogo).

### Lista de comandos planeados (exemplo de tabela para manteres atualizada)

Mantém isto num ficheiro `commands_plan.md` ou numa folha de cálculo à parte, para teres sempre visão geral do que já existe e o que falta:

| Comando | Categoria | Estado | Sistema |
|---|---|---|---|
| `/help` | Core | ✅ Implementado | Console |
| `/clear` | Core | ✅ Implementado | Console |
| `/give` | Debug | 🔲 Planeado | Inventory |
| `/tp` | Debug | 🔲 Planeado | Player |
| `/skip_day` | Projeto | 🔲 Planeado | DayCycle |

Isto também ajuda muito se estiveres a documentar o teu jogo em paralelo (como já fazes com o guia GodotSteam) — a tabela de comandos serve diretamente de rascunho para essa documentação.

---

## 15. Ordem de Implementação Recomendada

1. Criar a cena `console_ui.tscn` (UI básica: Panel + RichTextLabel + LineEdit).
2. Criar `console.gd` como Autoload, com toggle por tecla e ligação da UI.
3. Implementar `parse_input` + `_tokenize` (parser básico, sem aspas complexas de início).
4. Implementar `register_command` / `execute_command` / dicionário `commands`.
5. Implementar `/help`, `/clear`, `/echo`, `/quit` (comandos triviais para validar o sistema).
6. Implementar histórico (setas cima/baixo).
7. Implementar autocomplete (Tab).
8. Adicionar comandos específicos do jogo (debug_commands.gd) — só depois do core estar sólido.
9. Adicionar proteção de release (`OS.is_debug_build()` ou flag).
10. (Se aplicável) Adaptar comandos de mundo para multiplayer via RPC.

---

## 16. Checklist Final

- [ ] Autoload `Console` (com UI incluída) registado em Project Settings → Autoload
- [ ] Action `toggle_console` criada no Input Map, com tecla testada no teclado real (PT-PT)
- [ ] Consola confirmada como funcional em **pelo menos 2 cenas diferentes** sem duplicar nem desaparecer
- [ ] Comandos registados por scripts de cena são removidos em `_exit_tree()` (evitar `Callable`s órfãos)
- [ ] UI não bloqueia input do resto do jogo quando fechada (`mouse_filter`, `visible`)
- [ ] `process_mode = PROCESS_MODE_ALWAYS` se pausares o jogo ao abrir consola
- [ ] Pause reposto a `false` em transições de cena, mesmo que a consola estivesse aberta
- [ ] `/help` lista todos os comandos automaticamente (não hardcoded)
- [ ] Cada comando planeado numa ficha antes de implementado (nome, args, sistema afetado, validações)
- [ ] Comandos organizados por ficheiro/sistema, não tudo num só script gigante
- [ ] Comandos sensíveis protegidos em release builds
- [ ] Se multiplayer: comandos de mundo replicados corretamente (sem dessync)

---

*Este plano é pensado para ser copiável entre projetos — a pasta `console/` inteira pode ir para outro jogo Godot 4 sem alterações, bastando reimplementar os comandos específicos de cada jogo.*
