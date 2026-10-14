"""I plugin di Ciel Codice: server MCP (Model Context Protocol, lo standard dei plugin per agenti) avviati come
processi e interrogati su stdin/stdout con JSON-RPC. Ogni strumento di un plugin arriva al modello come
«mcp__PLUGIN__STRUMENTO». Elenco in ~/.config/cielos/codice/plugin.json:
  {"plugin": {"nome": {"comando": ["npx", "-y", "@modelcontextprotocol/server-filesystem", "~"], "env": {},
                       "attivo": true, "descrizione": "…"}}}
Partono solo quando una sessione li usa, e si fermano con lei."""
import json, os, queue, subprocess, threading
from pathlib import Path

FILE = Path.home() / ".config/cielos/codice/plugin.json"


def leggi():
    try:
        return json.loads(FILE.read_text()).get("plugin", {})
    except (OSError, ValueError):
        return {}

def scrivi(p):
    FILE.parent.mkdir(parents=True, exist_ok=True)
    tmp = FILE.with_suffix(".tmp")
    tmp.write_text(json.dumps({"plugin": p}, indent=2, ensure_ascii=False) + "\n")
    tmp.replace(FILE)

def aggiungi(nome, comando, descrizione="", env=None):
    p = leggi()
    p[nome] = {"comando": comando, "env": env or {}, "attivo": True, "descrizione": descrizione}
    scrivi(p)

def togli(nome):
    p = leggi()
    p.pop(nome, None)
    scrivi(p)

def attiva(nome, si):
    p = leggi()
    if nome in p:
        p[nome]["attivo"] = bool(si)
        scrivi(p)


class Server:
    def __init__(self, nome, conf, cartella):
        self.nome = nome
        cmd = [os.path.expanduser(x) for x in conf["comando"]]
        self.proc = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                                     cwd=cartella, env={**os.environ, **conf.get("env", {})}, text=True, bufsize=1)
        self.n = 0
        self.risposte = {}
        self.coda = queue.Queue()
        threading.Thread(target=self._leggi, daemon=True).start()
        self._chiedi("initialize", {"protocolVersion": "2025-06-18", "capabilities": {},
                                    "clientInfo": {"name": "ciel-codice", "version": "1"}}, 30)
        self._avvisa("notifications/initialized")
        self.strumenti = self._chiedi("tools/list", {}, 30).get("tools", [])

    def _leggi(self):
        for riga in self.proc.stdout:
            try:
                d = json.loads(riga)
            except ValueError:
                continue
            if "id" in d and ("result" in d or "error" in d):
                self.coda.put(d)

    def _avvisa(self, metodo, params=None):
        self.proc.stdin.write(json.dumps({"jsonrpc": "2.0", "method": metodo, "params": params or {}}) + "\n")
        self.proc.stdin.flush()

    def _chiedi(self, metodo, params, attesa=120):
        self.n += 1
        mio = self.n
        self.proc.stdin.write(json.dumps({"jsonrpc": "2.0", "id": mio, "method": metodo, "params": params}) + "\n")
        self.proc.stdin.flush()
        while True:
            d = self.coda.get(timeout=attesa)
            if d["id"] == mio:
                if "error" in d:
                    raise RuntimeError(d["error"].get("message", str(d["error"])))
                return d["result"]

    def chiama(self, strumento, argomenti):
        r = self._chiedi("tools/call", {"name": strumento, "arguments": argomenti})
        pezzi = []
        for c in r.get("content", []):
            if c.get("type") == "text":
                pezzi.append(c["text"])
            else:
                pezzi.append(f"[{c.get('type')}]")
        testo = "\n".join(pezzi)
        return ("Error: " + testo) if r.get("isError") else testo

    def ferma(self):
        try:
            self.proc.terminate()
            self.proc.wait(3)
        except Exception:
            self.proc.kill()


class Plugin:
    """i plugin attivi di una sessione: avviati la prima volta che servono"""
    def __init__(self, cartella):
        self.cartella = cartella
        self.server = {}
        self.errori = {}

    def avvia(self):
        for nome, conf in leggi().items():
            if conf.get("attivo", True) and nome not in self.server and nome not in self.errori:
                try:
                    self.server[nome] = Server(nome, conf, self.cartella)
                except Exception as e:
                    self.errori[nome] = str(e) or type(e).__name__

    def definizioni(self):
        out = []
        for nome, s in self.server.items():
            for t in s.strumenti:
                out.append({"name": f"mcp__{nome}__{t['name']}"[:64],
                            "description": (t.get("description") or "")[:1000] + f" (plugin {nome})",
                            "parameters": t.get("inputSchema") or {"type": "object", "properties": {}}})
        return out

    def chiama(self, nome_completo, argomenti):
        _, plugin, strumento = nome_completo.split("__", 2)
        s = self.server.get(plugin)
        if not s:
            return f"Error: plugin {plugin} not running"
        try:
            return s.chiama(strumento, argomenti)
        except Exception as e:
            return f"Error from plugin {plugin}: {e}"

    def ferma(self):
        for s in self.server.values():
            s.ferma()
        self.server = {}
