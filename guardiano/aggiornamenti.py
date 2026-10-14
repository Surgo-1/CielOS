"""Gli aggiornamenti sicuri di CielOS (fase 5), la parte da amministratore: la usano il guardiano (azione «aggiorna»
e «ritorna») e il servizio d'avvio (avvio.py). Ciel non la chiama mai direttamente.

  Ondate        I repository di Arch (core, extra, multilib) possono puntare a un giorno fisso dell'Arch Linux
                Archive (/etc/pacman.d/cielos-ondata). Il giorno avanza solo quando lo approvi tu (azione «aggiorna»
                con «ondata»), dopo che Ciel ha controllato notizie e pacchetti (bin/cielondate, senza root).
  Prima         spazio libero, copia dei file d'avvio (kernel, initramfs, configurazione del bootloader: su un PC con
                la partizione EFI stanno FUORI dalle istantanee), istantanea snapper «prima».
  Dopo          prima di riavviare: ogni kernel ha initramfs e moduli; se c'è NVIDIA, il modulo per ogni kernel.
                Se manca qualcosa: si torna indietro subito.
  In prova      /var/lib/cielos/aggiornamenti/in-prova.json: il servizio d'avvio conta i tentativi e guarda se il
                desktop parte; se no rimette il sistema com'era (ritorna) e riavvia.
  Ritorna       sottovolume btrfs: quello attuale diventa «@rotto-DATA», al suo posto una copia scrivibile
                dell'istantanea «prima»; i sottovolumi annidati (le istantanee stesse) passano al nuovo; i file
                d'avvio tornano quelli di prima. Vale al prossimo riavvio.

CIELOS_RADICE (solo per le prove): una cartella al posto di / per i file di stato e d'avvio."""
import json, os, re, shutil, subprocess, time
from pathlib import Path

R = Path(os.environ.get("CIELOS_RADICE", "/"))
STATO = R / "var/lib/cielos/aggiornamenti"
IN_PROVA = STATO / "in-prova.json"
STORICO = STATO / "storico.json"
RITORNI = STATO / "ritorni.json"             # i ritorni indietro fatti (letti da Ciel per dirtelo)
ONDATA = R / "etc/pacman.d/cielos-ondata"
PACMAN_CONF = R / "etc/pacman.conf"
BOOT = R / "boot"
ARCHIVIO = "https://archive.archlinux.org/repos"
SPAZIO_MINIMO_GB = 3
FILE_AVVIO = re.compile(r"(vmlinuz|initramfs|initrd|-ucode\.img$|\.efi$|limine\.conf$|grub\.cfg$|\.img$)")
TENTATIVI_MAX = 2                             # avvii senza desktop prima di tornare indietro


def _cmd(*c, timeout=600):
    r = subprocess.run(c, capture_output=True, text=True, timeout=timeout)
    return r.returncode, (r.stdout + r.stderr).strip()

def _leggi(p, d):
    try:
        return json.loads(Path(p).read_text())
    except (OSError, ValueError):
        return d

def _scrivi(p, d):
    p = Path(p)
    p.parent.mkdir(parents=True, exist_ok=True)
    t = p.with_suffix(".tmp")
    with open(t, "w") as f:
        json.dump(d, f, indent=2, ensure_ascii=False)
        f.flush()
        os.fsync(f.fileno())
    os.replace(t, p)

def _aggiungi(p, voce, quante=30):
    l = _leggi(p, [])
    l.append(voce)
    _scrivi(p, l[-quante:])


# ── ondate ────────────────────────────────────────────────────────────────────────────────────────────────────
def ondate_attive():
    """pacman.conf usa il nostro elenco di server (l'ha messo installa.sh ondate)"""
    try:
        return "cielos-ondata" in PACMAN_CONF.read_text()
    except OSError:
        return False

def ondata_attuale():
    try:
        m = re.search(r"/repos/(\d{4})/(\d{2})/(\d{2})/", ONDATA.read_text())
        return f"{m[1]}-{m[2]}-{m[3]}" if m else None
    except OSError:
        return None

def controlla_data(giorno):
    if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", str(giorno or "")):
        raise ValueError("data dell'ondata non valida (AAAA-MM-GG)")
    t = time.mktime(time.strptime(giorno, "%Y-%m-%d"))
    if t > time.time():
        raise ValueError("l'ondata non può essere nel futuro")
    if t < time.time() - 400 * 86400:
        raise ValueError("ondata troppo vecchia")
    return giorno

def metti_ondata(giorno):
    a, m, g = controlla_data(giorno).split("-")
    ONDATA.parent.mkdir(parents=True, exist_ok=True)
    ONDATA.write_text(f"# CielOS: i repository di Arch fermi al {g}/{m}/{a} (lo cambia solo il guardiano)\n"
                      f"Server = {ARCHIVIO}/{a}/{m}/{g}/$repo/os/$arch\n")


# ── prima ─────────────────────────────────────────────────────────────────────────────────────────────────────
def spazio_libero_gb():
    s = os.statvfs(R)
    return s.f_bavail * s.f_frsize / 1e9

def controlli_prima():
    """problemi che fermano l'aggiornamento (lista vuota: si può)"""
    no = []
    if spazio_libero_gb() < SPAZIO_MINIMO_GB:
        no.append(f"meno di {SPAZIO_MINIMO_GB} GB liberi sul disco di sistema")
    if IN_PROVA.exists():
        no.append("l'aggiornamento di prima non è ancora stato confermato da un avvio riuscito: riavvia prima")
    for b in Path("/sys/class/power_supply").glob("BAT*") if str(R) == "/" else []:
        try:
            if (b / "status").read_text().strip() == "Discharging" and int((b / "capacity").read_text()) < 30:
                no.append("batteria sotto il 30% e senza alimentatore")
        except (OSError, ValueError):
            pass
    return no

def copia_avvio(ident):
    """i file d'avvio di adesso, dentro lo stato (che finisce nell'istantanea «prima»)"""
    dest = STATO / ident / "avvio"
    copiati = []
    for f in sorted(BOOT.rglob("*")) if BOOT.exists() else []:
        if f.is_file() and FILE_AVVIO.search(f.name) and "snapshot" not in str(f).lower():
            rel = f.relative_to(BOOT)
            (dest / rel).parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(f, dest / rel)
            copiati.append(str(rel))
    _scrivi(STATO / ident / "avvio.json", copiati)
    # solo le copie degli ultimi 3 aggiornamenti (ognuna può pesare 50-150 MB; quelle più vecchie restano comunque
    # dentro le loro istantanee «prima»)
    vecchie = sorted(d for d in STATO.iterdir() if d.is_dir() and re.fullmatch(r"\d{8}-\d{6}", d.name))[:-3]
    for d in vecchie:
        shutil.rmtree(d / "avvio", ignore_errors=True)
    return copiati

def rimetti_avvio(radice_stato, ident, boot=BOOT):
    """dal sottovolume di prima (radice_stato) rimette in /boot i file d'avvio salvati"""
    base = Path(radice_stato) / "var/lib/cielos/aggiornamenti" / ident
    for rel in _leggi(base / "avvio.json", []):
        src, dst = base / "avvio" / rel, Path(boot) / rel
        if src.is_file():
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src, dst)


# ── dopo ──────────────────────────────────────────────────────────────────────────────────────────────────────
def kernel_installati():
    m = R / "usr/lib/modules"
    return sorted(d.name for d in m.iterdir() if (d / "modules.dep").exists() or (d / "vmlinuz").exists()) if m.exists() else []

def controlli_dopo():
    """quello che manca per riavviare tranquilli (lista vuota: tutto a posto)"""
    no = []
    kernel = [k for k in kernel_installati() if (R / "usr/lib/modules" / k / "vmlinuz").exists()]
    if not kernel:
        no.append("nessun kernel installato")
    nvidia = (R / "usr/bin/nvidia-smi").exists()
    for k in kernel:
        d = R / "usr/lib/modules" / k
        if not (d / "modules.dep").exists():
            no.append(f"kernel {k}: moduli incompleti")
        if nvidia and not any(d.rglob("nvidia.ko*")):
            no.append(f"kernel {k}: manca il modulo NVIDIA (dkms non l'ha compilato)")
    # ogni kernel con il suo vmlinuz e il suo initramfs nella cartella d'avvio (per nome del pacchetto, «pkgbase»:
    # /boot/vmlinuz-linux con GRUB, /boot/<machine-id>/linux-cachyos/vmlinuz-linux-cachyos con Limine)
    avvio = [f for f in BOOT.rglob("*") if f.is_file()] if BOOT.exists() else []
    for k in kernel:
        try:
            base = (R / "usr/lib/modules" / k / "pkgbase").read_text().strip()
        except OSError:
            continue
        suoi = [f for f in avvio if f.name.endswith(base) or f"-{base}." in f.name or f.parent.name == base]
        if not any(f.name.startswith("vmlinuz") for f in suoi):
            no.append(f"kernel {base}: manca il kernel nella cartella d'avvio")
        if not any(f.name.startswith("initramfs") for f in suoi):
            no.append(f"kernel {base}: manca l'initramfs")
    return no


# ── in prova (la sorveglia avvio.py) ─────────────────────────────────────────────────────────────────────────
def pacchetti():
    rc, out = _cmd("pacman", "-Q")
    return dict(l.split(" ", 1) for l in out.splitlines() if " " in l) if not rc else {}

def segna_in_prova(ident, prima, dopo, ondata, cambiati=None):
    _scrivi(IN_PROVA, {"id": ident, "prima": prima, "dopo": dopo, "ondata": ondata,
                       "data": time.strftime("%Y-%m-%d %H:%M"), "tentativi": 0, "pacchetti": cambiati or {}})

def conferma(nota="avvio riuscito"):
    p = _leggi(IN_PROVA, None)
    if p:
        _aggiungi(STORICO, {**p, "esito": "ok", "nota": nota, "fine": time.strftime("%Y-%m-%d %H:%M")})
        IN_PROVA.unlink(missing_ok=True)
    return p


# ── tornare indietro ──────────────────────────────────────────────────────────────────────────────────────────
class Impossibile(RuntimeError):
    pass

def _radice_btrfs():
    """(dispositivo, sottovolume della radice relativo al livello più alto, es. «@»)"""
    rc, out = _cmd("findmnt", "-no", "SOURCE,FSTYPE", "/")
    parti = out.split()
    if rc or len(parti) < 2 or parti[1] != "btrfs":
        raise Impossibile("la radice non è btrfs")
    dev = re.sub(r"\[.*\]$", "", parti[0])
    rc, out = _cmd("btrfs", "subvolume", "show", "/")
    nome = out.splitlines()[0].strip() if not rc and out else ""
    if not nome or nome in ("/", "<FS_TREE>"):
        raise Impossibile("la radice non è un sottovolume (serve lo schema con @)")
    return dev, nome

def _annidati(livello_alto, sv):
    """i sottovolumi dentro sv (per esempio sv/.snapshots), come percorsi relativi a sv"""
    rc, out = _cmd("btrfs", "subvolume", "list", "-o", str(Path(livello_alto) / sv))
    rel = []
    for riga in out.splitlines() if not rc else []:
        p = riga.split(" path ", 1)[-1].strip()
        p = p.removeprefix("<FS_TREE>/")
        if p.startswith(sv + "/"):
            rel.append(p[len(sv) + 1:])
    # solo quelli «di primo livello» dentro sv (quelli annidati più dentro viaggiano con il loro genitore)
    return sorted(x for x in rel if not any(x != y and x.startswith(y + "/") for y in rel))

def ritorna(prima, ident=None, motivo="", mnt="/run/cielos/radice", cambiati=None):
    """rimette il sistema com'era all'istantanea snapper «prima» (numero). Vale dal prossimo avvio."""
    prima = str(int(prima))
    dev, sv = _radice_btrfs()
    rc, snap_sv = _cmd("btrfs", "subvolume", "show", "/.snapshots")
    if rc:
        raise Impossibile("non trovo le istantanee (/.snapshots)")
    snap_sv = snap_sv.splitlines()[0].strip()                       # es. «@/.snapshots» o «@snapshots»
    Path(mnt).mkdir(parents=True, exist_ok=True)
    rc, out = _cmd("mount", "-o", "subvolid=5", dev, mnt)
    if rc:
        raise Impossibile("non riesco a montare il disco: " + out)
    try:
        top = Path(mnt)
        sorgente = top / snap_sv / prima / "snapshot"
        if not sorgente.is_dir():
            raise Impossibile(f"l'istantanea {prima} non c'è")
        ts = time.strftime("%Y%m%d-%H%M%S")
        nuovo, rotto = f"{sv}-ritorno-{ts}", f"{sv}-rotto-{ts}"
        rc, out = _cmd("btrfs", "subvolume", "snapshot", str(sorgente), str(top / nuovo))
        if rc:
            raise Impossibile("copia dell'istantanea non riuscita: " + out)
        annidati = _annidati(top, sv)
        os.rename(top / sv, top / rotto)                              # il sistema acceso resta su quello (per id)
        os.rename(top / nuovo, top / sv)
        for rel in annidati:                                          # le istantanee e gli altri annidati passano
            dst = top / sv / rel
            if dst.is_dir() and not any(dst.iterdir()):
                dst.rmdir()
            dst.parent.mkdir(parents=True, exist_ok=True)
            os.rename(top / rotto / rel, dst)
        if ident:
            rimetti_avvio(top / sv, ident)
        voce = {"data": time.strftime("%Y-%m-%d %H:%M"), "istantanea": prima, "id": ident, "motivo": motivo,
                "rotto": rotto, "pacchetti": cambiati or {}}     # le versioni che l'ondata dopo dovrà evitare
        dove = top / sv / "var/lib/cielos/aggiornamenti"
        dove.mkdir(parents=True, exist_ok=True)
        l = _leggi(dove / "ritorni.json", [])
        _scrivi(dove / "ritorni.json", (l + [voce])[-30:])
        (dove / "in-prova.json").unlink(missing_ok=True)
        _pulisci_rotti(top, sv, tieni=rotto)
        return voce
    finally:
        _cmd("umount", mnt)

def _pulisci_rotti(top, sv, tieni):
    """tiene solo l'ultimo sottovolume «rotto» (per guardarci dentro), gli altri occupano spazio e basta"""
    for d in Path(top).glob(f"{sv}-rotto-*"):
        if d.name != tieni:
            _cmd("btrfs", "subvolume", "delete", str(d))
