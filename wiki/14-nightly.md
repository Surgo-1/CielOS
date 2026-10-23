# Nightly: il nuovo comparto grafico

La **Nightly** è la CielOS che cambia faccia: un altro comparto grafico sullo stesso sistema nervoso. Non è un tema
della shell stabile e non la sostituisce: è un'altra configurazione di Quickshell (`ciel-nightly`), con i suoi tasti,
i suoi pannelli e la sua cartella. La stabile resta com'è, e si può avere l'una accanto all'altra.

## Cosa c'è dentro

- **Barra a capsula**: galleggia in cima allo schermo, vetro quasi nero con un filo di luce ciano. A sinistra il segno
  di Ciel e i workspace, al centro l'ora in monospaziato, a destra volume, rete, batteria e il centro di controllo.
- **Lanciatore** (`Super+Spazio`): vetro al centro, ricerca delle app, frecce e Invio, Esc per chiudere.
- **Centro di controllo**: volume, luminosità, Wi-Fi, IA di Ciel accesa/spenta, e le scorciatoie a sessione,
  terminale e impostazioni.
- **Sessione**: blocca, sospendi, esci, riavvia, spegni.
- **Sfondo**: il vuoto di CielOS con una griglia appena visibile (o la tua immagine, se ne hai scelta una).

Gli angoli a mirino, il maiuscoletto spaziato e i fili di luce sono il linguaggio: **HUD olografico** per la struttura,
**vetro e neon** per le superfici. Niente sfocature, niente animazioni infinite: la GPU resta tua.

## Provarla

Nel repository:

```sh
ciel-nightly             # la apre accanto alla stabile
```

Installata come pacchetto (convive con `cielos`):

```sh
sudo pacman -S cielos-nightly
ciel-nightly
```

All'accesso, al posto della stabile:

```sh
mkdir -p ~/.config/cielos-nightly && touch ~/.config/cielos-nightly/attiva
systemctl --user start ciel-nightly
```

Per tornare indietro: `systemctl --user stop ciel-nightly` e togli il file `attiva`.

## Cosa manca (è una beta, e si vede)

- Notifiche e OSD (volume/luminosità a schermo): per ora restano quelli della stabile, o niente.
- Le impostazioni: il centro di controllo apre `cielos-tui impostazioni` nel terminale (che c'è, ed è completo).
- Blocco schermo: usa `loginctl lock-session` (lo schermo di blocco è quello della stabile).
- Tastiera: solo lanciatore e sessione hanno i tasti; i workspace si cambiano con Hyprland.

Quello che c'è è provato: `python3 prove/test_nightly.py` avvia davvero la shell e pretende che non ci siano errori
QML, e controlla che il pacchetto non tocchi niente della stabile.

## Com'è fatta (per chi la modifica)

```
shell-nightly/
  shell.qml            Sfondo, Barra, Lanciatore, Centro, Sessione
  servizi/             Tema (palette HUD), Percorsi, Lingua, Pannelli (stato), Avvia
  moduli/              i cinque pezzi che si vedono
  componenti/          Hud (vetro + angoli), Icona
```

I comandi sono quelli di CielOS (`cieltema`, `cielrete`, `cielplugin`, `cielmodelli`, `ciel-apri`): la Nightly non
reimplementa niente, cambia solo come si vede e come si tocca.
