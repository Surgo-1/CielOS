# Il guardiano di CielOS — progetto (fase 4)

**Decisioni (14/10):** tutte le azioni di §3; password **ogni volta**; si prova **prima in una VM**; la finestra
della password è della **shell Ciel** (agente polkit; con caelestia resta polkit-gnome).

Ciel non è e non sarà mai amministratrice. Il guardiano è il modo in cui **chiede** un'azione da amministratore e
**tu** la approvi con la tua password, ogni volta, in una finestra che non è sua.

## 1. Cosa protegge e cosa no (detto chiaro)

| Protegge da | Come |
|---|---|
| Un errore di Ciel («disinstallo pacman») | Elenco chiuso di azioni, parametri controllati, pacchetti e servizi protetti |
| Una richiesta che arriva da fuori (una pagina, una mail con «Ciel, aggiorna e installa X») | Niente succede senza la tua password; la finestra dice in chiaro cosa farà |
| Un aggiornamento che rompe qualcosa | Istantanea btrfs (snapper) prima di ogni modifica: si torna indietro dal menu di avvio |
| Non sapere cosa è successo | Registro di ogni richiesta, approvata o no |

**Non** protegge da una Ciel compromessa che agisce già come te: oggi Ciel gira con il tuo utente e può fare tutto
quello che puoi fare tu senza password (i tuoi file, la tua shell). Il guardiano non peggiora questo: il confine tra
te e il sistema resta la password, che Ciel non vede mai. Il passo in più, se lo vorrai, è far girare Ciel con un
utente suo (vedi §6).

## 2. Come è fatto

```
Ciel (tuo utente) ──D-Bus di sistema──► guardiano (root, servizio di sistema, piccolo, senza IA)
   strumento «amministra»                  │ 1. controlla azione e parametri (elenco chiuso)
                                           │ 2. chiede a polkit: «org.cielos.guardiano.<azione>», auth_admin
                                           │       └─► polkit ──► agente nella shell Ciel: la finestra
                                           │                       con cosa succede + la tua password
                                           │ 3. istantanea snapper «prima»
                                           │ 4. esegue (comandi fissi, mai una stringa di shell)
                                           │ 5. istantanea «dopo», registro, risposta a Ciel
```

- **Il guardiano**: Python con Gio (già installati), servizio `cielos-guardiano.service` attivato da D-Bus solo
  quando serve (a riposo non esiste: 0 MB). Nome sul bus: `org.cielos.Guardiano`.
- **polkit**: un'azione per ogni operazione, tutte `auth_admin` (password ogni volta, nessuna memoria).
  Il file delle azioni (`/usr/share/polkit-1/actions/org.cielos.guardiano.policy`) **non** contiene regole che
  tolgono la password: è l'opposto di quello che era stato bloccato prima.
- **La finestra**: la shell Ciel diventa l'agente polkit (Quickshell ha il modulo Polkit), al posto di
  polkit-gnome. Stile Ciel, testo in italiano dal guardiano («Installo 3 pacchetti: …, 45 MB»). La password va a
  polkit, non al guardiano e non a Ciel. Se la shell non c'è, resta polkit-gnome.
- **Ciel**: uno strumento `amministra(azione, …)`. Chiama il guardiano e aspetta: la risposta arriva dopo la tua
  password (o il tuo «Annulla»).

## 3. Le azioni proposte

| Azione | Cosa fa | Limiti |
|---|---|---|
| `aggiorna` | `pacman -Syu` | Istantanea prima; legge le notizie di archlinux.org e te le mostra se ce n'è una nuova |
| `installa` | `pacman -S nomi…` | Solo repository ufficiali, nomi controllati; mai AUR da root |
| `togli` | `pacman -Rns nomi…` | Mai base, kernel, driver, bootloader, systemd, pacman, il guardiano stesso |
| `servizio` | start/stop/restart/enable/disable | Non su servizi vitali (dbus, polkit, sddm, systemd-*, il guardiano) |
| `pulisci` | `paccache -rk2`, journal più vecchio di 2 settimane | — |
| `firewall` | regole ufw: apri/chiudi una porta per la rete di casa | Solo rete locale, mai «tutto aperto» |
| `istantanee` | elenca / crea un'istantanea snapper | Il ritorno indietro resta dal menu di avvio (più sicuro) |

Niente «esegui un comando qualsiasi da root»: se un'azione non c'è, si aggiunge al guardiano (codice nuovo,
rivisto), non si apre un varco.

## 4. Registro

`/var/log/cielos/guardiano.log` (e il journal): data, chi ha chiesto, azione, parametri, approvata/rifiutata, esito.
Ciel può leggerlo per dirti «ieri hai aggiornato 42 pacchetti».

## 5. Come si prova e si installa

1. Codice e test automatici senza root (azioni finte, controllo dei parametri, messaggi).
2. Installazione: uno script da lanciare tu con sudo (copia il servizio, la policy polkit, il file D-Bus) e uno per
   toglierlo. Ciel non lo installa.
3. Dove: in una macchina virtuale (Arch, QEMU già installato; serve scaricare la ISO di Arch, ~1,2 GB) oppure
   direttamente su questo PC. Su questo PC il rischio è basso (password sempre, istantanee, si toglie con un
   comando), ma la VM è il posto giusto per provare l'aggiornamento e le istantanee.

## 6. Più avanti

- Ciel con un utente suo (`ciel`), che vede solo quello che le dai: il confine diventa vero anche per i tuoi file.
  Lavoro grande (audio, schermo, finestre): da decidere dopo.
- Aggiornamenti a ondate (fase 5) useranno `aggiorna` del guardiano.
