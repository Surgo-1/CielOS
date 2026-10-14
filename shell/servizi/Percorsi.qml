pragma Singleton
// Dove sta CielOS: installata come pacchetto è /usr/share/cielos (la sessione mette CIELOS_DIR), in sviluppo
// ~/cielos. Tutti i comandi della shell passano da qui: bin("cieltema") → <radice>/bin/cieltema.
import QtQuick
import Quickshell

Singleton {
    readonly property string radice: Quickshell.env("CIELOS_DIR") || (Quickshell.env("HOME") + "/cielos")
    function bin(nome) { return radice + "/bin/" + nome; }
}
