# Errori

Cosa significa ogni errore e cosa fare. Per cercarne uno: incollalo in Super+A → Guida → *Cosa vuol dire?*, oppure `cielos errore "testo dell'errore"`.

<!-- generata da «cielos errore --markdown» da wiki/errori.json: non modificarla a mano -->

## Aggiornamenti e programmi

<a id="lucchetto"></a>
### Pacman è bloccato

**Cosa significa.** Un aggiornamento o un'installazione si è interrotto a metà (PC spento, terminale chiuso) e ha lasciato il suo «lucchetto»: finché c'è, nessun altro aggiornamento parte.

**Cosa fare.** Se nessun aggiornamento sta lavorando: Impostazioni → Medico → Ripara, oppure `cielos medico ripara lucchetto` (chiede la password). Se un aggiornamento sta lavorando, aspetta che finisca.

<a id="firma"></a>
### Firma di un pacchetto non valida

**Cosa significa.** Pacman controlla che ogni pacchetto sia firmato da chi lo fa. Di solito succede quando le chiavi di Arch sul PC sono vecchie (PC fermo da tanto) o un download si è rovinato.

**Cosa fare.** Aggiorna prima le chiavi: `sudo pacman -Sy archlinux-keyring` e poi `cielos aggiorna`. Se riguarda il repository di CielOS: `sudo pacman-key --populate cielos`.

<a id="conflitto-file"></a>
### File in conflitto

**Cosa significa.** Un pacchetto vuole scrivere un file che c'è già sul disco ma non appartiene a nessun pacchetto (spesso messo a mano o da uno script).

**Cosa fare.** Guarda di chi è: `pacman -Qo PERCORSO`. Se non è di nessuno e sai cos'è, spostalo via (non cancellarlo) e riprova. Se non sai cos'è, manda `cielos segnala`.

<a id="dipendenze"></a>
### Dipendenze che non tornano

**Cosa significa.** Un programma (spesso dall'AUR) chiede una versione di una libreria diversa da quella che c'è nel sistema.

**Cosa fare.** Aggiorna tutto insieme (Super+A → Install → Aggiorna tutto): quasi sempre si sistema. Se è un pacchetto AUR, aspetta che il suo autore lo aggiorni o prova la variante -bin.

<a id="spazio"></a>
### Disco pieno

**Cosa significa.** Il disco non ha più spazio: aggiornamenti, programmi e anche il login possono fallire.

**Cosa fare.** Impostazioni → Medico → Ripara libera i pacchetti scaricati vecchi e il registro. Poi svuota il cestino e guarda le cartelle grandi con File. Le istantanee vecchie si cancellano da sole.

<a id="rete-pacchetti"></a>
### Download non riuscito

**Cosa significa.** Il PC non riesce a scaricare dai server: internet assente o un server lento/fermo.

**Cosa fare.** Controlla internet (barra → rete). Riprova tra qualche minuto: pacman prova il server successivo. Con le ondate attive i pacchetti vengono dall'archivio di Arch, che a volte è lento.

<a id="ondata-vecchia"></a>
### Ondata non valida

**Cosa significa.** Gli aggiornamenti a ondate vanno solo avanti; per tornare indietro c'è «ritorna».

**Cosa fare.** Per tornare a com'era prima dell'ultimo aggiornamento: `cielos ritorna` (vale dal riavvio).

<a id="aur-root"></a>
### Pacchetto non nei repository

**Cosa significa.** Il guardiano installa solo dai repository ufficiali; i pacchetti dell'AUR si compilano come utente normale.

**Cosa fare.** Usa Super+A → Install: trova anche l'AUR e lo installa nel modo giusto (con paru).

<a id="paru-libalpm"></a>
### paru non parte (libalpm.so)

**Cosa significa.** paru, il programma che installa dall'AUR, era stato compilato per la versione di pacman di prima. Arch ha aggiornato pacman e paru non trova più la sua libreria. I pacchetti normali si aggiornano lo stesso: si fermano solo quelli dell'AUR.

**Cosa fare.** Rifai «Aggiorna tutto» (Super+A → Install, oppure `cielplugin aggiorna-tutto`): CielOS si accorge che paru è rotto e lo ricompila da solo (qualche minuto, chiede la password).

<a id="vitale"></a>
### Pacchetto o servizio protetto

**Cosa significa.** CielOS non toglie né ferma i pezzi senza cui il PC non partirebbe (kernel, systemd, pacman, il login…).

**Cosa fare.** È voluto. Se ti serve davvero, fallo a mano dal terminale sapendo cosa fai.

<a id="pacnew"></a>
### File .pacnew

**Cosa significa.** Un aggiornamento ha portato una versione nuova di un file di configurazione, ma tu avevi cambiato quello vecchio: pacman non sovrascrive e mette il nuovo accanto.

**Cosa fare.** Non è urgente. Chiedi a Ciel di confrontarli, oppure `sudo DIFFPROG="diff -u" pacdiff`. Per i mirrorlist puoi semplicemente tenere il nuovo.

## Avvio e sistema

<a id="kernel-aggiornato"></a>
### Kernel aggiornato, riavvio da fare

**Cosa significa.** Il kernel è nuovo ma gira ancora il vecchio: alcuni moduli (USB, rete, schede video) non si caricano finché non riavvii.

**Cosa fare.** Riavvia appena puoi.

<a id="emergenza"></a>
### Il PC parte in modalità di emergenza

**Cosa significa.** Qualcosa di importante non è partito all'avvio, spesso un disco in /etc/fstab che non c'è più.

**Cosa fare.** Al menu di avvio scegli lo stesso sistema: se un aggiornamento appena fatto non parte bene, CielOS torna indietro da solo. Altrimenti `journalctl -xb` per vedere cosa è fallito, e controlla /etc/fstab.

<a id="luks"></a>
### Disco cifrato: frase non accettata

**Cosa significa.** La frase segreta del disco non è giusta. Attenzione alla tastiera: all'avvio vale quella scelta nell'installazione.

**Cosa fare.** Riprova con calma (Bloc Maiusc, tastiera italiana o americana). Senza la frase giusta i dati non si possono recuperare.

<a id="servizi"></a>
### Un servizio non parte

**Cosa significa.** Un programma di sistema che dovrebbe girare in sottofondo si è fermato con un errore.

**Cosa fare.** Impostazioni → Medico → Ripara prova a riavviarlo. Per vedere il perché: `systemctl status NOME` o `journalctl -u NOME -b`.

<a id="memoria"></a>
### Memoria finita

**Cosa significa.** La RAM è piena: per non bloccare il PC, il sistema ha chiuso il programma che ne usava di più.

**Cosa fare.** Chiudi qualche programma (schede del browser, giochi, modelli di Ciel in Super+A → I miei modelli). Se succede spesso, il Medico controlla che zram e oomd siano accesi.

<a id="bios-limine"></a>
### Avvio BIOS non installato

**Cosa significa.** Durante l'installazione la partizione per i PC senza UEFI conteneva i resti di un vecchio file system. Corretto da CielOS r83: ora viene ripulita prima.

**Cosa fare.** Sui PC UEFI non cambia niente (parte lo stesso). Se il PC è vecchio (solo BIOS), reinstalla con una ISO aggiornata.

## Installazione

<a id="inst-pacstrap"></a>
### Installazione: pacchetti non scaricati

**Cosa significa.** L'installatore non è riuscito a scaricare o installare i pacchetti di base.

**Cosa fare.** Controlla internet (cavo o Wi-Fi nella barra della chiavetta) e riprova. Se il disco è piccolo, servono almeno 16 GB.

<a id="inst-disco"></a>
### Installazione: il disco non si prepara

**Cosa significa.** Il disco scelto non si lascia cancellare o formattare: è in uso (montato dalla live), protetto o rovinato.

**Cosa fare.** Chiudi File e tutto quello che usa quel disco, riprova. Se continua, prova un'altra porta/cavo o un altro disco, e manda il registro (/var/log/cielos-installa.log).

<a id="inst-utente"></a>
### Installazione: utente non creato

**Cosa significa.** Il nome per entrare deve essere minuscolo, senza spazi né accenti, e iniziare con una lettera.

**Cosa fare.** Torna alla pagina «Tu» e cambia il nome per entrare (es. mario).

<a id="inst-avvio"></a>
### Installazione: l'ultima parte non è andata

**Cosa significa.** Il sistema è copiato ma la preparazione dell'avvio o di CielOS è fallita.

**Cosa fare.** Manda il registro (/var/log/cielos-installa.log) con `cielos segnala` dalla chiavetta; di solito basta riprovare l'installazione.

## Password e sicurezza

<a id="guardiano"></a>
### Il guardiano non risponde

**Cosa significa.** Il guardiano è il servizio che fa le cose da amministratore (con la tua password). Non è installato o non è partito.

**Cosa fare.** `sudo systemctl status cielos-guardiano` per vedere. Se manca: `sudo cielos-sistema`.

<a id="non-autorizzato"></a>
### Password non data

**Cosa significa.** La finestra della password è stata chiusa o la password era sbagliata: l'azione non è stata fatta (niente è cambiato).

**Cosa fare.** Riprova e scrivi la tua password (quella del login).

<a id="occupato"></a>
### Il guardiano è occupato

**Cosa significa.** Fa una cosa da amministratore alla volta, per sicurezza.

**Cosa fare.** Aspetta che finisca quella in corso (una notifica lo dice) e riprova.

<a id="firewall-casa"></a>
### Porta non aperta

**Cosa significa.** CielOS apre le porte del firewall solo verso la rete di casa, mai verso internet.

**Cosa fare.** È voluto. Collegati alla rete di casa e riprova.

## Audio

<a id="microfono"></a>
### Il microfono non si sente

**Cosa significa.** Spesso un microfono USB (con l'uscita per le cuffie) è partito in modalità «solo uscita», oppure l'app usa il microfono sbagliato.

**Cosa fare.** Esci e rientra (CielOS rimette il profilo con il microfono da solo, cielos-microfono). Nell'app scegli il microfono vero, non «Microfono di Ciel». Controlla: `pactl list short sources`.

<a id="audio-uscita"></a>
### Niente audio

**Cosa significa.** PipeWire non vede la scheda audio, o l'audio esce dal dispositivo sbagliato (es. le casse del monitor HDMI).

**Cosa fare.** Barra → Volume → scegli l'uscita giusta. Poi `systemctl --user restart pipewire pipewire-pulse wireplumber`. Se l'uscita è «fittizia», riavvia e manda `cielos segnala`.

<a id="pipewire-spento"></a>
### Il servizio dell'audio è spento

**Cosa significa.** PipeWire (il sistema audio) non è partito.

**Cosa fare.** `systemctl --user restart pipewire pipewire-pulse wireplumber`. Se non basta, riavvia.

## Schermo, finestre e giochi

<a id="hypr-config"></a>
### Errore nella configurazione di Hyprland

**Cosa significa.** Una riga scritta a mano nei file di Hyprland ha un errore: di solito in ~/.config/cielos/hypr-mio.lua.

**Cosa fare.** Apri il file indicato e correggi la riga (il messaggio dice quale). Per tornare di serie, svuota hypr-mio.lua. Le scelte delle Impostazioni non si toccano a mano.

<a id="schermo-nero-condivisione"></a>
### Condivisione dello schermo nera

**Cosa significa.** Le app X11 (come Discord ufficiale) non vedono lo schermo di Wayland.

**Cosa fare.** Usa «Discord (web)» da Super+A → Install → Consigliati, oppure installa «Ponte per condividere lo schermo» e condividi la sua finestra.

<a id="discord-crash"></a>
### Discord si chiude

**Cosa significa.** Discord ufficiale su Wayland si chiude spesso con la condivisione dello schermo o la codifica video hardware.

**Cosa fare.** Discord → Impostazioni → Avanzate → Accelerazione hardware spenta; nei codec video spegni AV1 e H.265. Oppure «Discord (web)».

<a id="vulkan"></a>
### Vulkan / giochi non partono

**Cosa significa.** Manca il driver Vulkan giusto (o la sua versione a 32 bit per Steam e Proton).

**Cosa fare.** `sudo cielos-hardware installa` mette i driver di questo PC, anche a 32 bit. Poi riavvia.

<a id="schermata-gialla"></a>
### Schermata gialla

**Cosa significa.** Nelle versioni vecchie il mirino della selezione finiva dentro la foto.

**Cosa fare.** Aggiorna (`cielos aggiorna`): corretto da CielOS r78.

## Strumenti

<a id="strumenti-manca"></a>
### Manca un programma

**Cosa significa.** Lo strumento ha bisogno di un programma che non è installato.

**Cosa fare.** Super+A → Install, cerca il nome del programma e installalo. Su CielOS aggiornato ci sono già tutti tranne l'OCR in italiano (tesseract-data-ita).

<a id="registrazione"></a>
### La registrazione non parte

**Cosa significa.** gpu-screen-recorder non riesce a usare la scheda video o lo schermo scelto.

**Cosa fare.** Riprova con «Registra un'area». Se continua: guarda $XDG_RUNTIME_DIR/cielos/registrazione.log e manda `cielos segnala`.

<a id="ocr-qr"></a>
### Testo o QR non trovato

**Cosa significa.** Nell'area scelta il testo è troppo piccolo/sfocato o il QR non è intero.

**Cosa fare.** Scegli un'area più grande, con tutto il codice dentro; ingrandisci la pagina prima.

<a id="wifi-qr"></a>
### QR del Wi-Fi non disponibile

**Cosa significa.** Serve essere collegati a un Wi-Fi con password normale (non aziendale con utente).

**Cosa fare.** Collegati al Wi-Fi di casa e riprova.

## Ciel

<a id="ciel-mente"></a>
### Ciel non ha una mente

**Cosa significa.** Ciel funziona anche senza modello (comandi, ora, volume…), ma per conversare serve una mente: un modello scaricato.

**Cosa fare.** Super+A → Scarica modelli: scegli uno adatto al tuo PC e premi «Usa per Ciel».

<a id="vram"></a>
### Memoria della scheda video finita

**Cosa significa.** Il modello di Ciel (o un gioco) non ci sta nella memoria della scheda video.

**Cosa fare.** Scegli un modello più piccolo (Super+A → Scarica modelli mostra cosa ci sta) o chiudi i giochi mentre Ciel pensa.

