# CielOS

Una distro basata su Arch costruita intorno a Ciel (l'assistente in `~/assistente-vocale`): l'IA è il modo in cui il
PC funziona, non un'app installata sopra. Leggerissima di base. Il progetto completo: [MAPPA.md](MAPPA.md).

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
