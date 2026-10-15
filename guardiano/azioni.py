"""Le azioni del guardiano: un elenco chiuso. Ognuna controlla i parametri e prepara (senza eseguire niente):
  - la frase per la finestra della password, in italiano («Installo 2 pacchetti: htop, btop»)
  - i comandi da eseguire, come liste di argomenti (mai una stringa di shell)
  - se serve un'istantanea prima
Qui non si tocca il sistema: si può provare senza root (test_azioni.py). Chi esegue è guardiano.py.

Azioni (polkit: org.cielos.guardiano.<nome>, password ogni volta tranne le sole letture):
  aggiorna {ondata?: AAAA-MM-GG}                installa {pacchetti: [..]}      togli {pacchetti: [..]}
  ritorna {}   (rimette il sistema com'era prima dell'ultimo aggiornamento; vale dal prossimo avvio)
  servizio {nome, comando: avvia|ferma|riavvia|abilita|disabilita}
  pulisci {}                                    firewall {porta, protocollo: tcp|udp, comando: apri|chiudi}
  istantanea {descrizione}                      istantanee {}   (solo lettura: l'elenco)
  dns {fornitore: automatico|cloudflare|google|quad9}   (il DNS di tutto il PC, per NetworkManager)"""
import ipaddress, os, re, subprocess, sys
from pathlib import Path

# le frasi nella lingua del sistema (lingua/lingua.py di CielOS: installato in /usr/share/cielos, in sviluppo accanto)
for _d in (Path(os.environ.get("CIELOS_DIR", "/usr/share/cielos")) / "lingua", Path(__file__).resolve().parent.parent / "lingua"):
    if (_d / "lingua.py").exists():
        sys.path.insert(0, str(_d))
        break
try:
    from lingua import tr
except ImportError:
    def tr(testo, *valori):
        for i, v in enumerate(valori, 1):
            testo = testo.replace(f"%{i}", str(v))
        return testo

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
    ondata = None                                  # solo «aggiorna»
    ultimo = None                                  # solo «ritorna»

    def __init__(self, azione, frase, comandi, istantanea=True, lettura=False, fatto=None):
        self.azione, self.frase, self.comandi = azione, frase, comandi
        self.fatto = fatto or tr("Fatto.")                 # da dire a cose fatte
        self.istantanea, self.lettura = istantanea, lettura


def _elenco(pacchetti):
    if isinstance(pacchetti, str):
        pacchetti = pacchetti.replace(",", " ").split()
    p = [str(x).strip().lower() for x in (pacchetti or []) if str(x).strip()]
    if not p:
        raise Rifiutata(tr("Quali pacchetti?"))
    if len(p) > 30:
        raise Rifiutata(tr("Troppi pacchetti in una volta (al massimo 30)."))
    for x in p:
        if not NOME_PACCHETTO.match(x):
            raise Rifiutata(tr("«%1» non è un nome di pacchetto valido.", x))
    return sorted(set(p))


def _nomi(p, n=6):
    return ", ".join(p[:n]) + (tr(" e altri %1", len(p) - n) if len(p) > n else "")


def _esegui(*cmd):
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=120)
    return r.returncode, r.stdout, r.stderr


def aggiorna(info=None, ondata=None, ondate=None, **_):
    """info(): quanti aggiornamenti ci sono (checkupdates), per la frase; None se non si sa.
    ondata: il giorno dell'Arch Linux Archive a cui portare i repository di Arch (solo con le ondate attive);
    ondate: (attive: bool, attuale: str|None) da guardiano.py."""
    attive, attuale = ondate or (False, None)
    if ondata is not None:
        if not attive:
            raise Rifiutata(tr("Le ondate non sono attive su questo PC (si attivano con: sudo installa.sh ondate)."))
        if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", str(ondata)):
            raise Rifiutata(tr("Data dell'ondata non valida (AAAA-MM-GG)."))
        if attuale and ondata < attuale:
            raise Rifiutata(tr("L'ondata del %1 è più vecchia di quella attuale (%2): per tornare indietro c'è «ritorna».",
                               ondata, attuale))
    n = info() if info and ondata is None else None
    if n == 0:
        raise Rifiutata(tr("Il sistema è già aggiornato."))
    if ondata:
        g = "/".join(reversed(ondata.split("-")))
        frase = tr("Aggiorno il sistema all'ondata del %1 (pacchetti di Arch di quel giorno).", g)
    else:
        frase = tr("Aggiorno il sistema (%1 pacchetti).", n) if n else tr("Aggiorno il sistema.")
    p = Piano("aggiorna", frase + " " + tr("Prima copio i file d'avvio e faccio un'istantanea; al primo riavvio controllo "
                                           "che il desktop parta, se no torno indietro da solo."),
              [["pacman", "-Syyu" if ondata else "-Syu", "--noconfirm"]],
              fatto=tr("Sistema aggiornato. Riavvia quando vuoi: al primo avvio controllo che il desktop parta, "
                       "altrimenti rimetto tutto com'era."))
    p.ondata = ondata
    return p


def ritorna(ultimo=None, **_):
    """ultimo(): l'aggiornamento a cui tornare prima {id, prima, data} (in prova o l'ultimo riuscito), o None."""
    u = ultimo() if ultimo else None
    if not u:
        raise Rifiutata(tr("Non c'è un aggiornamento fatto dal guardiano a cui tornare prima."))
    d = re.match(r"(\d{4})-(\d{2})-(\d{2}) (\d{2}:\d{2})", str(u.get("data", "")))
    quando = tr("del %1/%2 alle %3", d[3], d[2], d[4]) if d else tr("più recente")
    p = Piano("ritorna", tr("Rimetto il sistema com'era prima dell'aggiornamento %1 (istantanea %2). Vale dal prossimo "
                            "riavvio; i tuoi file in /home non cambiano.", quando, u['prima']),
              [], istantanea=False, fatto=tr("Fatto: al prossimo riavvio il sistema è com'era prima dell'aggiornamento."))
    p.ultimo = u
    return p


def installa(pacchetti=None, esiste=None, **_):
    """esiste(nome) -> bool: il pacchetto è nei repository ufficiali (pacman -Si)."""
    p = _elenco(pacchetti)
    if esiste:
        mancano = [x for x in p if not esiste(x)]
        if mancano:
            raise Rifiutata(tr("Non trovo nei repository: %1. (L'AUR non si installa da amministratore.)", _nomi(mancano)))
    return Piano("installa", tr("Installo 1 pacchetto: %1.", _nomi(p)) if len(p) == 1 else tr("Installo %1 pacchetti: %2.", len(p), _nomi(p)),
                 [["pacman", "-S", "--needed", "--noconfirm", "--", *p]], fatto=tr("Installato: %1.", _nomi(p)))


def togli(pacchetti=None, bersagli=None, **_):
    """bersagli(nomi) -> tutti i pacchetti che verrebbero tolti, dipendenze comprese (pacman -Rnsp)."""
    p = _elenco(pacchetti)
    protetti = [x for x in p if PACCHETTI_PROTETTI.match(x)]
    if protetti:
        raise Rifiutata(tr("Non tolgo %1: senza il PC potrebbe non partire più.", _nomi(protetti)))
    tutti = bersagli(p) if bersagli else p
    protetti = [x for x in tutti if PACCHETTI_PROTETTI.match(x)]
    if protetti:
        raise Rifiutata(tr("Non tolgo %1: senza il PC potrebbe non partire più.", _nomi(protetti)))
    extra = [x for x in tutti if x not in p]
    frase = (tr("Tolgo %1, e le dipendenze che non servono più: %2.", _nomi(p), _nomi(extra)) if extra
             else tr("Tolgo %1.", _nomi(p)))
    return Piano("togli", frase, [["pacman", "-Rns", "--noconfirm", "--", *p]], fatto=tr("Tolto: %1.", _nomi(p)))


def servizio(nome="", comando="", **_):
    n = str(nome).strip()
    if not n.endswith((".service", ".timer", ".socket")):
        n += ".service"
    if not NOME_SERVIZIO.match(n):
        raise Rifiutata(tr("«%1» non è un nome di servizio valido.", nome))
    if comando not in COMANDI_SERVIZIO:
        raise Rifiutata(tr("Cosa faccio con %1? (%2)", n, ', '.join(COMANDI_SERVIZIO)))
    if SERVIZI_MAI.match(n) or (comando in ("ferma", "disabilita") and SERVIZI_VITALI.match(n)):
        raise Rifiutata(tr("%1 è vitale per il sistema: non lo tocco.", n))
    return Piano("servizio", tr("%1 il servizio di sistema %2.", tr(PAROLE_SERVIZIO[comando]), n),
                 [["systemctl", COMANDI_SERVIZIO[comando], "--", n]], istantanea=False,
                 fatto=f"{n}: {tr(FATTI_SERVIZIO[comando])}.")


def pulisci(**_):
    return Piano("pulisci", tr("Faccio pulizia: tengo solo le ultime 2 versioni dei pacchetti scaricati e tolgo il "
                               "registro di sistema più vecchio di 2 settimane."),
                 [["paccache", "-rk2"], ["journalctl", "--vacuum-time=2weeks"]], istantanea=False, fatto=tr("Pulizia fatta."))


def firewall(porta=None, protocollo="tcp", comando="apri", rete=None, **_):
    """rete: la rete di casa (es. 192.168.1.0/24), trovata da guardiano.py; solo quella, mai «da ovunque»."""
    try:
        p = int(porta)
    except (TypeError, ValueError):
        raise Rifiutata(tr("Quale porta?"))
    if not 1 <= p <= 65535:
        raise Rifiutata(tr("La porta va da 1 a 65535."))
    if protocollo not in ("tcp", "udp"):
        raise Rifiutata(tr("Protocollo tcp o udp."))
    if comando not in ("apri", "chiudi"):
        raise Rifiutata(tr("Apro o chiudo?"))
    try:
        net = ipaddress.ip_network(str(rete), strict=False)
    except ValueError:
        raise Rifiutata(tr("Non trovo la rete di casa: apro le porte solo verso quella."))
    if not net.is_private or net.prefixlen < 16:
        raise Rifiutata(tr("%1 non è una rete di casa: non apro porte verso fuori.", net))
    regola = ["allow", "from", str(net), "to", "any", "port", str(p), "proto", protocollo]
    if comando == "apri":
        return Piano("firewall", tr("Apro la porta %1 solo per la rete di casa (%2).", f"{p}/{protocollo}", net),
                     [["ufw", *regola]], istantanea=False, fatto=tr("Porta %1 aperta per la rete di casa.", f"{p}/{protocollo}"))
    return Piano("firewall", tr("Chiudo la porta %1 per la rete di casa (%2).", f"{p}/{protocollo}", net),
                 [["ufw", "delete", *regola]], istantanea=False)


def istantanea(descrizione="a mano", **_):
    d = re.sub(r"[^\w .,:'()-]", "", str(descrizione))[:80] or "a mano"
    return Piano("istantanea", tr("Creo un'istantanea del sistema («%1»).", d),
                 [["snapper", "-c", "root", "create", "-c", "number", "-d", f"guardiano: {d}"]], istantanea=False,
                 fatto=tr("Istantanea creata."))


def istantanee(**_):
    return Piano("istantanee", tr("Elenco le istantanee."), [["snapper", "-c", "root", "--jsonout", "list"]],
                 istantanea=False, lettura=True)


DNS_FILE = "/etc/NetworkManager/conf.d/20-cielos-dns.conf"
DNS_NOMI = {"cloudflare": "Cloudflare (1.1.1.1)", "google": "Google (8.8.8.8)", "quad9": "Quad9 (9.9.9.9)"}


def dns(fornitore="", **_):
    """i file sono quelli di CielOS (sistema/dns/), mai scritti da fuori: si sceglie solo il nome"""
    f = str(fornitore).strip().lower()
    ricarica = ["nmcli", "general", "reload", "conf", "dns-rc"]
    if f == "automatico":
        return Piano("dns", tr("Rimetto il DNS automatico (quello che dà la rete)."), [["rm", "-f", "--", DNS_FILE], ricarica],
                     istantanea=False, fatto=tr("DNS automatico."))
    if f not in DNS_NOMI:
        raise Rifiutata(tr("Quale DNS? (%1)", "automatico, " + ", ".join(DNS_NOMI)))
    radice = Path(os.environ.get("CIELOS_DIR", "/usr/share/cielos"))
    sorgente = radice / "sistema" / "dns" / f"{f}.conf"
    if not sorgente.exists():
        sorgente = Path(__file__).resolve().parent.parent / "sistema" / "dns" / f"{f}.conf"
    return Piano("dns", tr("Uso il DNS di %1 per tutto il PC.", DNS_NOMI[f]),
                 [["install", "-Dm644", "--", str(sorgente), DNS_FILE], ricarica], istantanea=False,
                 fatto=tr("DNS: %1.", DNS_NOMI[f]))


AZIONI = {f.__name__: f for f in (aggiorna, ritorna, installa, togli, servizio, pulisci, firewall, istantanea, istantanee, dns)}


def prepara(azione, parametri, **aiuti):
    """Il Piano per azione+parametri, o Rifiutata. aiuti: esiste, bersagli, info, rete (dal guardiano)."""
    f = AZIONI.get(azione)
    if not f:
        raise Rifiutata(tr("Azione sconosciuta «%1» (possibili: %2).", azione, ', '.join(AZIONI)))
    if not isinstance(parametri, dict):
        raise Rifiutata(tr("Parametri non validi."))
    ammessi = {"aggiorna": {"ondata"}, "ritorna": set(), "installa": {"pacchetti"}, "togli": {"pacchetti"}, "servizio": {"nome", "comando"},
               "pulisci": set(), "firewall": {"porta", "protocollo", "comando"}, "istantanea": {"descrizione"},
               "istantanee": set(), "dns": {"fornitore"}}[azione]
    extra = set(parametri) - ammessi
    if extra:
        raise Rifiutata(tr("Parametri sconosciuti per %1: %2.", azione, ', '.join(sorted(extra))))
    return f(**parametri, **aiuti)
