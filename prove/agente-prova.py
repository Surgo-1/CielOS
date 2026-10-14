#!/usr/bin/env python3
"""SOLO NELLA VM DI PROVA. Fa le veci di chi approva, per provare il guardiano vero con polkit vero.
Gira nella sessione locale (tty1, accesso automatico dell'utente di prova): polkit chiede la password solo alle
sessioni locali e attive, non a ssh. Ascolta su /tmp/prova-guardiano.sock richieste come
  {"azione": "installa", "parametri": {...}, "risposta": "giusta" | "sbagliata" | "annulla"}
Per ognuna avvia l'agente testuale ufficiale di polkit (pkttyagent) registrato per la propria connessione al bus,
su un terminale finto: quando chiede la password risponde come detto (la giusta la legge da ~/.password-prova),
poi manda la richiesta al guardiano e restituisce la sua risposta e cosa ha mostrato l'agente.
(Un agente scritto in Python con PolkitAgent andava in crash dentro libpolkit-agent: 14/10.)"""
import json, os, pty, select, signal, socket, threading, time
from pathlib import Path

import gi
gi.require_version("Gio", "2.0")
from gi.repository import Gio, GLib

PASSWORD = (Path.home() / ".password-prova").read_text().strip()


def agente(nome_bus, risposta, visto, pronto, fine):
    """pkttyagent su un terminale finto; risponde alla domanda della password. Finisce quando fine è impostato."""
    pid, fd = pty.fork()
    if pid == 0:
        # senza opzioni si registra per la sessione (tty1, locale): vale per le richieste di questo processo
        os.execvp("pkttyagent", ["pkttyagent"])
    testo, risposto = "", False
    t0 = time.monotonic()
    while not fine.is_set():
        if not pronto.is_set() and time.monotonic() - t0 > 1.0:     # il tempo di registrarsi
            pronto.set()
        r, _, _ = select.select([fd], [], [], 0.2)
        if not r:
            continue
        try:
            dati = os.read(fd, 4096).decode(errors="replace")
        except OSError:
            break
        testo += dati
        if not risposto and "assword" in testo:
            risposto = True
            time.sleep(0.5)          # pkttyagent toglie l'eco e svuota l'input: scrivere prima la farebbe perdere
            if risposta == "annulla":
                os.write(fd, b"\x04")                              # fine dell'input: nessuna password
            else:
                os.write(fd, ((PASSWORD if risposta == "giusta" else "sbagliatissima") + "\n").encode())
    try:
        os.kill(pid, signal.SIGTERM)
        os.waitpid(pid, 0)
    except OSError:
        pass
    visto.append(testo.replace("\r", "").replace(PASSWORD, "●●●●").strip()[-600:])


def servi(conn):
    with conn:
        d = json.loads(conn.makefile().readline())
        bus = Gio.DBusConnection.new_for_address_sync(
            Gio.dbus_address_get_for_bus_sync(Gio.BusType.SYSTEM, None),
            Gio.DBusConnectionFlags.AUTHENTICATION_CLIENT | Gio.DBusConnectionFlags.MESSAGE_BUS_CONNECTION, None, None)
        visto, pronto, fine = [], threading.Event(), threading.Event()
        t = threading.Thread(target=agente, args=(bus.get_unique_name(), d.get("risposta", "giusta"), visto, pronto, fine))
        t.start()
        pronto.wait(5)
        try:
            r = bus.call_sync("org.cielos.Guardiano", "/org/cielos/Guardiano", "org.cielos.Guardiano1", "Esegui",
                              GLib.Variant("(ss)", (d["azione"], json.dumps(d.get("parametri", {})))),
                              GLib.VariantType("(s)"), Gio.DBusCallFlags.NONE, 3600 * 1000, None)
            r = json.loads(r.unpack()[0])
        except GLib.Error as e:
            r = {"errore": e.message}
        fine.set()
        t.join()
        bus.close_sync(None)
        if d["azione"] != "istantanee":
            r.pop("uscita", None)
        conn.sendall((json.dumps({"guardiano": r, "agente": visto}, ensure_ascii=False) + "\n").encode())


def main():
    p = "/tmp/prova-guardiano.sock"
    if os.path.exists(p):
        os.unlink(p)
    s = socket.socket(socket.AF_UNIX)
    s.bind(p)
    os.chmod(p, 0o600)
    s.listen()
    print("pronto", flush=True)
    while True:
        c, _ = s.accept()
        try:
            servi(c)
        except Exception as e:                       # una prova andata storta non ferma le altre
            print("errore:", e, flush=True)


if __name__ == "__main__":
    main()
