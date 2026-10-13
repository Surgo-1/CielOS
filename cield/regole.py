"""Le automazioni: regole «quando succede X, se Y, fai Z», una per file in ~/.config/cielos/automazioni/*.toml.
Le scrive Ciel a parole tue (o tu a mano); tu le vedi descritte in italiano e le approvi. Poi girano qui, senza IA.

    nome = "Serata di gioco"
    attiva = true
    [quando]
    evento = "gioco.inizio"            # anche con *: "finestra.*", "dispositivo.collegato"
    [se]                               # facoltativo: tutte vere
    classe = { contiene = "steam" }    # un campo dell'evento: uguale, contiene, inizia, diverso, regex, maggiore, minore
    ora_tra = ["18:00", "03:00"]
    giorni = ["ven", "sab"]
    [ritmo]                            # facoltativo
    al_massimo_ogni_min = 30
    finche = "gioco.fine"              # quando arriva, le azioni tornano com'erano prima
    [[fai]]
    azione = "profilo_energetico"
    valore = "prestazioni"
    [[fai]]
    azione = "ciel_di"
    testo = "Buona partita a {titolo}!"   # {campo} = un campo dell'evento

Per l'orario: evento = "orario" e in [se] ora = "21:00" (e giorni = [...])."""
import fnmatch, os, re, time, tomllib
from datetime import datetime
from pathlib import Path

from . import azioni, fonti

CARTELLA = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config")) / "cielos" / "automazioni"
EVENTI_NOTI = sorted({e for f in fonti.TUTTE for e in f.eventi})
OPERATORI = {"uguale", "contiene", "inizia", "diverso", "regex", "maggiore", "minore"}
SPECIALI = {"ora_tra", "giorni", "ora"}


QUANDO = {"gioco.inizio": "quando inizi a giocare", "gioco.fine": "quando smetti di giocare",
             "finestra.aperta": "quando si apre una finestra", "finestra.chiusa": "quando si chiude una finestra",
             "finestra.attiva": "quando passi a un'altra finestra", "notifica": "quando arriva una notifica",
             "dispositivo.collegato": "quando colleghi un dispositivo USB", "dispositivo.scollegato": "quando scolleghi un dispositivo USB",
             "disco.collegato": "quando colleghi un disco o una chiavetta", "audio.uscita": "quando cambia l'uscita audio",
             "rete.connessa": "quando torna Internet", "rete.disconnessa": "quando cade Internet",
             "sistema.errore": "quando il sistema registra un errore", "pacchetti.aggiornati": "dopo un aggiornamento dei pacchetti",
             "orario": "ogni minuto"}


class Regola:
    def __init__(self, file, d):
        self.file = Path(file)
        self.nome = str(d.get("nome") or self.file.stem)
        self.attiva = bool(d.get("attiva", True))
        self.evento = str((d.get("quando") or {}).get("evento", ""))
        self.se = dict(d.get("se") or {})
        r = d.get("ritmo") or {}
        self.ogni = float(r.get("al_massimo_ogni_min", 0)) * 60
        self.finche = str(r.get("finche", "") or "")
        self.fai = [dict(a) for a in (d.get("fai") or [])]
        self.ultima = 0.0
        self.da_ripristinare = []        # [(azione, parametri)] in attesa del «finche»

    def errori(self):
        e = []
        if not self.evento:
            e.append("manca [quando] evento")
        elif not self.evento.startswith(("ciel.", "mio.")) and not any(fnmatch.fnmatchcase(x, self.evento) for x in EVENTI_NOTI):
            e.append(f"evento sconosciuto: {self.evento} (noti: {', '.join(EVENTI_NOTI)}; i tuoi: mio.*)")
        if not self.fai:
            e.append("nessuna azione in [[fai]]")
        for a in self.fai:
            x = azioni.parametri_ok(a)
            if x:
                e.append(x)
        for k, v in self.se.items():
            if k == "ora_tra" and not (isinstance(v, list) and len(v) == 2 and all(re.match(r"^\d\d:\d\d$", str(x)) for x in v)):
                e.append('ora_tra vuole ["HH:MM", "HH:MM"]')
            elif k == "giorni" and not (isinstance(v, list) and set(v) <= set(fonti.GIORNI)):
                e.append(f"giorni tra {fonti.GIORNI}")
            elif isinstance(v, dict) and not set(v) <= OPERATORI:
                e.append(f"{k}: operatori possibili {sorted(OPERATORI)}")
        return e

    # ---------------------------------------------------------- quando scatta
    def vale(self, evento, dati):
        if not self.attiva or not fnmatch.fnmatchcase(evento, self.evento):
            return False
        if self.ogni and time.time() - self.ultima < self.ogni:
            return False
        adesso = datetime.now()
        for k, cond in self.se.items():
            if k == "ora_tra":
                o, a, b = adesso.strftime("%H:%M"), cond[0], cond[1]
                if not (a <= o < b if a <= b else (o >= a or o < b)):     # anche a cavallo della mezzanotte
                    return False
            elif k == "giorni":
                if fonti.GIORNI[adesso.weekday()] not in cond:
                    return False
            elif not _confronta(dati.get(k), cond):
                return False
        return True

    def azioni_pronte(self, dati):
        """Le azioni con i {campi} dell'evento sostituiti."""
        def sost(v):
            if isinstance(v, str):
                return re.sub(r"\{(\w+)\}", lambda m: str(dati.get(m.group(1), m.group(0))), v)
            if isinstance(v, dict):
                return {k: sost(x) for k, x in v.items()}
            if isinstance(v, list):
                return [sost(x) for x in v]
            return v
        return [{k: sost(v) for k, v in a.items()} for a in self.fai]

    # ---------------------------------------------------------- in italiano
    def descrizione(self):
        q = QUANDO.get(self.evento, f"all'evento «{self.evento}»")
        cond = []
        for k, v in self.se.items():
            if k == "ora" and self.evento == "orario":
                q = f"alle {v}"
            elif k == "ora_tra":
                cond.append(f"tra le {v[0]} e le {v[1]}")
            elif k == "giorni":
                cond.append("solo " + ", ".join(v))
            elif isinstance(v, dict):
                cond.extend(f"{k} {op} «{x}»" for op, x in v.items())
            else:
                cond.append(f"{k} è «{v}»")
        t = q[0].upper() + q[1:] + (" (" + "; ".join(cond) + ")" if cond else "") + ": "
        t += ", poi ".join(azioni.descrivi(a) for a in self.fai)
        if self.finche:
            fine = QUANDO.get(self.finche, f"quando arriva «{self.finche}»")
            t += f"; {fine} torna tutto com'era"
        if self.ogni:
            m = int(self.ogni // 60)
            t += "; al massimo una volta al minuto" if m <= 1 else f"; al massimo una volta ogni {m} minuti"
        return t + ("." if self.attiva else ". (In pausa.)")


def _confronta(valore, cond):
    if not isinstance(cond, dict):
        cond = {"uguale": cond}
    s = "" if valore is None else str(valore)
    for op, x in cond.items():
        xs = str(x)
        ok = {"uguale": lambda: s.lower() == xs.lower(), "diverso": lambda: s.lower() != xs.lower(),
              "contiene": lambda: xs.lower() in s.lower(), "inizia": lambda: s.lower().startswith(xs.lower()),
              "regex": lambda: re.search(xs, s, re.I) is not None,
              "maggiore": lambda: _num(s) is not None and _num(s) > float(x),
              "minore": lambda: _num(s) is not None and _num(s) < float(x)}[op]()
        if not ok:
            return False
    return True


def _num(s):
    try:
        return float(s)
    except ValueError:
        return None


def da_testo(testo, file="nuova.toml"):
    """(Regola, errori) da un testo TOML (per «prova», prima di salvare)."""
    try:
        r = Regola(file, tomllib.loads(testo))
    except (tomllib.TOMLDecodeError, ValueError, TypeError) as e:
        return None, [f"TOML non valido: {e}"]
    return r, r.errori()


def carica():
    """Tutte le regole della cartella: ({file: Regola}, {file: errori})."""
    CARTELLA.mkdir(parents=True, exist_ok=True)
    regole, errori = {}, {}
    for f in sorted(CARTELLA.glob("*.toml")):
        try:
            r = Regola(f, tomllib.loads(f.read_text(encoding="utf-8")))
        except (OSError, tomllib.TOMLDecodeError, ValueError, TypeError) as e:
            errori[f.name] = [str(e)]
            continue
        e = r.errori()
        if e:
            errori[f.name] = e
        else:
            regole[f.name] = r
    return regole, errori


def firma():
    """Cambia se cambia qualcosa nella cartella (file nuovi, tolti o modificati)."""
    try:
        return tuple(sorted((f.name, f.stat().st_mtime_ns) for f in CARTELLA.glob("*.toml")))
    except OSError:
        return ()
