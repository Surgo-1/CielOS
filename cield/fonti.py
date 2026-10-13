"""Le fonti degli eventi: ognuna ascolta una parte del PC e la traduce in eventi di CielOS.

Ogni fonte dichiara gli eventi che produce; cield la accende solo se qualcuno (un iscritto o una regola) ne vuole
almeno uno, e la spegne quando non serve più. Niente controlli a intervalli: Hyprland, D-Bus, udev, journald,
PipeWire e la rete avvisano loro quando succede qualcosa (l'unico «orologio» è l'evento orario, una volta al minuto).

Eventi (i dati sono un dizionario):
  finestra.attiva {classe, titolo, indirizzo}      finestra.aperta {classe, titolo, indirizzo, workspace}
  finestra.chiusa {classe, indirizzo}               finestra.schermo_intero {attivo, classe}
  workspace.cambiato {nome}                         schermo.collegato / schermo.scollegato {nome}
  gioco.inizio {classe, titolo}                     gioco.fine {classe, durata_min}
  notifica {app, titolo, testo}
  dispositivo.collegato / dispositivo.scollegato {nome, tipo}   disco.collegato / disco.scollegato {etichetta, dispositivo}
  audio.uscita {nome}                               rete.connessa / rete.disconnessa {}
  sistema.errore {da, messaggio}                    pacchetti.aggiornati {quanti, nomi}
  orario {ora: "HH:MM", giorno: "lun".."dom"}
Le finestre private (incognito) arrivano senza titolo: «Finestra privata»."""
import asyncio, glob, json, os, re, time
from datetime import datetime

RT = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
PRIVATA_RE = re.compile(r"\b(?:scheda|finestra) privata\b|\bprivate (?:tab|window)\b|\bincognito\b|\bInPrivate\b", re.I)
GIOCO_RE = re.compile(r"^(steam_app_\d+|gamescope|.*\.exe|minecraft.*|factorio|retroarch|dolphin-emu|pcsx2.*|"
                      r"yuzu|ryujinx)$", re.I)
GIORNI = ["lun", "mar", "mer", "gio", "ven", "sab", "dom"]


class Fonte:
    nome = "?"
    eventi = ()

    def __init__(self, emetti):
        self.emetti = emetti          # emetti(evento, dati)
        self.compito = None

    def accesa(self):
        return self.compito is not None and not self.compito.done()

    def accendi(self):
        if not self.accesa():
            self.compito = asyncio.get_running_loop().create_task(self._sempre(), name=self.nome)

    def spegni(self):
        if self.accesa():
            self.compito.cancel()
        self.compito = None

    async def _sempre(self):
        """Se la fonte cade (Hyprland riavviato, programma chiuso), riparte dopo un po'."""
        while True:
            try:
                await self.ascolta()
            except asyncio.CancelledError:
                raise
            except Exception as e:
                print(f"[{self.nome}] {e}", flush=True)
            await asyncio.sleep(5)

    async def ascolta(self):
        raise NotImplementedError


class FonteProcesso(Fonte):
    """Un programma che scrive gli eventi riga per riga (dbus-monitor, udevadm, journalctl…)."""
    comando = ()

    async def ascolta(self):
        p = await asyncio.create_subprocess_exec(*self.comando, stdout=asyncio.subprocess.PIPE,
                                                 stderr=asyncio.subprocess.DEVNULL)
        try:
            async for riga in p.stdout:
                self.riga(riga.decode(errors="replace").rstrip("\n"))
        finally:
            if p.returncode is None:
                p.kill()
                await p.wait()

    def riga(self, r):
        raise NotImplementedError


# ---------------------------------------------------------------- Hyprland
def _hypr_dir():
    sig = os.environ.get("HYPRLAND_INSTANCE_SIGNATURE")
    if sig and os.path.isdir(f"{RT}/hypr/{sig}"):
        return f"{RT}/hypr/{sig}"
    d = sorted(glob.glob(f"{RT}/hypr/*/"), key=os.path.getmtime)
    return d[-1].rstrip("/") if d else None


async def hypr(comando):
    """Una domanda al socket di Hyprland («j/clients»): testo della risposta."""
    d = _hypr_dir()
    if not d:
        raise OSError("Hyprland non trovato")
    r, w = await asyncio.open_unix_connection(f"{d}/.socket.sock")
    w.write(comando.encode())
    await w.drain()
    dati = await r.read()
    w.close()
    return dati.decode(errors="replace")


class Hyprland(Fonte):
    nome = "hyprland"
    eventi = ("finestra.attiva", "finestra.aperta", "finestra.chiusa", "finestra.schermo_intero",
              "workspace.cambiato", "schermo.collegato", "schermo.scollegato", "gioco.inizio", "gioco.fine")

    def __init__(self, emetti):
        super().__init__(emetti)
        self.finestre = {}            # indirizzo -> {classe, privata}
        self.attiva = {}
        self.giochi = {}              # indirizzo -> (classe, titolo, inizio)

    def _titolo(self, t, privata):
        return "Finestra privata" if privata else t

    async def ascolta(self):
        d = _hypr_dir()
        if not d:
            raise OSError("Hyprland non trovato")
        self.finestre = {}
        for c in json.loads(await hypr("j/clients") or "[]"):
            a = c["address"].removeprefix("0x")
            priv = bool(PRIVATA_RE.search(c.get("initialTitle") or "") or PRIVATA_RE.search(c.get("title") or ""))
            self.finestre[a] = {"classe": c.get("class") or "", "privata": priv}
            if GIOCO_RE.match(c.get("class") or "") and a not in self.giochi:
                self.giochi[a] = (c.get("class"), self._titolo(c.get("title") or "", priv), time.time())
        r, w = await asyncio.open_unix_connection(f"{d}/.socket2.sock", limit=1 << 20)
        try:
            async for riga in r:
                ev, _, dati = riga.decode(errors="replace").rstrip("\n").partition(">>")
                await self.evento(ev, dati)
        finally:
            w.close()

    async def evento(self, ev, dati):
        if ev == "openwindow":
            a, ws, classe, titolo = (dati.split(",", 3) + ["", "", ""])[:4]
            priv = bool(PRIVATA_RE.search(titolo))
            if not priv and classe.lower() in ("brave-browser", "brave-origin", "firefox", "chromium", "google-chrome"):
                try:                     # il titolo iniziale dice se è una finestra privata
                    for c in json.loads(await hypr("j/clients") or "[]"):
                        if c["address"].removeprefix("0x") == a:
                            priv = bool(PRIVATA_RE.search(c.get("initialTitle") or ""))
                except (OSError, ValueError):
                    pass
            self.finestre[a] = {"classe": classe, "privata": priv}
            self.emetti("finestra.aperta", {"classe": classe, "titolo": self._titolo(titolo, priv),
                                            "indirizzo": a, "workspace": ws})
            if GIOCO_RE.match(classe):
                self.giochi[a] = (classe, self._titolo(titolo, priv), time.time())
                if len(self.giochi) == 1:
                    self.emetti("gioco.inizio", {"classe": classe, "titolo": self._titolo(titolo, priv)})
        elif ev == "closewindow":
            f = self.finestre.pop(dati, {})
            self.emetti("finestra.chiusa", {"classe": f.get("classe", ""), "indirizzo": dati})
            g = self.giochi.pop(dati, None)
            if g and not self.giochi:
                self.emetti("gioco.fine", {"classe": g[0], "durata_min": round((time.time() - g[2]) / 60)})
        elif ev == "activewindow":                     # arriva prima di activewindowv2 (l'indirizzo)
            self.in_arrivo = dati.partition(",")
        elif ev == "activewindowv2":
            classe, _, titolo = getattr(self, "in_arrivo", ("", "", ""))
            priv = (self.finestre.get(dati) or {}).get("privata") or bool(PRIVATA_RE.search(titolo))
            nuovo = {"classe": classe, "titolo": self._titolo(titolo, priv), "indirizzo": dati}
            if nuovo != self.attiva:
                self.attiva = nuovo
                self.emetti("finestra.attiva", dict(nuovo))
        elif ev == "fullscreen":
            self.emetti("finestra.schermo_intero", {"attivo": dati.strip() == "1", "classe": self.attiva.get("classe", "")})
        elif ev == "workspace":
            self.emetti("workspace.cambiato", {"nome": dati})
        elif ev == "monitoradded":
            self.emetti("schermo.collegato", {"nome": dati})
        elif ev == "monitorremoved":
            self.emetti("schermo.scollegato", {"nome": dati})


# ---------------------------------------------------------------- notifiche (D-Bus)
class Notifiche(FonteProcesso):
    nome = "notifiche"
    eventi = ("notifica",)
    comando = ("dbus-monitor", "--session", "interface='org.freedesktop.Notifications',member='Notify'")

    def __init__(self, emetti):
        super().__init__(emetti)
        self.stringhe, self.dentro = [], False

    def riga(self, r):
        if "member=Notify" in r:
            self.stringhe, self.dentro = [], True
            return
        if not self.dentro:
            return
        m = re.match(r'\s*string "(.*)"\s*$', r)
        if m:
            self.stringhe.append(m.group(1))
        elif r.lstrip().startswith("array"):          # dopo il testo vengono le azioni: notifica completa
            if len(self.stringhe) >= 4:
                s = self.stringhe
                self.emetti("notifica", {"app": s[0], "titolo": s[2], "testo": re.sub(r"<[^>]+>", "", s[3])[:500]})
            self.dentro = False


# ---------------------------------------------------------------- dispositivi (udev)
class Dispositivi(FonteProcesso):
    nome = "dispositivi"
    eventi = ("dispositivo.collegato", "dispositivo.scollegato", "disco.collegato", "disco.scollegato")
    comando = ("udevadm", "monitor", "--udev", "--property", "--subsystem-match=usb", "--subsystem-match=block")

    def __init__(self, emetti):
        super().__init__(emetti)
        self.p = {}

    def riga(self, r):
        if r.strip():
            k, _, v = r.partition("=")
            if v:
                self.p[k] = v
            return
        p, self.p = self.p, {}                        # riga vuota: fine di un evento
        azione = {"add": "collegato", "remove": "scollegato"}.get(p.get("ACTION"))
        if not azione:
            return
        if p.get("SUBSYSTEM") == "usb" and p.get("DEVTYPE") == "usb_device":
            nome = " ".join(x for x in (p.get("ID_VENDOR_FROM_DATABASE") or p.get("ID_VENDOR", ""),
                                         p.get("ID_MODEL_FROM_DATABASE") or p.get("ID_MODEL", "")) if x).replace("_", " ")
            self.emetti(f"dispositivo.{azione}", {"nome": nome or "dispositivo USB", "tipo": "usb"})
        elif p.get("SUBSYSTEM") == "block" and p.get("DEVTYPE") == "partition" and (p.get("ID_FS_TYPE") or azione == "scollegato"):
            self.emetti(f"disco.{azione}", {"etichetta": p.get("ID_FS_LABEL", ""), "dispositivo": p.get("DEVNAME", "")})


# ---------------------------------------------------------------- errori di sistema (journald)
class Registro(FonteProcesso):
    nome = "registro"
    eventi = ("sistema.errore",)
    comando = ("journalctl", "-f", "-n", "0", "-p", "3", "-o", "json", "-q")

    def __init__(self, emetti):
        super().__init__(emetti)
        self.visti = {}

    def riga(self, r):
        try:
            d = json.loads(r)
        except ValueError:
            return
        m = d.get("MESSAGE")
        m = (m if isinstance(m, str) else "").strip().splitlines()[:1]
        if not m:
            return
        da = d.get("SYSLOG_IDENTIFIER") or os.path.basename(d.get("_EXE", "?"))
        chiave = da + re.sub(r"\d+", "#", m[0])[:80]
        if time.time() - self.visti.get(chiave, 0) < 600:     # lo stesso errore al massimo ogni 10 minuti
            return
        self.visti[chiave] = time.time()
        if len(self.visti) > 500:
            self.visti.clear()
        self.emetti("sistema.errore", {"da": da, "messaggio": m[0][:300]})


# ---------------------------------------------------------------- pacchetti (pacman.log)
class Pacchetti(FonteProcesso):
    nome = "pacchetti"
    eventi = ("pacchetti.aggiornati",)
    comando = ("tail", "-n", "0", "-F", "/var/log/pacman.log")

    def __init__(self, emetti):
        super().__init__(emetti)
        self.nomi = []

    def riga(self, r):
        m = re.search(r"\[ALPM\] (?:upgraded|installed) (\S+)", r)
        if m:
            self.nomi.append(m.group(1))
        elif "[ALPM] transaction completed" in r and self.nomi:
            self.emetti("pacchetti.aggiornati", {"quanti": len(self.nomi), "nomi": self.nomi[:30]})
            self.nomi = []


# ---------------------------------------------------------------- audio (PipeWire)
class Audio(FonteProcesso):
    nome = "audio"
    eventi = ("audio.uscita",)
    comando = ("pactl", "subscribe")

    def __init__(self, emetti):
        super().__init__(emetti)
        self.uscita = None

    def riga(self, r):
        if "on server" not in r:
            return
        asyncio.get_running_loop().create_task(self._controlla())

    async def _controlla(self):
        p = await asyncio.create_subprocess_exec("pactl", "get-default-sink", stdout=asyncio.subprocess.PIPE)
        nome = (await p.stdout.read()).decode().strip()
        await p.wait()
        if nome and nome != self.uscita:
            if self.uscita is not None:
                self.emetti("audio.uscita", {"nome": nome})
            self.uscita = nome


# ---------------------------------------------------------------- rete (NetworkManager)
class Rete(FonteProcesso):
    nome = "rete"
    eventi = ("rete.connessa", "rete.disconnessa")
    comando = ("nmcli", "monitor")

    def __init__(self, emetti):
        super().__init__(emetti)
        self.stato = None

    def riga(self, r):
        m = re.search(r"Connectivity is now '([^']+)'|Networkmanager is now in the '([^']+)' state", r)
        if not m:
            return
        su = (m.group(1) or m.group(2) or "") in ("full", "connected", "connected (site/global)")
        if su != self.stato:
            if self.stato is not None:
                self.emetti("rete.connessa" if su else "rete.disconnessa", {})
            self.stato = su


# ---------------------------------------------------------------- orario
class Orario(Fonte):
    nome = "orario"
    eventi = ("orario",)

    async def ascolta(self):
        while True:
            await asyncio.sleep(60.05 - time.time() % 60)     # allo scoccare del minuto
            n = datetime.now()
            self.emetti("orario", {"ora": n.strftime("%H:%M"), "giorno": GIORNI[n.weekday()]})


TUTTE = (Hyprland, Notifiche, Dispositivi, Registro, Pacchetti, Audio, Rete, Orario)
