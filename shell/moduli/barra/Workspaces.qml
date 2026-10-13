// I workspace dello schermo: dieci per schermo (il gruppo di quello attivo: qui 1-10 sul principale, 11-20
// sull'altro). Oro allungato = quello che guardi, pieno = con finestre, vuoto = libero. Rotella: avanti e indietro.
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
            readonly property bool pieno: Hyprland.workspaces.values.some(w => w.id === numero && w.toplevels.values.length > 0)
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
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: ws.vai(punto.numero)
            }
        }
    }

    }
}
