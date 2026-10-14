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
Registro: `~/.local/state/cielos/installa.log`.

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
