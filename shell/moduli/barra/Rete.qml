// La rete: cavo, Wi-Fi o niente. Chiede a NetworkManager solo quando qualcosa cambia (nmcli monitor).
import QtQuick
import Quickshell.Io
import qs.servizi

Icona {
    id: r
    property string tipo: ""            // "ethernet", "wifi" o "" (scollegato)
    nome: tipo === "ethernet" ? "lan" : tipo === "wifi" ? "wifi" : "wifi_off"
    colore: tipo ? Tema.oroChiaro : Tema.allarme
    dimensione: 19

    Process {
        id: leggi
        command: ["nmcli", "-t", "-f", "TYPE,STATE", "device"]
        stdout: StdioCollector {
            onStreamFinished: {
                const righe = text.split("\n").map(x => x.split(":")).filter(x => x[1] === "connected");
                r.tipo = righe.some(x => x[0] === "ethernet") ? "ethernet" : righe.some(x => x[0] === "wifi") ? "wifi" : "";
            }
        }
    }
    Process {                            // nmcli monitor scrive una riga a ogni cambiamento
        running: true
        command: ["nmcli", "monitor"]
        stdout: SplitParser { onRead: _ => { if (!leggi.running) leggi.running = true; } }
    }
    Component.onCompleted: leggi.running = true
}
