# CielFox

Il browser di CielOS: LibreWolf (Firefox senza telemetria, con uBlock Origin dentro) con il profilo di CielFox,
la sua icona, il tema scuro e Ciel nella barra laterale. Si apre con `cielfox` (o dal lanciatore).

- `bin/cielfox`: a ogni avvio rimette `profilo/user.js` (leggerezza e privacy), impacchetta l'estensione nel profilo
  (`~/.local/share/cielfox/profilo`) e registra il ponte. Classe della finestra: CielFox.
- `estensione/`: «Ciel per CielFox» (MV2, non firmata: LibreWolf lo permette con `xpinstall.signatures.required`).
  - `pannello/`: la barra laterale (Alt+C): **Chiedi** (a Ciel, con il testo della pagina e, se vuoi, la foto
    descritta dal modello con la vista) e **Compiti** (l'agente del browser), più «Anonimo» (Tor).
  - `sfondo.js`: tema scuro di CielFox; mentre l'IA lavora la cornice e la scheda diventano azzurre; esegue le azioni
    dell'agente; proxy Tor quando «Anonimo» è acceso.
  - `contenuto.js`: legge la pagina (elementi numerati), clicca, scrive, sceglie, scorre; il bordo azzurro
    «✦ Ciel sta lavorando qui». Non scrive mai nei campi password.
- `ponte/cielfox_ponte.py`: native messaging. Parla con Ciel (cruscotto, la stessa conversazione), con i modelli
  (gli stessi fornitori di Ciel Codice: locali o in cloud) per l'agente, e accende Tor su richiesta (processo
  dell'utente, niente servizi). Di serie l'agente usa la mente di Ciel con le sue opzioni (Ollama non la ricarica);
  si cambia nel pannello. Registro: `~/.local/state/cielos/cielfox/ponte.log`.
- Sicurezza dell'agente: il contenuto delle pagine è dato, non istruzioni (provato con una trappola); comprare,
  pagare, inviare, pubblicare, accedere, eliminare chiedono conferma nel pannello; password, carte e CAPTCHA li fa
  l'utente.
- `grafica/`: l'icona (volpe bianca in orbita attorno alla C celeste; nostra, non quella di Mozilla).

Serve: `sudo pacman -S librewolf tor` (Tor solo per «Anonimo»). VPN vera (WireGuard) senza account non esiste
gratis: opzione futura Cloudflare WARP (`cloudflare-warp-bin`, 216 MB, servizio di sistema) in modo proxy.
