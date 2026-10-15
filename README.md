# ClashAttackLab

App macOS in SwiftUI per simulare e analizzare attacchi di Clash of Clans: editor di basi ed eserciti, simulazione della battaglia, generazione, confronto e raffinamento di piani d'attacco.

## Struttura

- `ClashAttackLabMac/GameData/` – dati di gioco e layout delle basi (`ReferenceGameData.json` è generato, vedi sotto)
- `ClashAttackLabMac/Simulation/` – motore di simulazione
- `ClashAttackLabMac/Pathfinding/` – A* e griglia di navigazione
- `ClashAttackLabMac/Strategy/` – piani d'attacco, generatore, valutazione, libreria
- `ClashAttackLabMac/AI/`, `ClashAttackLabMac/Rendering/` – selezione dei bersagli e scena di battaglia
- `ClashAttackLabMac/Bases/` – basi reali incluse nell'app, in formato testo (vedi `Docs/importare-una-base.md`)
- `ClashAttackLabMacTests/`, `ClashAttackLabMacUITests/` – test
- `Tools/generate_reference_game_data.py` – rigenera `ReferenceGameData.json`

## Build e test

Apri `ClashAttackLab.xcodeproj` e usa lo schema `ClashAttackLabMac`. La CI (`.github/workflows/macos.yml`) compila ed esegue i test a ogni push e pull request su `main`.

## Rigenerare i dati di gioco

```
python3 Tools/generate_reference_game_data.py
```

## Importare una base reale

In modalità Reale usa **Importa base…** con un file di testo. Il formato è descritto in [`Docs/importare-una-base.md`](Docs/importare-una-base.md).

## Cosa simula la modalità Reale

L'elenco di truppe, difese, incantesimi ed equipaggiamenti simulati, e dei valori stimati, è in [`Docs/modalita-reale.md`](Docs/modalita-reale.md).
