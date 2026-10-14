"""Ciel Codice: il Codex di CielOS.

  ciel-codice                    nel terminale, nel progetto della cartella dove sei (la aggiunge se serve)
  ciel-codice app                apre l'app (la finestra)
  ciel-codice servi              il motore per l'app: comandi e notizie in JSON, una riga alla volta
  ciel-codice progetti           i progetti
  ciel-codice fornitori          da dove vengono i modelli (locali e in cloud) e se sono pronti
  ciel-codice modelli FORNITORE  i modelli di un fornitore (quelli gratuiti per primi)
  ciel-codice chiave FORNITORE   incolla la chiave di un servizio in cloud (non si vede mentre la scrivi)
  ciel-codice usa FORNITORE MODELLO   il modello di serie
  ciel-codice plugin [aggiungi NOME COMANDO… | togli NOME | accendi NOME | spegni NOME]"""
import getpass, json, os, sys, threading
from pathlib import Path

from . import fornitori, mcp, sessione as S


# ── il motore per l'app ──────────────────────────────────────────────────────────────────────────────────────────

class Servizio:
    def __init__(self):
        self.lock = threading.Lock()
        self.s = None
        self.lavoro = None
        self.domande = {}                         # id -> [Event, risposta]

    def manda(self, d):
        with self.lock:
            sys.stdout.write(json.dumps(d, ensure_ascii=False) + "\n")
            sys.stdout.flush()

    def chiedi(self, info):
        ev = threading.Event()
        self.domande[info["id"]] = [ev, (False, False)]
        self.manda({"ev": "permesso", **info})
        ev.wait()
        return self.domande.pop(info["id"])[1]

    def stato(self):
        imp = S.impostazioni()
        self.manda({"ev": "stato", "progetti": S.progetti(), "fornitori": fornitori.elenco_fornitori(),
                    "fornitore": imp.get("fornitore"), "modello": imp.get("modello"),
                    "plugin": [{"nome": k, **v} for k, v in mcp.leggi().items()]})

    def apri(self, pid, sid=None):
        if self.s:
            self.s.chiudi()
        self.s = S.Sessione(pid, sid, self.manda, self.chiedi)
        self.manda({"ev": "sessione", "progetto": pid, "id": self.s.id, "titolo": self.s.titolo,
                    "fornitore": self.s.fornitore, "modello": self.s.modello, "modo": self.s.p.get("modo", "progetto"),
                    "vista": self.s.vista()})

    def gestisci(self, d):
        c = d.get("cmd")
        if c == "stato":
            self.stato()
        elif c == "suggerimenti":
            self.manda({"ev": "suggerimenti", "cartelle": S.suggerimenti()})
        elif c == "aggiungi_progetto":
            p = S.aggiungi_progetto(d["cartella"])
            self.stato()
            self.manda({"ev": "progetto_aggiunto", "id": p["id"]})
        elif c == "togli_progetto":
            S.togli_progetto(d["progetto"])
            self.stato()
        elif c == "sessioni":
            self.manda({"ev": "sessioni", "progetto": d["progetto"], "sessioni": S.sessioni(d["progetto"])})
        elif c == "apri":
            self.apri(d["progetto"], d.get("sessione"))
        elif c == "elimina_sessione":
            S.elimina_sessione(d["progetto"], d["sessione"])
            self.manda({"ev": "sessioni", "progetto": d["progetto"], "sessioni": S.sessioni(d["progetto"])})
        elif c == "invia":
            if not self.s:
                return self.manda({"ev": "errore", "messaggio": "apri prima un progetto"})
            if self.lavoro and self.lavoro.is_alive():
                return self.manda({"ev": "errore", "messaggio": "sto ancora lavorando: aspetta o fermami"})
            self.lavoro = threading.Thread(target=self._invia, args=(d["testo"],), daemon=True)
            self.lavoro.start()
        elif c == "ferma":
            if self.s:
                self.s.fermo = True
            for ev, _ in list(self.domande.values()):
                ev.set()
        elif c == "permesso":
            if d["id"] in self.domande:
                self.domande[d["id"]][1] = (bool(d.get("si")), bool(d.get("sempre")))
                self.domande[d["id"]][0].set()
        elif c == "annulla_turno":
            fatti = self.s.annulla_turno() if self.s else []
            self.manda({"ev": "annullato", "file": fatti})
        elif c == "modo":
            S.cambia_progetto(d["progetto"], modo=d["valore"])
            if self.s and self.s.p["id"] == d["progetto"]:
                self.s.p["modo"] = d["valore"]
            self.stato()
        elif c == "modelli":
            try:
                self.manda({"ev": "modelli", "fornitore": d["fornitore"], "modelli": fornitori.modelli(d["fornitore"])})
            except Exception as e:
                self.manda({"ev": "modelli", "fornitore": d["fornitore"], "modelli": [], "errore": str(e)})
        elif c == "usa":
            S.salva_impostazioni(fornitore=d["fornitore"], modello=d["modello"])
            if self.s:
                self.s.fornitore, self.s.modello = d["fornitore"], d["modello"]
                self.s.salva()
            self.stato()
        elif c == "chiave":
            fornitori.salva_chiave(d["fornitore"], d.get("valore", ""))
            fornitori._cache.pop(d["fornitore"], None)
            self.stato()
        elif c == "plugin_aggiungi":
            mcp.aggiungi(d["nome"], d["comando"], d.get("descrizione", ""))
            self.stato()
        elif c == "plugin_togli":
            mcp.togli(d["nome"])
            self.stato()
        elif c == "plugin_attiva":
            mcp.attiva(d["nome"], d.get("si", True))
            self.stato()
        else:
            self.manda({"ev": "errore", "messaggio": f"comando sconosciuto: {c}"})

    def _invia(self, testo):
        self.s.invia(testo)
        self.manda({"ev": "sessioni", "progetto": self.s.p["id"], "sessioni": S.sessioni(self.s.p["id"])})

    def ciclo(self):
        self.stato()
        for riga in sys.stdin:
            if not riga.strip():
                continue
            try:
                self.gestisci(json.loads(riga))
            except Exception as e:
                self.manda({"ev": "errore", "messaggio": str(e)})
        if self.s:
            self.s.fermo = True
            self.s.chiudi()


# ── nel terminale ────────────────────────────────────────────────────────────────────────────────────────────────

ORO, TENUE, ROSSO, VERDE, FINE = "\033[33m", "\033[2m", "\033[31m", "\033[32m", "\033[0m"

def terminale():
    cartella = os.getcwd()
    p = next((x for x in S.progetti() if x["cartella"] == str(Path(cartella).resolve())), None) or S.aggiungi_progetto(cartella)
    stato = {"testo": False}

    def emetti(d):
        e = d["ev"]
        if e == "testo":
            if not stato["testo"]:
                print(f"\n{ORO}ciel ›{FINE} ", end="")
                stato["testo"] = True
            print(d["delta"], end="", flush=True)
        elif e == "pensiero":
            pass
        elif e == "fine_messaggio":
            if stato["testo"]:
                print()
            stato["testo"] = False
        elif e == "strumento":
            print(f"{TENUE}  ⏵ {d['etichetta']} {d['dettaglio'][:100]}{FINE}")
        elif e == "esito":
            if not d["ok"]:
                print(f"{ROSSO}    ✗ {d['testo'].splitlines()[0][:120] if d['testo'] else ''}{FINE}")
        elif e in ("errore", "avviso"):
            print(f"{ROSSO if e == 'errore' else ORO}  {d['messaggio']}{FINE}")
        elif e == "fine" and d.get("toccati"):
            print(f"{TENUE}  file toccati: {len(d['toccati'])} (scrivi /annulla per rimetterli com'erano){FINE}")

    def chiedi(info):
        print(f"\n{ORO}  ? {info['etichetta']} {info['dettaglio'][:200]} — {info['motivo']}{FINE}")
        if info.get("anteprima"):
            for r in info["anteprima"].splitlines()[:40]:
                colore = VERDE if r.startswith("+") else ROSSO if r.startswith("-") else TENUE
                print(f"    {colore}{r}{FINE}")
        try:
            r = input(f"  {ORO}[s]ì / [t]utta la sessione / [n]o › {FINE}").strip().lower()
        except EOFError:
            return False, False
        return r in ("s", "si", "sì", "t", "y"), r == "t"

    s = S.Sessione(p["id"], None, emetti, chiedi)
    print(f"{ORO}✦ Ciel Codice{FINE} · {p['nome']} · {s.fornitore}/{s.modello.removeprefix('hf.co/')} · permessi: {p.get('modo')}")
    print(f"{TENUE}  /annulla rimette i file dell'ultimo turno · /modo chiedi|progetto|libero · Ctrl+D per uscire{FINE}")
    try:
        while True:
            try:
                t = input(f"\n{ORO}tu ›{FINE} ").strip()
            except EOFError:
                break
            if not t:
                continue
            if t == "/annulla":
                print("  rimessi:", ", ".join(s.annulla_turno()) or "niente")
                continue
            if t.startswith("/modo "):
                s.p["modo"] = t.split()[1]
                S.cambia_progetto(p["id"], modo=s.p["modo"])
                continue
            try:
                s.invia(t)
            except KeyboardInterrupt:
                s.fermo = True
    finally:
        s.chiudi()
        print()


def apri_app():
    """una sola finestra: se c'è già, la porta davanti (Hyprland); altrimenti la apre"""
    import subprocess
    try:
        finestre = json.loads(subprocess.run(["hyprctl", "clients", "-j"], capture_output=True, text=True, timeout=5).stdout)
        f = next((x for x in finestre if x.get("title") == "Ciel Codice"), None)
    except (OSError, ValueError, subprocess.TimeoutExpired):
        f = None
    if f:
        subprocess.run(["hyprctl", "dispatch", f'hl.dsp.focus({{ window = "address:{f["address"]}" }})'],
                       capture_output=True, timeout=5)
        return
    os.execvp("qs", ["qs", "-n", "-p", str(Path(__file__).resolve().parent.parent / "app")])


def main():
    a = sys.argv[1:]
    if not a:
        return terminale()
    c = a[0]
    if c in ("-h", "--help"):
        print(__doc__)
    elif c == "servi":
        Servizio().ciclo()
    elif c == "app":
        apri_app()
    elif c == "progetti":
        for p in S.progetti():
            print(f"{p['nome']:<24} {p['cartella']}  ({p.get('modo')})")
    elif c == "fornitori":
        for f in fornitori.elenco_fornitori():
            print(f"{'●' if f['pronto'] else '○'} {f['id']:<11} {f['nome']:<22} {f.get('gratis') or ''}")
    elif c == "modelli" and len(a) > 1:
        for m in fornitori.modelli(a[1]):
            print(f"{'gratis ' if m['gratis'] else '       '}{m['id']}")
    elif c == "chiave" and len(a) > 1:
        f = fornitori.FORNITORI[a[1]]
        if f.get("iscrizione"):
            print(f"La chiave si crea qui: {f['iscrizione']}")
        fornitori.salva_chiave(a[1], getpass.getpass("Chiave (vuota per toglierla): "))
        print("Salvata." )
    elif c == "usa" and len(a) > 2:
        S.salva_impostazioni(fornitore=a[1], modello=a[2])
    elif c == "plugin":
        if len(a) == 1:
            for n, v in mcp.leggi().items():
                print(f"{'●' if v.get('attivo', True) else '○'} {n:<16} {' '.join(v['comando'])}")
        elif a[1] == "aggiungi" and len(a) > 3:
            mcp.aggiungi(a[2], a[3:])
        elif a[1] == "togli":
            mcp.togli(a[2])
        elif a[1] in ("accendi", "spegni"):
            mcp.attiva(a[2], a[1] == "accendi")
    else:
        print(__doc__)


if __name__ == "__main__":
    main()
