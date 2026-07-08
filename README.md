# Vivo Sprint

Jogo de corridas multiplayer 3D feito em Godot 4.7 com integração Steamworks.

## Requisitos

- Godot 4.7+ (Forward+ renderer, Jolt Physics)
- Steamworks SDK (via GodotSteam)
- Steam client em execução para testar funcionalidades online

## Setup

```bash
# Clonar
git clone https://github.com/Strefiz/Vivo-Sprint.git
cd Vivo-Sprint

# Abrir no editor Godot com Steam (módulo)
./game/editor_steam/godotsteam.47.editor.win64.exe

# Ou abrir com Godot normal (sem Steam)
# godot --path ./game
```

O `steam_appid.txt` contém o App ID 480 (Spacewar) para testes offline. Substituir pelo App ID real antes do lançamento.

## Estrutura

```
game/
├── assets/          # Modelos, texturas, áudio, skyboxes
├── scenes/          # Cenas (ui, tracks, vehicles, world, pitlane)
├── scripts/         # Lógica (network, race, steam, vehicles, weather)
├── shaders/         # Shaders custom
├── config/          # Dados de configuração (carros, pistas, pneus)
├── addons/          # Plugins Godot
└── project.godot
```

Ver `PLAN.md` para o documento de design completo.

## Licença

MIT
