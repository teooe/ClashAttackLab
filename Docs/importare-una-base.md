# Importare una base reale

In modalità **Reale** il menu **Base** contiene:

- le tre basi generate (Fortezza, Corridoio, Doppio nucleo);
- le basi incluse nell'app, cioè i file `.txt` della cartella `ClashAttackLabMac/Bases`;
- le basi che hai importato con **Importa base…**.

Una base importata resta salvata nell'app. La togli con **Rimuovi base**.
Se il file indica il livello del Municipio, quando scegli la base l'app passa da sola alla modalità di quel Municipio.

## Due modi per inserire la tua base

1. **Scrivi il file a mano** con il formato descritto qui sotto e importalo con **Importa base…**.
2. **Mandami uno screenshot** della base vista dall'alto, con l'intera mappa visibile. Io trascrivo il file e lo aggiungo in `ClashAttackLabMac/Bases`, così appare nel menu.

## Il formato

È un file di testo semplice, con un'istruzione per riga:

```
# Le righe che iniziano con # sono commenti.
nome La mia base
livello 15

townHall 20 20
xBow 14 14
torreinfernale 24 18
wall 10 10 - 33 10
```

| Riga | Significato |
| --- | --- |
| `nome …` | Nome mostrato nel menu. Se manca, si usa il nome del file. |
| `livello 15` | Livello del Municipio a cui appartiene la base, da 7 a 18. |
| `edificio colonna riga` | Un edificio, indicato dalla casella in alto a sinistra del suo ingombro. |
| `edificio c1 r1 - c2 r2` | Una linea orizzontale o verticale di pezzi da una casella: muri, bombe, trappole. |
| `rinforzi truppa numero …` | Truppe nel Castello del clan, per esempio `rinforzi dragon 2 wizard 2 archer 2`. Il numero si può omettere (vale 1). `rinforzi nessuno` lascia il Castello vuoto. |

### Rinforzi del Castello del clan

Se il file non ha la riga `rinforzi`, il Castello viene riempito come capita spesso in difesa:
fino a 2 Draghi, poi 2 Stregoni, poi Arcieri per lo spazio rimasto. Al Municipio 15 ci stanno 50 posti, cioè 2 Draghi, 2 Stregoni e 2 Arcieri.

I rinforzi escono quando una truppa attaccante arriva a 13 caselle dal Castello, uno ogni 0,4 secondi, oppure tutti insieme se il Castello viene distrutto.
Inseguono l'attaccante più vicino. Le truppe che colpiscono qualsiasi bersaglio si fermano a combatterli; Giganti, Domatori e Palloncini li ignorano.
Le truppe accettano gli stessi nomi degli edifici: chiave inglese (`dragon`, `wizard`, `archer`, `valkyrie`…) o nome italiano (`drago`, `stregone`, `arciere`, `valchiria`…).

### Coordinate

- La mappa costruibile è di **44 × 44** caselle.
- La **colonna 0** è il bordo sinistro e la **riga 0** il bordo in alto.
- Ogni edificio si indica con l'**angolo in alto a sinistra** del suo ingombro. Per esempio un Municipio 4×4 in `20 20` occupa le colonne 20–23 e le righe 20–23.

### Nomi degli edifici

Puoi usare la chiave inglese o il nome italiano dell'app, senza spazi. Maiuscole, accenti e punteggiatura non contano: `torredellarciera`, `TorreDellArciera` e `archerTower` vanno tutti bene.
Valgono anche alcune abbreviazioni: `municipio`, `muro`, `balestra`, `aquila`, `inferno`, `tesla`, `deposito`, `capanna`.

| Chiave | Ingombro | Edificio |
| --- | --- | --- |
| `townHall` | 4×4 | Municipio |
| `wall` | 1×1 | Muro |
| `cannon` | 3×3 | Cannone |
| `archerTower` | 3×3 | Torre dell'Arciera |
| `mortar` | 3×3 | Mortaio |
| `airDefense` | 3×3 | Difesa aerea |
| `wizardTower` | 3×3 | Torre dello Stregone |
| `airSweeper` | 2×2 | Spazzaria |
| `hiddenTesla` | 2×2 | Tesla Occulta |
| `bombTower` | 3×3 | Torre Bombardiera |
| `xBow` | 4×4 | Balestra |
| `infernoTower` | 2×2 | Torre Infernale |
| `eagleArtillery` | 4×4 | Artiglieria Aquila |
| `scattershot` | 3×3 | Scattershot |
| `spellTower` | 2×2 | Torre degli Incantesimi |
| `monolith` | 3×3 | Monolito |
| `builderHut` | 2×2 | Capanna del costruttore |
| `clanCastle` | 3×3 | Castello del clan |
| `goldStorage`, `elixirStorage`, `darkElixirStorage` | 3×3 | Depositi |
| `goldMine`, `elixirCollector`, `darkElixirDrill` | 3×3 | Estrattori |
| `armyCamp`, `heroHall`, `workshop` | 4×4 | Campo militare, Sala degli eroi, Officina |
| `barracks`, `darkBarracks`, `laboratory`, `spellFactory`, `darkSpellFactory`, `blacksmith`, `petHouse`, `helperHut` | 3×3 | Edifici dell'esercito |
| `bomb`, `springTrap`, `airBomb`, `seekingAirMine` | 1×1 | Trappole |
| `giantBomb` | 2×2 | Bomba gigante |

## Controlli all'importazione

- **Errori**, che bloccano l'importazione:
  - una riga che non si capisce (ti indico il numero di riga);
  - edifici fuori dalla mappa o sovrapposti;
  - un numero di Municipi diverso da uno;
  - una truppa al posto di un edificio.
- **Avvisi**, che non bloccano l'importazione: più copie di un edificio di quante ne permetta il Municipio indicato, oppure rinforzi che occupano più posti di quanti ne contenga il Castello.
- Un eroe, o una truppa che nasce solo in battaglia (Cucciolo lavico, Golemita), nella riga `rinforzi` è un errore.

Un esempio completo del Municipio 15 è in `ClashAttackLabMac/Bases/esempio-municipio-15.txt`.
