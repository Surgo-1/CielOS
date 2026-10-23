pragma Singleton
// Lo stato della rete in un posto solo: le barre (una per schermo) leggono da qui invece di avere ognuna il suo
// «nmcli monitor» e la sua query. Un processo solo, qualunque sia il numero di monitor; si aggiorna quando
// NetworkManager dice che qualcosa è cambiato (nessun polling).
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: stato

    property var connessioni: []        // [{nome, tipo, ip}]
    property string tipo: ""            // "ethernet", "wifi" o "" (scollegato)
    property bool pronta: false

    function aggiorna() {
        if (!leggi.running) leggi.running = true;
    }

    Process {
        id: leggi
        // una riga per connessione attiva: nome|tipo|indirizzo
        command: ["sh", "-c", "nmcli -t -f NAME,TYPE,DEVICE connection show --active | while IFS=: read n t d; do " +
                  "[ \"$t\" = loopback ] && continue; echo \"$n|$t|$(nmcli -g IP4.ADDRESS device show \"$d\" | head -1)\"; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                stato.connessioni = text.trim().split("\n").filter(x => x).map(x => {
                    const p = x.split("|");
                    return { nome: p[0], tipo: p[1].includes("wireless") ? "wifi" : p[1].includes("ethernet") ? "ethernet" : p[1],
                             ip: p[2] || "" };
                });
                stato.tipo = stato.connessioni.some(c => c.tipo === "ethernet") ? "ethernet"
                           : stato.connessioni.some(c => c.tipo === "wifi") ? "wifi" : "";
                stato.pronta = true;
            }
        }
    }
    Process {                            // nmcli monitor scrive una riga a ogni cambiamento
        running: true
        command: ["setpriv", "--pdeathsig", "TERM", "nmcli", "monitor"]     // muore con la shell (niente orfani ai riavvii)
        stdout: SplitParser { onRead: _ => stato.aggiorna() }
    }
    Component.onCompleted: aggiorna()
}
