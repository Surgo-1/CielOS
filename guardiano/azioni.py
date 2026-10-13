"""Le azioni del guardiano: un elenco chiuso. Ognuna controlla i parametri e prepara (senza eseguire niente):
  - la frase per la finestra della password, in italiano («Installo 2 pacchetti: htop, btop»)
  - i comandi da eseguire, come liste di argomenti (mai una stringa di shell)
  - se serve un'istantanea prima
Qui non si tocca il sistema: si può provare senza root (test_azioni.py). Chi esegue è guardiano.py.

Azioni (polkit: org.cielos.guardiano.<nome>, password ogni volta tranne le sole letture):
  aggiorna {}                                   installa {pacchetti: [..]}      togli {pacchetti: [..]}
  servizio {nome, comando: avvia|ferma|riavvia|abilita|disabilita}
  pulisci {}                                    firewall {porta, protocollo: tcp|udp, comando: apri|chiudi}
  istantanea {descrizione}                      istantanee {}   (solo lettura: l'elenco)"""
import ipaddress, re, subprocess

NOME_PACCHETTO = re.compile(r"^[a-z0-9@_+][a-z0-9@._+-]{0,99}$")
NOME_SERVIZIO = re.compile(r"^[A-Za-z0-9][A-Za-z0-9@._:\\-]{0,99}$")

# mai da togliere (anche come dipendenze tolte insieme): senza di loro il PC non parte o non si ripara
PACCHETTI_PROTETTI = re.compile(
    r"^(base|base-devel|linux(-[a-z0-9-]+)?|linux-firmware.*|nvidia.*|mesa|glibc|systemd.*|pacman.*|sudo|polkit|"
    r"sddm.*|hyprland.*|python|python-gobject|mkinitcpio|dracut|limine.*|grub|efibootmgr|btrfs-progs|snapper|"
    r"snap-pac|networkmanager|.*-keyring|cachyos-.*|bash|coreutils|util-linux|shadow|filesystem|dbus.*|"
    r"cielos-.*|pipewire.*|wireplumber)$")

# servizi che non si fermano né si disabilitano (riavviarli sì, tranne i primi)
SERVIZI_VITALI = re.compile(r"^(dbus|dbus-broker|polkit|sddm|display-manager|systemd-[a-z-]+|user@\d+|getty@.*|"
                            r"cielos-guardiano)\.service$")
SERVIZI_MAI = re.compile(r"^(dbus|dbus-broker|polkit|systemd-journald|systemd-logind|cielos-guardiano)\.service$")

COMANDI_SERVIZIO = {"avvia": "start", "ferma": "stop", "riavvia": "restart", "abilita": "enable", "disabilita": "disable"}
FATTI_SERVIZIO = {"avvia": "avviato", "ferma": "fermato", "riavvia": "riavviato", "abilita": "parte all'avvio",
                  "disabilita": "non parte più all'avvio"}
PAROLE_SERVIZIO = {"avvia": "Avvio", "ferma": "Fermo", "riavvia": "Riavvio", "abilita": "Abilito all'avvio",
                   "disabilita": "Tolgo dall'avvio"}


class Rifiutata(ValueError):
    """Parametri non validi o azione non permessa: il messaggio va detto all'utente così com'è."""


class Piano:
    def __init__(self, azione, frase, comandi, istantanea=True, lettura=False, fatto=None):
        self.azione, self.frase, self.comandi = azione, frase, comandi
        self.fatto = fatto or "Fatto."                 # da dire a cose fatte
        self.istantanea, self.lettura = istantanea, lettura


def _elenco(pacchetti):
    if isinstance(pacchetti, str):
        pacchetti = pacchetti.replace(",", " ").split()
    p = [str(x).strip().lower() for x in (pacchetti or []) if str(x).strip()]
    if not p:
        raise Rifiutata("Quali pacchetti?")
    if len(p) > 30:
        raise Rifiutata("Troppi pacchetti in una volta (al massimo 30).")
    for x in p:
        if not NOME_PACCHETTO.match(x):
            raise Rifiutata(f"«{x}» non è un nome di pacchetto valido.")
    return sorted(set(p))


def _nomi(p, n=6):
    return ", ".join(p[:n]) + (f" e altri {len(p) - n}" if len(p) > n else "")


def _esegui(*cmd):
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
    return r.returncode, r.stdout, r.stderr


def aggiorna(info=None, **_):
    """info(): quanti aggiornamenti ci sono (checkupdates), per la frase; None se non si sa."""
    n = info() if info else None
    if n == 0:
        raise Rifiutata("Il sistema è già aggiornato.")
    frase = f"Aggiorno il sistema ({n} pacchetti)." if n else "Aggiorno il sistema."
    return Piano("aggiorna", frase + " Prima faccio un'istantanea per poter tornare indietro.",
                 [["pacman", "-Syu", "--noconfirm"]],
                 fatto="Sistema aggiornato. Se qualcosa non va, l'istantanea di prima è nel menu di avvio.")


def installa(pacchetti=None, esiste=None, **_):
    """esiste(nome) -> bool: il pacchetto è nei repository ufficiali (pacman -Si)."""
    p = _elenco(pacchetti)
    if esiste:
        mancano = [x for x in p if not esiste(x)]
        if mancano:
            raise Rifiutata(f"Non trovo nei repository: {_nomi(mancano)}. (L'AUR non si installa da amministratore.)")
    return Piano("installa", f"Installo {len(p)} {'pacchetto' if len(p) == 1 else 'pacchetti'}: {_nomi(p)}.",
                 [["pacman", "-S", "--needed", "--noconfirm", "--", *p]], fatto=f"Installato: {_nomi(p)}.")


def togli(pacchetti=None, bersagli=None, **_):
    """bersagli(nomi) -> tutti i pacchetti che verrebbero tolti, dipendenze comprese (pacman -Rnsp)."""
    p = _elenco(pacchetti)
    protetti = [x for x in p if PACCHETTI_PROTETTI.match(x)]
    if protetti:
        raise Rifiutata(f"Non tolgo {_nomi(protetti)}: senza il PC potrebbe non partire più.")
    tutti = bersagli(p) if bersagli else p
    protetti = [x for x in tutti if PACCHETTI_PROTETTI.match(x)]
    if protetti:
        raise Rifiutata(f"Non tolgo {_nomi(protetti)}: senza il PC potrebbe non partire più.")
    extra = [x for x in tutti if x not in p]
    frase = f"Tolgo {_nomi(p)}" + (f", e le dipendenze che non servono più: {_nomi(extra)}" if extra else "") + "."
    return Piano("togli", frase, [["pacman", "-Rns", "--noconfirm", "--", *p]], fatto=f"Tolto: {_nomi(p)}.")


def servizio(nome="", comando="", **_):
    n = str(nome).strip()
    if not n.endswith((".service", ".timer", ".socket")):
        n += ".service"
    if not NOME_SERVIZIO.match(n):
        raise Rifiutata(f"«{nome}» non è un nome di servizio valido.")
    if comando not in COMANDI_SERVIZIO:
        raise Rifiutata(f"Cosa faccio con {n}? ({', '.join(COMANDI_SERVIZIO)})")
    if SERVIZI_MAI.match(n) or (comando in ("ferma", "disabilita") and SERVIZI_VITALI.match(n)):
        raise Rifiutata(f"{n} è vitale per il sistema: non lo tocco.")
    return Piano("servizio", f"{PAROLE_SERVIZIO[comando]} il servizio di sistema {n}.",
                 [["systemctl", COMANDI_SERVIZIO[comando], "--", n]], istantanea=False,
                 fatto=f"{n}: {FATTI_SERVIZIO[comando]}.")


def pulisci(**_):
    return Piano("pulisci", "Faccio pulizia: tengo solo le ultime 2 versioni dei pacchetti scaricati e tolgo il "
                 "registro di sistema più vecchio di 2 settimane.",
                 [["paccache", "-rk2"], ["journalctl", "--vacuum-time=2weeks"]], istantanea=False, fatto="Pulizia fatta.")


def firewall(porta=None, protocollo="tcp", comando="apri", rete=None, **_):
    """rete: la rete di casa (es. 192.168.1.0/24), trovata da guardiano.py; solo quella, mai «da ovunque»."""
    try:
        p = int(porta)
    except (TypeError, ValueError):
        raise Rifiutata("Quale porta?")
    if not 1 <= p <= 65535:
        raise Rifiutata("La porta va da 1 a 65535.")
    if protocollo not in ("tcp", "udp"):
        raise Rifiutata("Protocollo tcp o udp.")
    if comando not in ("apri", "chiudi"):
        raise Rifiutata("Apro o chiudo?")
    try:
        net = ipaddress.ip_network(str(rete), strict=False)
    except ValueError:
        raise Rifiutata("Non trovo la rete di casa: apro le porte solo verso quella.")
    if not net.is_private or net.prefixlen < 16:
        raise Rifiutata(f"{net} non è una rete di casa: non apro porte verso fuori.")
    regola = ["allow", "from", str(net), "to", "any", "port", str(p), "proto", protocollo]
    if comando == "apri":
        return Piano("firewall", f"Apro la porta {p}/{protocollo} solo per la rete di casa ({net}).",
                     [["ufw", *regola]], istantanea=False, fatto=f"Porta {p}/{protocollo} aperta per la rete di casa.")
    return Piano("firewall", f"Chiudo la porta {p}/{protocollo} per la rete di casa ({net}).",
                 [["ufw", "delete", *regola]], istantanea=False)


def istantanea(descrizione="a mano", **_):
    d = re.sub(r"[^\w .,:'()-]", "", str(descrizione))[:80] or "a mano"
    return Piano("istantanea", f"Creo un'istantanea del sistema («{d}»).",
                 [["snapper", "-c", "root", "create", "-c", "number", "-d", f"guardiano: {d}"]], istantanea=False,
                 fatto="Istantanea creata.")


def istantanee(**_):
    return Piano("istantanee", "Elenco le istantanee.", [["snapper", "-c", "root", "--jsonout", "list"]],
                 istantanea=False, lettura=True)


AZIONI = {f.__name__: f for f in (aggiorna, installa, togli, servizio, pulisci, firewall, istantanea, istantanee)}


def prepara(azione, parametri, **aiuti):
    """Il Piano per azione+parametri, o Rifiutata. aiuti: esiste, bersagli, info, rete (dal guardiano)."""
    f = AZIONI.get(azione)
    if not f:
        raise Rifiutata(f"Azione sconosciuta «{azione}» (possibili: {', '.join(AZIONI)}).")
    if not isinstance(parametri, dict):
        raise Rifiutata("Parametri non validi.")
    ammessi = {"aggiorna": set(), "installa": {"pacchetti"}, "togli": {"pacchetti"}, "servizio": {"nome", "comando"},
               "pulisci": set(), "firewall": {"porta", "protocollo", "comando"}, "istantanea": {"descrizione"},
               "istantanee": set()}[azione]
    extra = set(parametri) - ammessi
    if extra:
        raise Rifiutata(f"Parametri sconosciuti per {azione}: {', '.join(sorted(extra))}.")
    return f(**parametri, **aiuti)
