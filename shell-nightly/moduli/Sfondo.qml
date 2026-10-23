// Lo sfondo della Nightly: il vuoto, con una griglia appena visibile e un alone in alto. Niente sfocature e niente
// animazioni: costa quasi zero (un gradiente e qualche linea). Se in CielOS hai scelto un'immagine, quella resta.
import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.servizi

Variants {
    model: Pannelli.prova ? [] : Quickshell.screens

    PanelWindow {
        required property ShellScreen modelData
        screen: modelData
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "nightly-sfondo"
        color: Tema.vuoto

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0; color: Tema.vuotoAlto }
                GradientStop { position: 0.55; color: Tema.vuoto }
                GradientStop { position: 1; color: "#02030a" }
            }
        }

        Image {
            anchors.fill: parent
            visible: Tema.sfondoImmagine !== ""
            source: Tema.sfondoImmagine ? "file://" + Tema.sfondoImmagine : ""
            sourceSize: Qt.size(parent.width, parent.height)
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            opacity: 0.55
        }

        // la griglia: una linea ogni 96 px, appena percettibile
        Item {
            anchors.fill: parent
            opacity: 0.16
            Repeater {
                model: Math.ceil(width / 96)
                Rectangle {
                    required property int index
                    x: index * 96; y: 0; width: 1; height: parent.height
                    color: Tema.alfa(Tema.ciano, 0.10)
                }
            }
            Repeater {
                model: Math.ceil(height / 96)
                Rectangle {
                    required property int index
                    x: 0; y: index * 96; width: parent.width; height: 1
                    color: Tema.alfa(Tema.ciano, 0.10)
                }
            }
        }

        // l'alone: la luce che arriva da fuori schermo, dentro lo stesso gradiente (niente un'altra superficie)
        Rectangle {
            anchors.fill: parent
            opacity: 0.5
            gradient: Gradient {
                GradientStop { position: 0; color: Tema.alfa(Tema.ciano, 0.06) }
                GradientStop { position: 0.35; color: "transparent" }
                GradientStop { position: 1; color: "transparent" }
            }
        }
    }
}
