"""cield — il sistema nervoso di CielOS.

Raccoglie gli eventi del PC (fonti.py), li manda a chi li ascolta e fa girare le automazioni (regole.py, azioni.py).
Le fonti si accendono solo se a qualcuno servono: a riposo, senza iscritti e senza regole, non ascolta niente.

Socket: $XDG_RUNTIME_DIR/cield.sock (solo il tuo utente), una riga JSON per messaggio:
  {"cmd": "iscrivi", "eventi": ["finestra.*", "gioco.*"]}  -> poi arriva una riga per evento {"evento", "dati", "t"}
  {"cmd": "emetti", "evento": "mio.qualcosa", "dati": {}}  {"cmd": "regole"}  {"cmd": "prova", "testo": "<toml>"}
  {"cmd": "ricarica"}  {"cmd": "registro"}  {"cmd": "stato"}  {"cmd": "esegui", "file": "x.toml"} (prova le azioni)
Comando a mano: cielctl (bin/cielctl)."""
import asyncio, fnmatch, json, os, resource, signal, time
from collections import deque

from . import azioni, fonti, regole

SOCKET = os.path.join(fonti.RT, "cield.sock")
PROFONDITA_MAX = 3            # eventi nati da regole che fanno scattare altre regole: oltre, si ferma (niente cicli)


class Cield:
    def __init__(self):
        self.fonti = [F(self.emetti) for F in fonti.TUTTE]
        self.iscritti = {}               # writer -> [schemi]
        self.regole, self.errori = {}, {}
        self.firma, self.controllata = None, 0.0
        self.registro = deque(maxlen=200)
        self.conteggio = 0
        self.profondita = 0

    # ---------------------------------------------------------- fonti su richiesta
    def _servono(self):
        schemi = [s for v in self.iscritti.values() for s in v]
        for r in self.regole.values():
            if r.attiva:
                schemi.append(r.evento)
                if r.finche:
                    schemi.append(r.finche)
        return schemi

    def aggiorna_fonti(self):
        schemi = self._servono()
        for f in self.fonti:
            serve = any(fnmatch.fnmatchcase(e, s) for e in f.eventi for s in schemi)
            if serve and not f.accesa():
                f.accendi()
                print(f"[cield] accesa la fonte {f.nome}", flush=True)
            elif not serve and f.accesa():
                f.spegni()
                print(f"[cield] spenta la fonte {f.nome}", flush=True)

    # ---------------------------------------------------------- regole
    def ricarica(self, forza=False):
        self.controllata = time.monotonic()
        f = regole.firma()
        if f == self.firma and not forza:
            return False
        vecchie = self.regole
        self.regole, self.errori = regole.carica()
        for nome, r in self.regole.items():         # chi aspettava un «finche» continua ad aspettarlo
            if nome in vecchie:
                r.da_ripristinare, r.ultima = vecchie[nome].da_ripristinare, vecchie[nome].ultima
        self.firma = f
        for nome, e in self.errori.items():
            print(f"[cield] regola {nome} non valida: {'; '.join(e)}", flush=True)
        print(f"[cield] {len(self.regole)} automazioni", flush=True)
        self.aggiorna_fonti()
        return True

    def emetti(self, evento, dati=None, profondita=0):
        dati = dati or {}
        self.conteggio += 1
        if time.monotonic() - self.controllata > 2:  # le regole cambiate si vedono al primo evento (e da «ricarica»)
            self.ricarica()
        riga = (json.dumps({"evento": evento, "dati": dati, "t": round(time.time(), 3)}, ensure_ascii=False) + "\n").encode()
        for w, schemi in list(self.iscritti.items()):
            if any(fnmatch.fnmatchcase(evento, s) for s in schemi):
                try:
                    w.write(riga)
                except (ConnectionError, RuntimeError):
                    self.iscritti.pop(w, None)
        if profondita > PROFONDITA_MAX:
            return
        loop = asyncio.get_running_loop()
        for r in self.regole.values():
            if r.finche and r.da_ripristinare and fnmatch.fnmatchcase(evento, r.finche):
                ripr, r.da_ripristinare = r.da_ripristinare, []
                loop.create_task(self._fai(r, [{"azione": a, **p} for a, p in reversed(ripr)], evento, profondita,
                                           ripristino=True))
            if r.vale(evento, dati):
                r.ultima = time.time()
                loop.create_task(self._fai(r, r.azioni_pronte(dati), evento, profondita))

    async def _fai(self, r, lista, evento, profondita, ripristino=False):
        esiti = []
        for a in lista:
            nome = a.get("azione")
            p = {k: v for k, v in a.items() if k != "azione"}
            try:
                if nome == "emetti":
                    self.emetti(str(p.get("evento")), p.get("dati") or {}, profondita + 1)
                    esito = f"evento {p.get('evento')}"
                else:
                    esito, prima = await azioni.CATALOGO[nome](**p)
                    if r.finche and not ripristino and prima is not None:
                        r.da_ripristinare.append((nome, prima))
                esiti.append(esito)
            except Exception as e:
                esiti.append(f"ERRORE {nome}: {e}")
        voce = {"t": round(time.time()), "regola": r.nome, "evento": evento, "ripristino": ripristino, "esiti": esiti}
        self.registro.append(voce)
        print(f"[cield] {r.nome}{' (ripristino)' if ripristino else ''} <- {evento}: {'; '.join(esiti)}", flush=True)

    # ---------------------------------------------------------- socket
    async def cliente(self, r, w):
        try:
            async for riga in r:
                try:
                    m = json.loads(riga)
                    risposta = await self.comando(m, w)
                except Exception as e:
                    risposta = {"ok": False, "errore": str(e)}
                if risposta is not None:
                    w.write((json.dumps(risposta, ensure_ascii=False) + "\n").encode())
                    await w.drain()
        except (ConnectionError, asyncio.IncompleteReadError):
            pass
        finally:
            if self.iscritti.pop(w, None) is not None:
                self.aggiorna_fonti()
            w.close()

    async def comando(self, m, w):
        c = m.get("cmd")
        if c == "iscrivi":
            self.iscritti[w] = [str(s) for s in (m.get("eventi") or ["*"])]
            self.aggiorna_fonti()
            return {"ok": True, "iscritto": self.iscritti[w]}
        if c == "emetti":
            ev = str(m.get("evento") or "")
            if not ev.startswith(("ciel.", "mio.")):
                return {"ok": False, "errore": "da fuori si possono mandare solo eventi ciel.* e mio.*"}
            self.emetti(ev, m.get("dati") or {})
            return {"ok": True}
        if c == "regole":
            self.ricarica()
            return {"ok": True, "regole": [{"file": n, "nome": r.nome, "attiva": r.attiva, "descrizione": r.descrizione()}
                                           for n, r in self.regole.items()],
                    "errori": self.errori, "cartella": str(regole.CARTELLA)}
        if c == "prova":
            reg, err = regole.da_testo(str(m.get("testo") or ""))
            return {"ok": not err, "errori": err, "descrizione": reg.descrizione() if reg and not err else ""}
        if c == "ricarica":
            self.ricarica(forza=True)
            return {"ok": True, "regole": len(self.regole), "errori": self.errori}
        if c == "esegui":
            self.ricarica()
            reg = self.regole.get(str(m.get("file")))
            if not reg:
                return {"ok": False, "errore": "regola non trovata"}
            await self._fai(reg, reg.azioni_pronte({}), "prova a mano", 0)
            return {"ok": True, "esiti": self.registro[-1]["esiti"]}
        if c == "registro":
            return {"ok": True, "registro": list(self.registro)[-int(m.get("n", 30)):]}
        if c == "stato":
            return {"ok": True, "fonti": {f.nome: f.accesa() for f in self.fonti}, "iscritti": len(self.iscritti),
                    "regole": len(self.regole), "eventi": self.conteggio,
                    "memoria_mb": round(resource.getrusage(resource.RUSAGE_SELF).ru_maxrss / 1024, 1)}
        return {"ok": False, "errore": f"comando sconosciuto: {c}"}


async def principale():
    c = Cield()
    c.ricarica(forza=True)
    try:
        os.unlink(SOCKET)
    except FileNotFoundError:
        pass
    vecchia = os.umask(0o077)                 # il socket è solo tuo
    server = await asyncio.start_unix_server(c.cliente, SOCKET, limit=1 << 20)
    os.umask(vecchia)
    loop = asyncio.get_running_loop()
    loop.add_signal_handler(signal.SIGHUP, lambda: c.ricarica(forza=True))
    fine = asyncio.Event()
    for s in (signal.SIGTERM, signal.SIGINT):
        loop.add_signal_handler(s, fine.set)
    print(f"[cield] in ascolto su {SOCKET}", flush=True)
    c.emetti("cield.avvio", {})
    async with server:
        await fine.wait()
    for f in c.fonti:
        f.spegni()


if __name__ == "__main__":
    asyncio.run(principale())
