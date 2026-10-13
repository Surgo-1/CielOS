// I workspace dello schermo: dieci per schermo (il gruppo di quello attivo: qui 1-10 sul principale, 11-20
// sull'altro). Oro allungato = quello che guardi, pieno = con finestre, vuoto = libero. Rotella: avanti e indietro.
// Mouse sopra un punto: le finestre di quel workspace (clic su una per andarci).
import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.servizi

Item {
    id: ws
    required property ShellScreen schermo
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(schermo)
    readonly property int attivo: monitor?.activeWorkspace?.id ?? 1
    readonly property int base: Math.floor((Math.max(1, attivo) - 1) / 10) * 10
    implicitWidth: colonna.implicitWidth
    implicitHeight: colonna.implicitHeight

    function vai(n) { Pannelli.dispatch(`hl.dsp.focus({ workspace = ${n} })`, `workspace ${n}`); }

    MouseArea {                         // la rotella su tutta la colonna
        anchors.fill: parent
        acceptedButtons: Qt.NoButton
        onWheel: r => Pannelli.dispatch(`hl.dsp.focus({ workspace = "r${r.angleDelta.y > 0 ? "-" : "+"}1" })`,
                                        `workspace r${r.angleDelta.y > 0 ? "-" : "+"}1`)
    }

    Column {
    id: colonna
    spacing: 7
    Repeater {
        model: 10
        Item {
            id: punto
            required property int index
            readonly property int numero: ws.base + index + 1
            readonly property bool qui: numero === ws.attivo
            readonly property var spazio: Hyprland.workspaces.values.find(w => w.id === numero)
            readonly property var finestre: spazio ? spazio.toplevels.values : []
            readonly property bool pieno: finestre.length > 0
            readonly property bool sopra: tocco.containsMouse
            width: Tema.barra - 20
            height: qui ? 26 : 12
            Behavior on height { NumberAnimation { duration: Tema.durata; easing.type: Easing.OutCubic } }

            Rectangle {
                anchors.centerIn: parent
                width: punto.qui ? 8 : punto.pieno ? 8 : 7
                height: punto.qui ? parent.height : width
                radius: width / 2
                color: punto.qui ? Tema.oro : punto.pieno ? Tema.tenue : "transparent"
                border.width: punto.qui || punto.pieno ? 0 : 1.5
                border.color: Qt.rgba(0.6, 0.65, 0.78, 0.6)
            }
            MouseArea {
                id: tocco
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: { scheda.aperta = false; ws.vai(punto.numero); }
            }
            Schedina {
                id: scheda
                icona: punto
                inAlto: true
                larghezza: 280
                titolo: "Workspace " + punto.numero
                Text {
                    visible: !punto.pieno
                    text: "Vuoto."
                    color: Tema.tenue; font.family: Tema.font; font.pixelSize: 13
                }
                Repeater {
                    model: punto.finestre
                    Bottone {
                        required property var modelData
                        readonly property string classe: modelData.lastIpcObject?.class ?? ""
                        icona: "web_asset"
                        testo: {
                            const t = modelData.title || classe;
                            return t.length > 32 ? t.slice(0, 31) + "…" : t;
                        }
                        onPremuto: {
                            scheda.aperta = false;
                            const a = String(modelData.address).startsWith("0x") ? modelData.address : "0x" + modelData.address;
                            Pannelli.dispatch(`hl.dsp.focus({ window = "address:${a}" })`, `focuswindow address:${a}`);
                        }
                    }
                }
            }
        }
    }

    }
}
