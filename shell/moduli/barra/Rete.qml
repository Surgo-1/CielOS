// La rete: cavo, Wi-Fi o niente. Chiede a NetworkManager solo quando qualcosa cambia (nmcli monitor).
// Mouse sopra (o clic): una schedina accanto alla barra con le connessioni attive (nome, indirizzo) e «Impostazioni di rete».
import QtQuick
import Quickshell
import Quickshell.Io
import qs.servizi

Icona {
    id: r
    property string tipo: ""            // "ethernet", "wifi" o "" (scollegato)
    property var connessioni: []        // [{nome, tipo, ip}]
    nome: tipo === "ethernet" ? "lan" : tipo === "wifi" ? "wifi" : "wifi_off"
    colore: tipo ? Tema.oroChiaro : Tema.allarme
    dimensione: 19

    onPremuto: riquadro.alterna()

    Process {
        id: leggi
        // una riga per connessione attiva: nome|tipo|indirizzo
        command: ["sh", "-c", "nmcli -t -f NAME,TYPE,DEVICE connection show --active | while IFS=: read n t d; do " +
                  "[ \"$t\" = loopback ] && continue; echo \"$n|$t|$(nmcli -g IP4.ADDRESS device show \"$d\" | head -1)\"; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                r.connessioni = text.trim().split("\n").filter(x => x).map(x => {
                    const p = x.split("|");
                    return { nome: p[0], tipo: p[1].includes("wireless") ? "wifi" : p[1].includes("ethernet") ? "ethernet" : p[1], ip: p[2] || "" };
                });
                r.tipo = r.connessioni.some(c => c.tipo === "ethernet") ? "ethernet" : r.connessioni.some(c => c.tipo === "wifi") ? "wifi" : "";
            }
        }
    }
    Process {                            // nmcli monitor scrive una riga a ogni cambiamento
        running: true
        command: ["nmcli", "monitor"]
        stdout: SplitParser { onRead: _ => { if (!leggi.running) leggi.running = true; } }
    }
    Component.onCompleted: leggi.running = true

    Schedina {
        id: riquadro
        icona: r
        titolo: "Rete"
        onApertaChanged: if (aperta && !leggi.running) leggi.running = true

        Text {
            visible: r.connessioni.length === 0
            text: "Nessuna connessione."
            color: Tema.tenue; font.family: Tema.font; font.pixelSize: 14
        }
        Repeater {
            model: r.connessioni
            Row {
                required property var modelData
                spacing: 10
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData.tipo === "wifi" ? "wifi" : modelData.tipo === "ethernet" ? "lan" : "hub"
                    font.family: Tema.icone; font.pixelSize: 20; color: Tema.oroChiaro
                }
                Column {
                    Text {
                        text: modelData.nome
                        color: Tema.testo; font.family: Tema.font; font.pixelSize: 14
                        width: 230; elide: Text.ElideRight
                    }
                    Text {
                        visible: text !== ""
                        text: modelData.ip.replace(/\/\d+$/, "")
                        color: Tema.tenue; font.family: Tema.font; font.pixelSize: 12
                    }
                }
            }
        }
        Bottone {
            icona: "settings"; testo: "Impostazioni di rete"
            onPremuto: { riquadro.aperta = false; Avvia.comando("nm-connection-editor", ["nm-connection-editor"]); }
        }
    }
}
