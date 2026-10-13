#!/usr/bin/env python3
"""SOLO NELLA VM DI PROVA. Un agente polkit finto che fa le veci di chi approva, per provare il guardiano vero.
Gira nella sessione locale (tty1, accesso automatico dell'utente di prova): polkit chiede la password solo alle
sessioni locali e attive, non a ssh. Ascolta su /tmp/prova-guardiano.sock richieste come
  {"azione": "installa", "parametri": {...}, "risposta": "giusta" | "sbagliata" | "annulla"}
le manda al guardiano (dal suo processo, quindi dalla sessione locale) e quando polkit chiede la password risponde
come detto: la password giusta la legge da ~/.password-prova. Restituisce la risposta del guardiano e la frase
che la finestra della password avrebbe mostrato."""
import json, os, socket, threading
from pathlib import Path

import gi
gi.require_version("Polkit", "1.0")
gi.require_version("PolkitAgent", "1.0")
from gi.repository import Gio, GLib, GObject, Polkit, PolkitAgent

PASSWORD = (Path.home() / ".password-prova").read_text().strip()
STATO = {"risposta": "giusta", "visto": []}


class Agente(PolkitAgent.Listener):
    def do_initiate_authentication(self, action_id, message, icon_name, details, cookie, identities, cancellable,
                                   callback, user_data):
        task = Gio.Task.new(self, cancellable, callback, user_data)
        STATO["visto"].append({"azione": action_id, "messaggio": message,
                               "identita": [i.to_string() for i in identities]})
        if STATO["risposta"] == "annulla":
            task.return_error(GLib.Error.new_literal(Polkit.error_quark(), "annullata", int(Polkit.Error.CANCELLED)))
            return
        identita = next((i for i in identities if isinstance(i, Polkit.UnixUser) and i.get_uid() == os.getuid()),
                        identities[0])
        sessione = PolkitAgent.Session.new(identita, cookie)

        def richiesta(s, prompt, echo):
            s.response(PASSWORD if STATO["risposta"] == "giusta" else "sbagliatissima")

        def finita(s, ottenuta):
            STATO["visto"][-1]["ottenuta"] = bool(ottenuta)
            task.return_boolean(True)

        sessione.connect("request", richiesta)
        sessione.connect("completed", finita)
        sessione.initiate()

    def do_initiate_authentication_finish(self, res):
        return res.propagate_boolean()


def guardiano(azione, parametri):
    bus = Gio.bus_get_sync(Gio.BusType.SYSTEM, None)
    r = bus.call_sync("org.cielos.Guardiano", "/org/cielos/Guardiano", "org.cielos.Guardiano1", "Esegui",
                      GLib.Variant("(ss)", (azione, json.dumps(parametri))), GLib.VariantType("(s)"),
                      Gio.DBusCallFlags.NONE, 3600 * 1000, None)
    return json.loads(r.unpack()[0])


def servi(conn):
    with conn:
        d = json.loads(conn.makefile().readline())
        STATO["risposta"] = d.get("risposta", "giusta")
        STATO["visto"] = []
        try:
            r = guardiano(d["azione"], d.get("parametri", {}))
        except GLib.Error as e:
            r = {"errore": e.message}
        conn.sendall((json.dumps({"guardiano": r, "agente": STATO["visto"]}, ensure_ascii=False) + "\n").encode())


def main():
    agente = Agente()
    soggetto = Polkit.UnixSession.new_for_process_sync(os.getpid(), None)
    PolkitAgent.register_listener(agente, soggetto, None)
    print("agente di prova registrato per", soggetto.to_string(), flush=True)
    p = "/tmp/prova-guardiano.sock"
    if os.path.exists(p):
        os.unlink(p)
    s = socket.socket(socket.AF_UNIX)
    s.bind(p)
    os.chmod(p, 0o600)
    s.listen()
    threading.Thread(target=lambda: [threading.Thread(target=servi, args=(s.accept()[0],), daemon=True).start()
                                     for _ in iter(int, 1)], daemon=True).start()
    GLib.MainLoop().run()


if __name__ == "__main__":
    main()
