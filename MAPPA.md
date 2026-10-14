# CielOS — la mappa

Una distro basata su Arch, costruita intorno a Ciel: l'IA non è un'app installata sopra, è il modo in cui il PC
funziona. Stile Omarchy (un sistema di configurazione e installazione sopra Arch puro, pacchetti dai repository
normali), ma con l'IA nel cuore del sistema.

Stato: **progetto** (13/10/2026). Niente è ancora installato come CielOS; diversi pezzi esistono già dentro Ciel
(segnati con ✅) e diventeranno parte della distro.

---

## 0. Principi (valgono per ogni pezzo)

1. **Leggerissima di base.** Il sistema a riposo deve occupare il meno possibile: RAM, VRAM, CPU e disco sono
   dell'utente, che li dà a chi vuole (giochi, modelli, lavoro). Ogni pezzo ha un budget (sezione 1) e si misura.
   Niente animazioni continue, niente processi che girano a vuoto, niente sondaggi a intervalli dove esiste un evento.
2. **L'IA crea, il sistema esegue.** Il modello scrive regole, configurazioni e automazioni una volta (tu le vedi e
   le approvi); poi girano come programmi normali, senza IA: deterministiche, istantanee, gratis. Il modello si
   carica solo quando serve davvero pensare.
3. **Ciel non è mai amministratrice.** Le azioni di sistema passano da un guardiano separato con un elenco fisso
   di azioni; la conferma la dai tu in una finestra che Ciel non può cliccare né imitare.
4. **Tutto in locale.** Niente cloud, niente account, niente telemetria. La privacy è una regola del sistema
   (incognito invisibile, password mai lette né salvate).
5. **Tutto si annulla.** Istantanee btrfs prima di ogni cambiamento di sistema; ogni modifica di configurazione ha il
   suo «torna come prima».
6. **A strati.** Ogni strato funziona da solo e serve subito, anche sul PC attuale prima che CielOS esista.
7. **Si adatta all'hardware.** L'installatore misura RAM, VRAM e CPU e sceglie modelli e impostazioni adatti.

---

## 1. Budget di leggerezza

Misurato sul PC di adesso (CachyOS + caelestia + Ciel, i5-10400F, 32 GB, GTX 1650 4 GB, nessuna grafica
integrata: anche il desktop usa la scheda NVIDIA).

| A riposo (senza modelli) | Oggi | Obiettivo CielOS |
|---|---|---|
| RAM del desktop (compositor, shell, avatar, sfondo, audio) | ~2,2 GB | **< 700 MB** |
| VRAM del desktop | ~1,1 GB (sfondo animato 133 MB, app Electron ~170 MB) | **< 400 MB** |
| CPU a riposo | processi che controllano a intervalli (in parte già tolti, hypr.py) | **~0%**: solo eventi |
| Processi in background | decine | pochi, tutti nella fetta `ciel.slice` |
| Avvio fino al desktop | — | da misurare, poi tagliare |

Dove si guadagna: una sola shell Quickshell per barra + avatar + blocco (oggi sono due istanze: caelestia 670 MB
+ avatar 500 MB), sfondo animato solo su richiesta, niente servizi inutili di serie, modelli caricati solo quando
servono e scaricati quando giochi.

---

## 2. Le parti

### 2.1 Sistema nervoso (bus degli eventi) — ✅ prima versione (cield, 13/10)
Un unico canale dove ogni parte del PC dice cosa succede, subito, senza che nessuno debba chiedere.
- Fonti: finestre e workspace (socket di Hyprland ✅ in parte), notifiche e app (D-Bus ✅ notifiche), dispositivi
  (udev), errori (journald), pacchetti (hook di pacman), rete, audio (cuffie, microfono), giochi, batteria, sonno.
- Un demone leggero (`cield`) li raccoglie e li pubblica; Ciel, le automazioni e la barra si iscrivono.
- Sostituisce tutti i controlli a intervalli rimasti.

### 2.2 Automazioni — ✅ prima versione (cield + strumento «automazione» di Ciel, 13/10)
- Le scrivi a parole («quando apro un gioco: profilo prestazioni, notifiche silenziose, Ciel in silenzio»); il
  modello le traduce in una regola leggibile (evento → condizioni → azioni), te la mostra, tu approvi.
- Il motore delle regole gira senza IA. Le azioni sono un catalogo fisso (finestre, audio, app, profili, notifiche,
  file, comandi approvati); quelle di sistema passano dal guardiano (2.3).
- Ciel propone automazioni dalle tue abitudini ✅ (abitudini.py fa già «la solita serata?»).
- Elenco, pausa, modifica e cancellazione a voce e da un pannello.

### 2.3 Guardiano (sicurezza)
- Un piccolo servizio di sistema, separato da Ciel, con un elenco chiuso di azioni da amministratore: aggiornare,
  installare/togliere pacchetti, montare dischi, gestire servizi, rete, energia.
- Ciel chiede, il guardiano mostra la **sua** finestra di conferma (con cosa succede, in chiaro); solo un tuo clic
  o la tua password la sbloccano. Ciel non può cliccarla, non può scriverci, non può imitarla.
- Registro di ogni azione; tutto quello che cambia il sistema passa da un'istantanea prima.
- Da progettare con cura: è il punto delicato di tutta la distro.

### 2.4 Configurazione unica e personalizzazione
- Un solo file (o cartella) strutturato con tutto l'aspetto e il comportamento: colori, bordi, barra, animazioni,
  scorciatoie, sfondi, suoni, font, comportamento di Ciel.
- Ciel lo modifica a voce («bordi più tondi», «tema dal mio sfondo», «barra in alto»): validazione prima di
  applicare, anteprima, annulla. Temi generati dallo sfondo o da una descrizione.
- Da qui si generano le configurazioni dei programmi (Hyprland, Quickshell, terminale, GTK/Qt, SDDM, limine).

### 2.5 Il desktop è Ciel (shell) — 🟡 prima versione in `shell/` (13/10): ~155 MB contro i ~465 di caelestia
- Una sola istanza Quickshell: barra ✅, lanciatore = Ciel (Super+Spazio ✅), palette dei comandi, centro notifiche
  con riassunti, impostazioni, blocco ✅, avatar ✅, sottotitoli ✅, traduzioni sullo schermo ✅.
- Login SDDM a tema ✅ (sistema/sddm-ciel, da installare).
- Tutto leggero: animazioni solo quando succede qualcosa.

### 2.6 Memoria del PC
- Indice locale dei tuoi file per significato ✅ (archivista, solo documenti) → esteso a progetti, immagini (per
  nome, data, luogo), cronologia delle app ✅ (cronista), appunti ✅.
- Regole di privacy fisse ✅ (privato.py): incognito escluso, password mai, cartelle escluse a scelta.
- L'indicizzazione gira solo a PC libero ✅ (officina).

### 2.7 Manutenzione da sola
- Aggiornamenti a ondate: repository di Arch fermati a una data già provata (Arch Linux Archive), che avanza solo
  dopo i controlli; Ciel legge le notizie di archlinux.org prima di avanzare.
- Istantanea prima, verifica dopo, ritorno indietro automatico se il desktop non parte.
- Kernel LTS e driver NVIDIA fissati, aggiornati a parte.
- Salute del PC ✅ (sentinella, custode, errori spiegati ✅), sicurezza ✅ (guardiana).

### 2.8 Gestore dei modelli
- **Nessun modello installato di serie (14/10):** tutto deve funzionare e spiegarsi anche a zero modelli; il riquadro (Super+A) cerca, stima, scarica, accende/spegne, elimina.
- Sceglie i modelli in base all'hardware (VRAM, RAM, CPU) e li scambia da solo: mente veloce, mente del codice ✅
  (alternanza), visione, voce, embedding.
- Divide la GPU tra giochi e modelli ✅ (vram.py) e cede la CPU ✅ (priorità).
- llama.cpp compilato per la CPU della macchina (AVX2 qui), memoria e kernel regolati per i modelli MoE.
- Allenamento leggero dei modelli piccoli di notte ✅ (officina) → esteso dove l'hardware lo permette (sezione 4).

### 2.9 Installatore e identità
- Installazione stile Omarchy su Arch puro: un comando porta da Arch minimo a CielOS completo.
- Rileva l'hardware e sceglie le impostazioni; **nessun modello di serie** (deciso 14/10): li scarica l'utente se e quando vuole (riquadro Super+A), con la stima per il suo PC; importa (o rifà) la tua configurazione: è anche il backup.
- Nome e logo ovunque: menu di avvio (limine) ✅, schermata di avvio ✅, login ✅, `fastfetch` ✅, os-release ✅.
- Prove in macchina virtuale prima di toccare un PC vero.

---

### 2.10 Il meglio delle altre distro (richiesta del 14/10)
Prendere da ognuna la cosa per cui è famosa, ma alla maniera di CielOS: leggera, accesa solo quando serve.

| Da | Cosa | In CielOS |
|---|---|---|
| **Bazzite / SteamOS / Nobara** | Il gaming pronto: Steam, Proton aggiornato, gamescope (sessione «console» e HDR/VRR), MangoHud, gamemode, controller (Xbox, PlayStation, 8BitDo), driver NVIDIA giusti, Decky | Pacchetti scelti dall'installatore + **modalità gioco** di cield (`gioco.inizio`): profilo prestazioni, non disturbare, Ciel libera la VRAM (4 GB!), indicizzazione in pausa, sfondo animato fermo; tutto torna com'era a `gioco.fine`. Avvio diretto in Steam Big Picture come scelta al login |
| **CachyOS** | Kernel e pacchetti ottimizzati (x86-64-v3, BORE, sched-ext), ananicy | Kernel e pacchetti CachyOS sopra Arch (deciso 14/10, §5) |
| **openSUSE Tumbleweed / Fedora Atomic** | Aggiornamenti provati prima di arrivarti, ritorno indietro sicuro | Fase 5: ondate + istantanee avviabili (già ci sono snapper e Limine) |
| **Pop!_OS / Mint** | Funziona subito: driver, codec, firmware; gestore dei driver semplice | L'installatore riconosce l'hardware e mette i driver giusti; Ciel spiega cosa ha messo |
| **Omarchy** | Hyprland pronto, tutto da tastiera, temi in un colpo | Già: shell Ciel, scorciatoie e temi in `cieltema` |
| **NixOS** | Il sistema descritto in un file, riproducibile | Una «ricetta» di CielOS (pacchetti + cielos.json + automazioni) per rifare il tuo PC identico |
| **Tails / Qubes** (lo spirito) | Privacy | Già: Ciel non guarda le finestre private, niente cloud |

## 3. Ordine dei lavori

| Fase | Cosa | Dove si prova | Tocca il sistema? |
|---|---|---|---|
| **1** | Sistema nervoso (`cield`) + motore delle automazioni — ✅ fatto; resta: i controlli a intervalli di Ciel (avvisi, vram, abitudini, autonomia) passano agli eventi di cield | sul PC di adesso | no (utente) |
| **2** | Shell unica e leggera — ✅ barra, lanciatore = Ciel, notifiche, volume, sessione, blocco, avatar dentro; si usa con `ciel-shell-scegli ciel` (indietro: `… caelestia`). La shell si chiama **Ciel**: scritta da noi su Quickshell (il motore, lo stesso di caelestia). Fatti anche: schedine col mouse sopra su ogni icona, menu del vassoio, centro notifiche (Super+N). Fatti anche: musica (MPRIS), sistema (CPU, RAM, GPU, temperature, letti solo a schedina aperta), luminosità per monitor via DDC/CI (ddcutil, senza permessi in più: ACL della sessione). Di base: tema scuro, nessuno sfondo (solo il colore di fondo, disegnato dalla shell); l'utente sceglie poi sfondo, terminale (di serie foot) e modo chiaro/scuro nelle Impostazioni | sul PC di adesso | no |
| **3** | Configurazione unica + personalizzazione — ✅ `cieltema`: le scelte in ~/.config/cielos/cielos.json → tema della shell, scorciatoie e finestre di Hyprland (hypr-ciel.lua), login (sddm.conf, portato da installa.sh), app GTK e terminale foot (tema_app); temi pronti, colori dallo sfondo, annulla (30 passi); barra a sinistra/destra/in alto/in basso; suono delle notifiche. A voce: lo strumento «aspetto» di Ciel (anteprima, poi «ti piace?»). A mano: le Impostazioni (Super+I, la schedina di Ciel, «Impostazioni di Ciel» nel lanciatore), nate dallo schema di cieltema, con le automazioni (pausa, prova, modifica, togli, nuova). Restano fuori: le app Qt (kdeglobals) | sul PC di adesso | no |
| **4** | Guardiano — ✅ progetto (guardiano/PROGETTO.md, decisioni prese 14/10), codice, test senza root, e prova vera in VM (prove/: Arch in QEMU, polkit e pacman veri): password giusta/sbagliata/annullata, vietate, sessione remota rifiutata, istantanee prima/dopo, registro, timeout di 5 minuti se nessuno risponde. Finestra della password nella shell Ciel; strumento «amministra» di Ciel. Sul PC vero lo installi tu: `sudo ~/cielos/guardiano/sistema/installa.sh` | macchina virtuale ✅ | sì (lo installi tu) |
| **5** | Aggiornamenti a ondate + ritorno indietro automatico — ✅ codice e prova nella VM senza Internet (guardiano/PROGETTO.md §7: controlli prima e dopo, file d'avvio salvati, controllo dell'avvio, ritorno automatico e a mano, Ciel avvisa); provata anche con un'ondata vera dell'Arch Linux Archive (kernel 7.2.7 → 7.2.9: initramfs, avvio confermato) | macchina virtuale ✅ | sì (reinstalli tu il guardiano) |
| **6** | Gestore dei modelli per hardware diversi — ✅ cielmodelli: schede NVIDIA/AMD/Intel lette dal sistema, quella che Ollama usa davvero (dal suo registro), consiglio se non la usa (ollama-cuda/rocm/vulkan), RAM con la velocità misurata, riserva di RAM in proporzione, AVX2; «motore»: Ollama mancante/spento detto chiaro (niente di serie); prove con 6 PC finti e nella VM senza scheda video (prove/test_cielmodelli.py) | PC di adesso + VM ✅ | no |
| **7** | Installatore CielOS su Arch puro — ✅ `installa.sh` (README): pacchetti ufficiali (538 MB), driver per la scheda video, file dell'utente, Hyprland di CielOS (`hypr/hyprland.lua`, stesse scorciatoie di caelestia), guardiano e ondate, login a tema, firewall; si rilancia senza danni; `--prova`. Provato da zero nella VM: login, desktop, terminale, riquadro, CielFox. Resta: Ciel (l'assistente vocale) come passo a parte | macchina virtuale ✅ | — |
| **8** | Identità: nome, logo, avvio — ✅ `sistema/identita/`: os-release CielOS (con hook di pacman), menu di avvio con sfondo e nome (Limine provato in QEMU, GRUB nella VM, systemd-boot), schermata d'avvio Plymouth «cielos» (logo e stelline, password del disco), login testuale; grafica a tre livelli e sfondi; Ciel come passo facoltativo dell'installatore, senza voce di serie (casella di testo) | macchina virtuale ✅ | sì |
| **8b** | Distro vera — pacchetti (`pacchetti/`), sessione CielOS, `cielos-hardware` (solo i driver del PC), Impostazioni di sistema (schermi con VRR/HDR, input, audio, energia, avanzate), monitor di sistema e sensori nella barra, File (il file manager), plugin e hook (come Omarchy), ISO con installatore grafico (`iso/`) | VM + QEMU | — |
| **8c** | Il PC che si prende cura di sé — aggiornamenti online firmati (`pacchetti/pubblica.sh`, github.com/Surgo-1/cielos-pacchetti), il medico (`cielmedico`: visita, ripara, avvisa), modalità gioco di serie, VRR/tearing nei giochi, zram, systemd-oomd, ntsync, cache degli shader | VM + QEMU ✅ | — |
| **8e** | Install (Super+A), come Shelly — un posto solo per i programmi: Arch, AUR (-git, -bin) e Flathub insieme, la versione la scegli tu (anche le vecchie dall'archivio di Arch), Rimuovi per lettere (i pacchetti vitali bloccati), Aggiorna tutto (ondate + AUR + Flatpak), Consigliati (il catalogo dei plugin, tolto dalle Impostazioni) | PC ✅ | — |
| **8d** | Inglese — tutta CielOS in due lingue (`lingua/`): la shell (`Lingua.t("…")`, singleton `shell/servizi/Lingua.qml`), le app (File, Monitor, Codice, installatore), i comandi in Python (`tr()` di `lingua/lingua.py`) e bash (`lingua/lingua.sh`), il guardiano (frasi della password), il login (SDDM), il saluto del terminale, il catalogo dei plugin (`plugin/catalogo.en.json`). La chiave è la frase italiana, la traduzione in `lingua/en.json`; quello che manca resta in italiano. La lingua: Impostazioni → Sistema (`cielimposta lingua it|en`), se no quella del sistema (LANG); l'installatore la sceglie nella prima pagina. Resta in italiano: Ciel (voce e mente) e CielFox | QEMU + PC ✅ | — |
| **9** | Installazione vera (da zero, dopo un backup) | il tuo PC | quando decidi tu |

---

## 4. Modelli e allenamento: cosa si può e cosa no

- **La distro libera risorse ma non le crea.** Il limite resta l'hardware: 4 GB di VRAM, 32 GB di RAM, banda della
  memoria. Una base leggera dà più VRAM e RAM ai modelli (circa +0,7 GB di VRAM e +1,5 GB di RAM rispetto ad
  adesso), quindi più strati sulla GPU e prompt più veloci, ma non un salto di categoria.
- **Modelli enormi (es. DeepSeek, centinaia di miliardi di parametri): no.** Servono centinaia di GB anche
  compressi; con 32 GB di RAM non si caricano.
- **Modelli MoE fino a ~30-35B: sì**, come adesso (Gemma 4 26B, Qwen3.6 35B), con gli esperti in RAM.
- **Allenare da zero: no** (servono milioni di ore di GPU).
- **Rifinire (LoRA/QLoRA) modelli piccoli (1-4B): sì**, di notte, lentamente, sulla GTX 1650.
- **Rifinire i modelli grandi (26B+): no** con 4 GB (servono 16-24 GB di VRAM anche con QLoRA).
- **MoE «assemblati» da modelli piccoli** (mergekit-moe: più modelli rifiniti uniti come esperti, senza allenamento):
  sì, si fa con CPU e RAM; utile per esperimenti, il guadagno di qualità è incerto.
- **Distillazione** (un modello piccolo che impara dalle risposte di uno più grande, entrambi locali): sì, lenta ma
  fattibile per compiti specifici (es. un modello minuscolo e velocissimo solo per i comandi del PC).
- Le licenze dei pesi pubblici vanno rispettate (Gemma ha i suoi termini, altre sono MIT/Apache).

---

## 5. Decisioni aperte
- Base: Arch puro (consigliato, per gli aggiornamenti a ondate) o CachyOS.
- Una shell sola: partire da caelestia (già tua) o riscriverla leggera da zero.
- Nome dei comandi (`cielos`, `ciel`) e struttura del repository di CielOS (separato da assistente-vocale?).
- ~~Le azioni del guardiano~~ (decise 14/10).
- ~~Kernel e pacchetti CachyOS sopra Arch~~ — **deciso 14/10: base Arch + kernel e pacchetti CachyOS** (x86-64-v3); le ondate aspettano che i due repository siano allineati e CielOS tiene i pacchetti esatti di ogni ondata approvata (per tornarci anche se CachyOS non ha un archivio per data).

---

## 6. Come lavoriamo (finché il PC resta su CachyOS)

CachyOS resta il sistema di tutti i giorni (e quello da cui lavoriamo con Claude) fino alla fine. CielOS cresce
accanto, senza toccarlo:

1. **Pezzi che servono anche oggi** (sistema nervoso, automazioni, shell leggera, configurazione unica, gestore dei
   modelli): si scrivono e si usano su CachyOS, come Ciel adesso. Poi entrano nella ISO così come sono.
2. **La ISO** (profilo archiso in `iso/`): la preparo io; la costruisci tu con `sudo` (mkarchiso gira come
   root); esce un file `cielos-AAAA.MM.GG.iso`.
3. **Prova in macchina virtuale** (QEMU, senza sudo): si avvia il file in una finestra, niente riavvii.
4. **Prova sul PC vero** solo quando una versione è pronta: copi il file sulla chiavetta Ventoy, avvii da lì in
   modalità live. I dischi non vengono toccati (l'installatore chiede sempre, e non parte da solo).
5. **Installazione vera**, alla fine e quando decidi tu: su un disco o una partizione a parte (CachyOS resta, si
   sceglie all'avvio) oppure al posto di CachyOS dopo un backup. Claude Code funziona anche su Arch: dopo il
   passaggio si continua a lavorare da CielOS.

Una volta sola: `sudo pacman -S archiso qemu-desktop` (strumenti per costruire e provare la ISO).
