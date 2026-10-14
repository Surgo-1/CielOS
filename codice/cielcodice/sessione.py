"""Progetti, sessioni e il ciclo dell'agente.
Un progetto è una cartella (con il suo modo dei permessi e il suo modello preferito); dentro, tante sessioni salvate
(conversazioni da riprendere). Ogni turno: il modello risponde, se chiede strumenti si eseguono (chiedendo il permesso
quando serve) e si ricomincia, finché risponde senza strumenti. Le istruzioni: quelle di CielOS (qui sotto), più
~/.config/cielos/codice/AGENTS.md (tue, per tutti i progetti) e AGENTS.md nella cartella del progetto."""
import json, re, time, uuid
from pathlib import Path

from . import fornitori, mcp, tr
from .strumenti import DEFINIZIONI, ETICHETTE, Strumenti

DATI = Path.home() / ".local/share/cielos/codice"
PROGETTI = DATI / "progetti.json"
IMPOSTAZIONI = fornitori.CARTELLA / "impostazioni.json"
MAX_PASSI = 60

ISTRUZIONI = """You are Ciel Codice, the coding agent of CielOS (an Arch Linux based OS built around Ciel, a local
voice assistant; desktop: Hyprland with the Ciel shell written in Quickshell/QML; shell: fish; packages: pacman).
You work inside the user's project folder: {radice}
Rules:
- Always answer in Italian, briefly and clearly. Code, file names and commands stay as they are.
- Explore before changing: list_dir, search, read_file. Never guess file contents.
- Make focused changes with edit_file (exact text); use write_file for new files or full rewrites.
- Match the style of the surrounding code (names, comments, language of comments).
- After changing code, verify it when possible (run the tests, a build, or a quick check with run_command).
- No sudo and no system-wide changes: if something needs admin rights, explain it and give the user the command.
- Never delete or overwrite the user's data outside the project. Ask when unsure.
- When done, say in a few lines what you changed and what you checked.
Today is {oggi}."""


# ── impostazioni e progetti ──────────────────────────────────────────────────────────────────────────────────────

def _leggi(p, serie):
    try:
        return json.loads(p.read_text())
    except (OSError, ValueError):
        return serie

def _scrivi(p, d):
    p.parent.mkdir(parents=True, exist_ok=True)
    tmp = p.with_suffix(".tmp")
    tmp.write_text(json.dumps(d, indent=2, ensure_ascii=False) + "\n")
    tmp.replace(p)

def impostazioni():
    i = _leggi(IMPOSTAZIONI, {})
    i.setdefault("contesto", 16384)
    if not i.get("modello") or (i.get("fornitore", "ollama") == "ollama" and not _ce_ancora(i["modello"])):
        i["fornitore"], i["modello"] = "ollama", modello_locale_di_serie()     # mai scelto, o disinstallato
    return i

def salva_impostazioni(**k):
    i = _leggi(IMPOSTAZIONI, {})
    i.update(k)
    _scrivi(IMPOSTAZIONI, i)

def _ce_ancora(modello):
    try:
        return any(m["id"] == modello for m in fornitori.modelli("ollama"))
    except OSError:
        return True                       # Ollama non risponde: non è colpa del modello, lo si lascia com'è

def modello_locale_di_serie():
    """tra i modelli locali che sanno usare gli strumenti: prima uno «coder», poi il più grande che c'è"""
    try:
        ms = fornitori.modelli("ollama")
    except OSError:
        return ""
    if not ms:
        return ""
    coder = [m for m in ms if "coder" in m["id"].lower()]
    return (coder or sorted(ms, key=lambda m: -m.get("dimensione_gb", 0)))[0]["id"]

def progetti():
    return _leggi(PROGETTI, [])

def aggiungi_progetto(cartella, nome=None):
    c = Path(cartella).expanduser().resolve()
    if not c.is_dir():
        raise ValueError(tr("non è una cartella: %1", c))
    ps = progetti()
    for p in ps:
        if p["cartella"] == str(c):
            return p
    p = {"id": uuid.uuid4().hex[:10], "nome": nome or c.name, "cartella": str(c), "modo": "progetto",
         "aggiunto": time.time()}
    ps.append(p)
    _scrivi(PROGETTI, ps)
    return p

def cambia_progetto(pid, **k):
    ps = progetti()
    for p in ps:
        if p["id"] == pid:
            p.update(k)
    _scrivi(PROGETTI, ps)

def togli_progetto(pid):
    """lo toglie dall'elenco (la cartella e le sue sessioni restano su disco)"""
    _scrivi(PROGETTI, [p for p in progetti() if p["id"] != pid])

def progetto(pid):
    return next((p for p in progetti() if p["id"] == pid), None)

def suggerimenti(limite=30):
    """cartelle che sembrano progetti (con .git) nella home, fino a due livelli: per aggiungerle con un clic"""
    casa = Path.home()
    gia = {p["cartella"] for p in progetti()}
    out = []
    for g in list(casa.glob("*/.git")) + list(casa.glob("*/*/.git")):
        c = g.parent
        if any(x.startswith(".") for x in c.relative_to(casa).parts) or str(c) in gia:
            continue
        out.append({"cartella": str(c), "nome": c.name, "modificata": c.stat().st_mtime})
    return sorted(out, key=lambda x: -x["modificata"])[:limite]


# ── sessioni ─────────────────────────────────────────────────────────────────────────────────────────────────────

def _cartella_sessioni(pid):
    return DATI / "sessioni" / pid

def sessioni(pid):
    out = []
    for f in _cartella_sessioni(pid).glob("*.json"):
        d = _leggi(f, None)
        if d:
            out.append({"id": d["id"], "titolo": d.get("titolo", ""), "aggiornata": d.get("aggiornata", 0),
                        "modello": d.get("modello", "")})
    return sorted(out, key=lambda x: -x["aggiornata"])

def elimina_sessione(pid, sid):
    (_cartella_sessioni(pid) / f"{sid}.json").unlink(missing_ok=True)


class Sessione:
    def __init__(self, pid, sid=None, emetti=print, chiedi=None):
        self.p = progetto(pid)
        if not self.p:
            raise ValueError(tr("progetto sconosciuto"))
        self.emetti = emetti
        self.chiedi = chiedi or (lambda info: (False, False))
        self.id = sid or time.strftime("%Y%m%d-%H%M%S-") + uuid.uuid4().hex[:4]
        self.file = _cartella_sessioni(pid) / f"{self.id}.json"
        d = _leggi(self.file, {}) if sid else {}
        self.messaggi = d.get("messaggi", [])
        self.titolo = d.get("titolo", "")
        imp = impostazioni()
        self.fornitore = d.get("fornitore") or self.p.get("fornitore") or imp["fornitore"]
        self.modello = d.get("modello") or self.p.get("modello") or imp["modello"]
        self.contesto = imp["contesto"]
        self.permessi_sessione = set()          # strumenti approvati «per questa sessione»
        self.fermo = False
        self.ultimo_turno = None                # gli Strumenti dell'ultimo turno: per annullarlo
        self.plugin = mcp.Plugin(self.p["cartella"])

    def salva(self):
        _scrivi(self.file, {"id": self.id, "titolo": self.titolo, "creata": self.id[:15], "aggiornata": time.time(),
                            "fornitore": self.fornitore, "modello": self.modello, "messaggi": self.messaggi})

    def istruzioni(self):
        testo = ISTRUZIONI.format(radice=self.p["cartella"], oggi=time.strftime("%d/%m/%Y"))
        for f, chi in ((fornitori.CARTELLA / "AGENTS.md", "the user (for all projects)"),
                       (Path(self.p["cartella"]) / "AGENTS.md", "this project")):
            if f.is_file():
                testo += f"\n\nInstructions from {chi} ({f.name}):\n" + f.read_text(errors="replace")[:12000]
        return testo

    def _strumenti(self):
        defs = [{"type": "function", "function": d} for d in DEFINIZIONI]
        self.plugin.avvia()
        defs += [{"type": "function", "function": d} for d in self.plugin.definizioni()]
        return defs

    def _compatta(self, messaggi):
        """se la storia sta per non entrare nel contesto, le uscite vecchie degli strumenti si accorciano"""
        bilancio = self.contesto * 3                          # ~3 caratteri per token, tenendo margine
        tot = sum(len(json.dumps(m)) for m in messaggi)
        if tot <= bilancio:
            return messaggi
        out = [dict(m) for m in messaggi]
        for m in out[1:-6]:
            if m["role"] == "tool" and len(m.get("content", "")) > 400:
                m["content"] = m["content"][:300] + "\n[… output shortened to save context]"
                tot = sum(len(json.dumps(x)) for x in out)
                if tot <= bilancio:
                    break
        return out

    def invia(self, testo):
        self.fermo = False
        if not self.titolo:
            self.titolo = re.sub(r"\s+", " ", testo).strip()[:70]
        self.messaggi.append({"role": "user", "content": testo})
        self.salva()
        if not self.modello:
            self.emetti({"ev": "errore", "messaggio": tr("Nessun modello: scaricane uno dal riquadro (Super+A → Scarica modelli; "
                                                          "serve uno che sappia usare gli strumenti) o collega un servizio "
                                                          "gratuito in cloud (in basso a sinistra: «Modelli in cloud e plugin»).")})
            self.emetti({"ev": "fine"})
            return
        turno = Strumenti(self.p["cartella"], self.p.get("modo", "progetto"),
                          self.file.parent / f"{self.id}.copie" / str(len(self.messaggi)))
        self.ultimo_turno = turno
        try:
            defs = self._strumenti()
            for e in self.plugin.errori.items():
                self.emetti({"ev": "avviso", "messaggio": tr("Il plugin %1 non parte: %2", e[0], e[1])})
            for _ in range(MAX_PASSI):
                storia = [{"role": "system", "content": self.istruzioni()}] + self._compatta(self.messaggi)
                fine = None
                for tipo, x in fornitori.parla(self.fornitore, self.modello, storia, defs, lambda: self.fermo,
                                               self.contesto):
                    if tipo in ("testo", "pensiero"):
                        self.emetti({"ev": tipo, "delta": x})
                    elif tipo == "avviso":
                        self.emetti({"ev": "avviso", "messaggio": x})
                    elif tipo == "fine":
                        fine = x
                m = {"role": "assistant", "content": fine["testo"]}
                if fine["chiamate"]:
                    m["tool_calls"] = [{"id": c["id"], "type": "function",
                                        "function": {"name": c["nome"], "arguments": json.dumps(c["argomenti"], ensure_ascii=False)}}
                                       for c in fine["chiamate"]]
                self.messaggi.append(m)
                self.emetti({"ev": "fine_messaggio"})
                if not fine["chiamate"]:
                    break
                for c in fine["chiamate"]:
                    if self.fermo:
                        raise fornitori.Fermato()
                    self.messaggi.append({"role": "tool", "tool_call_id": c["id"], "name": c["nome"],
                                          "content": self._usa(turno, c)})
                self.salva()
            else:
                self.emetti({"ev": "avviso", "messaggio": tr("Mi fermo dopo %1 passi: dimmi se continuo.", MAX_PASSI)})
        except fornitori.Fermato:
            self.emetti({"ev": "avviso", "messaggio": "Fermato."})
        except Exception as e:
            self.emetti({"ev": "errore", "messaggio": str(e)})
        finally:
            # una chiamata a strumento rimasta senza risposta romperebbe la storia: si chiude
            richieste = next((m for m in reversed(self.messaggi) if m["role"] == "assistant"), None)
            risposte = {m.get("tool_call_id") for m in self.messaggi if m["role"] == "tool"}
            for c in (richieste or {}).get("tool_calls") or []:
                if c["id"] not in risposte:
                    self.messaggi.append({"role": "tool", "tool_call_id": c["id"], "name": c["function"]["name"],
                                          "content": "Not executed (stopped)."})
            self.salva()
            self.emetti({"ev": "fine", "toccati": [str(p) for p, _ in turno.toccati]})

    def _usa(self, turno, c):
        nome, a = c["nome"], c["argomenti"] if isinstance(c["argomenti"], dict) else {}
        etichetta = tr(ETICHETTE.get(nome) or "") or (("Plugin " + nome.split("__")[1]) if nome.startswith("mcp__") else nome)
        dettaglio = a.get("path") or a.get("command") or a.get("pattern") or ""
        self.emetti({"ev": "strumento", "id": c["id"], "nome": nome, "etichetta": etichetta, "dettaglio": dettaglio,
                     "argomenti": a})
        if "_non_valido" in a:
            r = "Error: the arguments are not valid JSON. Call the tool again with valid JSON arguments."
            self.emetti({"ev": "esito", "id": c["id"], "ok": False, "testo": r})
            return r
        motivo = turno.serve_permesso(nome, a)
        if motivo == "NO":
            r = "Not allowed: the project is in plan mode (read only). Describe the change instead of making it."
            self.emetti({"ev": "esito", "id": c["id"], "ok": False, "testo": tr("modo piano: solo lettura")})
            return r
        approvato = False
        if motivo and (nome not in self.permessi_sessione or "pericoloso" in motivo):
            anteprima = ""
            if nome == "edit_file":
                from .strumenti import diff
                anteprima = diff(a.get("old_text", ""), a.get("new_text", ""), a.get("path", ""))
            elif nome == "write_file":
                anteprima = a.get("content", "")[:3000]
            si, sempre = self.chiedi({"id": c["id"], "nome": nome, "etichetta": etichetta, "dettaglio": dettaglio,
                                      "motivo": motivo, "anteprima": anteprima})
            if not si:
                r = "The user did not allow this. Do not retry the same action; ask or try another way."
                self.emetti({"ev": "esito", "id": c["id"], "ok": False, "testo": tr("non permesso")})
                return r
            approvato = True
            if sempre:
                self.permessi_sessione.add(nome)
        if nome.startswith("mcp__"):
            r = self.plugin.chiama(nome, a)
        else:
            r = turno.esegui(nome, a, approvato)
        self.emetti({"ev": "esito", "id": c["id"], "ok": not r.startswith("Error"), "testo": r[:4000]})
        return r

    def annulla_turno(self):
        if not self.ultimo_turno:
            return []
        return self.ultimo_turno.annulla()

    def vista(self):
        """la storia per l'app: messaggi tuoi, risposte, strumenti usati con il loro esito"""
        out, esiti = [], {m["tool_call_id"]: m["content"] for m in self.messaggi if m["role"] == "tool"}
        for m in self.messaggi:
            if m["role"] == "user":
                out.append({"tipo": "tu", "testo": m["content"]})
            elif m["role"] == "assistant":
                if m.get("content"):
                    out.append({"tipo": "ciel", "testo": m["content"]})
                for c in m.get("tool_calls") or []:
                    a = fornitori._json_o_vuoto(c["function"]["arguments"])
                    n = c["function"]["name"]
                    r = esiti.get(c["id"], "")
                    out.append({"tipo": "strumento", "id": c["id"], "nome": n,
                                "etichetta": tr(ETICHETTE.get(n, n)), "dettaglio": a.get("path") or a.get("command") or a.get("pattern") or "",
                                "ok": not r.startswith(("Error", "The user did not", "Not executed")), "testo": r[:4000]})
        return out

    def chiudi(self):
        self.plugin.ferma()
