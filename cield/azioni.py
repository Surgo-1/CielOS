"""Il catalogo delle azioni che le automazioni possono fare. Un elenco fisso: niente da amministratore.

Ogni azione è una funzione asincrona azione(**parametri) -> (esito, ripristino). «ripristino» (o None) sono i
parametri per tornare com'era prima: servono alle regole con «finche» (es. finché giochi: profilo prestazioni,
poi torna quello di prima).

  notifica {titolo, testo}                      non_disturbare {attivo}
  profilo_energetico {valore: risparmio|bilanciato|prestazioni}
  volume {valore: 0-100 oppure "+5"/"-5"}       muto {attivo}
  media {comando: pausa|riprendi|successivo|precedente}
  apri {comando}                                chiudi {classe}
  ciel_di {testo}         (Ciel lo dice a voce)  ciel_silenzio {attivo}   (Ciel risponde solo per iscritto)
  emetti {evento, dati}   (un evento tuo, per collegare regole)
  attendi {secondi}
  comando {cmd}           (un comando qualsiasi, come utente: lo vedi scritto nella regola prima di approvarla)"""
import asyncio, json, os, re, urllib.request

from . import fonti

RT = fonti.RT
PROFILI = {"risparmio": "power-saver", "bilanciato": "balanced", "prestazioni": "performance"}
PROFILI_INV = {v: k for k, v in PROFILI.items()}


async def _esegui(*cmd, timeout=10):
    p = await asyncio.create_subprocess_exec(*cmd, stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE)
    try:
        out, err = await asyncio.wait_for(p.communicate(), timeout)
    except asyncio.TimeoutError:
        p.kill()
        raise RuntimeError(f"{cmd[0]}: non risponde")
    if p.returncode:
        raise RuntimeError(f"{cmd[0]}: {(err or out).decode(errors='replace').strip()[:150]}")
    return out.decode(errors="replace").strip()


def _vero(v):
    return v if isinstance(v, bool) else str(v).lower() in ("1", "si", "sì", "true", "vero", "on")


async def notifica(titolo="CielOS", testo=""):
    await _esegui("notify-send", "-a", "CielOS", str(titolo), str(testo))
    return "notifica mandata", None


async def non_disturbare(attivo=True):
    attivo = _vero(attivo)
    shell = "ciel" if os.path.exists(os.path.expanduser("~/.config/cielos/shell-attiva")) else "caelestia"
    await _esegui("qs", "-c", shell, "ipc", "call", "notifs", "enableDnd" if attivo else "disableDnd")
    return f"non disturbare {'acceso' if attivo else 'spento'}", {"attivo": not attivo}


async def profilo_energetico(valore="bilanciato"):
    if valore not in PROFILI:
        raise ValueError(f"profilo sconosciuto: {valore} (risparmio, bilanciato, prestazioni)")
    prima = PROFILI_INV.get(await _esegui("powerprofilesctl", "get"), "bilanciato")
    await _esegui("powerprofilesctl", "set", PROFILI[valore])
    return f"profilo {valore}", {"valore": prima}


async def volume(valore=50):
    vecchio = await _esegui("wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@")
    m = re.search(r"([\d.]+)", vecchio)
    prima = round(float(m.group(1)) * 100) if m else None
    v = str(valore).strip()
    if v[:1] in "+-":
        arg = f"{abs(int(v))}%{v[0]}"
    else:
        arg = f"{max(0, min(100, int(v)))}%"
    await _esegui("wpctl", "set-volume", "-l", "1.0", "@DEFAULT_AUDIO_SINK@", arg)
    return f"volume {arg}", ({"valore": prima} if prima is not None else None)


async def muto(attivo=True):
    attivo = _vero(attivo)
    await _esegui("wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "1" if attivo else "0")
    return f"audio {'muto' if attivo else 'acceso'}", {"attivo": not attivo}


async def media(comando="pausa"):
    c = {"pausa": "pause", "riprendi": "play", "successivo": "next", "precedente": "previous"}.get(comando)
    if not c:
        raise ValueError(f"comando media sconosciuto: {comando}")
    await _esegui("playerctl", c)
    return f"media: {comando}", None


async def apri(comando=""):
    if not str(comando).strip():
        raise ValueError("manca il comando da aprire")
    await asyncio.create_subprocess_exec("setsid", "-f", "sh", "-c", str(comando),
                                         stdout=asyncio.subprocess.DEVNULL, stderr=asyncio.subprocess.DEVNULL)
    return f"aperto: {comando}", None


async def chiudi(classe=""):
    if not classe:
        raise ValueError("manca la classe della finestra da chiudere")
    n = 0
    for c in json.loads(await fonti.hypr("j/clients") or "[]"):
        if (c.get("class") or "").lower() == str(classe).lower():
            await fonti.hypr(f'dispatch hl.dsp.window.close({{ window = "address:{c["address"]}" }})')
            n += 1
    return f"chiuse {n} finestre di {classe}", None


def _ciel(dati):
    """Una richiesta al cruscotto di Ciel (se è accesa)."""
    try:
        url = open(f"{RT}/ciel-cruscotto.url").read().strip()
    except OSError:
        raise RuntimeError("Ciel è spenta")
    base, q = url.split("?", 1)
    req = urllib.request.Request(base.rstrip("/") + "/api/gui?" + q, data=json.dumps(dati).encode(),
                                 headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=5) as r:
        return json.loads(r.read())


async def ciel_di(testo=""):
    r = await asyncio.to_thread(_ciel, {"azione": "annuncia", "testo": str(testo)[:400]})
    if not r.get("ok"):
        raise RuntimeError(r.get("messaggio") or "Ciel non può parlare adesso")
    return "detto da Ciel", None


async def ciel_silenzio(attivo=True):
    attivo = _vero(attivo)
    await asyncio.to_thread(_ciel, {"azione": "silenzio", "attivo": attivo})
    return f"Ciel {'in silenzio' if attivo else 'di nuovo a voce'}", {"attivo": not attivo}


async def attendi(secondi=1):
    await asyncio.sleep(max(0.0, min(3600.0, float(secondi))))
    return f"atteso {secondi} s", None


async def comando(cmd=""):
    if not str(cmd).strip():
        raise ValueError("comando vuoto")
    out = await _esegui("sh", "-c", str(cmd), timeout=120)
    return f"comando eseguito: {out[:80]}" if out else "comando eseguito", None


# emetti è speciale: lo gestisce il motore (deve rientrare nel bus)
CATALOGO = {f.__name__: f for f in (notifica, non_disturbare, profilo_energetico, volume, muto, media, apri, chiudi,
                                    ciel_di, ciel_silenzio, attendi, comando)}
CATALOGO_NOMI = sorted([*CATALOGO, "emetti"])


def descrivi(a):
    """L'azione in italiano, per mostrarla prima di approvare la regola."""
    n = a.get("azione")
    p = {k: v for k, v in a.items() if k != "azione"}
    testi = {
        "notifica": lambda: f"mando la notifica «{p.get('titolo', 'CielOS')}: {p.get('testo', '')}»",
        "non_disturbare": lambda: "accendo il non disturbare" if _vero(p.get("attivo", True)) else "spengo il non disturbare",
        "profilo_energetico": lambda: f"metto il profilo energetico «{p.get('valore')}»",
        "volume": lambda: f"porto il volume a {p.get('valore')}" if str(p.get("valore"))[:1] not in "+-"
                          else f"cambio il volume di {p.get('valore')}",
        "muto": lambda: "tolgo l'audio" if _vero(p.get("attivo", True)) else "riaccendo l'audio",
        "media": lambda: {"pausa": "metto in pausa", "riprendi": "faccio ripartire", "successivo": "passo al brano dopo",
                          "precedente": "torno al brano prima"}.get(p.get("comando"), str(p.get("comando"))) + " la musica o il video",
        "apri": lambda: f"apro «{p.get('comando')}»",
        "chiudi": lambda: f"chiudo le finestre di {p.get('classe')}",
        "ciel_di": lambda: f"Ciel dice «{p.get('testo')}»",
        "ciel_silenzio": lambda: "Ciel risponde solo per iscritto" if _vero(p.get("attivo", True)) else "Ciel torna a parlare",
        "emetti": lambda: f"mando l'evento «{p.get('evento')}»",
        "attendi": lambda: f"aspetto {p.get('secondi')} secondi",
        "comando": lambda: f"eseguo il comando: {p.get('cmd')}",
    }
    return testi.get(n, lambda: f"{n} {p}")()


def parametri_ok(a):
    """Errore (testo) se l'azione non va bene, altrimenti None."""
    import inspect
    n = a.get("azione")
    if n == "emetti":
        return None if a.get("evento") else "emetti: manca «evento»"
    f = CATALOGO.get(n)
    if not f:
        return f"azione sconosciuta: {n} (possibili: {', '.join(CATALOGO_NOMI)})"
    ammessi = set(inspect.signature(f).parameters)
    extra = set(a) - ammessi - {"azione"}
    if extra:
        return f"{n}: parametri sconosciuti {sorted(extra)} (possibili: {sorted(ammessi)})"
    if n == "profilo_energetico" and a.get("valore") not in PROFILI:
        return f"profilo_energetico: valore tra {list(PROFILI)}"
    return None
