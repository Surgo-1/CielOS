#!/usr/bin/env python3
"""Le prove del collaudo, DENTRO la VM (utente «collaudo», sudo senza password: solo lì). Solo la libreria di Python.
Lo lancia prove/collaudo/collaudo.sh; i risultati in --uscita (risultati.json, foto/, registri).

  1. comandi    i comandi di CielOS, uno per uno: devono rispondere senza eccezioni (e in JSON quando si chiede)
  2. scossoni   gli stessi con argomenti a caso (vuoti, lunghissimi, unicode, numeri assurdi): possono dire «no»,
                non devono andare in crash; e il guardiano (D-Bus) con richieste sbagliate: deve restare in piedi
  3. utente     un utente finto nella sessione grafica: lanciatore, riquadro, ogni pagina delle Impostazioni, File,
                Monitor, terminale, workspace; una foto per passo; dopo ogni passo si guardano gli errori della shell
  4. torchio    processore e memoria al massimo, disco pieno di scritture, pacchetti installati e tolti, programmi
                di CielOS uccisi apposta: devono tornare da soli
  5. esploratore  (con --modello) un modello di Ollama del PC che ospita la VM sceglie cosa fare, da un elenco chiuso
                di azioni, guardando cosa è successo finora; si ferma allo scadere dei minuti
Alla fine: crash (coredump), errori del registro, servizi falliti, errori del kernel, eccezioni Python e QML."""
import argparse, glob, json, os, random, shlex, subprocess, sys, time, urllib.request
from pathlib import Path

A = argparse.ArgumentParser()
A.add_argument("--minuti", type=float, default=60)
A.add_argument("--uscita", default="/tmp/collaudo")
A.add_argument("--modello", default="")
A.add_argument("--solo", default="", help="solo queste fasi, separate da virgole")
ARG = A.parse_args()
OUT = Path(ARG.uscita); (OUT / "foto").mkdir(parents=True, exist_ok=True)
FINE = time.monotonic() + ARG.minuti * 60
UID = os.getuid()
RUN = f"/run/user/{UID}"
ENV = dict(os.environ, XDG_RUNTIME_DIR=RUN, DBUS_SESSION_BUS_ADDRESS=f"unix:path={RUN}/bus", LANG="it_IT.UTF-8")
for s in sorted(glob.glob(f"{RUN}/wayland-[0-9]")):
    ENV["WAYLAND_DISPLAY"] = os.path.basename(s)
for s in sorted(glob.glob(f"{RUN}/hypr/*/.socket.sock")):
    ENV["HYPRLAND_INSTANCE_SIGNATURE"] = Path(s).parent.name
RISULTATI = []
random.seed(int(time.time()))


def log(*a):
    print(time.strftime("%H:%M:%S"), *a, flush=True)


def esegui(cmd, timeout=120, shell=False, entrata=None):
    t0 = time.monotonic()
    try:
        r = subprocess.run(cmd, shell=shell, capture_output=True, text=True, timeout=timeout, env=ENV, input=entrata)
        return r.returncode, r.stdout, r.stderr, time.monotonic() - t0
    except subprocess.TimeoutExpired as e:
        return "timeout", (e.stdout or b"").decode(errors="replace") if isinstance(e.stdout, bytes) else (e.stdout or ""), \
               "", time.monotonic() - t0
    except OSError as e:
        return "manca", "", str(e), 0.0


def segna(fase, nome, ok, dettaglio="", **altro):
    RISULTATI.append({"fase": fase, "nome": nome, "ok": ok, "dettaglio": dettaglio[-3000:], "t": time.time(), **altro})
    if not ok:
        log(f"  ✗ {fase}: {nome}: {dettaglio.strip().splitlines()[-1][:160] if dettaglio.strip() else ''}")


def eccezione(testo):
    """un'eccezione vera (Python o QML), non un «no» detto bene"""
    return any(x in testo for x in ("Traceback (most recent call last)", "TypeError:", "ReferenceError:", "Segmentation fault",
                                     "core dumped", "SyntaxError", "IndentationError"))


def senza_nulls(valori):
    """subprocess rifiuta i byte nulli dentro un argomento (ValueError: embedded null byte): via prima"""
    return [x.replace("\x00", "") for x in valori]


BIN_PACCHETTO = Path("/usr/share/cielos/bin")            # quello che il pacchetto installato contiene davvero
_versione = None


def versione():
    """la versione di CielOS che gira nella VM (una volta sola)"""
    global _versione
    if _versione is None:
        _, out, _, _ = esegui(["pacman", "-Q", "cielos"], timeout=15)
        _versione = out.strip().split()[-1] if out.strip() else "?"
    return _versione


def comando_di_un_altra_versione(comando):
    """Il comando non si trova nel PATH: è colpa di CielOS o della VM? Se nel pacchetto installato quel file non
    c'è, la VM ha una CielOS più vecchia del repository (il collaudo lo dice all'inizio del giro): quella prova
    salta, e non diventa una issue (il giro del 16/10 ne aprì 30 così, con la VM ferma a r50)."""
    if "/" in comando:
        return False
    return not (BIN_PACCHETTO / comando).exists()


def prova_comando(fase, cmd, json_atteso=False, timeout=120, codici_ok=None):
    nome = " ".join(cmd)[:160]
    rc, out, err, dt = esegui(cmd, timeout=timeout)
    problemi = []
    if rc == "timeout":
        problemi.append(f"non finisce in {timeout} s")
    elif rc == "manca" and comando_di_un_altra_versione(cmd[0]):
        segna(fase, nome, True, f"saltata: «{cmd[0]}» non c'è in CielOS {versione()} (la VM è più vecchia del "
              f"repository: collaudo.sh prepara)", saltata=True)
        return rc, out
    elif rc == "manca":
        problemi.append("comando mancante: " + err)
    elif eccezione(out + err):
        problemi.append("eccezione:\n" + (err or out)[-2500:])
    elif rc not in (codici_ok or (0,)) and fase == "comandi":
        problemi.append(f"uscita {rc}:\n" + (err or out)[-1500:])
    if json_atteso and not problemi and rc == 0:
        try:
            json.loads(out)
        except ValueError:
            problemi.append("doveva rispondere in JSON:\n" + out[:600])
    if rc in (-11, -6, 139, 134):
        problemi.append(f"ucciso dal segnale {rc}")
    segna(fase, nome, not problemi, "\n".join(problemi), secondi=round(dt, 1))
    return rc, out


# ── 1. i comandi ──────────────────────────────────────────────────────────────────────────────────────────────────
def fase_comandi():
    log("1. comandi")
    # nella home: il cestino di CielOS non c'è su /tmp (giustamente), e la prova del cestino fallirebbe per finta
    lavoro = Path.home() / "collaudo-file"; lavoro.mkdir(exist_ok=True)
    (lavoro / "uno.txt").write_text("prova\n")
    C = [
        (["cielos", "versione"], False), (["cielos", "aiuto"], False), (["cielos", "medico"], False),
        (["cielos", "errore", "error: failed to commit transaction (conflicting files)"], False),
        (["cielos", "errore", "--json", "libalpm.so.15: cannot open shared object file"], True),
        (["cielos", "wiki", "05"], False),
        (["cielmedico", "--json"], True), (["cielmedico", "avvisa"], False),
        (["cielplugin"], False), (["cielplugin", "elenco", "--json"], True),
        (["cielplugin", "cerca", "firefox", "--json"], True), (["cielplugin", "installati", "fire", "--json"], True),
        (["cielplugin", "script", "vesktop"], False),
        (["cielmodelli", "motore"], False), (["cielmodelli", "installati", "--json"], True),
        (["cielmodelli", "consigli", "--json"], True), (["cielmodelli", "scaricamenti", "--json"], True),
        (["cielimposta", "stato"], True), (["cieltema"], False), (["cieltema", "schema", "--json"], True),
        (["cielstrumenti", "stato", "--json"], True), (["cielstrumenti", "scorciatoie"], False),
        (["cielondate", "stato"], False), (["cielos-hardware"], False), (["cielctl", "regole", "--json"], True),
        (["cielfile", "nuovo", str(lavoro), "due.txt"], True), (["cielfile", "rinomina", str(lavoro / "uno.txt"), "tre.txt"], True),
        (["cielfile", "copia", str(lavoro), str(lavoro / "tre.txt")], True),
        (["cielfile", "comprimi", str(lavoro / "a.zip"), str(lavoro / "tre.txt")], True),
        (["cielfile", "estrai", str(lavoro / "a.zip"), str(lavoro / "estratto")], True),
        (["cielfile", "proprieta", str(lavoro)], True), (["cielfile", "cerca", str(lavoro), "tre"], True),
        (["cielfile", "cestino", str(lavoro / "due.txt")], True), (["cielfile", "cestino-elenco"], True),
    ]
    for cmd, js in C:
        if time.monotonic() > FINE:
            return
        prova_comando("comandi", cmd, js, codici_ok=(0, 1) if cmd[:2] == ["cielos", "errore"] else None)


# ── 2. scossoni ───────────────────────────────────────────────────────────────────────────────────────────────────
STRANI = ["", " ", "-", "--", "--json", "../../../etc/passwd", "a" * 5000, "ñ€😀日本", "-1", "999999999999", "1e309", "nan",
          "$(id)", "`id`", "'", '"', "\\", "%s%s%n", "\x00", "chiave=", "=valore", "a=b=c", "null", "{}", "[]", "\n\n"]


def fase_scossoni():
    log("2. scossoni")
    comandi = [["cielos"], ["cielmedico"], ["cielplugin"], ["cielmodelli"], ["cielimposta"], ["cieltema"],
               ["cielstrumenti"], ["cielondate"], ["cielfile"], ["cielctl"], ["cielos", "errore"], ["cieltema", "imposta"],
               ["cielimposta", "input"], ["cielplugin", "cerca"], ["cielmodelli", "dettagli"], ["cielfile", "rinomina"]]
    pericolosi = {"elimina", "svuota", "ripara", "rimuovi", "togli", "installa", "pacchetto", "aggiorna", "aggiorna-tutto",
                  "ritorna", "registra", "sveglio", "luce", "schermo", "permessi", "sposta", "scarica", "libera", "segnala",
                  "lingua", "ripristina", "energia"}
    n = 0
    while n < 160 and time.monotonic() < FINE:
        base = random.choice(comandi)
        args = senza_nulls([random.choice(STRANI) for _ in range(random.randint(0, 3))])
        if any(a in pericolosi for a in args):
            continue
        prova_comando("scossoni", base + args, timeout=60)
        n += 1
    # cieltema e cielimposta con chiavi vere e valori sbagliati: devono rifiutare, non rompere la configurazione
    rc, out, _, _ = esegui(["cieltema", "schema", "--json"])
    try:
        chiavi = list(json.loads(out)["chiavi"])
    except (ValueError, KeyError):
        chiavi = []
    sbagliati = senza_nulls(STRANI[:20])                                # con «\x00» subprocess si rifiutava di partire
    for k in random.sample(chiavi, min(15, len(chiavi))):
        prova_comando("scossoni", ["cieltema", "imposta", f"{k}={random.choice(sbagliati)}"], timeout=60)
    prova_comando("scossoni", ["cieltema", "ripristina"], timeout=60)
    rc, out, err, _ = esegui(["hyprctl", "configerrors"])
    if out.strip() and "no errors" not in out.lower():
        segna("scossoni", "Hyprland dopo i valori sbagliati", False, "errori di configurazione:\n" + out[:1500])
    # il guardiano: richieste sbagliate dal bus di sistema; deve rispondere «no» e restare acceso
    for _ in range(25):
        azione = random.choice(["installa", "rimuovi", "dns", "sblocca", "inesistente", "", "../x", "a" * 300])
        param = random.choice(['{}', '{"pacchetti": ["$(id)"]}', '{"fornitore": "x"}', 'non json', '{"a": ' * 50, '[]'])
        esegui(["busctl", "--system", "call", "org.cielos.Guardiano", "/org/cielos/Guardiano", "org.cielos.Guardiano1",
                "Esegui", "ss", azione, param], timeout=30)
    rc, out, _, _ = esegui(["systemctl", "is-active", "cielos-guardiano.service"])
    segna("scossoni", "il guardiano resta acceso dopo richieste sbagliate", out.strip() in ("active", "inactive"),
          f"stato: {out.strip()}")


# ── 3. l'utente finto ────────────────────────────────────────────────────────────────────────────────────────────
def pid_shell():
    rc, out, _, _ = esegui(["systemctl", "--user", "show", "ciel-shell.service", "-p", "MainPID", "--value"])
    return out.strip() if rc == 0 and out.strip() not in ("", "0") else ""


def ipc(*a):
    p = pid_shell()
    if not p:
        segna("utente", "la shell Ciel non è accesa", False, "systemctl --user show ciel-shell: MainPID 0")
        return None
    return esegui(["qs", "ipc", "--pid", p, "call", *a], timeout=20)


def foto(nome):
    f = OUT / "foto" / f"{len(list((OUT / 'foto').iterdir())):03d}-{nome}.png"
    esegui(["grim", str(f)], timeout=20)
    return f.name


ERRORI_QML = ("TypeError", "ReferenceError", "Cannot read property", "is not a function", "Unable to assign",
              "failed to load component", "is not a type", "Binding loop")


def errori_shell(dal):
    rc, out, _, _ = esegui(["journalctl", "--user", "-u", "ciel-shell.service", "--since", f"@{int(dal)}", "--no-pager", "-q",
                            "-o", "cat"], timeout=30)
    return [r for r in out.splitlines() if any(e in r for e in ERRORI_QML)]


def passo(nome, azione, attesa=1.2):
    t0 = time.time()
    try:
        r = azione()
    except Exception as e:  # noqa: BLE001
        r = None
        segna("utente", nome, False, f"eccezione nel collaudo: {e!r}")
        return
    time.sleep(attesa)
    f = foto(nome.replace(" ", "_").replace("/", "-")[:40])
    err = errori_shell(t0 - 0.5)
    problemi = []
    if isinstance(r, tuple) and r[0] not in (0, None):
        problemi.append(f"uscita {r[0]}: {(r[2] or r[1])[-600:]}")
    if err:
        problemi.append("errori della shell (QML):\n" + "\n".join(sorted(set(err)))[:2000])
    segna("utente", nome, not problemi, "\n".join(problemi), foto=f)


def hypr(*a):
    return esegui(["hyprctl", "dispatch", *a], timeout=10)


def apri_app(cmd, nome, classe="", titolo=""):
    """apre un programma, aspetta la sua finestra e la chiude. Si cerca per classe (le app di sistema) o per
    titolo: le finestre di Quickshell (File, Monitor) hanno tutte classe «org.quickshell»"""
    t0 = time.time()
    subprocess.Popen(cmd, env=ENV, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
    trovata = False
    for _ in range(40):
        time.sleep(0.5)
        rc, out, _, _ = esegui(["hyprctl", "-j", "clients"], timeout=10)
        try:
            c = [x for x in json.loads(out)
                 if (classe and classe in (x.get("class") or "").lower())
                 or (titolo and titolo in (x.get("title") or "").lower())]
        except ValueError:
            c = []
        if c:
            trovata = True
            time.sleep(1.5)
            f = foto(nome)
            esegui(["hyprctl", "dispatch", "hl.dsp.window.close()"], timeout=10)      # la nuova finestra ha il fuoco
            break
    err = errori_shell(t0)
    segna("utente", f"apri {nome}", trovata and not err, ("" if trovata else "nessuna finestra in 20 s") +
          ("\n" + "\n".join(err) if err else ""), foto=f if trovata else "")


SEZIONI = ["aspetto", "finestre", "schermi", "tastiera e mouse", "audio", "energia e ora", "scorciatoie", "ciel",
           "automazioni", "medico", "hardware", "sistema", "avanzate"]
AZIONI_UI = {
    "lanciatore": lambda: ipc("lanciatore", "scrivi", random.choice(["fire", "impost", "file", "term", "xyz", "?"])),
    "lanciatore_chiudi": lambda: ipc("lanciatore", "chiudi"),
    "riquadro": lambda: ipc("riquadro", "pagina", random.choice(["", "modelli", "scarica", "install", "strumenti", "guida"])),
    "riquadro_chiudi": lambda: ipc("riquadro", "chiudi"),
    "impostazioni": lambda: ipc("impostazioni", "sezione", random.choice(SEZIONI)),
    "impostazioni_chiudi": lambda: ipc("impostazioni", "chiudi"),
    "guida": lambda: ipc("riquadro", "guida", random.choice(["00", "05", "errori", "07"])),
    "strumento": lambda: ipc("riquadro", "strumento", random.choice(["appunti", "emoji", "scorciatoie", "velocita"])),
    "notifica": lambda: ipc("notifs", "prova"),
    "workspace": lambda: esegui(["hyprctl", "dispatch", f"hl.dsp.focus({{ workspace = {random.randint(1, 5)} }})"], timeout=10),
    "cerca_programmi": lambda: ipc("riquadro", "programmi", random.choice(["vlc", "gimp", "steam", "zzz"])),
}


def fase_utente():
    log("3. utente")
    if not ENV.get("WAYLAND_DISPLAY"):
        segna("utente", "sessione grafica", False, "nessun WAYLAND_DISPLAY: l'accesso automatico non è partito")
        return
    passo("desktop", lambda: None, 0.5)
    for s in SEZIONI:
        passo(f"impostazioni {s}", lambda s=s: ipc("impostazioni", "sezione", s), 1.5)
    passo("impostazioni chiudi", lambda: ipc("impostazioni", "chiudi"))
    for p in ["modelli", "scarica", "install", "strumenti", "guida"]:
        passo(f"riquadro {p}", lambda p=p: ipc("riquadro", "pagina", p), 2.0)
    passo("riquadro chiudi", lambda: ipc("riquadro", "chiudi"))
    passo("lanciatore", lambda: ipc("lanciatore", "scrivi", "impost"))
    passo("lanciatore chiudi", lambda: ipc("lanciatore", "chiudi"))
    passo("notifica", lambda: ipc("notifs", "prova"))
    for app, classe, titolo in ((["ciel-file"], "", "file —"), (["ciel-monitor"], "", "monitor"),
                                (["foot"], "foot", "")):
        apri_app(app, app[0], classe, titolo)
    for k in random.sample(list(AZIONI_UI), len(AZIONI_UI)):
        passo(f"a caso: {k}", AZIONI_UI[k], 1.0)
    ipc("riquadro", "chiudi"); ipc("impostazioni", "chiudi"); ipc("lanciatore", "chiudi")


# ── 4. il torchio ────────────────────────────────────────────────────────────────────────────────────────────────
def vivo(servizio, utente=True):
    rc, out, _, _ = esegui(["systemctl"] + (["--user"] if utente else []) + ["is-active", servizio], timeout=10)
    return out.strip() == "active"


def fase_torchio():
    log("4. torchio")
    n = os.cpu_count() or 2
    # processore: tutti i core per 60 s; la shell deve rispondere anche così
    pr = [subprocess.Popen([sys.executable, "-c", "import time\nt=time.time()+60\nwhile time.time()<t: pass"]) for _ in range(n)]
    time.sleep(20)
    t0 = time.monotonic(); r = ipc("lanciatore", "scrivi", "file"); dt = time.monotonic() - t0
    segna("torchio", "la shell risponde col processore al 100%", r is not None and r[0] == 0 and dt < 10, f"{dt:.1f} s")
    ipc("lanciatore", "chiudi")
    for p in pr:
        p.wait()
    # memoria: fino al 85% di quella libera per 30 s (systemd-oomd e zram devono reggere; niente deve morire a caso)
    libera = int(next(l for l in open("/proc/meminfo") if l.startswith("MemAvailable")).split()[1]) * 1024
    mem = subprocess.Popen([sys.executable, "-c", f"import time\nb=bytearray({int(libera * 0.85)})\n"
                            f"for i in range(0,len(b),4096): b[i]=1\ntime.sleep(30)"])
    mem.wait(timeout=180)
    segna("torchio", "memoria quasi piena per 30 s", vivo("ciel-shell.service"), "la shell è ancora accesa?")
    # disco: 2 GB scritti e cancellati
    rc, _, err, dt = esegui(["dd", "if=/dev/zero", "of=/tmp/collaudo-grosso", "bs=4M", "count=512", "conv=fsync"], timeout=300)
    Path("/tmp/collaudo-grosso").unlink(missing_ok=True)
    segna("torchio", "2 GB scritti sul disco", rc == 0, err[-300:], secondi=round(dt, 1))
    # pacchetti installati e tolti (dai repository di Arch, come farebbe chiunque)
    for pk in ("cowsay", "sl", "figlet"):
        prova_comando("torchio", ["sudo", "pacman", "-S", "--noconfirm", pk], timeout=300)
        prova_comando("torchio", ["sudo", "pacman", "-Rns", "--noconfirm", pk], timeout=300)
    # programmi di CielOS uccisi apposta: devono tornare
    for servizio in ("ciel-shell.service", "cield.service"):
        if not vivo(servizio):
            continue
        esegui(["systemctl", "--user", "kill", "-s", "KILL", servizio])
        tornato = False
        for _ in range(30):
            time.sleep(1)
            if vivo(servizio):
                tornato = True
                break
        segna("torchio", f"{servizio} ucciso: torna da solo", tornato, "")
        time.sleep(5)
    for servizio in ("pipewire.service", "wireplumber.service"):
        esegui(["systemctl", "--user", "kill", "-s", "KILL", servizio])
        time.sleep(8)
        rc, out, _, _ = esegui(["wpctl", "status"], timeout=15)
        segna("torchio", f"audio dopo aver ucciso {servizio}", rc == 0, out[-300:])


# ── 5. l'esploratore ─────────────────────────────────────────────────────────────────────────────────────────────
COMANDI_ESPLORA = {
    "medico": ["cielos", "medico"], "versione": ["cielos", "versione"], "plugin": ["cielplugin"],
    "consigli_modelli": ["cielmodelli", "consigli"], "hardware": ["cielos-hardware"], "tema_alba": ["cieltema", "tema", "alba"],
    "tema_notte": ["cieltema", "tema", "notte"], "luce_si": ["cielstrumenti", "luce", "si"], "luce_no": ["cielstrumenti", "luce", "no"],
    "sveglio_si": ["cielstrumenti", "sveglio", "si"], "sveglio_no": ["cielstrumenti", "sveglio", "no"],
    "schermata": ["cielos-schermata", "schermo"], "stato_strumenti": ["cielstrumenti", "stato"], "ondate": ["cielondate", "stato"],
}


def chiedi_modello(storia):
    azioni = sorted(list(AZIONI_UI) + [f"cmd:{k}" for k in COMANDI_ESPLORA])
    domanda = (
        "Stai collaudando CielOS, un sistema operativo (Arch Linux + Hyprland + una shell in QML). Il tuo compito: trovare "
        "bug. Scegli la prossima azione da fare, preferendo quelle poco provate o vicine a dove qualcosa è andato storto. "
        f"Azioni possibili: {', '.join(azioni)}.\nUltimi passi (azione → esito):\n" +
        "\n".join(f"- {a} → {'ok' if ok else 'ERRORE: ' + d[:200]}" for a, ok, d in storia[-15:]) +
        '\nRispondi solo in JSON: {"azione": "<una delle azioni>", "perche": "<breve>"}')
    corpo = {"model": ARG.modello, "messages": [{"role": "user", "content": domanda}], "stream": False, "format": "json",
             "options": {"temperature": 0.9, "num_ctx": 4096}, "keep_alive": "10m"}
    req = urllib.request.Request("http://10.0.2.2:11434/api/chat", data=json.dumps(corpo).encode(),
                                 headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=180) as r:
        d = json.loads(json.loads(r.read())["message"]["content"])
    a = d.get("azione", "")
    return (a if a in azioni else random.choice(azioni)), d.get("perche", "")


def fase_esploratore():
    if not ARG.modello:
        log("5. esploratore: nessun modello, faccio azioni a caso")
    else:
        log(f"5. esploratore con {ARG.modello}")
    storia = []
    guasto_modello = 0
    while time.monotonic() < FINE - 30:
        perche = ""
        if ARG.modello and guasto_modello < 3:
            try:
                azione, perche = chiedi_modello(storia)
            except Exception as e:  # noqa: BLE001
                guasto_modello += 1
                log(f"  il modello non risponde ({e!r}): a caso")
                azione = random.choice(list(AZIONI_UI) + [f"cmd:{k}" for k in COMANDI_ESPLORA])
        else:
            azione = random.choice(list(AZIONI_UI) + [f"cmd:{k}" for k in COMANDI_ESPLORA])
        prima = len(RISULTATI)
        if azione.startswith("cmd:"):
            prova_comando("esploratore", COMANDI_ESPLORA[azione[4:]], timeout=120, codici_ok=(0, 1))
        else:
            passo(f"esploratore: {azione}", AZIONI_UI[azione], 1.0)
        nuovi = RISULTATI[prima:]
        ok = all(r["ok"] for r in nuovi)
        storia.append((azione, ok, " ".join(r["dettaglio"] for r in nuovi if not r["ok"])))
        if perche:
            RISULTATI[-1]["perche"] = perche[:200]
        time.sleep(random.uniform(0.5, 3))
    esegui(["cieltema", "ripristina"]); esegui(["cielstrumenti", "luce", "no"]); esegui(["cielstrumenti", "sveglio", "no"])


# ── alla fine: cosa si è rotto nel sistema ────────────────────────────────────────────────────────────────────────
def raccogli(inizio):
    log("raccolgo")
    since = f"@{int(inizio)}"
    r = {}
    _, r["coredump"], _, _ = esegui(["coredumpctl", "list", "--since", since, "--no-pager", "-q"], timeout=30)
    _, r["errori_sistema"], _, _ = esegui(["sudo", "journalctl", "--since", since, "-p", "3", "--no-pager", "-q", "-o", "short-monotonic"], timeout=60)
    _, r["errori_utente"], _, _ = esegui(["journalctl", "--user", "--since", since, "-p", "3", "--no-pager", "-q"], timeout=60)
    _, r["shell"], _, _ = esegui(["journalctl", "--user", "-u", "ciel-shell.service", "--since", since, "--no-pager", "-q", "-o", "cat"], timeout=60)
    _, r["falliti_sistema"], _, _ = esegui(["systemctl", "--failed", "--no-legend", "--plain"], timeout=20)
    _, r["falliti_utente"], _, _ = esegui(["systemctl", "--user", "--failed", "--no-legend", "--plain"], timeout=20)
    _, r["kernel"], _, _ = esegui("sudo dmesg --level=emerg,alert,crit,err,warn | grep -E 'BUG:|Oops|panic|segfault|Call Trace|general protection|hung_task|oom-kill' | tail -50",
                                  shell=True, timeout=30)
    _, r["medico"], _, _ = esegui(["cielmedico", "--json"], timeout=180)
    _, r["versioni"], _, _ = esegui("pacman -Q cielos ciel-assistente linux hyprland quickshell mesa 2>&1; uname -r", shell=True)
    return r


def main():
    inizio = time.time()
    fasi = {"comandi": fase_comandi, "scossoni": fase_scossoni, "utente": fase_utente, "torchio": fase_torchio,
            "esploratore": fase_esploratore}
    scelte = [f for f in (ARG.solo.split(",") if ARG.solo else fasi) if f in fasi]
    for f in scelte:
        try:
            fasi[f]()
        except Exception as e:  # noqa: BLE001
            import traceback
            segna(f, "il collaudo stesso", False, "eccezione nel collaudo (non per forza un bug di CielOS):\n" + traceback.format_exc())
    sistema = raccogli(inizio)
    (OUT / "risultati.json").write_text(json.dumps({"inizio": inizio, "fine": time.time(), "prove": RISULTATI,
                                                    "sistema": sistema, "modello": ARG.modello}, ensure_ascii=False, indent=1))
    rotte = [r for r in RISULTATI if not r["ok"]]
    log(f"fatto: {len(RISULTATI)} prove, {len(rotte)} non riuscite")


if __name__ == "__main__":
    main()
