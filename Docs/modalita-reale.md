# Cosa simula la modalità Reale

La modalità **Reale** usa i dati del gioco (pacchetto `clash-of-clans-data` 0.18.0) al livello massimo sbloccato dal Municipio scelto, da 7 a 18.
Questa pagina elenca cosa viene simulato e quali valori sono stime, cioè numeri che i dati non riportano.

## Campo di battaglia

- **Mappa:** 44 × 44 caselle costruibili, più un bordo di 3 caselle dove schierare. La battaglia dura 3 minuti.
- **Ostacoli:** muri ed edifici bloccano il passaggio. Le truppe di terra li aggirano, oppure abbattono i muri quando conviene.
- **Basi:** tre basi generate per ogni Municipio, quelle incluse nell'app e quelle importate (vedi [importare una base](importare-una-base.md)).

## Difese e trappole

- **Valori reali:** danni, punti vita, gittate, raffiche, zone cieche e raggi di attivazione vengono dai dati del gioco.
- **Difese del TH15 e trappole:** Balestra, Artiglieria Aquila (si sveglia dopo un certo numero di truppe schierate), Scattershot, Torre degli Incantesimi, Monolito, bombe, trappole a molla, mine aeree. Dal Municipio 14 anche le Capanne del costruttore armate.
- **Castello del clan:**
  - si apre quando un attaccante arriva a 13 caselle; i rinforzi escono uno ogni 0,4 s, tutti insieme se il Castello cade;
  - se la base non indica la riga `rinforzi`, il Castello contiene fino a 2 Draghi, poi 2 Stregoni, poi Arcieri per lo spazio rimasto. Al TH15 sono 50 posti;
  - i rinforzi inseguono l'attaccante più vicino. Le truppe che attaccano qualsiasi bersaglio si fermano a combatterli; Giganti, Domatori e Palloncini li ignorano.

## Truppe

- **Truppe:**
  - tutte le truppe fino al TH15;
  - i Golemiti, rilasciati dal Golem quando muore;
  - i Cuccioli lavici, rilasciati dal Segugio lavico quando muore;
  - gli Scheletri e i Pipistrelli evocati dagli incantesimi.
- **Abilità speciali:**
  - Minatori sottoterra;
  - catena dell'Elettrodrago;
  - Cavalcaradici che passano sui muri;
  - Segugio che punta le Difese aeree.
- **Eroi:**
  - Re, Regina, Gran Sorvegliante e Campionessa;
  - l'aura del Sorvegliante riduce del 20% il danno subito dalle truppe vicine.

### Equipaggiamento degli eroi

Ogni eroe porta due pezzi, al livello massimo del Fabbro per il Municipio: al TH15 i comuni arrivano al 18 e gli epici al 24.
Li scegli con il pulsante **Equipaggiamento**. **Trova attacco → Confronta equipaggiamento eroi** prova tutte le coppie sulla base attuale e propone le migliori.

| Eroe | Pezzi disponibili | Predefiniti |
| --- | --- | --- |
| Re barbaro | Fiala della furia, Guanto gigante, Palla chiodata, Vampibaffi | Guanto gigante + Palla chiodata |
| Regina degli arcieri | Freccia gigante, Freccia congelante, Fiala dell'invisibilità | Freccia gigante + Freccia congelante |
| Gran Sorvegliante | Tomo eterno, Palla di fuoco, Gemma della furia, Tomo curativo | Tomo eterno + Palla di fuoco |
| Campionessa reale | Scudo cercatore, Lancia razzo, Stivali elettrici, Gemma reale, Fiala della velocità | Lancia razzo + Stivali elettrici |

## Incantesimi

- **Disponibili:** Cura, Furia, Gelo, Fulmine, Terremoto, Salto, Invisibilità, Velocità, Veleno, Rampicante, Blocco di ghiaccio, Scheletri, Pipistrelli.
- **Su chi agiscono:**
  - il Veleno colpisce e rallenta solo i rinforzi del Castello;
  - il Gelo ferma anche i rinforzi;
  - il Rampicante ferma le difese e nasconde gli edifici;
  - il Blocco di ghiaccio protegge le truppe ma le tiene ferme.
- **Esercito predefinito:** nelle armate reali predefinite c'è sempre un Veleno, che i piani lanciano sul Castello del clan.

## Valori stimati

Questi numeri non sono nei dati e sono stati scelti a mano:

| Cosa | Valore |
| --- | --- |
| Intervallo di uscita dei rinforzi | 0,4 s |
| Distanza a cui le truppe ingaggiano i rinforzi | gittata + 4 caselle |
| Crescita del danno del Veleno | lineare in 4 s |
| Riduzione del danno dell'aura del Sorvegliante | 20% |
| Raggio del Tomo eterno | 7 caselle |
| Portata della Palla chiodata, dello Scudo cercatore, della Palla di fuoco | 6, 9 e 8 caselle |
| Bersagli della Freccia gigante | 3 entro 12 caselle |
| Raggio del Tomo curativo | 5 caselle |

Altre semplificazioni:
- i rinforzi del Castello camminano dritti, senza aggirare i muri;
- le abilità degli eroi partono quando la loro salute scende sotto una soglia, oppure al momento scelto nel piano;
- i pezzi attivi dello stesso eroe partono insieme.

## Non ancora simulati

- **Truppe:** Mini Yeti (mancano i dati), animali, truppe super, macchine d'assedio oltre a Ariete e Schiantapietre.
- **Incantesimi:** Richiamo, Rianimazione, Totem, Clonazione, Rabbia (Angry Spell).
- **Equipaggiamenti:** quelli che evocano truppe (marionette, Specchio magico) e alcuni pezzi recenti.
