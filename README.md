# CielOS

Una distro basata su Arch costruita intorno a Ciel (l'assistente in `~/assistente-vocale`): l'IA è il modo in cui il
PC funziona, non un'app installata sopra. Leggerissima di base. Il progetto completo: [MAPPA.md](MAPPA.md).

## Installare CielOS (su un'Arch Linux minima)

Serve un'Arch appena installata con un utente, `sudo` e la rete (va bene anche `archinstall` con il profilo
«minimal»; meglio con la radice su btrfs: così ci sono le istantanee e il ritorno indietro dopo gli aggiornamenti).

    git clone <questo repository> ~/cielos
    ~/cielos/installa.sh --prova      # dice cosa farebbe
    ~/cielos/installa.sh              # lo fa (sudo te lo chiede lui)

Mette: Hyprland con la shell Ciel, login a tema, terminale (foot + fish + starship), CielFox, Ciel Codice, il riquadro
dei modelli, cield, il guardiano (password ogni volta, aggiornamenti a ondate, ritorno indietro automatico), i driver
della scheda video. Nessun modello di IA e niente Ollama: si scelgono dal riquadro (Super+A) se e quando si vuole.
Si può rilanciare: rifà solo quello che manca; i file che sostituisce restano accanto con «.prima-di-cielos».
Registro: `~/.local/state/cielos/installa.log`. Mette anche nome e logo (os-release, menu di avvio, schermata
d'avvio Plymouth: `sistema/identita/`, si toglie con `sudo /usr/lib/cielos/identita.sh togli`).

Alla fine propone **Ciel, l'assistente** (`installa-ciel.sh`, anche dopo): di serie senza voce, risponde nella
**casella di testo** sullo schermo (Super+J, o Super+Spazio) dove le scrivi; nessun microfono aperto, nessun modello
audio (~340 MB di librerie). La voce è un'opzione: `installa-ciel.sh --voce paola` (o `sara`). Nessuna mente di serie:
senza, Ciel fa i comandi e spiega come sceglierne una (Super+A → «Usa per Ciel»).

**Grafica**: tre livelli nelle Impostazioni (Aspetto → grafica): leggerissima, bilanciata (di serie: animazioni
brevi, ombre leggere, pannelli sfocati) e bella; sfondi disegnati da CielOS (Notte di serie, Alba, Aurora).

Consumi misurati il 14/10 nella VM (4 core, 6 GB, grafica software), a riposo con Ciel accesa senza voce né mente:
CPU 0,2% in tutto, ~1,1 GB di RAM usata dall'intero sistema. Sul PC vero: shell Ciel ~150 MB più ~25 MB per schermo
con lo sfondo, Hyprland ~75 MB, cield ~15 MB, Ciel senza voce ~95 MB.

## Cosa c'è già

**cield** — il sistema nervoso: raccoglie gli eventi del PC (finestre, giochi, notifiche, dispositivi, dischi,
audio, rete, errori, pacchetti, orario) e fa girare le automazioni, senza IA. Le fonti si accendono solo quando
servono: a riposo ~26 MB e nessun processo in più.

    cielctl eventi "gioco.*"      # guarda gli eventi
    cielctl regole                # le automazioni in italiano
    cielctl prova FILE.toml       # controlla una regola
    cielctl aggiungi FILE.toml

Le automazioni stanno in `~/.config/cielos/automazioni/*.toml` (formato: `cield/regole.py`, esempi in
`automazioni/esempi/`). A Ciel basta dirle «crea un'automazione: quando…»: scrive la regola, te la descrive, la salva
solo se dici di sì.

## Installazione (sul sistema attuale, solo utente)

    ln -sf ~/cielos/sistema/cield.service ~/.config/systemd/user/
    ln -sf ~/cielos/bin/cielctl ~/.local/bin/
    systemctl --user daemon-reload && systemctl --user enable --now cield

**shell** — la shell di CielOS (Quickshell): barra, lanciatore che è anche Ciel, notifiche, volume, menu di
spegnimento, blocco a tema Ciel, avatar di Ciel nello stesso processo. ~155 MB (caelestia ~465). Si sceglie al volo:

    ciel-shell-scegli ciel           # usa Ciel, la shell di CielOS
    ciel-shell-scegli caelestia      # torna indietro

Tasti con la shell di CielOS: Super (da solo) o Super+Spazio = lanciatore e Ciel, Super+L = blocco,
Ctrl+Alt+Canc = spegnimento, Super+Maiusc+S = una zona dello schermo negli appunti.
L'aspetto si cambia in `~/.config/cielos/tema.json` (es. `{"oro": "#7fd0ff", "barra": 52}`), e si vede subito.
