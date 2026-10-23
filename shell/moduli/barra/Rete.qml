// La rete: cavo, Wi-Fi o niente. Lo stato arriva da qs.servizi.ReteStato (un solo nmcli monitor per tutta la shell,
// non uno per schermo); si rilegge quando NetworkManager dice che qualcosa è cambiato.
// Mouse sopra (o clic): una schedina accanto alla barra con le connessioni attive (nome, indirizzo) e «Impostazioni di rete».
import QtQuick
import Quickshell
import Quickshell.Io
import qs.servizi

Icona {
    id: r
    readonly property string tipo: ReteStato.tipo            // "ethernet", "wifi" o "" (scollegato)
    readonly property var connessioni: ReteStato.connessioni // [{nome, tipo, ip}]
    nome: tipo === "ethernet" ? "lan" : tipo === "wifi" ? "wifi" : "wifi_off"
    colore: tipo ? Tema.oroChiaro : Tema.allarme
    dimensione: 19

    onPremuto: riquadro.alterna()



    Schedina {
        id: riquadro
        icona: r
        titolo: Lingua.t("Rete")
        onApertaChanged: if (aperta) ReteStato.aggiorna()

        Text {
            visible: r.connessioni.length === 0
            text: Lingua.t("Nessuna connessione.")
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
            icona: "settings"; testo: Lingua.t("Impostazioni di rete")
            onPremuto: {
                riquadro.aperta = false;
                // le impostazioni di CielOS, direttamente sulla pagina Rete (non il programma di GNOME)
                Quickshell.execDetached(["qs", "-c", "ciel", "ipc", "call", "impostazioni", "sezione", "rete"]);
            }
        }
    }
}
