"""Da dove vengono i modelli: Ollama (locali, con l'API sua: si sceglie il contesto) e i servizi in cloud compatibili con
l'API di OpenAI. Quelli in elenco hanno un piano gratuito; per usarli serve un account tuo e la sua chiave, che si
incolla nell'app (resta in ~/.config/cielos/codice/chiavi.json, leggibile solo da te, e non finisce mai nei registri).
Ogni fornitore sa: elencare i modelli (quelli gratuiti segnati) e parlare in streaming con gli strumenti."""
import json, os, re, time, urllib.error, urllib.request
from pathlib import Path

CARTELLA = Path.home() / ".config/cielos/codice"
CHIAVI = CARTELLA / "chiavi.json"
OLLAMA = "http://" + os.environ.get("OLLAMA_HOST", "127.0.0.1:11434").removeprefix("http://")

FORNITORI = {
    "ollama": {"nome": "Sul tuo PC (Ollama)", "tipo": "ollama", "url": OLLAMA, "chiave": False,
               "nota": "I modelli che hai scaricato. Niente esce dal PC."},
    "openrouter": {"nome": "OpenRouter", "tipo": "openai", "url": "https://openrouter.ai/api/v1",
                   "iscrizione": "https://openrouter.ai/keys", "gratis": "i modelli che finiscono in «:free»",
                   "nota": "Centinaia di modelli; alcuni gratuiti, con un limite di richieste al giorno."},
    "gemini": {"nome": "Google Gemini", "tipo": "openai", "url": "https://generativelanguage.googleapis.com/v1beta/openai",
               "iscrizione": "https://aistudio.google.com/apikey", "gratis": "piano gratuito con limiti al minuto e al giorno",
               "nota": "Nel piano gratuito Google può usare le conversazioni per migliorare i suoi modelli."},
    "groq": {"nome": "Groq", "tipo": "openai", "url": "https://api.groq.com/openai/v1",
             "iscrizione": "https://console.groq.com/keys", "gratis": "piano gratuito con limiti al minuto",
             "nota": "Velocissimo; modelli aperti (Llama, Qwen, GPT-OSS…)."},
    "cerebras": {"nome": "Cerebras", "tipo": "openai", "url": "https://api.cerebras.ai/v1",
                 "iscrizione": "https://cloud.cerebras.ai", "gratis": "piano gratuito con limiti giornalieri",
                 "nota": "Molto veloce; modelli aperti."},
    "mistral": {"nome": "Mistral", "tipo": "openai", "url": "https://api.mistral.ai/v1",
                "iscrizione": "https://console.mistral.ai/api-keys", "gratis": "piano «Experiment» gratuito",
                "nota": "Europeo (Codestral, Devstral, Mistral)."},
}


# ── chiavi ───────────────────────────────────────────────────────────────────────────────────────────────────────

def chiavi():
    try:
        return json.loads(CHIAVI.read_text())
    except (OSError, ValueError):
        return {}

def salva_chiave(fornitore, valore):
    if fornitore not in FORNITORI or not FORNITORI[fornitore].get("chiave", True):
        raise ValueError(f"fornitore sconosciuto: {fornitore}")
    c = chiavi()
    if valore:
        c[fornitore] = valore.strip()
    else:
        c.pop(fornitore, None)
    CARTELLA.mkdir(parents=True, exist_ok=True)
    tmp = CHIAVI.with_suffix(".tmp")
    fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w") as f:
        json.dump(c, f)
    tmp.replace(CHIAVI)
    os.chmod(CHIAVI, 0o600)

def pronto(fornitore):
    f = FORNITORI[fornitore]
    return not f.get("chiave", True) or bool(chiavi().get(fornitore))

def elenco_fornitori():
    return [{"id": k, "nome": f["nome"], "pronto": pronto(k), "chiave": f.get("chiave", True),
             "iscrizione": f.get("iscrizione"), "gratis": f.get("gratis"), "nota": f.get("nota")}
            for k, f in FORNITORI.items()]


# ── modelli ──────────────────────────────────────────────────────────────────────────────────────────────────────

_cache = {}

def _get(url, chiave=None, timeout=15):
    h = {"User-Agent": "CielOS-codice/1"}
    if chiave:
        h["Authorization"] = f"Bearer {chiave}"
    with urllib.request.urlopen(urllib.request.Request(url, headers=h), timeout=timeout) as r:
        return json.loads(r.read())

def modelli(fornitore):
    """[{id, nome, gratis, contesto}] — solo quelli che sanno usare gli strumenti, dove il fornitore lo dice"""
    if fornitore in _cache and time.time() - _cache[fornitore][0] < 600:
        return _cache[fornitore][1]
    f = FORNITORI[fornitore]
    out = []
    if f["tipo"] == "ollama":
        spenti = set()
        try:
            spenti = set(json.loads((Path.home() / ".config/cielos/modelli.json").read_text()).get("spenti", []))
        except (OSError, ValueError):
            pass
        for m in _get(f["url"] + "/api/tags").get("models", []):
            if m["name"] in spenti:
                continue
            try:
                cap = _post_json(f["url"] + "/api/show", {"model": m["name"]}).get("capabilities", [])
            except OSError:
                cap = []
            if "tools" not in cap:
                continue
            out.append({"id": m["name"], "nome": m["name"].removeprefix("hf.co/"), "gratis": True,
                        "dimensione_gb": round(m.get("size", 0) / 1e9, 1)})
    else:
        k = chiavi().get(fornitore)
        if not k:
            return []
        d = _get(f["url"] + "/models", k)
        for m in d.get("data", d if isinstance(d, list) else []):
            mid = m.get("id", "")
            if fornitore == "openrouter":
                prezzo = m.get("pricing", {})
                gratis = str(prezzo.get("prompt")) in ("0", "0.0") and str(prezzo.get("completion")) in ("0", "0.0")
                if "tools" not in (m.get("supported_parameters") or []):
                    continue
                out.append({"id": mid, "nome": m.get("name", mid), "gratis": gratis, "contesto": m.get("context_length")})
            else:
                if any(x in mid for x in ("embed", "whisper", "tts", "guard", "image", "audio", "moderation", "imagen", "veo")):
                    continue
                out.append({"id": mid.removeprefix("models/"), "nome": mid.removeprefix("models/"), "gratis": True,
                            "contesto": m.get("context_window") or m.get("max_context_length")})
        out.sort(key=lambda x: (not x["gratis"], x["nome"].lower()))
    _cache[fornitore] = (time.time(), out)
    return out

def _post_json(url, dati, timeout=15):
    req = urllib.request.Request(url, data=json.dumps(dati).encode(), headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read())


# ── parlare, in streaming ────────────────────────────────────────────────────────────────────────────────────────
# Si passa la storia in formato OpenAI (role/content/tool_calls/tool_call_id) e gli strumenti in formato OpenAI;
# escono pezzi: ("testo", s) ("pensiero", s) e alla fine ("fine", {"testo", "chiamate": [{id, nome, argomenti}]}).

class Fermato(Exception):
    pass

def parla(fornitore, modello, messaggi, strumenti, fermo=lambda: False, contesto=16384):
    f = FORNITORI[fornitore]
    if f["tipo"] == "ollama":
        # CIEL_CODICE_CPU=1: solo processore (le prove, o quando la scheda video serve ad altro)
        solo_cpu = os.environ.get("CIEL_CODICE_CPU") == "1"
        try:
            yield from _parla_ollama(f["url"], modello, messaggi, strumenti, fermo, contesto, solo_cpu)
        except RuntimeError as e:
            # la scheda video è piena (Ciel, un gioco): si riprova sul processore, più lento ma funziona
            if solo_cpu or not re.search(r"out of memory|cudaMalloc|CUDA error", str(e), re.I):
                raise
            yield "avviso", "La scheda video è piena: uso il processore (più lento)."
            yield from _parla_ollama(f["url"], modello, messaggi, strumenti, fermo, contesto, True)
    else:
        k = chiavi().get(fornitore)
        if not k:
            raise RuntimeError(f"manca la chiave di {f['nome']}: aggiungila nelle impostazioni di Codice")
        yield from _parla_openai(f["url"], k, modello, messaggi, strumenti, fermo, fornitore)

def _parla_ollama(url, modello, messaggi, strumenti, fermo, contesto, solo_cpu=False):
    # l'API sua (non quella compatibile): così si sceglie il contesto, che di serie è piccolo
    msg = []
    for m in messaggi:
        x = {"role": m["role"], "content": m.get("content") or ""}
        if m.get("tool_calls"):
            x["tool_calls"] = [{"function": {"name": c["function"]["name"],
                                             "arguments": _json_o_vuoto(c["function"]["arguments"])}}
                               for c in m["tool_calls"]]
        if m["role"] == "tool":
            x["tool_name"] = m.get("name", "")
        msg.append(x)
    corpo = {"model": modello, "messages": msg, "tools": strumenti, "stream": True,
             "options": {"num_ctx": contesto, **({"num_gpu": 0} if solo_cpu else {})}, "keep_alive": "15m"}
    req = urllib.request.Request(url + "/api/chat", data=json.dumps(corpo).encode(),
                                 headers={"Content-Type": "application/json"})
    testo, chiamate = "", []
    try:
        r = urllib.request.urlopen(req, timeout=600)
    except urllib.error.HTTPError as e:
        raise RuntimeError(_errore_http(e)) from None
    with r:
        for riga in r:
            if fermo():
                raise Fermato()
            if not riga.strip():
                continue
            d = json.loads(riga)
            if d.get("error"):
                raise RuntimeError(d["error"])
            m = d.get("message") or {}
            if m.get("thinking"):
                yield "pensiero", m["thinking"]
            if m.get("content"):
                testo += m["content"]
                yield "testo", m["content"]
            for i, c in enumerate(m.get("tool_calls") or []):
                fn = c.get("function", {})
                chiamate.append({"id": f"c{len(chiamate)}_{int(time.time() * 1000) % 100000}", "nome": fn.get("name", ""),
                                 "argomenti": fn.get("arguments") or {}})
            if d.get("done"):
                break
    yield "fine", {"testo": testo, "chiamate": chiamate}

def _parla_openai(url, chiave, modello, messaggi, strumenti, fermo, fornitore):
    corpo = {"model": modello, "messages": messaggi, "stream": True}
    if strumenti:
        corpo["tools"] = strumenti
    h = {"Content-Type": "application/json", "Authorization": f"Bearer {chiave}", "User-Agent": "CielOS-codice/1"}
    if fornitore == "openrouter":
        h.update({"HTTP-Referer": "https://cielos.local", "X-Title": "Ciel Codice"})
    req = urllib.request.Request(url + "/chat/completions", data=json.dumps(corpo).encode(), headers=h)
    testo, parti = "", {}
    try:
        r = urllib.request.urlopen(req, timeout=600)
    except urllib.error.HTTPError as e:
        raise RuntimeError(_errore_http(e)) from None
    with r:
        for riga in r:
            if fermo():
                raise Fermato()
            riga = riga.decode(errors="replace").strip()
            if not riga.startswith("data:"):
                continue
            dati = riga[5:].strip()
            if dati == "[DONE]":
                break
            d = json.loads(dati)
            if d.get("error"):
                raise RuntimeError(d["error"].get("message", str(d["error"])))
            for sc in d.get("choices", []):
                delta = sc.get("delta") or {}
                ragiona = delta.get("reasoning") or delta.get("reasoning_content")
                if ragiona:
                    yield "pensiero", ragiona
                if delta.get("content"):
                    testo += delta["content"]
                    yield "testo", delta["content"]
                for c in delta.get("tool_calls") or []:
                    p = parti.setdefault(c.get("index", 0), {"id": "", "nome": "", "arg": ""})
                    p["id"] = c.get("id") or p["id"]
                    fn = c.get("function") or {}
                    p["nome"] += fn.get("name") or ""
                    p["arg"] += fn.get("arguments") or ""
    chiamate = [{"id": p["id"] or f"c{i}", "nome": p["nome"], "argomenti": _json_o_vuoto(p["arg"])}
                for i, p in sorted(parti.items())]
    yield "fine", {"testo": testo, "chiamate": chiamate}

def _json_o_vuoto(s):
    if isinstance(s, dict):
        return s
    try:
        return json.loads(s) if s else {}
    except ValueError:
        return {"_non_valido": s}

def _errore_http(e):
    try:
        corpo = e.read().decode(errors="replace")[:400]
    except Exception:
        corpo = ""
    if e.code == 401:
        return "chiave non valida (401): controllala nelle impostazioni di Codice"
    if e.code == 429:
        return "troppe richieste (429): il piano gratuito ha un limite, riprova tra poco o cambia modello"
    if e.code == 404:
        return f"modello non trovato (404). {corpo}"
    return f"errore {e.code}: {corpo}"
