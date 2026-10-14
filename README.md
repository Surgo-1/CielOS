# CielOS

Una distro basata su Arch costruita intorno a Ciel (l'assistente in `~/assistente-vocale`): l'IA è il modo in cui il
PC funziona, non un'app installata sopra. Leggerissima di base. Il progetto completo: [MAPPA.md](MAPPA.md).

## La ISO e l'installatore

    sudo iso/costruisci.sh pacchetti/repo        (dopo pacchetti/costruisci.sh; su Arch, con archiso)

La chiavetta parte nella sessione live di CielOS e apre **Installa CielOS**: disco (intero), utente, lingua e
tastiera, fuso orario, Ciel sì/no, riepilogo con conferma, poi fa tutto da sola (`cielos-installa-sistema`):
GPT con BIOS boot + EFI + btrfs (@, @home), Limine che parte in UEFI e in BIOS, **solo i driver e il firmware di
quel PC** (`cielos-hardware`), CielOS come pacchetto, login, rete, firewall, istantanee, aggiornamenti a ondate,
logo all'avvio. CielOS è un pacchetto (`pacchetti/`): i file in /usr/share/cielos, i comandi in /usr/bin, la
sessione «CielOS» nel login. In sviluppo resta tutto in ~/cielos (CIELOS_DIR).

## Pubblicare un aggiornamento

    git commit …                       (nel pacchetto va solo l'ultimo commit)
    pacchetti/pubblica.sh              costruisce, firma e carica su github.com/Surgo-1/cielos-pacchetti

I PC con CielOS leggono il repository `[cielos]` da lì (`/etc/pacman.d/cielos-mirrorlist`) e accettano **solo pacchetti firmati** con la chiave di CielOS: l'aggiornamento arriva con la
prossima ondata (Ciel: «aggiorna»; `cielondate controlla` lo mostra). La prima volta: `sudo pacman -S github-cli`,
`gh auth login`. **Pubblica prima di dare una ISO a qualcuno**: se online non c'è niente, il suo `pacman -Syu` si
ferma. La chiave segreta sta in `~/.local/share/cielos/firma`: **fanne una copia** (senza, i PC già
installati non accettano più aggiornamenti; con lei, chiunque potrebbe firmare al posto tuo). La pubblica è in
`sistema/repo/`; l'indirizzo si cambia con `pacchetti/pubblica.sh dove UTENTE/REPO` (vale per le ISO nuove e,
con un aggiornamento, anche per i PC già installati).

## Cosa c'è in CielOS

- **Medico** (`cielmedico`, Impostazioni → Medico, a Ciel «come sta il PC?» / «ripara il PC»): visita il PC
  (kernel, servizi, dischi, driver, scheda video, memoria, temperature, audio, rete, ora, firewall, istantanee, SSD,
  aggiornamenti, file .pacnew) e per ogni cosa che non va propone il rimedio; ripara (quello di sistema con la tua
  password, dal guardiano) e ricontrolla. Ogni giorno una visita in silenzio: notifica solo se c'è qualcosa di nuovo.
- **Giochi e prestazioni**: modalità gioco di serie (mentre giochi profilo prestazioni, niente notifiche, grafica
  del desktop leggera; poi torna tutto com'era), VRR nei giochi a schermo intero, latenza minima (tearing solo per
  i giochi che lo chiedono), ntsync per Wine/Proton, cache degli shader da 10 GB, zram e systemd-oomd (se la
  memoria finisce si chiude un programma, il PC non si blocca), AUR compilato con tutti i core.
- **Hardware**: `cielos-hardware` guarda il PC (scheda video Intel/AMD/NVIDIA, processore, audio, rete,
  bluetooth, impronte, macchina virtuale) e propone solo quello che serve; controller (Xbox, PlayStation,
  Nintendo, Steam, 8BitDo…) pronti con le regole udev; PipeWire per tutto (Pulse, JACK, ALSA).
- **Impostazioni** (Super+I): aspetto e grafica (tre livelli), finestre, **schermi** (risoluzione, frequenza, scala,
  rotazione, posizione, specchio, VRR/FreeSync, 10 bit, HDR, con ritorno automatico in 15 s), **tastiera e mouse**,
  **audio** (dispositivi e programmi), **energia e ora**, scorciatoie, automazioni, **plugin**, **hardware**, sistema,
  **avanzate** (qualsiasi opzione di Hyprland). Il motore è `cielimposta`.
- **Monitor di sistema** (`ciel-monitor`): ogni core con uso, frequenza e temperatura, memoria, scheda video,
  rete, dischi, processi, tutti i sensori; quelli che scegli compaiono nella barra.
- **File** (`ciel-file`, Super+E), il file manager sul modello di Dolphin: schede, vista divisa (F3), griglia con
  anteprime e dettagli, luoghi e segnalibri, dischi e chiavette, cestino, ricerca anche nelle sottocartelle,
  taglia/copia/incolla e trascinamento, rinomina (F2), comprimi/estrai, apri con, proprietà, terminale qui (F4).
- **Schermate** (`cielos-schermata`): Stamp per scegliere l'area col mouse (un clic prende una finestra, Esc annulla),
  Shift+Stamp tutto lo schermo, Ctrl+Stamp la finestra attiva; in Immagini/Schermate e negli appunti.
- **Install** (Super+A → Install, `cielplugin`), come Shelly: cerca insieme nei repository di Arch, nell'AUR (anche le varianti -git e -bin) e su Flathub, e scegli la variante e la versione (per Arch anche le vecchie, dall'archivio); «Rimuovi» trova tutto quello che è installato e contiene certe lettere e lo toglie (mai i pacchetti vitali); «Aggiorna tutto» aggiorna sistema (con le ondate), AUR e Flatpak. «Consigliati» è il catalogo dei plugin, come il menu Installa di Omarchy: giochi (Steam, GameMode,
  MangoHud, Gamescope, Lutris…), sviluppo, web app, programmi da terminale, servizi (Tailscale, Syncthing, SSH,
  stampanti…), comunicazione, grafica, ufficio. Hook in ~/.config/cielos/hooks/{tema,accesso,plugin}/.

## Lingua

CielOS è in italiano e in inglese: segue la lingua del sistema (LANG), oppure la scelta in Impostazioni → Sistema (`cielimposta lingua en`). Le frasi stanno in `lingua/en.json`, con la frase italiana come chiave: per tradurre una scritta nuova basta scriverla in italiano dentro `Lingua.t("…")` (QML) o `tr("…")` (Python) e aggiungerla al dizionario. Il catalogo dei plugin ha le sue traduzioni in `plugin/catalogo.en.json`.

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
Super+Esc = spegnimento, Super+Maiusc+S = una zona dello schermo negli appunti.
L'aspetto si cambia in `~/.config/cielos/tema.json` (es. `{"oro": "#7fd0ff", "barra": 52}`), e si vede subito.
