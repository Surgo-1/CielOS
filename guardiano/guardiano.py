#!/usr/bin/env python3
"""Il guardiano di CielOS: le azioni da amministratore che Ciel può chiedere, e che solo la tua password approva.
Progetto: PROGETTO.md. Elenco delle azioni e controlli: azioni.py.

Servizio di sistema (root), attivato da D-Bus quando serve, si spegne dopo 2 minuti senza richieste.
  bus di sistema: org.cielos.Guardiano  /org/cielos/Guardiano  org.cielos.Guardiano1.Esegui(azione, json) -> json
Per ogni richiesta: controlla azione e parametri → chiede a polkit (org.cielos.guardiano.<azione>, password ogni
volta; la finestra la mostra l'agente polkit, cioè la shell Ciel) → istantanea snapper «prima» → esegue i comandi
fissi → istantanea «dopo» → registro (/var/log/cielos/guardiano.log e journal) → risposta.
Una richiesta alla volta. Mai una stringa di shell, mai comandi fuori da azioni.py.

GUARDIANO_PROVA=1: sul bus di sessione, senza root, senza polkit e senza eseguire niente (dice cosa farebbe)."""
import ipaddress, json, os, subprocess, sys, threading, time
from pathlib import Path

import gi
gi.require_version("Gio", "2.0")
from gi.repository import Gio, GLib

sys.path.insert(0, str(Path(__file__).resolve().parent))
import azioni  # noqa: E402

PROVA = os.environ.get("GUARDIANO_PROVA") == "1"
NOME = "org.cielos.Guardiano"
PERCORSO = "/org/cielos/Guardiano"
REGISTRO = Path(os.environ.get("GUARDIANO_REGISTRO", "/var/log/cielos/guardiano.log"))
RIPOSO_S = 120

XML = """<node>
  <interface name="org.cielos.Guardiano1">
    <method name="Esegui">
      <arg type="s" name="azione" direction="in"/>
      <arg type="s" name="parametri" direction="in"/>
      <arg type="s" name="risposta" direction="out"/>
    </method>
    <method name="Prepara">
      <arg type="s" name="azione" direction="in"/>
      <arg type="s" name="parametri" direction="in"/>
      <arg type="s" name="risposta" direction="out"/>
    </method>
  </interface>
</node>"""

occupato = threading.Lock()
ultima = [time.monotonic()]


def registra(**voce):
    voce = {"t": time.strftime("%Y-%m-%d %H:%M:%S"), **voce}
    riga = json.dumps(voce, ensure_ascii=False)
    print(riga, flush=True)
    try:
        REGISTRO.parent.mkdir(parents=True, exist_ok=True)
        with REGISTRO.open("a", encoding="utf-8") as f:
            f.write(riga + "\n")
    except OSError:
        pass


# ── gli aiuti per azioni.py: domande al sistema, solo lettura ─────────────────────────────────────────────────
def _uscita(*cmd, timeout=120):
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
    return r.returncode, r.stdout

def esiste(nome):
    return _uscita("pacman", "-Si", "--", nome)[0] == 0

def bersagli(nomi):
    rc, out = _uscita("pacman", "-Rnsp", "--print-format", "%n", "--", *nomi)
    if rc:
        raise azioni.Rifiutata("Non posso toglierli: non sono installati, o altri pacchetti ne hanno bisogno.")
    return [x for x in out.split() if x]

def quanti_aggiornamenti():
    try:
        rc, out = _uscita("checkupdates", timeout=180)
    except (OSError, subprocess.TimeoutExpired):
        return None
    return len(out.split("\n")) - 1 if rc == 0 else 0 if rc == 2 else None

def rete_di_casa():
    try:
        rotte = json.loads(_uscita("ip", "-4", "-j", "route")[1] or "[]")
    except ValueError:
        return None
    for r in rotte:
        if r.get("scope") == "link" and r.get("dst", "default") != "default":
            try:
                n = ipaddress.ip_network(r["dst"], strict=False)
            except ValueError:
                continue
            if n.is_private and n.prefixlen >= 16:
                return str(n)
    return None

AIUTI = {"esiste": esiste, "bersagli": bersagli, "info": quanti_aggiornamenti, "rete": None}


# ── polkit ────────────────────────────────────────────────────────────────────────────────────────────────────
def autorizzato(bus, mittente, piano):
    """Chiede a polkit; la finestra della password la mostra l'agente (la shell Ciel). True solo se approvata."""
    if PROVA:
        registra(prova=True, nota=f"avrei chiesto la password per: {piano.frase}")
        return True
    soggetto = ("system-bus-name", {"name": GLib.Variant("s", mittente)})
    dettagli = {"polkit.message": piano.frase, "cielos.azione": piano.azione}
    r = bus.call_sync("org.freedesktop.PolicyKit1", "/org/freedesktop/PolicyKit1/Authority",
                      "org.freedesktop.PolicyKit1.Authority", "CheckAuthorization",
                      GLib.Variant("((sa{sv})sa{ss}us)", (soggetto, f"org.cielos.guardiano.{piano.azione}",
                                                          dettagli, 1, "")),
                      GLib.VariantType("((bba{ss}))"), Gio.DBusCallFlags.NONE, GLib.MAXINT, None)
    (si, _domanda, _info), = r.unpack()
    return si


# ── l'esecuzione ──────────────────────────────────────────────────────────────────────────────────────────────
def _snapper(*args):
    if PROVA:
        return "0"
    rc, out = _uscita("snapper", "-c", "root", *args)
    return out.strip() if rc == 0 else None

def esegui_piano(piano):
    prima = None
    if piano.istantanea:
        prima = _snapper("create", "-t", "pre", "-p", "-c", "number", "-d", f"guardiano: {piano.azione}")
        if prima is None:
            return False, "Non riesco a fare l'istantanea di sicurezza: non procedo."
    uscite = []
    ok = True
    for cmd in piano.comandi:
        if PROVA:
            uscite.append("(prova) " + " ".join(cmd))
            continue
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=3600, env={**os.environ, "LANG": "C"})
        uscite.append((r.stdout + r.stderr).strip()[-1500:])
        if r.returncode:
            ok = False
            break
    if prima is not None:
        _snapper("create", "-t", "post", "--pre-number", prima, "-c", "number", "-d", f"guardiano: {piano.azione}")
    return ok, "\n".join(uscite)


def gestisci(bus, mittente, uid, azione, parametri_json, solo_prepara):
    try:
        parametri = json.loads(parametri_json or "{}")
        aiuti = dict(AIUTI, rete=rete_di_casa() if azione == "firewall" else None)
        piano = azioni.prepara(azione, parametri, **aiuti)
    except azioni.Rifiutata as e:
        registra(uid=uid, azione=azione, parametri=parametri_json, esito="rifiutata", motivo=str(e))
        return {"ok": False, "messaggio": str(e)}
    except (ValueError, subprocess.TimeoutExpired) as e:
        return {"ok": False, "messaggio": f"Richiesta non valida: {e}"}
    if solo_prepara:
        return {"ok": True, "frase": piano.frase}
    if not occupato.acquire(blocking=False):
        return {"ok": False, "messaggio": "Sto già facendo un'altra azione da amministratore: aspetta che finisca."}
    try:
        if not autorizzato(bus, mittente, piano):
            registra(uid=uid, azione=azione, parametri=parametri, esito="non approvata")
            return {"ok": False, "approvata": False, "messaggio": "Non approvata: non ho fatto niente."}
        ok, uscita = esegui_piano(piano)
        registra(uid=uid, azione=azione, parametri=parametri, esito="fatta" if ok else "fallita", uscita=uscita[-400:])
        return {"ok": ok, "approvata": True, "frase": piano.frase,
                "messaggio": piano.fatto if ok else "Non è andata: " + piano.frase + " (dettagli nel registro del guardiano)",
                "uscita": uscita}
    finally:
        occupato.release()


def chiamata(conn, mittente, _percorso, _interfaccia, metodo, parametri, invocazione):
    ultima[0] = time.monotonic()
    azione, pj = parametri.unpack()
    try:
        uid = conn.call_sync("org.freedesktop.DBus", "/org/freedesktop/DBus", "org.freedesktop.DBus",
                             "GetConnectionUnixUser", GLib.Variant("(s)", (mittente,)), GLib.VariantType("(u)"),
                             Gio.DBusCallFlags.NONE, 5000, None).unpack()[0]
    except GLib.Error:
        uid = -1

    def lavoro():
        r = gestisci(conn, mittente, uid, azione, pj, metodo == "Prepara")
        ultima[0] = time.monotonic()
        GLib.idle_add(lambda: invocazione.return_value(GLib.Variant("(s)", (json.dumps(r, ensure_ascii=False),))))

    threading.Thread(target=lavoro, daemon=True).start()


def main():
    ciclo = GLib.MainLoop()
    info = Gio.DBusNodeInfo.new_for_xml(XML)

    def acquisito(conn, _nome):
        conn.register_object(PERCORSO, info.interfaces[0], chiamata, None, None)

    Gio.bus_own_name(Gio.BusType.SESSION if PROVA else Gio.BusType.SYSTEM, NOME, Gio.BusNameOwnerFlags.NONE,
                     acquisito, None, lambda *_: ciclo.quit())

    def riposo():                     # nessuna richiesta da un po' e niente in corso: si spegne
        if time.monotonic() - ultima[0] > RIPOSO_S and not occupato.locked():
            ciclo.quit()
            return False
        return True
    GLib.timeout_add_seconds(15, riposo)
    ciclo.run()


if __name__ == "__main__":
    main()
