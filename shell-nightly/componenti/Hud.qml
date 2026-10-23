// La superficie di base della Nightly: vetro quasi nero, un filo di luce in alto, gli angoli a mirino.
// Tutto il resto (barra, lanciatore, centro di controllo) è questo rettangolo con dentro qualcosa.
import QtQuick
import qs.servizi

Rectangle {
    id: hud
    property color accento: Tema.ciano
    property bool angoli: true
    property bool filoLuce: true
    property real angoloLungo: 13
    property real angoloDistanza: 7

    radius: Tema.raggio
    gradient: Gradient {
        GradientStop { position: 0; color: Tema.vetroAlto }
        GradientStop { position: 1; color: Tema.vetroBasso }
    }
    border.width: 1
    border.color: Tema.alfa(accento, 0.30)

    // il filo di luce: un pezzo di bordo acceso, come una spia
    Rectangle {
        visible: hud.filoLuce
        x: 14; y: 0; height: 1
        width: Math.max(24, parent.width * 0.28)
        color: Tema.alfa(hud.accento, 0.85)
    }

    // gli angoli: quattro parentesi, come un mirino
    Repeater {
        model: hud.angoli ? 4 : 0
        Item {
            required property int index
            width: hud.angoloLungo; height: hud.angoloLungo
            x: index % 2 === 0 ? hud.angoloDistanza : hud.width - width - hud.angoloDistanza
            y: index < 2 ? hud.angoloDistanza : hud.height - height - hud.angoloDistanza

            Rectangle {
                width: parent.width; height: 1; color: hud.accento; opacity: 0.75
                anchors.top: index < 2 ? parent.top : undefined
                anchors.bottom: index >= 2 ? parent.bottom : undefined
            }
            Rectangle {
                width: 1; height: parent.height; color: hud.accento; opacity: 0.75
                anchors.left: index % 2 === 0 ? parent.left : undefined
                anchors.right: index % 2 === 1 ? parent.right : undefined
            }
        }
    }
}
