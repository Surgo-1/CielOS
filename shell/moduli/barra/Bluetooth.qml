// Il bluetooth nella barra: acceso o spento, e i dispositivi. Lo stato arriva da Quickshell.Bluetooth (D-Bus di
// BlueZ): niente processi e niente sondaggi, la schedina si aggiorna da sola quando qualcosa cambia (un dispositivo
// che entra, la batteria che scende). Mouse sopra (o clic): una schedina con lo stato, i dispositivi — un clic li
// collega o li stacca — e «Cerca», per quelli nuovi.
import QtQuick
import Quickshell
import Quickshell.Bluetooth as Bt
import qs.servizi

Icona {
    id: b
    readonly property var adattatore: Bt.Bluetooth.defaultAdapter
    readonly property bool presente: !!adattatore               // senza adattatore la barra non mostra niente
    readonly property bool acceso: !!adattatore && adattatore.enabled
    // i collegati per primi, poi i conosciuti, e in fondo quelli visti con una ricerca
    readonly property var dispositivi: {
        const d = adattatore ? (adattatore.devices?.values ?? []) : [];
        return [...d].sort((x, y) => (y.connected ? 1 : 0) - (x.connected ? 1 : 0) || (y.paired ? 1 : 0) - (x.paired ? 1 : 0));
    }
    readonly property int collegati: dispositivi.filter(d => d.connected).length
    nome: !acceso ? "bluetooth_disabled" : collegati > 0 ? "bluetooth_connected" : "bluetooth"
    colore: acceso ? (collegati > 0 ? Tema.oro : Tema.oroChiaro) : Tema.tenue
    dimensione: 19

    // il disegno del dispositivo: l'icona che manda BlueZ, tradotta in un simbolo Material
    function icona(d) {
        const i = d?.icon ?? "";
        if (i.startsWith("audio-headset")) return "headset";
        if (i.startsWith("audio-headphones")) return "headphones";
        if (i.startsWith("audio")) return "speaker";
        if (i.startsWith("input-keyboard")) return "keyboard";
        if (i.startsWith("input-mouse")) return "mouse";
        if (i.startsWith("input-gaming")) return "sports_esports";
        if (i.startsWith("input-tablet")) return "tablet";
        if (i.startsWith("phone")) return "smartphone";
        if (i.startsWith("computer")) return "laptop";
        if (i.startsWith("printer")) return "print";
        return "bluetooth";
    }
    function stato(d) {
        if (d.batteryAvailable) return d.connected ? Lingua.t("collegato · %1%", Math.round(d.battery * 100))
                                                   : Lingua.t("conosciuto · %1%", Math.round(d.battery * 100));
        return d.connected ? Lingua.t("collegato") : d.paired ? Lingua.t("conosciuto") : Lingua.t("non accoppiato");
    }

    onPremuto: riquadro.alterna()

    Schedina {
        id: riquadro
        icona: b
        titolo: Lingua.t("Bluetooth")
        larghezza: 330

        Text {
            width: parent.width
            wrapMode: Text.WordWrap
            text: !b.presente ? Lingua.t("Questo PC non ha il bluetooth.")
                 : b.acceso ? ((b.adattatore.name || Lingua.t("acceso")) + (b.collegati > 0 ? " · " + b.collegati + " " + Lingua.t("collegati") : ""))
                 : Lingua.t("spento")
            color: b.acceso ? Tema.testo : Tema.tenue
            font.family: Tema.font; font.pixelSize: 14
        }

        Bottone {
            visible: b.presente
            icona: b.acceso ? "bluetooth_disabled" : "bluetooth"
            testo: b.acceso ? Lingua.t("Spegni il bluetooth") : Lingua.t("Accendi il bluetooth")
            onPremuto: if (b.adattatore) b.adattatore.enabled = !b.adattatore.enabled
        }

        Rectangle { visible: b.presente && b.dispositivi.length > 0; width: parent.width; height: 1; color: Tema.bordoTenue }

        Repeater {
            model: b.dispositivi
            Rectangle {
                required property var modelData
                width: parent.width
                height: 40
                radius: Tema.raggioPiccolo
                color: tocco.containsMouse ? Tema.accentoSoft : "transparent"
                Behavior on color { ColorAnimation { duration: Tema.durata } }
                Row {
                    anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
                    spacing: 10
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: b.icona(modelData); font.family: Tema.icone; font.pixelSize: 19
                        color: modelData.connected ? Tema.oro : Tema.tenue
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 0
                        Text {
                            width: 186; elide: Text.ElideRight
                            text: modelData.name || modelData.address
                            color: Tema.testo; font.family: Tema.font; font.pixelSize: 13
                        }
                        Text {
                            text: b.stato(modelData)
                            color: modelData.connected ? Tema.oro : Tema.tenue
                            font.family: Tema.font; font.pixelSize: 11
                        }
                    }
                }
                Text {
                    anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                    text: modelData.connected ? Lingua.t("stacca") : Lingua.t("collega")
                    color: tocco.containsMouse ? Tema.oro : Tema.tenue
                    font.family: Tema.font; font.pixelSize: 11
                }
                MouseArea {
                    id: tocco
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: b.acceso
                    cursorShape: Qt.PointingHandCursor
                    onClicked: modelData.connected ? modelData.disconnect() : modelData.connect()
                }
            }
        }

        Text {
            visible: b.presente && b.acceso && b.dispositivi.length === 0
            text: Lingua.t("Nessun dispositivo conosciuto. «Cerca» quelli vicini.")
            color: Tema.tenue; font.family: Tema.font; font.pixelSize: 13
        }

        Row {
            visible: b.presente
            width: parent.width
            spacing: 8
            Bottone {
                width: (parent.width - 8) / 2
                icona: b.adattatore?.discovering ? "bluetooth_searching" : "search"
                testo: b.adattatore?.discovering ? Lingua.t("Cerco…") : Lingua.t("Cerca")
                onPremuto: if (b.adattatore && !b.adattatore.discovering) { b.adattatore.discovering = true; cerca.restart(); }
            }
            Bottone {
                width: (parent.width - 8) / 2
                icona: "settings"
                testo: Lingua.t("Impostazioni")
                onPremuto: {
                    riquadro.aperta = false;
                    Quickshell.execDetached(["qs", "-c", "ciel", "ipc", "call", "impostazioni", "sezione", "bluetooth"]);
                }
            }
        }

        // la ricerca non si lascia accesa per sempre: si spegne da sola (BlueZ continua a scandagliare finché
        // qualcuno glielo dice, e la radio resta accesa)
        Timer { id: cerca; interval: 12000; onTriggered: if (b.adattatore) b.adattatore.discovering = false }
    }
}
